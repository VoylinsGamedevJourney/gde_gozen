extends Control
#
#
#var video: Video
#
#var is_playing: bool = false
#var was_playing: bool = false
#
#var current_frame: int = 1: set = set_current_frame
#var framerate: float = 0
#var max_frame: int = 0: set = set_max_frame
#var frame_time: float = 0: set = set_frame_time
#
#var time_elapsed: float = 0.0
#var dragging: bool = false
#
#var fast_speed: int = 4
#var fast_rewind: bool = false
#var fast_forward: bool = false
#
#var task_id: int = -1
#
#
#var path: String = "/storage/Youtube/02 - Gamedev Journey/Videos/2. SPONSOR_READ/Sponsor_read_full.mp4"
#
#
#func _ready() -> void:
#	var width: int = 10
#	var height: int = 10
#	var y: PackedByteArray = PackedByteArray(
#		[235, 235, 235, 235, 235, 235, 235, 235, 235, 235,
#		 235, 235, 235, 235, 235, 235, 235, 235, 235, 235,
#		 235, 235, 235, 235, 235, 235, 235, 235, 235, 235,
#		 235, 235, 235, 235, 235, 235, 235, 235, 235, 235,
#		 235, 235, 235, 235, 235, 235, 235, 235, 235, 235,
#		 235, 235, 235, 235, 235, 235, 235, 235, 235, 235,
#		 235, 235, 235, 235, 235, 235, 235, 235, 235, 235,
#		 235, 235, 235, 235, 235, 235, 235, 235, 235, 235,
#		 235, 235, 235, 235, 235, 235, 235, 235, 235, 235,
#		 235, 235, 235, 235, 235, 235, 235, 235, 235, 235])
#	var u: PackedByteArray = (
#		[128, 128, 128, 128, 128,
#		 128, 128, 128, 128, 128,
#		 128, 128, 128, 128, 128,
#		 128, 128, 128, 128, 128,
#		 128, 128, 128, 128, 128])
#	var v: PackedByteArray = (
#		[255, 255, 255, 255, 255,
#		 255, 255, 255, 255, 255,
#		 255, 255, 255, 255, 255,
#		 255, 255, 255, 255, 255,
#		 255, 255, 255, 255, 255])
#	var rgb: PackedByteArray = []
#	rgb.resize(y.size()*4) 
#
#	var l_params: PackedByteArray = PackedInt32Array([width, height]).to_byte_array()
#
#	var l_rendering_server: RenderingDevice= RenderingServer.create_local_rendering_device()
#	var l_shader_file: RDShaderFile = load("res://shaders/yuv_to_rgb.glsl")
#	var l_shader_spirv: RDShaderSPIRV = l_shader_file.get_spirv()
#	var l_shader: RID = l_rendering_server.shader_create_from_spirv(l_shader_spirv)
#	
#	var l_y_buffer: RID = l_rendering_server.storage_buffer_create(y.size(), y)
#	var l_u_buffer: RID = l_rendering_server.storage_buffer_create(u.size(), u)
#	var l_v_buffer: RID = l_rendering_server.storage_buffer_create(v.size(), v)
#	var l_rgb_buffer: RID = l_rendering_server.storage_buffer_create(rgb.size(), rgb)
#	var l_params_buffer: RID = l_rendering_server.storage_buffer_create(l_params.size(), l_params)
#
#	var l_y_uniform: RDUniform = RDUniform.new()
#	l_y_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
#	l_y_uniform.binding = 0
#	l_y_uniform.add_id(l_y_buffer)
#	var l_y_uniform_set: RID = l_rendering_server.uniform_set_create([l_y_uniform], l_shader, 0)
#
#	var l_u_uniform: RDUniform = RDUniform.new()
#	l_u_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
#	l_u_uniform.binding = 0
#	l_u_uniform.add_id(l_u_buffer)
#	var l_u_uniform_set: RID = l_rendering_server.uniform_set_create([l_u_uniform], l_shader, 1)
#
#	var l_v_uniform: RDUniform = RDUniform.new()
#	l_v_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
#	l_v_uniform.binding = 0
#	l_v_uniform.add_id(l_v_buffer)
#	var l_v_uniform_set: RID = l_rendering_server.uniform_set_create([l_v_uniform], l_shader, 2)
#
#	var l_rgb_uniform: RDUniform = RDUniform.new()
#	l_rgb_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
#	l_rgb_uniform.binding = 0
#	l_rgb_uniform.add_id(l_rgb_buffer)
#	var l_rgb_uniform_set: RID = l_rendering_server.uniform_set_create([l_rgb_uniform], l_shader, 3)
#
#	var l_params_uniform: RDUniform = RDUniform.new()
#	l_params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
#	l_params_uniform.binding = 0
#	l_params_uniform.add_id(l_params_buffer)
#	var l_params_uniform_set: RID = l_rendering_server.uniform_set_create([l_params_uniform], l_shader, 4)
#
#	var l_pipeline: RID = l_rendering_server.compute_pipeline_create(l_shader)
#	var l_compute_list: int = l_rendering_server.compute_list_begin()
#	l_rendering_server.compute_list_bind_compute_pipeline(l_compute_list, l_pipeline)
#
#	l_rendering_server.compute_list_bind_uniform_set(l_compute_list, l_y_uniform_set, 0)
#	l_rendering_server.compute_list_bind_uniform_set(l_compute_list, l_u_uniform_set, 1)
#	l_rendering_server.compute_list_bind_uniform_set(l_compute_list, l_v_uniform_set, 2)
#	l_rendering_server.compute_list_bind_uniform_set(l_compute_list, l_rgb_uniform_set, 3)
#	l_rendering_server.compute_list_bind_uniform_set(l_compute_list, l_params_uniform_set, 4)
#
#	l_rendering_server.compute_list_dispatch(l_compute_list, ceili(width/8.0), ceili(height/8.0), 1)
#	l_rendering_server.compute_list_end()
#
#	l_rendering_server.submit()
#	l_rendering_server.sync()
#
#	var l_output: PackedByteArray = l_rendering_server.buffer_get_data(l_rgb_buffer)
#	print("output: ", l_output)
#	print("output size: ", l_output.size())
#
#	var l_image: Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, l_output)
#	(%TR as TextureRect).get_texture().set_image(l_image)
#
#
#
#	#(%VideoPlayback as VideoPlayback).set_video_path(path)
#	if OS.get_cmdline_args().size() > 1:
#		video = Video.new()
#		video.open_video(OS.get_cmdline_args()[1], true)
#		after_video_open()
#	get_window().files_dropped.connect(on_video_drop)
#
#
#func on_video_drop(a_files: PackedStringArray) -> void:
#	if a_files[0].split('.')[-1].to_lower() in ["webm" ,"mkv" ,"flv" ,"vob" ,"ogv" ,"ogg" ,"mng" ,"avi" ,"mts" ,"m2ts" ,"ts" ,"mov" ,"qt" ,"wmv" ,"yuv" ,"rm" ,"rmvb" ,"viv" ,"asf" ,"amv" ,"mp4" ,"m4p" ,"mp2" ,"mpe" ,"mpv" ,"mpg" ,"mpeg" ,"m2v" ,"m4v" ,"svi" ,"3gp" ,"3g2" ,"mxf" ,"roq" ,"nsv" ,"flv" ,"f4v" ,"f4p" ,"f4a" ,"f4b"]: 
#		%LoadingLabel.visible = true
#		video = Video.new()
#		task_id = WorkerThreadPool.add_task(video.open_video.bind(a_files[0]))
#	else:
#		print("Not a valid video file!");
#
#
#func open_video(a_file: String) -> void:
#	video.open_video(a_file, true)
#
#
#func after_video_open() -> void:
#	$AudioStream1.stream = video.get_audio()
#	is_playing = false
#	framerate = video.get_framerate()
#	max_frame = video.get_total_frame_nr()
#	frame_time = 1.0 / framerate
#	seek_frame(0)
#	%Timeline.max_value = max_frame
#	%LoadingLabel.visible = false
#	%PlayPauseButton.texture_normal = preload("res://icons/play_arrow_48dp_FILL1_wght400_GRAD0_opsz48.png")
#	%FPSValue.text = str(framerate).left(5)
#
#
#func is_video_open() -> bool:
#	if !video:
#		return false
#	return video.is_video_open()
#
#
#func _process(a_delta) -> void:
#	if task_id != -1 and WorkerThreadPool.is_task_completed(task_id):
#		WorkerThreadPool.wait_for_task_completion(task_id)
#		task_id = -1
#		%LoadingLabel.visible = false
#		if !is_video_open():
#			printerr("Couldn't open video!")
#		after_video_open()
#
#	elif !is_video_open():
#		return
#	
#	if is_playing:
#		time_elapsed += a_delta
#		if time_elapsed < frame_time:
#			return
#		
#		while time_elapsed >= frame_time:
#			time_elapsed -= frame_time
#			current_frame += 1
#		%EditorFPSValue.text = str(Engine.get_frames_per_second()).left(6)
#		
#		if current_frame >= max_frame:
#			if dragging:
#				return
#			is_playing = !is_playing
#			seek_frame(0)
#			$AudioStream1.set_stream_paused(true)
#		else:
#			var l_frame: Image = video.next_frame()
#			if !l_frame.is_empty():
#				%FrameImage.texture.set_image(l_frame)
#			if !dragging:
#				%Timeline.value = current_frame
#	elif fast_rewind:
#		seek_frame(current_frame - fast_speed)
#	elif fast_forward:
#		seek_frame(current_frame + fast_speed)
#
#
#func seek_frame(a_frame_nr: int) -> void:
#	if !is_video_open():
#		return
#	current_frame = clampi(a_frame_nr, 0, max_frame - 1)
#	if !is_playing:
#		$AudioStream1.set_stream_paused(false)
#	$AudioStream1.seek(current_frame/framerate)
#	if !is_playing:
#		$AudioStream1.set_stream_paused(true)
#	var l_frame: Image = video.seek_frame(current_frame)
#	if l_frame != null and !l_frame.is_empty():
#		%FrameImage.texture.set_image(l_frame)
#	else:
#		printerr("Seek returned an empty image!")
#	if !dragging:
#		%Timeline.value = current_frame
#
#
#func _on_fast_forward_button_button_up() -> void:
#	is_playing = was_playing
#	$AudioStream1.set_stream_paused(!was_playing)
#	fast_forward = false
#
#
#func _on_fast_forward_button_button_down() -> void:
#	was_playing = is_playing
#	is_playing = false
#	$AudioStream1.set_stream_paused(!is_playing)
#	fast_forward = true
#
#
#func _on_play_pause_button_pressed() -> void:
#	if !is_video_open():
#		return
#	is_playing = !is_playing
#	if is_playing:
#		$AudioStream1.play($AudioStream1.get_playback_position())
#		seek_frame(current_frame)
#		%PlayPauseButton.texture_normal = preload("res://icons/pause_48dp_FILL1_wght400_GRAD0_opsz48.png")
#	else:
#		%PlayPauseButton.texture_normal = preload("res://icons/play_arrow_48dp_FILL1_wght400_GRAD0_opsz48.png")
#	$AudioStream1.set_stream_paused(!is_playing)
#
#
#func _on_fast_rewind_button_button_up() -> void:
#	is_playing = was_playing
#	$AudioStream1.set_stream_paused(!was_playing)
#	fast_rewind = false
#
#
#func _on_fast_rewind_button_button_down() -> void:
#	was_playing = is_playing
#	is_playing = false
#	$AudioStream1.set_stream_paused(!is_playing)
#	fast_forward = true
#
#
#func _on_timeline_value_changed(_value:float) -> void:
#	if dragging:
#		seek_frame(%Timeline.value)
#
#
#func _on_timeline_drag_started() -> void:
#	dragging = true
#	if is_playing:
#		$AudioStream1.set_stream_paused(true)
#
#
#func _on_timeline_drag_ended(_value:bool) -> void:
#	dragging = false
#	if is_playing:
#		$AudioStream1.set_stream_paused(false)
#		$AudioStream1.seek(%Timeline.value/framerate)
#
#
## Setters
#
#func set_current_frame(a_value: int) -> void:
#	current_frame = a_value
#	%CurrentFrameValue.text = str(a_value)
#
#
#func set_max_frame(a_value: int) -> void:
#	max_frame = a_value
#	%MaxFrameValue.text = str(a_value)
#
#
#func set_frame_time(a_value: float) -> void:
#	frame_time = a_value
#	%FrameTimeValue.text = str(a_value).left(4)
#
#
#func _on_audio_stream_1_finished():
#	print("Audio stream finished playing!")
#
