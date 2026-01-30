extends Control

const VIDEO_EXTENSIONS: PackedStringArray = [
	"webm","mkv","flv","vob","ogv","ogg","mng","avi","mts","m2ts","ts","mov",
	"qt","wmv","yuv","rm","rmvb","viv","asf","amv","mp4","m4p","mp2","mpe",
	"mpv","mpg","mpeg","m2v","m4v","svi","3gp","3g2","mxf","roq","nsv","flv",
	"f4v","f4p","f4a","f4b", "gif"]


@onready var video_playback: VideoPlayback = %VideoPlayback

@onready var timeline: HSlider = %Timeline
@onready var play_pause_button: TextureButton = %PlayPauseButton

@onready var current_frame_value: Label = %CurrentFrameValue
@onready var editor_fps_value: Label = %EditorFPSValue
@onready var max_frame_value: Label = %MaxFrameValue
@onready var fps_value: Label = %FPSValue
@onready var speed_spin_box: SpinBox = %SpeedSpinBox
@onready var audio_track_option_button: OptionButton = %AudioTrackOption

@onready var loading_screen: Panel = $LoadingPanel

var icons: Array[Texture2D] = [
	preload("res://icons/play_arrow_48dp_FILL1_wght400_GRAD0_opsz48.png"), # PLAY
	preload("res://icons/pause_48dp_FILL1_wght400_GRAD0_opsz48.png") # PAUSE
]

var is_dragging: bool = false
var was_playing: bool = false



func _ready() -> void:
	if OS.get_cmdline_args().size() > 1:
		open_video(OS.get_cmdline_args()[1])
	if OS.get_name().to_lower() == "android" and OS.request_permissions():
		print("Permissions already granted!")

	_connect(get_window().files_dropped, _on_video_drop)
	_connect(video_playback.video_loaded, after_video_open)
	_connect(video_playback.frame_changed, _frame_changed)

	loading_screen.visible = false
	speed_spin_box.value = video_playback.playback_speed


func _input(event: InputEvent) -> void:
	if event.is_action_released("play_pause"):
		_on_play_pause_button_pressed()


func _on_video_drop(file_paths: PackedStringArray) -> void:
	if file_paths[0].get_extension().to_lower() not in VIDEO_EXTENSIONS:
		return print("Not a valid video file!");
	for path: String in file_paths:
		if !path.ends_with(".tscn"):
			open_video(path)
			return


func _on_url_line_edit_text_submitted(path: String) -> void:
	open_video(path)


func _frame_changed(value: int) -> void:
	timeline.value = value
	current_frame_value.text = str(value)
	editor_fps_value.text = str(Engine.get_frames_per_second())


func open_video(file_path: String) -> void:
	if video_playback and timeline and loading_screen:
		timeline.value = 0
		loading_screen.visible = true
		video_playback.set_video_path(file_path)


func after_video_open() -> void:
	if video_playback.is_open():
		timeline.max_value = video_playback.get_video_frame_count() - 1
		play_pause_button.texture_normal = icons[0]
		max_frame_value.text = str(video_playback.get_video_frame_count())
		fps_value.text = str(video_playback.get_video_framerate()).left(5)
		loading_screen.visible = false

		audio_track_option_button.clear()

		for i: int in range(len(video_playback.audio_streams)):
			var title: String = video_playback.get_stream_title(video_playback.audio_streams[i])
			var lang: String = video_playback.get_stream_language(video_playback.audio_streams[i])

			if title == "":
				title = "Track " + str(i + 1)
			if lang == "":
				audio_track_option_button.add_item(title)
			else:
				audio_track_option_button.add_item(title + " - " + lang)


func _on_play_pause_button_pressed() -> void:
	if video_playback.is_open():
		if video_playback.is_playing:
			video_playback.pause()
			play_pause_button.texture_normal = icons[0]
		else:
			video_playback.play()
			play_pause_button.texture_normal = icons[1]

		play_pause_button.release_focus()


func _on_timeline_value_changed(_value: float) -> void:
	if is_dragging:
		video_playback.seek_frame(timeline.value as int)


func _on_timeline_drag_started() -> void:
	is_dragging = true
	was_playing = video_playback.is_playing
	video_playback.pause()


func _on_timeline_drag_ended(_value: bool) -> void:
	is_dragging = false
	if was_playing:
		video_playback.play()


func _on_speed_spin_box_value_changed(value: float) -> void:
	video_playback.playback_speed = value


func _on_load_video_button_pressed() -> void:
	var dialog: FileDialog = FileDialog.new()

	dialog.title = "Open video"
	dialog.force_native = true
	dialog.use_native_dialog = true
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_connect(dialog.file_selected, open_video)

	add_child(dialog)
	dialog.popup_centered()


func _connect(from_signal: Signal, target_func: Callable) -> void:
	if from_signal.connect(target_func):
		printerr("Couldn't connect function '", target_func.get_method(), "' to '", from_signal.get_name(), "'!")


func _on_audio_track_option_item_selected(index: int) -> void:
	video_playback.set_audio_stream(video_playback.audio_streams[index])
