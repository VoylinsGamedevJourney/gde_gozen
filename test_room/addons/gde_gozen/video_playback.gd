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
@export var hardware_decoding: bool = true ## Setting hardware decoding uses the GPU of the system to get the frame data out of video files, this does NOT convert the data to RGB. If you want hardware pixel format conversion to be on, which is needed for hardware decoding to get good performance, you will also need to enable hardware_conversion!
@export var hardware_conversion: bool = true ## Setting hardware conversion uses the GPU to change the pixel format of the video frame to RGB. This is needed to have good performance when using Hardware decoding and can help perfomance with just software decoding.
@export var debug: bool = true ## Setting this value will print debug messages of the video file whilst opening and during playback.

var video: Video = null ## The video object uses GDEGoZen to function, this class interacts with a library called FFmpeg to get the audio and the frame data.

var texture_rect: TextureRect = TextureRect.new() ## The texture rect is the view of the video, you can adjust the scaling options as you like, it is set to always center and scale the image to fit within the main VideoPlayback node size.
var audio_player: AudioStreamPlayer = AudioStreamPlayer.new() ## Audio player is the AudioStreamPlayer which handles the audio playback for the video, only mess with the settings if you know what you are doing and know what you'd like to achieve.

var is_playing: bool = false ## Bool to check if the video is currently playing or not.
var current_frame: int = 0: set = _set_current_frame ## Current frame number which the video playback is at.


var _time_elapsed: float = 0.
var _frame_time: float = 0
var _skips: int = 0

var _resolution: Vector2i = Vector2i.ZERO
var _uv_resolution: Vector2i = Vector2i.ZERO
var _shader_material: ShaderMaterial = null



#------------------------------------------------ TREE FUNCTIONS
func _enter_tree() -> void:
	texture_rect.texture = ImageTexture.new()
	texture_rect.anchor_right = TextureRect.ANCHOR_END
	texture_rect.anchor_bottom = TextureRect.ANCHOR_END
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(texture_rect)
	add_child(audio_player)
	
	_shader_material = ShaderMaterial.new()
	texture_rect.material = _shader_material
	if debug:
		print("Available hardware devices:")
		print(Video.get_available_hw_devices())


func _exit_tree() -> void:
	if video != null:
		close()


func _ready() -> void:
	# Function get's run like this because else the project crashes as export variables get set and their setters run before the node is completely ready.
	if path != "":
		set_video_path(path)


#------------------------------------------------ VIDEO DATA HANDLING
func set_video_path(a_path: String) -> void:
	## This is the starting point for video playback, provide a path of where the video file can be found and it will load a Video object. After which [code]update_video()[/code] get's run and set's the first frame image.
	path = a_path
	if !is_node_ready():
		return

	audio_player.stream = null
	video = Video.new()
	video.set_hw_decoding(hardware_decoding)
	video.set_hw_conversion(hardware_conversion)

	if debug:
		video.enable_debug()
		if hardware_decoding:
			print("Available hardware decoders:")
			print(Video.get_available_hw_codecs(a_path))
	else:
		video.disable_debug()

	var err: int = video.open(path, true)
	if err:
		printerr("Error opening video: ", err)

	update_video(video)


func update_video(a_video: Video) -> void:
	## Only run this function after manually having added a Video object to the `video` variable. A good reason for doing this is to load your video's at startup time to prevent your program for freezing for a second when loading in big video files. Some video formats load faster then others so if you are experiencing issues with long loading times, try to use this function and create the video object on startup, or try switching the video format which you are using. 
	video = a_video
	if !is_open():
		printerr("Video isn't open!")
		return

	_resolution = video.get_resolution()
	_shader_material.shader = null

	if video.get_hw_conversion():
		var l_image: Image = Image.create_empty(_resolution.x, _resolution.y, false, Image.FORMAT_L8)
		texture_rect.texture.set_image(l_image)

		_uv_resolution = Vector2i(_resolution.x / 2, _resolution.y / 2)
		if video.get_pixel_format() == "yuv420p":
			_shader_material.shader = preload("res://addons/gde_gozen/shaders/yuv420p.gdshader")
		else:
			_shader_material.shader = preload("res://addons/gde_gozen/shaders/nv12.gdshader")

	audio_player.stream = video.get_audio()

	is_playing = false
	_frame_time = 1.0 / video.get_framerate()
	video.seek_frame(0)

	_set_frame_image()

	_on_video_loaded.emit()


func seek_frame(a_frame_nr: int) -> void:
	## Seek frame can be used to switch to a frame number you want. Remember that some video codecs report incorrect video end frames or can't seek to the last couple of frames in a video file which may result in an error. Only use this when going to far distances in the video file, else you can use [code]next_frame()[/code].
	if !is_open():
		return

	current_frame = clamp(a_frame_nr, 0, video.get_frame_duration())
	video.seek_frame(a_frame_nr)

	_set_frame_image()

	audio_player.set_stream_paused(false)
	audio_player.play(current_frame / video.get_framerate())
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
		video.close()
		video = null


#------------------------------------------------ PLAYBACK HANDLING
func _process(a_delta: float) -> void:
	if is_playing:
		_time_elapsed += a_delta
		if _time_elapsed < _frame_time:
			return

		_skips = 0
		while _time_elapsed >= _frame_time:
			_time_elapsed -= _frame_time
			current_frame += 1
			_skips += 1

		if current_frame >= video.get_frame_duration():
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
	audio_player.play((current_frame + 1) / video.get_framerate())
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
func get_frame_duration() -> int:
	## Getting the frame duration returns the total amount of frames found in a video file.
	return video.get_frame_duration()


func get_framerate() -> float:
	## Getting the framerate of a video
	return video.get_framerate()


func is_open() -> bool:
	## Checking to see if the video is open or not, trying to run functions without checking if open can crash your project.
	return video != null and video.is_open()


#------------------------------------------------ SETTERS
func _set_current_frame(a_value: int) -> void:
	current_frame = a_value
	_current_frame_changed.emit(current_frame)


func _set_frame_image() -> void:
	if hardware_conversion:
		if video.get_pixel_format() == "yuv420p":
			_shader_material.set_shader_parameter("y_data", ImageTexture.create_from_image(Image.create_from_data(_resolution.x, _resolution.y, false, Image.FORMAT_L8, video.get_y_data())))
			_shader_material.set_shader_parameter("u_data", ImageTexture.create_from_image(Image.create_from_data(_uv_resolution.x, _uv_resolution.y, false, Image.FORMAT_R8, video.get_u_data())))
			_shader_material.set_shader_parameter("v_data", ImageTexture.create_from_image(Image.create_from_data(_uv_resolution.x, _uv_resolution.y, false, Image.FORMAT_R8, video.get_v_data())))
		else:
			_shader_material.set_shader_parameter("y_data", ImageTexture.create_from_image(Image.create_from_data(_resolution.x, _resolution.y, false, Image.FORMAT_R8, video.get_y_data())))
			_shader_material.set_shader_parameter("uv_data", ImageTexture.create_from_image(Image.create_from_data(_uv_resolution.x, _uv_resolution.y, false, Image.FORMAT_RG8, video.get_u_data())))
	else:
		texture_rect.texture.set_image(video.get_frame_image())

