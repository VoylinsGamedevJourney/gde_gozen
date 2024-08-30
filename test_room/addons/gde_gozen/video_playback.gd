class_name VideoPlayback extends Control
## Video playback and seeking inside of Godot.
##
## To use this node, just add it anywhere and resize it to the desired size. Use the function [code]set_video_path(a_path)[/code] and the video will load. Take in mind that long video's can take a second or longer to load. If this is an issue you can preload the Video on startup of your project and set the video variable yourself, just remember to use the function [code]update_video()[/code] before the moment that you'd like to use it.
## [br][br]
## There is a small limitation right now as FFmpeg requires a path to the video file so you can't make the video's part of the exported project and the [code]res://[/code] paths also don't work. This is just the nature of the beast and not something I can easily solve, but luckily there are solutions! First of all, the video path should be the full path, for testing this is easy as you can make the path whatever you want it to be, for exported projects ... Well, chances of the path being in the exact same location as on your pc are quite low.
## [br][br]
## The solution for exported projects is to create a folder inside of your exported projects in which you keep the video files, inside of your code you can check if the project is run from the editor or not with: [code]OS.has_feature(“editor”)[/code]. To get the path of your running project to find the folder where your video's are stored you can use [code]OS.get_executable_path()[/code]. So it requires a bit of code to get things properly working but everything should work without issues this way.




signal _current_frame_changed(frame_nr) ## Getting the current frame might be usefull if you want certain events to happen at a certain frame number. In the test project we use it for making the timeline move along with the video


@export_file var path: String = "": set = set_video_path ## You can set the video path straigth from the editor, you can also set it through code to do it more dynamically. Use the README to find out more about the limitations. Only provide [b]FULL[/b] paths, not [code]res://[/code] paths as FFmpeg can't deal with those. Solutions for setting the path in both editor and exported projects can be found in the readme info or on top.

var video: Video = null ## The video object uses GDEGoZen to function, this class interacts with a library called FFmpeg to get the audio and the frame data.

var texture_rect: TextureRect = TextureRect.new() ## The texture rect is the view of the video, you can adjust the scaling options as you like, it is set to always center and scale the image to fit within the main VideoPlayback node size.
var audio_player: AudioStreamPlayer = AudioStreamPlayer.new() ## Audio player is the AudioStreamPlayer which handles the audio playback for the video, only mess with the settings if you know what you are doing and know what you'd like to achieve.

var _buffers: Array[RID] = []
var _uniform_sets: Array[RID] = []
var _textures: Array[RID] = []

var _texture_fmt: RDTextureFormat

var is_playing: bool = false ## Bool to check if the video is currently playing or not.
var current_frame: int = 0: set = _set_current_frame ## Current frame number which the video playback is at.


var _time_elapsed: float = 0.0
var _frame_time: float = 0
var _skips: int = 0



#------------------------------------------------ TREE FUNCTIONS
func _enter_tree() -> void:
	texture_rect.texture = Texture2DRD.new()
	texture_rect.anchor_right = TextureRect.ANCHOR_END
	texture_rect.anchor_bottom = TextureRect.ANCHOR_END
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(texture_rect)
	add_child(audio_player)

	_buffers.resize(5)
	_uniform_sets.resize(5)
	_textures.resize(1)


func _exit_tree() -> void:
	GoZenServer.shutdown()
	if video != null:
		video.close()

	_free_buffers()
	_free_uniform_sets()
	_free_textures()


func _ready() -> void:
	# Function get's run like this because else the project crashes as export variables get set and their setters run before the node is completely ready.
	if path != "":
		set_video_path(path)


#------------------------------------------------ CLEANUP CREW
func _free_buffers() -> void:
	if _buffers.size() == 0:
		return
	for i: RID in _buffers:
		if GoZenServer.rd.framebuffer_is_valid(i):
			GoZenServer.rd.free_rid(i)
		

func _free_uniform_sets() -> void:
	if _uniform_sets.size() == 0:
		return
	for i: RID in _uniform_sets:
		if GoZenServer.rd.uniform_set_is_valid(i):
			GoZenServer.rd.free_rid(i)


func _free_textures() -> void:
	if _textures.size() == 0:
		return
	for i: RID in _textures:
		if GoZenServer.rd.texture_is_valid(i):
			GoZenServer.rd.free_rid(i)


#------------------------------------------------ VIDEO DATA HANDLING
func set_video_path(a_path: String) -> void:
	## This is the starting point for video playback, provide a path of where the video file can be found and it will load a Video object. After which [code]update_video()[/code] get's run and set's all the buffers for our shader which will help to display the current frame image.
	path = a_path
	if !is_node_ready():
		return

	if !GoZenServer.running:
		GoZenServer.startup()
	if video != null:
		video.close()

	video = Video.new()
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

	audio_player.stream = video.get_audio()

	is_playing = false
	_frame_time = 1.0 / video.get_framerate()
	
	_free_textures()
	_texture_fmt = RDTextureFormat.new()
	_texture_fmt.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	_texture_fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	_texture_fmt.width = video.get_width()
	_texture_fmt.height = video.get_height()
	_texture_fmt.depth = 1
	_texture_fmt.array_layers = 1
	_texture_fmt.mipmaps = 1
	_texture_fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	_textures[0] = GoZenServer.create_image(_texture_fmt)
	(texture_rect.texture as Texture2DRD).set_texture_rd_rid(_textures[0])

	video.seek_frame(0)
	_free_buffers()
	_buffers[0] = GoZenServer.create_storage_buffer(video.get_y())
	_buffers[1] = GoZenServer.create_storage_buffer(video.get_u())
	_buffers[2] = GoZenServer.create_storage_buffer(video.get_v())
	_buffers[3] = GoZenServer.create_storage_buffer(PackedInt32Array([video.get_width()]).to_byte_array())

	_free_uniform_sets()
	_uniform_sets[0] = GoZenServer.create_uniform_storage_buffer(_buffers[0], 0)
	_uniform_sets[1] = GoZenServer.create_uniform_storage_buffer(_buffers[1], 1)
	_uniform_sets[2] = GoZenServer.create_uniform_storage_buffer(_buffers[2], 2)
	_uniform_sets[3] = GoZenServer.create_uniform_storage_buffer(_buffers[3], 3)
	_uniform_sets[4] = GoZenServer.create_uniform_image(_textures[0], 4)

	_compute_list_dispatch()


func seek_frame(a_frame_nr: int) -> void:
	## Seek frame can be used to switch to a frame number you want. Remember that some video codecs report incorrect video end frames or can't seek to the last couple of frames in a video file which may result in an error. Only use this when going to far distances in the video file, else you can use [code]next_frame()[/code].
	if !is_open():
		return

	current_frame = clamp(a_frame_nr, 0, video.get_frame_duration())
	video.seek_frame(a_frame_nr)

	audio_player.set_stream_paused(false)
	audio_player.play(current_frame / video.get_framerate())
	audio_player.set_stream_paused(!is_playing)

	_update_frame()


func next_frame(a_skip: bool = false) -> void:
	## Seeking frames can be slow, so when you just need to go a couple of frames ahead, you can use next_frame and set skip to false for the last frame.
	video.next_frame(a_skip)

	if !a_skip:
		_update_frame()


func _update_frame() -> void:
	GoZenServer.buffer_update(_buffers[0], video.get_y())
	GoZenServer.buffer_update(_buffers[1], video.get_u())
	GoZenServer.buffer_update(_buffers[2], video.get_v())
	_compute_list_dispatch()


func _compute_list_dispatch() -> void:
	var l_compute_list: int = GoZenServer.cl_begin()
	GoZenServer.cl_bind_uniform_set(l_compute_list, _uniform_sets[0], 0)
	GoZenServer.cl_bind_uniform_set(l_compute_list, _uniform_sets[1], 1)
	GoZenServer.cl_bind_uniform_set(l_compute_list, _uniform_sets[2], 2)
	GoZenServer.cl_bind_uniform_set(l_compute_list, _uniform_sets[3], 3)
	GoZenServer.cl_bind_uniform_set(l_compute_list, _uniform_sets[4], 4)

	GoZenServer.cl_dispatch(l_compute_list, video.get_width(), video.get_height(), 1)


#------------------------------------------------ PLAYBACK HANDLING
func _process(a_delta: float) -> void:
	if is_playing:
		_time_elapsed += a_delta
		if _time_elapsed < _frame_time:
			return
		_handle_update()


func _handle_update() -> void:
		_skips = 0
		while _time_elapsed >= _frame_time:
			_time_elapsed -= _frame_time
			current_frame += 1
			_skips += 1
		
		if current_frame >= video.get_frame_duration():
			is_playing = !is_playing
			audio_player.set_stream_paused(true)
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
	seek_frame(current_frame)


func pause() -> void:
	## Pausing the video.
	if video != null and !is_open():
		return
	is_playing = false
	audio_player.set_stream_paused(true)


#------------------------------------------------ SETTERS
func _set_current_frame(a_value: int) -> void:
	current_frame = a_value
	_current_frame_changed.emit(current_frame)


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
