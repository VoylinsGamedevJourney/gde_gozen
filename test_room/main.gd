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
	preload("res://icons/play.png"), # PLAY
	preload("res://icons/pause.png") # PAUSE
]

var is_dragging: bool = false
var was_playing: bool = false



func _ready() -> void:
	if OS.get_name() == "Android":
		clear_folder("user://temp", true)
	
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
	var current_directory : String = OS.get_system_dir(OS.SYSTEM_DIR_MOVIES)
	var filters : PackedStringArray = PackedStringArray(["*"])
	var error : Error = DisplayServer.file_dialog_show("Open video", current_directory, "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters, _file_dialog_callback)
	if error:
		printerr("Problem with file dialog")


func _file_dialog_callback(_status: bool, selected_uris: PackedStringArray, _selected_filter_index: int) -> void:
	var filepath : String = selected_uris[0]
	if OS.get_name() != "Android":
		open_video(filepath)
		return

	if filepath.begins_with("user://") or filepath.begins_with("res://"):
		open_video(filepath)
		return

	var file_read : FileAccess = FileAccess.open(filepath, FileAccess.READ)

	if not file_read:
		return
	
	# android files starting with "content://" should be copied to a temp folder
	# in order to get absolute paths that Gozen GDE could read
	if DirAccess.dir_exists_absolute("user://temp"):
		clear_folder("user://temp", false)
	else:
		var createDirError : Error = DirAccess.make_dir_absolute("user://temp")
		if createDirError:
			printerr("Problem with temp folder creation")
			return

	var temp_path : String = "user://temp/temp_" + str(Time.get_ticks_msec()) + ".tmp"
	var file_write : FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file_write:
		var storeOperationOk : bool = file_write.store_buffer(file_read.get_buffer(file_read.get_length()))
		if not storeOperationOk:
			printerr("Problem catching the file")
			return
		file_write.close()
	file_read.close()
	
	open_video(ProjectSettings.globalize_path(temp_path))
	return


func _connect(from_signal: Signal, target_func: Callable) -> void:
	if from_signal.connect(target_func):
		printerr("Couldn't connect function '", target_func.get_method(), "' to '", from_signal.get_name(), "'!")


func _on_audio_track_option_item_selected(index: int) -> void:
	video_playback.set_audio_stream(video_playback.audio_streams[index])


func clear_folder(path: String, delete_folder : bool) -> void:
	var dir : DirAccess = DirAccess.open(path)
	if not dir:
		return
	
	var error : Error = dir.list_dir_begin()
	if error:
		printerr("Problems while reading %s folder" % path)
		return
	var item: String = dir.get_next()
	while item != "":
		if item != "." and item != "..":
			var full_path: String = path.path_join(item)
			if dir.current_is_dir():
				clear_folder(full_path, delete_folder)
			else:
				var removeFileError : Error = dir.remove(full_path)
				if removeFileError:
					printerr("Problem while removing %s file" % full_path)
					continue
		item = dir.get_next()
	
	if not delete_folder:
		return
	
	var removeFolderError : Error = DirAccess.remove_absolute(path)
	if removeFolderError:
		printerr("Problem while removing %s folder" % path)
