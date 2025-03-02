extends Control

const VIDEO_EXTENSIONS: PackedStringArray = [
	"webm","mkv","flv","vob","ogv","ogg","mng","avi","mts","m2ts","ts","mov",
	"qt","wmv","yuv","rm","rmvb","viv","asf","amv","mp4","m4p","mp2","mpe",
	"mpv","mpg","mpeg","m2v","m4v","svi","3gp","3g2","mxf","roq","nsv","flv",
	"f4v","f4p","f4a","f4b"]


@onready var video_playback: VideoPlayback = %VideoPlayback

@onready var timeline: HSlider = %Timeline
@onready var play_pause_button: TextureButton = %PlayPauseButton

@onready var current_frame_value: Label = %CurrentFrameValue
@onready var editor_fps_value: Label = %EditorFPSValue
@onready var max_frame_value: Label = %MaxFrameValue
@onready var fps_value: Label = %FPSValue
@onready var speed_spin_box: SpinBox = %SpeedSpinBox

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


	@warning_ignore("standalone_expression") [
		get_window().files_dropped.connect(_on_video_drop),

		video_playback.video_loaded.connect(after_video_open),
		video_playback.frame_changed.connect(
			func(a_value: int) -> void: 
				timeline.value = a_value
				current_frame_value.text = str(a_value)
				editor_fps_value.text = str(Engine.get_frames_per_second()))
	]

	loading_screen.visible = false
	speed_spin_box.value = video_playback.playback_speed
	

func _input(a_event: InputEvent) -> void:
	if a_event.is_action_released("play_pause"):
		_on_play_pause_button_pressed()


func _on_video_drop(a_files: PackedStringArray) -> void:
	if a_files[0].get_extension().to_lower() in VIDEO_EXTENSIONS:
		timeline.value = 0
		open_video(a_files[0])
	else:
		print("Not a valid video file!");


func open_video(a_file: String) -> void:
	loading_screen.visible = true

	video_playback.set_video_path(a_file)


func after_video_open() -> void:
	if video_playback.is_open():
		timeline.max_value = video_playback.get_video_frame_count() - 1
		play_pause_button.texture_normal = icons[0]
		max_frame_value.text = str(video_playback.get_video_frame_count())
		fps_value.text = str(video_playback.get_video_framerate()).left(5)
		loading_screen.visible = false


func _on_play_pause_button_pressed() -> void:
	if !video_playback.is_open():
		return

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


func _on_speed_spin_box_value_changed(a_value: float) -> void:
	video_playback.playback_speed = a_value

