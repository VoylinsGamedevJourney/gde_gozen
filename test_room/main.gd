extends Control


var video: Video

var is_playing: bool = false
var was_playing: bool = false

var current_frame: int = 1: set = set_current_frame
var framerate: float = 0
var max_frame: int = 0: set = set_max_frame
var frame_time: float = 0: set = set_frame_time

var time_elapsed: float = 0.0
var dragging: bool = false

var fast_speed: int = 4
var fast_rewind: bool = false
var fast_forward: bool = false

var task_id: int = -1



func _ready() -> void:
	if OS.get_cmdline_args().size() > 1:
		video = Video.new()
		video.open_video(OS.get_cmdline_args()[1])
		after_video_open()
	get_window().files_dropped.connect(on_video_drop)


func on_video_drop(a_files: PackedStringArray) -> void:
	%LoadingLabel.visible = true
	video = Video.new()
	task_id = WorkerThreadPool.add_task(video.open_video.bind(a_files[0]))


func open_video(a_file: String) -> void:
	video.open_video(a_file)


func after_video_open() -> void:
	$AudioStream1.stream = video.get_audio()
	is_playing = false
	framerate = video.get_framerate()
	max_frame = video.get_total_frame_nr()
	frame_time = 1.0 / framerate
	seek_frame(0)
	%Timeline.max_value = max_frame
	%LoadingLabel.visible = false
	%PlayPauseButton.texture_normal = preload("res://icons/play_arrow_48dp_FILL1_wght400_GRAD0_opsz48.png")
	%FPSValue.text = str(framerate).left(5)


func is_video_open() -> bool:
	if !video:
		return false
	return video.is_video_open()


func _process(a_delta) -> void:
	if task_id != -1 and WorkerThreadPool.is_task_completed(task_id):
		WorkerThreadPool.wait_for_task_completion(task_id)
		task_id = -1
		%LoadingLabel.visible = false
		if !is_video_open():
			printerr("Couldn't open video!")
		after_video_open()

	elif !is_video_open():
		return
	
	if is_playing:
		time_elapsed += a_delta
		if time_elapsed < frame_time:
			return
		
		while time_elapsed >= frame_time:
			time_elapsed -= frame_time
			current_frame += 1
		
		if current_frame >= max_frame:
			if dragging:
				return
			is_playing = !is_playing
			seek_frame(1)
			$AudioStream1.set_stream_paused(true)
		else:
			var l_frame: Image = video.next_frame()
			if !l_frame.is_empty():
				%FrameImage.texture.set_image(l_frame)
			if !dragging:
				%Timeline.value = current_frame
	elif fast_rewind:
		seek_frame(current_frame - fast_speed)
	elif fast_forward:
		seek_frame(current_frame + fast_speed)


func seek_frame(a_frame_nr: int) -> void:
	if !is_video_open():
		return
	current_frame = clampi(a_frame_nr, 1, max_frame - 1)
	if !is_playing:
		$AudioStream1.set_stream_paused(false)
	$AudioStream1.seek(current_frame/framerate)
	if !is_playing:
		$AudioStream1.set_stream_paused(true)
	var l_frame: Image = video.seek_frame(current_frame)
	if l_frame != null and !l_frame.is_empty():
		%FrameImage.texture.set_image(l_frame)
	else:
		print("Seek returned an empty image!")
	if !dragging:
		%Timeline.value = current_frame


func _on_fast_forward_button_button_up() -> void:
	is_playing = was_playing
	$AudioStream1.set_stream_paused(!was_playing)
	fast_forward = false


func _on_fast_forward_button_button_down() -> void:
	was_playing = is_playing
	is_playing = false
	$AudioStream1.set_stream_paused(!is_playing)
	fast_forward = true


func _on_play_pause_button_pressed() -> void:
	if !is_video_open():
		return
	is_playing = !is_playing
	if is_playing:
		$AudioStream1.play($AudioStream1.get_playback_position())
		seek_frame(current_frame)
		%PlayPauseButton.texture_normal = preload("res://icons/pause_48dp_FILL1_wght400_GRAD0_opsz48.png")
	else:
		%PlayPauseButton.texture_normal = preload("res://icons/play_arrow_48dp_FILL1_wght400_GRAD0_opsz48.png")
	$AudioStream1.set_stream_paused(!is_playing)


func _on_fast_rewind_button_button_up() -> void:
	is_playing = was_playing
	$AudioStream1.set_stream_paused(!was_playing)
	fast_rewind = false


func _on_fast_rewind_button_button_down() -> void:
	was_playing = is_playing
	is_playing = false
	$AudioStream1.set_stream_paused(!is_playing)
	fast_forward = true


func _on_timeline_value_changed(_value:float) -> void:
	if dragging:
		seek_frame(%Timeline.value)


func _on_timeline_drag_started() -> void:
	dragging = true
	if is_playing:
		$AudioStream1.set_stream_paused(true)


func _on_timeline_drag_ended(_value:bool) -> void:
	dragging = false
	if is_playing:
		$AudioStream1.set_stream_paused(false)
		$AudioStream1.seek(%Timeline.value/framerate)


# Setters

func set_current_frame(a_value: int) -> void:
	current_frame = a_value
	%CurrentFrameValue.text = str(a_value)


func set_max_frame(a_value: int) -> void:
	max_frame = a_value
	%MaxFrameValue.text = str(a_value)


func set_frame_time(a_value: float) -> void:
	frame_time = a_value
	%FrameTimeValue.text = str(a_value).left(4)


func _on_audio_stream_1_finished():
	print("Audio stream finished playing!")

