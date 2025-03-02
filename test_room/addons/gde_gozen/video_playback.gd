class_name VideoPlayback
extends Control
## Video playback and seeking inside of Godot.
##
## To use this node, just add it anywhere and resize it to the desired size. Use the function [code]set_video_path(a_path)[/code] and the video will load. Take in mind that long video's can take a second or longer to load. If this is an issue you can preload the Video on startup of your project and set the video variable yourself, just remember to use the function [code]update_video()[/code] before the moment that you'd like to use it.
## [br][br]
## There is a small limitation right now as FFmpeg requires a path to the video file so you can't make the video's part of the exported project and the [code]res://[/code] paths also don't work. This is just the nature of the beast and not something I can easily solve, but luckily there are solutions! First of all, the video path should be the full path, for testing this is easy as you can make the path whatever you want it to be, for exported projects ... Well, chances of the path being in the exact same location as on your pc are quite low.
## [br][br]
## The solution for exported projects is to create a folder inside of your exported projects in which you keep the video files, inside of your code you can check if the project is run from the editor or not with: [code]OS.has_feature(“editor”)[/code]. To get the path of your running project to find the folder where your video's are stored you can use [code]OS.get_executable_path()[/code]. So it requires a bit of code to get things properly working but everything should work without issues this way.


signal frame_changed(frame_nr: int) ## Emitted when the current frame has changed, for showing and skipped frames.
signal next_frame_called(frame_nr: int) ## Emitted when a new frame is showing.

signal video_loaded ## Emitted when the video is ready for playback.
signal video_ended ## Emitted when the last frame has been shown.

signal playback_started ## Emitted when playback started/resumed.
signal playback_paused ## Emitted when playback is paused.
signal playback_ready ## Emitted when the node if fully setup and ready for playback.


const PLAYBACK_SPEED_MIN: float = 0.25
const PLAYBACK_SPEED_MAX: float = 4


@export_file var path: String = "": set = set_video_path ## Full path to video file. Do not use [code]res://[/code] paths, only provide [b]full[/b] paths. Solutions for setting the path in both editor and exported projects can be found in the readme info or on top.
@export var hardware_decoding: bool = false ## Enable GPU decoding when available, this isn't useful for most cases due to some codecs being slower with GPU decoding.
@export var enable_audio: bool = true ## Enable/Disable audio playback. When setting this on false before loading the audio, the audio playback won't be loaded meaning that the video will load faster. If you want audio but only disable it at certain moments, switch this value to false *after* the video is loaded.
@export var enable_auto_play: bool = false ## Enable/disable auto video playback.
@export_range(PLAYBACK_SPEED_MIN, PLAYBACK_SPEED_MAX, 0.05)
var playback_speed: float = 1.0: set = set_playback_speed ## Adjust the video playback speed, 0.5 = half the speed and 2 = double the speed.
@export var pitch_adjust: bool = true: set = set_pitch_adjust ## When changing playback speed, do you want the pitch to change or stay the same?
@export var debug: bool = false ## Enable/disable the printing of debug info.

var video: Video = null ## Video class object of GDE GoZen which interacts with video files through FFmpeg.

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
var _uv_resolution: Vector2i = Vector2i.ZERO
var _shader_material: ShaderMaterial = null

var _thread: Thread = Thread.new()
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
	## Function get's run like this because else the project crashes as export variables get set and their setters run before the node is completely ready.
	if path != "":
		set_video_path(path)

	playback_ready.emit()


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

	if debug:
		video.enable_debug()
	else:
		video.disable_debug()

	if _thread.start(_open_video):
		printerr("Couldn't create thread!")


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
	_frame_count = video.get_frame_count()
	_uv_resolution = Vector2i(int((_resolution.x + _padding) / 2.), int(_resolution.y / 2.))
	l_image = Image.create_empty(_resolution.x, _resolution.y, false, Image.FORMAT_R8)

	if debug:
		_print_video_debug()

	video_texture.texture.set_image(l_image)

	if video.get_pixel_format().begins_with("yuv"):
		if video.is_full_color_range():
			_shader_material.shader = preload("res://addons/gde_gozen/shaders/yuv420p_full.gdshader")
		else:
			_shader_material.shader = preload("res://addons/gde_gozen/shaders/yuv420p_standard.gdshader")
	else:
		if video.is_full_color_range():
			_shader_material.shader = preload("res://addons/gde_gozen/shaders/nv12_full.gdshader")
		else:
			_shader_material.shader = preload("res://addons/gde_gozen/shaders/nv12_standard.gdshader")

	match video.get_color_profile():
		"bt601", "bt470": _shader_material.set_shader_parameter("color_profile", Vector4(1.402, 0.344136, 0.714136, 1.772))
		"bt2020", "bt2100": _shader_material.set_shader_parameter("color_profile", Vector4(1.4746, 0.16455, 0.57135, 1.8814))
		_: # bt709 and unknown
			_shader_material.set_shader_parameter("color_profile", Vector4(1.5748, 0.1873, 0.4681, 1.8556))

	_shader_material.set_shader_parameter("resolution", _resolution)
	
	if enable_audio:
		audio_player.stream = video.get_audio()

	is_playing = false
	set_playback_speed(playback_speed)
	current_frame = 0
	if video.seek_frame(current_frame):
		printerr("Couldn't seek frame!")

	_set_frame_image()

	video_loaded.emit()


func seek_frame(a_frame_nr: int) -> void:
	## Seek frame can be used to switch to a frame number you want. Remember that some video codecs report incorrect video end frames or can't seek to the last couple of frames in a video file which may result in an error. Only use this when going to far distances in the video file, else you can use [code]next_frame()[/code].
	if !is_open() and a_frame_nr == current_frame:
		return

	current_frame = clamp(a_frame_nr, 0, _frame_count)
	if video.seek_frame(a_frame_nr):
		printerr("Couldn't seek frame!")
	else:
		_set_frame_image()

	if enable_audio:
		audio_player.set_stream_paused(false)
		audio_player.play(current_frame / _frame_rate)
		audio_player.set_stream_paused(!is_playing)


func next_frame(a_skip: bool = false) -> void:
	## Seeking frames can be slow, so when you just need to go a couple of frames ahead, you can use next_frame and set skip to false for the last frame.
	if video.next_frame(a_skip) and !a_skip:
		_set_frame_image()
		next_frame_called.emit(current_frame)
	elif !a_skip:
		print("Something went wrong getting next frame!")

	
func close() -> void:
	if video != null:
		if is_playing:
			pause()
		video = null


#------------------------------------------------ PLAYBACK HANDLING
func _process(a_delta: float) -> void:
	if _thread.is_started():
		if !_thread.is_alive():
			_thread.wait_to_finish()
			update_video(video)
			if enable_auto_play:
				play()
		return

	if is_playing:
		_time_elapsed += a_delta

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


func _get_img_tex(a_data: PackedByteArray, a_width: int, a_height: int, a_r8: bool = true) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create_from_data(
			a_width, a_height, false,
			Image.FORMAT_R8 if a_r8 else Image.FORMAT_RG8, a_data))


#------------------------------------------------ SETTERS
func _set_current_frame(a_value: int) -> void:
	current_frame = a_value
	frame_changed.emit(current_frame)


func _set_frame_image() -> void:
	#first frame create texture
	if(!y_texture):
		y_texture = ImageTexture.create_from_image(video.get_y_data())
		u_texture = ImageTexture.create_from_image(video.get_u_data())
		if video.get_pixel_format().begins_with("yuv"):
			v_texture = ImageTexture.create_from_image(video.get_v_data())
	else: #just need to update texture, should be faster
		y_texture.update(video.get_y_data())
		u_texture.update(video.get_u_data())
		if video.get_pixel_format().begins_with("yuv"):
			v_texture.update(video.get_v_data())

	_shader_material.set_shader_parameter("y_data", y_texture)
	_shader_material.set_shader_parameter("u_data", u_texture)
	if video.get_pixel_format().begins_with("yuv"):
		_shader_material.set_shader_parameter("v_data", v_texture)


func set_playback_speed(a_value: float) -> void:
	playback_speed = clampf(a_value, 0.5, 2)
	_frame_time = (1.0 / _frame_rate) / playback_speed

	if enable_audio and audio_player.stream != null:
		audio_player.pitch_scale = playback_speed
		_set_pitch_adjust()

		if is_playing:
			audio_player.play(current_frame * (1.0 / _frame_rate))


func set_pitch_adjust(a_value: bool) -> void:
	pitch_adjust = a_value
	_set_pitch_adjust()


func _set_pitch_adjust() -> void:
	if pitch_adjust:
		_audio_pitch_effect.pitch_scale = clamp(1.0 / playback_speed, 0.5, 2.0)
	elif _audio_pitch_effect.pitch_scale != 1.0:
		_audio_pitch_effect.pitch_scale = 1.0



#------------------------------------------------ MISC
func _open_video() -> void:
	var err: int = video.open(path, enable_audio)
	if err:
		printerr("Error opening video!")
		GoZenError.print_error(err)


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
	print("Duration (in frames): ", _frame_count)
	print("Padding: ", _padding)
	print("Rotation: ", _rotation)
	print("Full color range: ", video.is_full_color_range())
	
