extends Control

@export var debug: bool = true

@onready var video_playback: VideoPlayback = %VideoPlayback
@onready var viewport: SubViewport = %SubViewport


var renderer: Renderer

var audio_stream: AudioStreamWAV
var profile: Dictionary

var error: int = 0


func _ready() -> void:
	print(Renderer.get_available_codecs(Renderer.V_H264))

	if get_window().files_dropped.connect(_on_video_drop):
		printerr("Couldn't connect files_dropped!")
	if video_playback._on_video_loaded.connect(_on_video_loaded):
		printerr("Couldn't connect _on_video_loaded!")


func _on_video_drop(a_files: PackedStringArray) -> void:
	video_playback.debug = true
	video_playback.set_video_path(a_files[0])


func _on_video_loaded() -> void:
	var l_time: int = Time.get_ticks_usec()

	audio_stream = video_playback.video.get_audio()

	renderer = Renderer.new()
	renderer.set_framerate(video_playback.video.get_framerate())
	renderer.set_resolution(video_playback.video.get_resolution())
	renderer.set_bit_rate(4000000)
	renderer.set_framerate(30)
	renderer.set_path("/storage/test.mp4")
	renderer.set_video_codec_id(Renderer.VIDEO_CODEC.V_H264)
	renderer.set_audio_codec_id(Renderer.AUDIO_CODEC.A_AAC)
	renderer.set_sample_rate(audio_stream.mix_rate)
	
	await RenderingServer.frame_post_draw

	error = renderer.open()
	if error:
		print("Couldn't open renderer: %s!" % error)
		return

	print("Sending audio!")
	var l_audio_data: PackedByteArray = audio_stream.data
	var l_mix_rate: int = audio_stream.mix_rate
	if renderer.send_audio(l_audio_data, l_mix_rate):
		printerr("Something went wrong sending audio!")
		return

	print("Sending frames!")
	for l_frame_nr: int in video_playback.get_video_frame_duration() + 1:
		if l_frame_nr == 0:
			video_playback.seek_frame(0)
		else:
			video_playback.next_frame()

		await RenderingServer.frame_post_draw

		if renderer.send_frame(viewport.get_texture().get_image()):
			print("Something went wrong sending frame!")
	
	if renderer.close():
		print("Something went wrong closing renderer!")

	print("Video got rendered in: ", Time.get_ticks_usec() - l_time)
