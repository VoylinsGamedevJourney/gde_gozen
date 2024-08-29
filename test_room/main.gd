extends Control

@onready var video_playback = %VideoPlayback

var is_dragging: bool = false
var was_playing: bool = false


func _ready() -> void:
	if OS.get_cmdline_args().size() > 1:
		open_video(OS.get_cmdline_args()[1])
	get_window().files_dropped.connect(on_video_drop)
	video_playback._current_frame_changed.connect(
			func(a_value: int) -> void: 
				%Timeline.value = a_value
				%CurrentFrameValue.text = str(a_value)
				%EditorFPSValue.text = str(Engine.get_frames_per_second()))


func on_video_drop(a_files: PackedStringArray) -> void:
	if a_files[0].get_extension().to_lower() in ["webm" ,"mkv" ,"flv" ,"vob" ,"ogv" ,"ogg" ,"mng" ,"avi" ,"mts" ,"m2ts" ,"ts" ,"mov" ,"qt" ,"wmv" ,"yuv" ,"rm" ,"rmvb" ,"viv" ,"asf" ,"amv" ,"mp4" ,"m4p" ,"mp2" ,"mpe" ,"mpv" ,"mpg" ,"mpeg" ,"m2v" ,"m4v" ,"svi" ,"3gp" ,"3g2" ,"mxf" ,"roq" ,"nsv" ,"flv" ,"f4v" ,"f4p" ,"f4a" ,"f4b"]: 
		open_video(a_files[0])
	else:
		print("Not a valid video file!");


func open_video(a_file: String) -> void:
	video_playback.set_video_path(a_file)
	after_video_open()


func after_video_open() -> void:
	%Timeline.max_value = video_playback.get_frame_duration()
	%PlayPauseButton.texture_normal = preload("res://icons/play_arrow_48dp_FILL1_wght400_GRAD0_opsz48.png")
	%MaxFrameValue.text = str(video_playback.get_frame_duration())
	%FPSValue.text = str(video_playback.get_framerate()).left(5)


func _on_play_pause_button_pressed() -> void:
	if !video_playback.is_open():
		return

	if video_playback.is_playing:
		video_playback.pause()
		%PlayPauseButton.texture_normal = preload("res://icons/play_arrow_48dp_FILL1_wght400_GRAD0_opsz48.png")
	else:
		video_playback.play()
		%PlayPauseButton.texture_normal = preload("res://icons/pause_48dp_FILL1_wght400_GRAD0_opsz48.png")


func _on_timeline_value_changed(_value:float) -> void:
	if is_dragging:
		video_playback.seek_frame(%Timeline.value)


func _on_timeline_drag_started() -> void:
	is_dragging = true
	was_playing = video_playback.is_playing
	video_playback.pause()


func _on_timeline_drag_ended(_value:bool) -> void:
	is_dragging = false
	if was_playing:
		video_playback.play()

