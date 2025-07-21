class_name VideoPlayback
extends Control
## Video playback and seeking inside of Godot.
##
## To use this node, just add it anywhere and resize it to the desired size. Use the function [code]set_video_path(new_path)[/code] and the video will load. Take in mind that long video's can take a second or longer to load. If this is an issue you can preload the Video on startup of your project and set the video variable yourself, just remember to use the function [code]update_video()[/code] before the moment that you'd like to use it.


signal frame_changed(frame_nr: int) ## Emitted when the current frame has changed, for showing and skipped frames.
signal next_frame_called(frame_nr: int) ## Emitted when a new frame is showing.

signal video_loaded ## Emitted when the video is ready for playback.
signal video_ended ## Emitted when the last frame has been shown.

signal playback_started ## Emitted when playback started/resumed.
signal playback_paused ## Emitted when playback is paused.
signal playback_ready ## Emitted when the node if fully setup and ready for playback.


const PLAYBACK_SPEED_MIN: float = 0.25
const PLAYBACK_SPEED_MAX: float = 4


@export_file var path: String = "": set = set_video_path ## Full path to video file.
@export var enable_audio: bool = true ## Enable/Disable audio playback. When setting this on false before loading the audio, the audio playback won't be loaded meaning that the video will load faster. If you want audio but only disable it at certain moments, switch this value to false *after* the video is loaded.
@export var enable_auto_play: bool = false ## Enable/disable auto video playback.
@export_range(PLAYBACK_SPEED_MIN, PLAYBACK_SPEED_MAX, 0.05)
var playback_speed: float = 1.0: set = set_playback_speed ## Adjust the video playback speed, 0.5 = half the speed and 2 = double the speed.
@export var pitch_adjust: bool = true: set = set_pitch_adjust ## When changing playback speed, do you want the pitch to change or stay the same?
@export var loop: bool = false ## Enable/disable looping on video_ended.
@export var debug: bool = false ## Enable/disable the printing of debug info.

var video: GoZenVideo = null ## Video class object of GDE GoZen which interacts with video files through FFmpeg.

var video_texture: TextureRect = TextureRect.new() ## The texture rect is the view of the video, you can adjust the scaling options as you like, it is set to always center and scale the image to fit within the main VideoPlayback node size.
var audio_player: AudioStreamPlayer = AudioStreamPlayer.new() ## Audio player is the AudioStreamPlayer which handles the audio playback for the video, only mess with the settings if you know what you are doing and know what you'd like to achieve.

var is_playing: bool = false ## Bool to check if the video is currently playing or not.
var current_frame: int = 0: set = _set_current_frame ## Current frame number which the video playback is at.

var _time_elapsed: float = 0.
var _frame_time: float = 0
var _skips: int = 0

var _rotation: int = 0
var _padding: int = 0
var _frame_rate: float = 0.
var _frame_count: int = 0

var _resolution: Vector2i = Vector2i.ZERO
var _shader_material: ShaderMaterial = null

var _threads: PackedInt64Array = []
var _audio_pitch_effect: AudioEffectPitchShift = AudioEffectPitchShift.new()

var y_texture: ImageTexture;
var u_texture: ImageTexture;
var v_texture: ImageTexture;




#------------------------------------------------ TREE FUNCTIONS
func _enter_tree() -> void:
	_shader_material = ShaderMaterial.new()

	video_texture.material = _shader_material
	video_texture.texture = ImageTexture.new()
	video_texture.anchor_right = TextureRect.ANCHOR_END
	video_texture.anchor_bottom = TextureRect.ANCHOR_END
	video_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	video_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	add_child(video_texture)
	add_child(audio_player)

	AudioServer.add_bus()
	audio_player.bus = AudioServer.get_bus_name(AudioServer.bus_count - 1)
	AudioServer.add_bus_effect(AudioServer.bus_count - 1, _audio_pitch_effect)

	if debug:
		_print_system_debug()


func _exit_tree() -> void:
	if video != null:
		close()
	
	AudioServer.remove_bus(AudioServer.get_bus_index(audio_player.bus))


func _ready() -> void:
	playback_ready.emit()


#------------------------------------------------ VIDEO DATA HANDLING
func set_video_path(new_path: String) -> void:
	## This is the starting point for video playback, provide a path of where
	## the video file can be found and it will load a Video object. After which
	## [code]_update_video()[/code] get's run and set's the first frame image.
	if video != null:
		close()

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.mix_rate = 44100
	stream.stereo = true
	stream.format = AudioStreamWAV.FORMAT_16_BITS

	audio_player.stream = stream

	path = new_path
	if path == "":
		return
	elif path.begins_with("res://") or path.begins_with("user://"):
		print("Path's with 'res://' don't work, globalizing path '%s' ...", % path)
		path = ProjectSettings.globalize_path(new_path)
		print("New path: ", path)


	video = GoZenVideo.new()
	if debug:
		video.enable_debug()
	else:
		video.disable_debug()

	if !is_node_ready():
		await ready

	_threads.append(WorkerThreadPool.add_task(_open_video))
	if enable_audio:
		_threads.append(WorkerThreadPool.add_task(_open_audio))


func update_video(video_instance: GoZenVideo, audio_stream: AudioStreamWAV = null) -> void:
	if video != null:
		close()

	audio_player.stream = audio_stream
	_update_video(video_instance)


func _update_video(new_video: GoZenVideo) -> void:
	## Only run this function after manually having added a Video object to the `video` variable. A good reason for doing this is to load your video's at startup time to prevent your program for freezing for a second when loading in big video files. Some video formats load faster then others so if you are experiencing issues with long loading times, try to use this function and create the video object on startup, or try switching the video format which you are using. 
	video = new_video
	if !is_open():
		printerr("Video isn't open!")
		return

	var image: Image
	var rotation_radians: float = deg_to_rad(float(video.get_rotation()))

	_padding = video.get_padding()
	_rotation = video.get_rotation()
	_frame_rate = video.get_framerate()
	_resolution = video.get_resolution()
	_frame_count = video.get_frame_count()

	if abs(_rotation) == 90:
		image = Image.create_empty(_resolution.y, _resolution.x, false, Image.FORMAT_R8)
	else:
		image = Image.create_empty(_resolution.x, _resolution.y, false, Image.FORMAT_R8)

	image.fill(Color.BLACK)

	if debug:
		_print_video_debug()

	video_texture.texture.set_image(image)
	if video.is_full_color_range():
		if video.get_interlaced() == 0:
			_shader_material.shader = preload("res://addons/gde_gozen/shaders/yuv420p_full.gdshader")
		else:
			_shader_material.shader = preload("res://addons/gde_gozen/shaders/deinterlace_yuv420p_full.gdshader")
	elif video.get_interlaced() == 0:
		_shader_material.shader = preload("res://addons/gde_gozen/shaders/yuv420p_standard.gdshader")
		_shader_material.shader = preload("res://addons/gde_gozen/shaders/yuv420p_standard.tres")
		_shader_material.set_shader_parameter("interlaced", video.get_interlaced())
	else:
		_shader_material.shader = preload("res://addons/gde_gozen/shaders/deinterlace_yuv420p_standard.gdshader")
		_shader_material.set_shader_parameter("interlaced", video.get_interlaced())

	match video.get_color_profile():
		"bt601", "bt470": _shader_material.set_shader_parameter("color_profile", Vector4(1.402, 0.344136, 0.714136, 1.772))
		"bt2020", "bt2100": _shader_material.set_shader_parameter("color_profile", Vector4(1.4746, 0.16455, 0.57135, 1.8814))
		_: # bt709 and unknown
			_shader_material.set_shader_parameter("color_profile", Vector4(1.5748, 0.1873, 0.4681, 1.8556))

	# Applying shader params.
	_shader_material.set_shader_parameter("resolution", video.get_actual_resolution())
	_shader_material.set_shader_parameter("rotation", rotation_radians)

	is_playing = false
	set_playback_speed(playback_speed)
	current_frame = 0

	if(!y_texture):
		y_texture = ImageTexture.create_from_image(video.get_y_data())
		u_texture = ImageTexture.create_from_image(video.get_u_data())
		v_texture = ImageTexture.create_from_image(video.get_v_data())

	_shader_material.set_shader_parameter("y_data", y_texture)
	_shader_material.set_shader_parameter("u_data", u_texture)
	_shader_material.set_shader_parameter("v_data", v_texture)

	seek_frame(current_frame)

	video_loaded.emit()


func seek_frame(new_frame_nr: int) -> void:
	## Seek frame can be used to switch to a frame number you want. Remember that some video codecs report incorrect video end frames or can't seek to the last couple of frames in a video file which may result in an error. Only use this when going to far distances in the video file, else you can use [code]next_frame()[/code].
	if !is_open() and new_frame_nr == current_frame:
		return

	current_frame = clamp(new_frame_nr, 0, _frame_count)
	if video.seek_frame(new_frame_nr):
		printerr("Couldn't seek frame!")
	else:
		_set_frame_image()

	if enable_audio:
		audio_player.set_stream_paused(false)
		audio_player.play(current_frame / _frame_rate)
		audio_player.set_stream_paused(!is_playing)


func next_frame(skip: bool = false) -> void:
	## Seeking frames can be slow, so when you just need to go a couple of frames ahead, you can use next_frame and set skip to false for the last frame.
	if video.next_frame(skip) and !skip:
		_set_frame_image()
		next_frame_called.emit(current_frame)
	elif !skip:
		print("Something went wrong getting next frame!")

	
func close() -> void:
	if video != null:
		if is_playing:
			pause()

		video = null

		y_texture = null
		u_texture = null
		v_texture = null


#------------------------------------------------ PLAYBACK HANDLING
func _process(delta: float) -> void:
	if !_threads.is_empty():
		for i: int in _threads:
			if WorkerThreadPool.is_task_completed(i):
				WorkerThreadPool.wait_for_task_completion(i)
				_threads.remove_at(_threads.find(i))

			if _threads.is_empty():
				_update_video(video)

				if enable_auto_play:
					play()
		return

	if is_playing:
		_time_elapsed += delta

		if _time_elapsed < _frame_time:
			return

		_skips = 0
		while _time_elapsed >= _frame_time:
			_time_elapsed -= _frame_time
			current_frame += 1
			_skips += 1

		if current_frame >= _frame_count:
			is_playing = !is_playing

			if enable_audio:
				audio_player.set_stream_paused(true)

			video_ended.emit()
			if loop:
				seek_frame(0)
				play()
		else:
			while _skips != 1:
				next_frame(true)
				_skips -= 1
			next_frame()


func play() -> void:
	## Start the video playback. This will play until reaching the end of the video and then pause and go back to the start.
	if video != null and !is_open() and is_playing:
		return
	is_playing = true

	if enable_audio:
		audio_player.set_stream_paused(false)
		audio_player.play((current_frame + 1) / _frame_rate)
		audio_player.set_stream_paused(!is_playing)

	playback_started.emit()


func pause() -> void:
	## Pausing the video.
	if video != null and !is_open():
		return
	is_playing = false
	
	if enable_audio:
		audio_player.set_stream_paused(true)

	playback_paused.emit()


#------------------------------------------------ GETTERS
func get_video_frame_count() -> int:
	## Getting the total amount of frames found in the video file.
	return _frame_count


func get_video_framerate() -> float:
	## Getting the framerate of the video
	return _frame_rate


func get_video_rotation() -> int:
	## Getting the rotation in degrees of the video
	return _rotation


func is_open() -> bool:
	## Checking to see if the video is open or not, trying to run functions without checking if open can crash your project.
	return video != null and video.is_open()


func _get_img_tex(image_data: PackedByteArray, width: int, height: int, r8: bool = true) -> ImageTexture:
	var format: Image.Format = Image.FORMAT_R8 if r8 else Image.FORMAT_RG8
	var image: Image = Image.create_from_data(width, height, false, format, image_data)

	return ImageTexture.create_from_image(image)

#------------------------------------------------ SETTERS
func _set_current_frame(new_current_frame: int) -> void:
	current_frame = new_current_frame
	frame_changed.emit(current_frame)


func _set_frame_image() -> void:
	y_texture.update(video.get_y_data())
	u_texture.update(video.get_u_data())
	v_texture.update(video.get_v_data())


func set_playback_speed(new_playback_value: float) -> void:
	playback_speed = clampf(new_playback_value, 0.5, 2)
	_frame_time = (1.0 / _frame_rate) / playback_speed

	if enable_audio and audio_player.stream != null:
		audio_player.pitch_scale = playback_speed
		_set_pitch_adjust()

		if is_playing:
			audio_player.play(current_frame * (1.0 / _frame_rate))


func set_pitch_adjust(new_pitch_value: bool) -> void:
	pitch_adjust = new_pitch_value
	_set_pitch_adjust()


func _set_pitch_adjust() -> void:
	if pitch_adjust:
		_audio_pitch_effect.pitch_scale = clamp(1.0 / playback_speed, 0.5, 2.0)
	elif _audio_pitch_effect.pitch_scale != 1.0:
		_audio_pitch_effect.pitch_scale = 1.0



#------------------------------------------------ MISC
func _open_video() -> void:
	if video.open(path):
		printerr("Error opening video!")


func _open_audio() -> void:
	audio_player.stream.data = GoZenAudio.get_audio_data(path)


func _print_system_debug() -> void:
	print_rich("[b]System info")
	print("OS name: ", OS.get_name())
	print("Distro name: ", OS.get_distribution_name())
	print("OS version: ", OS.get_version())
	print_rich("Memory info:\n\t", OS.get_memory_info())
	print("CPU name: ", OS.get_processor_name())
	print("Threads count: ", OS.get_processor_count())


func _print_video_debug() -> void:
	print_rich("[b]Video debug info")
	print("Extension: ", path.get_extension())
	print("Resolution: ", _resolution)
	print("Actual resolution: ", video.get_actual_resolution())
	print("Pixel format: ", video.get_pixel_format())
	print("Color profile: ", video.get_color_profile())
	print("Framerate: ", _frame_rate)
	print("Duration (in frames): ", _frame_count)
	print("Padding: ", _padding)
	print("Rotation: ", _rotation)
	print("Full color range: ", video.is_full_color_range())
	print("Interlaced flag: ", video.get_interlaced())
	print("Using sws: ", video.is_using_sws())
	print("Sar: ", video.get_sar())
	
