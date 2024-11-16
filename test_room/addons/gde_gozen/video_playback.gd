class_name VideoPlayback
extends Control
## Video playback and seeking inside of Godot.
##
## To use this node, just add it anywhere and resize it to the desired size. Use the function [code]set_video_path(a_path)[/code] and the video will load. Take in mind that long video's can take a second or longer to load. If this is an issue you can preload the Video on startup of your project and set the video variable yourself, just remember to use the function [code]update_video()[/code] before the moment that you'd like to use it.
## [br][br]
## There is a small limitation right now as FFmpeg requires a path to the video file so you can't make the video's part of the exported project and the [code]res://[/code] paths also don't work. This is just the nature of the beast and not something I can easily solve, but luckily there are solutions! First of all, the video path should be the full path, for testing this is easy as you can make the path whatever you want it to be, for exported projects ... Well, chances of the path being in the exact same location as on your pc are quite low.
## [br][br]
## The solution for exported projects is to create a folder inside of your exported projects in which you keep the video files, inside of your code you can check if the project is run from the editor or not with: [code]OS.has_feature(“editor”)[/code]. To get the path of your running project to find the folder where your video's are stored you can use [code]OS.get_executable_path()[/code]. So it requires a bit of code to get things properly working but everything should work without issues this way.


signal _current_frame_changed(frame_nr) ## Getting the current frame might be usefull if you want certain events to happen at a certain frame number. In the test project we use it for making the timeline move along with the video

signal _on_video_loaded ## Get's called when the video is ready to display
signal _video_ended ## Get's called when last frame has been shown.

signal _on_play_pressed ## Called when the play command has been used with an open video.
signal _on_pause_pressed ## Called when the pause command has been used with an open video.
signal _on_video_playback_ready ## Get's called when the video playback node is completely loaded, video is open and ready for playback.
signal _on_next_frame_called(frame_nr) ## _current_frame_changed gets called when the number changes, but frame skipping may occur to provide smooth playback, with this signal you can check when an actual new frame is being shown.


@export_file var path: String = "": set = set_video_path ## You can set the video path straigth from the editor, you can also set it through code to do it more dynamically. Use the README to find out more about the limitations. Only provide [b]FULL[/b] paths, not [code]res://[/code] paths as FFmpeg can't deal with those. Solutions for setting the path in both editor and exported projects can be found in the readme info or on top.
@export var hardware_decoding: bool = false ## HW decoding is not useful for most cases due to the added performance cost of putting the data from the GPU to the system memory, that's why it is disabled by default. For harder to decode formats this could be useful, but those cases are few. Hardware decoding is [b]NOT[/b] available for Windows due to issues with crashing.
@export var debug: bool = false ## Setting this value will print debug messages of the video file whilst opening and during playback.

var video: Video = null ## The video object uses GDEGoZen to function, this class interacts with a library called FFmpeg to get the audio and the frame data.

var texture_rect: TextureRect = TextureRect.new() ## The texture rect is the view of the video, you can adjust the scaling options as you like, it is set to always center and scale the image to fit within the main VideoPlayback node size.
var audio_player: AudioStreamPlayer = AudioStreamPlayer.new() ## Audio player is the AudioStreamPlayer which handles the audio playback for the video, only mess with the settings if you know what you are doing and know what you'd like to achieve.

var is_playing: bool = false ## Bool to check if the video is currently playing or not.
var current_frame: int = 0: set = _set_current_frame ## Current frame number which the video playback is at.

var hardware_decoding: bool = false ## Use your CPU/GPU decoder (if available). This should be set before opening a video! Default value is true inside of the Video class, when creating a new Video class and you want to disable hardware decoding, you should set the value before using Video.open() for it to have effect. NOTE: At this point Hardware decoding isn't working properly yet!

var _time_elapsed: float = 0.
var _frame_time: float = 0
var _skips: int = 0

var _rotation: int = 0
var _padding: int = 0
var _frame_rate: float = 0.
var _frame_duration: int = 0

var _resolution: Vector2i = Vector2i.ZERO
var _uv_resolution: Vector2i = Vector2i.ZERO
var _shader_material: ShaderMaterial = null

var _y_img: Image
var _u_img: Image
var _v_img: Image
var _y_img_tex: ImageTexture
var _u_img_tex: ImageTexture
var _v_img_tex: ImageTexture

var thread: Thread = Thread.new()


#------------------------------------------------ TREE FUNCTIONS
func _enter_tree() -> void:
	_shader_material = ShaderMaterial.new()

	texture_rect.material = _shader_material
	texture_rect.texture = ImageTexture.new()
	texture_rect.anchor_right = TextureRect.ANCHOR_END
	texture_rect.anchor_bottom = TextureRect.ANCHOR_END
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	add_child(texture_rect)
	add_child(audio_player)

	if debug:
		_print_system_debug()


func _exit_tree() -> void:
	if video != null:
		close()


func _ready() -> void:
	## Function get's run like this because else the project crashes as export variables get set and their setters run before the node is completely ready.
	if path != "":
		set_video_path(path)


#------------------------------------------------ VIDEO DATA HANDLING
func set_video_path(a_path: String) -> void:
	## This is the starting point for video playback, provide a path of where the video file can be found and it will load a Video object. After which [code]update_video()[/code] get's run and set's the first frame image.
	if !is_node_ready():
		return
	elif video != null:
		close()

	audio_player.stream = null
	video = Video.new()
	path = a_path

	# Windows hardware decoding is NOT available so should always be false to prevent crashing.
	video.set_hw_decoding(hardware_decoding if OS.get_name() != "Windows" else false)
	video.enable_debug() if debug else video.disable_debug()

	thread.start(_open_video)


func update_video(a_video: Video) -> void:
	## Only run this function after manually having added a Video object to the `video` variable. A good reason for doing this is to load your video's at startup time to prevent your program for freezing for a second when loading in big video files. Some video formats load faster then others so if you are experiencing issues with long loading times, try to use this function and create the video object on startup, or try switching the video format which you are using. 
	video = a_video
	if !is_open():
		printerr("Video isn't open!")
		return

	var l_image: Image

	_padding = video.get_padding()
	_rotation = video.get_rotation()
	_frame_rate = video.get_framerate()
	_resolution = video.get_resolution()
	_frame_duration = video.get_frame_duration()
	_uv_resolution = Vector2i((_resolution.x + _padding) / 2, _resolution.y / 2)
	l_image = Image.create_empty(_resolution.x, _resolution.y, false, Image.FORMAT_L8)

	if debug:
		_print_video_debug()

	texture_rect.texture.set_image(l_image)

	if video.get_pixel_format().begins_with("yuv"):
		_shader_material.shader = preload("res://addons/gde_gozen/shaders/yuv420p.gdshader")

		_y_img = Image.create_empty(_resolution.x + _padding, _resolution.y, false, Image.FORMAT_L8)
		_u_img = Image.create_empty(_uv_resolution.x, _uv_resolution.y, false, Image.FORMAT_R8)
		_v_img = Image.create_empty(_uv_resolution.x, _uv_resolution.y, false, Image.FORMAT_R8)

		_y_img_tex = ImageTexture.create_from_image(_y_img)
		_u_img_tex = ImageTexture.create_from_image(_u_img)
		_v_img_tex = ImageTexture.create_from_image(_v_img)

		_shader_material.set_shader_parameter("y_data", _y_img_tex)
		_shader_material.set_shader_parameter("u_data", _u_img_tex)
		_shader_material.set_shader_parameter("v_data", _v_img_tex)
	else:
		_shader_material.shader = preload("res://addons/gde_gozen/shaders/nv12.gdshader")

		_y_img = Image.create_empty(_resolution.x + _padding, _resolution.y, false, Image.FORMAT_L8)
		_u_img = Image.create_empty(_uv_resolution.x, _uv_resolution.y, false, Image.FORMAT_RG8)

		_y_img_tex = ImageTexture.create_from_image(_y_img)
		_u_img_tex = ImageTexture.create_from_image(_u_img)

		_shader_material.set_shader_parameter("y_data", _y_img_tex)
		_shader_material.set_shader_parameter("uv_data", _u_img_tex)

	match video.get_color_profile():
		"bt601", "bt470": _shader_material.set_shader_parameter("color_profile", Vector4(1.402, 0.344136, 0.714136, 1.772))
		"bt2020", "bt2100": _shader_material.set_shader_parameter("color_profile", Vector4(1.4746, 0.16455, 0.57135, 1.8814))
		_: # bt709 and unknown
			_shader_material.set_shader_parameter("color_profile", Vector4(1.5748, 0.1873, 0.4681, 1.8556))

	_shader_material.set_shader_parameter("resolution", _resolution)

	audio_player.stream = video.get_audio()

	is_playing = false
	_frame_time = 1.0 / _frame_rate
	video.seek_frame(0)
	current_frame = 0

	_set_frame_image()

	_on_video_loaded.emit()


func seek_frame(a_frame_nr: int) -> void:
	## Seek frame can be used to switch to a frame number you want. Remember that some video codecs report incorrect video end frames or can't seek to the last couple of frames in a video file which may result in an error. Only use this when going to far distances in the video file, else you can use [code]next_frame()[/code].
	if !is_open() and a_frame_nr == current_frame:
		return

	current_frame = clamp(a_frame_nr, 0, _frame_duration)
	video.seek_frame(a_frame_nr)

	_set_frame_image()

	audio_player.set_stream_paused(false)
	audio_player.play(current_frame / _frame_rate)
	audio_player.set_stream_paused(!is_playing)


func next_frame(a_skip: bool = false) -> void:
	## Seeking frames can be slow, so when you just need to go a couple of frames ahead, you can use next_frame and set skip to false for the last frame.
	if video.next_frame(a_skip) and !a_skip:
		_set_frame_image()
	elif !a_skip:
		print("Something went wrong getting next frame!")

	
func close() -> void:
	if video != null:
		if is_playing:
			pause()
		video = null


#------------------------------------------------ PLAYBACK HANDLING
func _process(a_delta: float) -> void:
	if thread.is_started():
		if !thread.is_alive():
			thread.wait_to_finish()
			update_video(video)

	if is_playing:
		_time_elapsed += a_delta
		if _time_elapsed < _frame_time:
			_video_ended.emit()
			return

		_skips = 0
		while _time_elapsed >= _frame_time:
			_time_elapsed -= _frame_time
			current_frame += 1
			_skips += 1

		if current_frame >= _frame_duration:
			is_playing = !is_playing
			audio_player.set_stream_paused(true)
			_video_ended.emit()
		else:
			while _skips != 1:
				next_frame(true)
				_skips -= 1
			next_frame()


func play() -> void:
	## Start the video playback. This will play untill reaching the end of the video and then pause and go back to the start.
	if video != null and !is_open() and is_playing:
		return
	is_playing = true

	audio_player.set_stream_paused(false)
	audio_player.play((current_frame + 1) / _frame_rate)
	audio_player.set_stream_paused(!is_playing)

	_on_play_pressed.emit()


func pause() -> void:
	## Pausing the video.
	if video != null and !is_open():
		return
	is_playing = false
	audio_player.set_stream_paused(true)
	_on_pause_pressed.emit()


#------------------------------------------------ GETTERS
func get_video_frame_duration() -> int:
	## Getting the frame duration returns the total amount of frames found of the video file.
	return _frame_duration


func get_video_framerate() -> float:
	## Getting the framerate of the video
	return _frame_rate


func get_video_rotation() -> int:
	## Getting the rotation in degrees of the video
	return _rotation


func is_open() -> bool:
	## Checking to see if the video is open or not, trying to run functions without checking if open can crash your project.
	return video != null and video.is_open()


#------------------------------------------------ SETTERS
func _set_current_frame(a_value: int) -> void:
	current_frame = a_value
	_current_frame_changed.emit(current_frame)


func _set_frame_image() -> void:
	_y_img.set_data(_y_img.get_width(), _y_img.get_height(), false, _y_img.get_format(), video.get_y_data())
	_u_img.set_data(_u_img.get_width(), _u_img.get_height(), false, _u_img.get_format(), video.get_u_data())

	if video.get_pixel_format().begins_with("yuv"):
		_v_img.set_data(_v_img.get_width(), _v_img.get_height(), false, _v_img.get_format(), video.get_v_data())
		_v_img_tex.update(_v_img)

	_y_img_tex.update(_y_img)
	_u_img_tex.update(_u_img)


#------------------------------------------------ MISC
func _open_video() -> void:
	var err: int = video.open(path, true)
	if err:
		printerr("Error opening video: ", err)


func _print_system_debug() -> void:
	print_rich("[b]System info")
	print("OS name: ", OS.get_name())
	print("Distro name: ", OS.get_distribution_name())
	print("OS version: ", OS.get_version())
	print_rich("Memory info:\n\t", OS.get_memory_info())
	print("CPU name: ", OS.get_processor_name())
	print("Core\threads count: ", OS.get_processor_count())
	if OS.get_name() != "Windows":
		print("GPU name: ", RenderingServer.get_video_adapter_name())
		print_rich("GPU info:\n\t", OS.get_video_adapter_driver_info())
		print_rich("Available hardware devices:\n\t", Video.get_available_hw_devices())


func _print_video_debug() -> void:
	print_rich("[b]Video debug info")
	print("Extension: ", path.get_extension())
	print("Resolution: ", _resolution)
	if OS.get_name() != "Windows":
		print("HW decoding: ", video.get_hw_decoding())
	print("Pixel format: ", video.get_pixel_format())
	print("Color profile: ", video.get_color_profile())
	print("Framerate: ", _frame_rate)
	print("Duration (in frames): ", _frame_duration)
	print("Padding: ", _padding)
	print("Rotation: ", _rotation)

