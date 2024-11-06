extends Control


@onready var timeline: HSlider = %Timeline
@onready var play_pause_button: TextureButton = %PlayPauseButton
@onready var video_playback: VideoPlayback = %VideoPlayback
@onready var current_frame_value: Label = %CurrentFrameValue
@onready var editor_fps_value: Label = %EditorFPSValue
@onready var max_frame_value: Label = %MaxFrameValue
@onready var fps_value: Label = %FPSValue


var is_dragging: bool = false
var was_playing: bool = false



func _ready() -> void:
	if OS.get_cmdline_args().size() > 1:
		open_video(OS.get_cmdline_args()[1])
	if get_window().files_dropped.connect(_on_video_drop):
		printerr("Couldn't connect files_dropped!")
	if video_playback._current_frame_changed.connect(
			func(a_value: int) -> void: 
				timeline.value = a_value
				current_frame_value.text = str(a_value)
				editor_fps_value.text = str(Engine.get_frames_per_second())):
		printerr("Couldn't connect _current_frame_changed!")
	

func _input(a_event: InputEvent) -> void:
	if a_event.is_action_pressed("play_pause"):
		_on_play_pause_button_pressed()


func _on_video_drop(a_files: PackedStringArray) -> void:
	if a_files[0].get_extension().to_lower() in ["webm" ,"mkv" ,"flv" ,"vob" ,"ogv" ,"ogg" ,"mng" ,"avi" ,"mts" ,"m2ts" ,"ts" ,"mov" ,"qt" ,"wmv" ,"yuv" ,"rm" ,"rmvb" ,"viv" ,"asf" ,"amv" ,"mp4" ,"m4p" ,"mp2" ,"mpe" ,"mpv" ,"mpg" ,"mpeg" ,"m2v" ,"m4v" ,"svi" ,"3gp" ,"3g2" ,"mxf" ,"roq" ,"nsv" ,"flv" ,"f4v" ,"f4p" ,"f4a" ,"f4b"]: 
		open_video(a_files[0])
	else:
		print("Not a valid video file!");


func open_video(a_file: String) -> void:
	video_playback.set_video_path(a_file)
	after_video_open()


func after_video_open() -> void:
	if video_playback.is_open():
		timeline.max_value = video_playback.get_frame_duration() - 1
		play_pause_button.texture_normal = preload("res://icons/play_arrow_48dp_FILL1_wght400_GRAD0_opsz48.png")
		max_frame_value.text = str(video_playback.get_frame_duration())
		fps_value.text = str(video_playback.get_framerate()).left(5)


func _on_play_pause_button_pressed() -> void:
	if !video_playback.is_open():
		return

	if video_playback.is_playing:
		video_playback.pause()
		play_pause_button.texture_normal = preload("res://icons/play_arrow_48dp_FILL1_wght400_GRAD0_opsz48.png")
	else:
		video_playback.play()
		play_pause_button.texture_normal = preload("res://icons/pause_48dp_FILL1_wght400_GRAD0_opsz48.png")


func _on_timeline_value_changed(_value:float) -> void:
	if is_dragging:
		video_playback.seek_frame(timeline.value as int)


func _on_timeline_drag_started() -> void:
	is_dragging = true
	was_playing = video_playback.is_playing
	video_playback.pause()


func _on_timeline_drag_ended(_value:bool) -> void:
	is_dragging = false
	if was_playing:
		video_playback.play()

