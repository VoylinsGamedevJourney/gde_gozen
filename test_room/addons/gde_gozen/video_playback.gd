class_name VideoPlayback
extends Control
## Video playback and seeking inside of Godot.
##
## To use this node, just add it anywhere and resize it to the desired size. Use the function [code]set_video_path(new_path)[/code] and the video will load. Take in mind that long video's can take a second or longer to load. If this is an issue you can preload the Video on startup of your project and set the video variable yourself, just remember to use the function [code]update_video()[/code] before the moment that you'd like to use it.

enum COLOR_PROFILE { AUTO, BT470, BT601, BT709, BT2020, BT2100 }
enum STREAM_TYPE { VIDEO = 0, AUDIO = 1, SUBTITLE = 2 }


signal frame_changed(frame_nr: int) ## Emitted when the current frame has changed, for showing and skipped frames.
signal next_frame_called(frame_nr: int) ## Emitted when a new frame is showing.

signal video_loaded ## Emitted when the video is ready for playback.
signal video_ended ## Emitted when the last frame has been shown.

signal playback_started ## Emitted when playback started/resumed.
signal playback_paused ## Emitted when playback is paused.
signal playback_ready ## Emitted when the node if fully setup and ready for playback.


const SHADER_PATH: String = "res://addons/gde_gozen/yuv_to_rgb.gdshader"
const PLAYBACK_SPEED_MIN: float = 0.25
const PLAYBACK_SPEED_MAX: float = 4
const AUDIO_OFFSET_THRESHOLD: float = 0.1


@export_file var path: String = "": set = set_video_path ## Full path to video file.
@export var enable_audio: bool = true ## Enable/Disable audio playback. When setting this on false before loading the audio, the audio playback won't be loaded meaning that the video will load faster. If you want audio but only disable it at certain moments, switch this value to false *after* the video is loaded.
@export var audio_speed_to_sync: bool = false ## Enable/Disable a slight audio playback speed increase/reduction when syncing audio and video to avoid a hard cut.
@export var enable_auto_play: bool = false ## Enable/disable auto video playback.
@export_range(PLAYBACK_SPEED_MIN, PLAYBACK_SPEED_MAX, 0.05)
var playback_speed: float = 1.0: set = set_playback_speed ## Adjust the video playback speed, 0.5 = half the speed and 2 = double the speed.
@export var pitch_adjust: bool = true: set = set_pitch_adjust ## When changing playback speed, do you want the pitch to change or stay the same?
@export var loop: bool = false ## Enable/disable looping on video_ended.
@export_group("Extra's")
@export var color_profile: COLOR_PROFILE = COLOR_PROFILE.AUTO: set = _set_color_profile ## Force a specific color profile if needed.
@export var debug: bool = false ## Enable/disable the printing of debug info.

var video: GoZenVideo = null ## Video class object of GDE GoZen which interacts with video files through FFmpeg.

var video_texture: TextureRect = TextureRect.new() ## The texture rect is the view of the video, you can adjust the scaling options as you like, it is set to always center and scale the image to fit within the main VideoPlayback node size.
var audio_player: AudioStreamPlayer = AudioStreamPlayer.new() ## Audio player is the AudioStreamPlayer which handles the audio playback for the video, only mess with the settings if you know what you are doing and know what you'd like to achieve.

var is_playing: bool = false ## Bool to check if the video is currently playing or not.
var current_frame: int = 0: set = _set_current_frame ## Current frame number which the video playback is at.

var video_streams: PackedInt32Array = [] ## List of video streams in the video file.
var audio_streams: PackedInt32Array = [] ## List of audio streams in the video file.
var subtitle_streams: PackedInt32Array = [] ## List of subtitle streams in the video file.
var chapters: Array[Chapter] = [] ## List of chapters in the video file.

var _time_elapsed: float = 0.
var _frame_time: float = 0
var _skips: int = 0

var _rotation: int = 0
var _padding: int = 0
var _frame_rate: float = 0.
var _frame_count: int = 0
var _has_alpha: bool = false

var _resolution: Vector2i = Vector2i.ZERO
var _shader_material: ShaderMaterial = null

var _threads: PackedInt64Array = []
var _audio_pitch_effect: AudioEffectPitchShift = AudioEffectPitchShift.new()

var y_texture: ImageTexture;
var u_texture: ImageTexture;
var v_texture: ImageTexture;
var a_texture: ImageTexture;



#------------------------------------------------ TREE FUNCTIONS
func _enter_tree() -> void:
	var empty_image: Image = Image.create_empty(2,2,false, Image.FORMAT_R8)

	y_texture = ImageTexture.create_from_image(empty_image)
	u_texture = ImageTexture.create_from_image(empty_image)
	v_texture = ImageTexture.create_from_image(empty_image)
	a_texture = ImageTexture.create_from_image(empty_image)

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = preload(SHADER_PATH)

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

	if debug and OS.get_name().to_lower() != "web":
		_print_system_debug()


func _exit_tree() -> void:
	# Making certain no remaining tasks are running in separate threads.
	while !_threads.is_empty():
		for i: int in _threads:
			if WorkerThreadPool.is_task_completed(i):
				var error: int = WorkerThreadPool.wait_for_task_completion(i)

				if error != OK:
					printerr("Something went wrong waiting for task completion! %s" % error)

				_threads.remove_at(_threads.find(i))

	if video != null:
		close()
	
	AudioServer.remove_bus(AudioServer.get_bus_index(audio_player.bus))


func _ready() -> void:
	playback_ready.emit()


#------------------------------------------------ VIDEO DATA HANDLING
## This is the starting point for video playback, provide a path of where
## the video file can be found and it will load a Video object. After which
## [code]_update_video()[/code] get's run and set's the first frame image.
func set_video_path(new_path: String) -> void:
	if video != null:
		close()

	if !is_node_ready():
		await ready
	if !get_tree().root.is_node_ready():
		await get_tree().root.ready

	audio_player.stream = null # Cleaning up the stream just in case.

	if new_path == "" or new_path.ends_with(".tscn"):
		return
	elif new_path.split(":")[0] == "uid":
		new_path = ResourceUID.get_id_path(ResourceUID.text_to_id(new_path))

	path = new_path
	video = GoZenVideo.new()

	if debug:
		video.enable_debug()
	else:
		video.disable_debug()

	if _threads.append(WorkerThreadPool.add_task(_open_video)):
		push_error("Something went wrong appending thread to _threads!")
	if enable_audio:
		_open_audio()


## Update the video manually by providing a GoZenVideo instance and an optional AudioStreamWAV.
func update_video(video_instance: GoZenVideo) -> void:
	if video != null:
		close()

	_update_video(video_instance)
	_open_audio()


## Only run this function after manually having added a Video object to the `video` variable. A good reason for doing this is to load your video's at startup time to prevent your program for freezing for a second when loading in big video files. Some video formats load faster then others so if you are experiencing issues with long loading times, try to use this function and create the video object on startup, or try switching the video format which you are using. 
func _update_video(new_video: GoZenVideo) -> void:
	video = new_video
	if !is_open():
		printerr("Video isn't open!")
		return

	var image: Image
	var rotation_radians: float = deg_to_rad(video.get_rotation())

	is_playing = false
	current_frame = 0

	# Getting video data
	_padding = video.get_padding()
	_rotation = video.get_rotation()
	_frame_rate = video.get_framerate()
	_resolution = video.get_resolution()
	_frame_count = video.get_frame_count()
	_has_alpha = video.get_has_alpha()

	video_streams = video.get_streams(STREAM_TYPE.VIDEO)
	audio_streams = video.get_streams(STREAM_TYPE.AUDIO)
	subtitle_streams = video.get_streams(STREAM_TYPE.SUBTITLE)
	
	chapters.clear()
	for i: int in range(video.get_chapter_count()):
		@warning_ignore("UNSAFE_CALL_ARGUMENT")
		var chapter: Chapter = Chapter.new(
			video.get_chapter_start(i),
			video.get_chapter_end(i),
			video.get_chapter_metadata(i).get("title", "")
		)
		chapters.append(chapter)
		
	if abs(_rotation) == 90:
		image = Image.create_empty(_resolution.y, _resolution.x, false, Image.FORMAT_R8)
	else:
		image = Image.create_empty(_resolution.x, _resolution.y, false, Image.FORMAT_R8)

	image.fill(Color.WHITE)

	if debug:
		_print_video_debug()

	@warning_ignore("UNSAFE_METHOD_ACCESS")
	video_texture.texture.set_image(image)

	# Applying shader params.
	_shader_material.set_shader_parameter("resolution", video.get_actual_resolution())
	_shader_material.set_shader_parameter("full_color", video.is_full_color_range())
	_shader_material.set_shader_parameter("interlaced", video.get_interlaced())
	_shader_material.set_shader_parameter("rotation", rotation_radians)
	_set_color_profile()

	y_texture.set_image(video.get_y_data())
	u_texture.set_image(video.get_u_data())
	v_texture.set_image(video.get_v_data())
	a_texture.set_image(video.get_a_data() if _has_alpha else image)

	_shader_material.set_shader_parameter("y_data", y_texture)
	_shader_material.set_shader_parameter("u_data", u_texture)
	_shader_material.set_shader_parameter("v_data", v_texture)
	_shader_material.set_shader_parameter("a_data", a_texture)

	set_playback_speed(playback_speed)
	seek_frame(current_frame)

	video_loaded.emit()


## Sometimes color profiles are unknown from video files and in case that happens, the colors might be slightly off. Changing the export variable `color_profile` might help fixing the colors.
func _set_color_profile(new_profile: COLOR_PROFILE = color_profile) -> void:
	var color_data: Vector4
	var profile_str: String = video.get_color_profile()

	color_profile = new_profile

	if new_profile != COLOR_PROFILE.AUTO:
		profile_str = str(COLOR_PROFILE.find_key(COLOR_PROFILE.BT2100)).to_lower()

	match profile_str:
		"bt2020", "bt2100": color_data = Vector4(1.4746, 0.16455, 0.57135, 1.8814)
		"bt601", "bt470": color_data = Vector4(1.402, 0.344136, 0.714136, 1.772)
		_: color_data = Vector4(1.5748, 0.1873, 0.4681, 1.8556) # bt709 and unknown

	_shader_material.set_shader_parameter("color_profile", color_data)


## Seek frame can be used to switch to a frame number you want. Remember that some video codecs report incorrect video end frames or can't seek to the last couple of frames in a video file which may result in an error. Only use this when going to far distances in the video file, else you can use [code]next_frame()[/code].
func seek_frame(new_frame_nr: int) -> void:
	if !is_open() and new_frame_nr == current_frame:
		return

	current_frame = clamp(new_frame_nr, 0, _frame_count)
	if video.seek_frame(current_frame):
		printerr("Couldn't seek frame!")
	else:
		_set_frame_image()

	if enable_audio and audio_player.stream.get_length() != 0:
		audio_player.set_stream_paused(false)
		audio_player.play(current_frame / _frame_rate)
		audio_player.set_stream_paused(!is_playing)


## Seeking frames can be slow, so when you just need to go a couple of frames ahead, you can use next_frame and set skip to false for the last frame.
func next_frame(skip: bool = false) -> void:
	if video.next_frame(skip) and !skip:
		_set_frame_image()
		next_frame_called.emit(current_frame)
	elif !skip:
		print("Something went wrong getting next frame!")

	
func close() -> void:
	if video != null:
		if is_playing:
			pause()

		video = null

		y_texture = null
		u_texture = null
		v_texture = null
		a_texture = null


#------------------------------------------------ PLAYBACK HANDLING
func _process(delta: float) -> void:
	if is_playing:
		_skips = 0
		_time_elapsed += delta

		if _time_elapsed < _frame_time:
			return

		while _time_elapsed >= _frame_time and _skips < 5:
			_time_elapsed -= _frame_time
			current_frame += 1
			_skips += 1

		if current_frame >= _frame_count:
			is_playing = !is_playing

			if enable_audio and audio_player.stream != null:
				audio_player.set_stream_paused(true)

			video_ended.emit()

			if loop:
				seek_frame(0)
				play()
		else:
			_sync_audio_video()

			while _skips != 1:
				next_frame(true)
				_skips -= 1
			next_frame()
	elif !_threads.is_empty():
		for i: int in _threads:
			if WorkerThreadPool.is_task_completed(i):
				var error: int = WorkerThreadPool.wait_for_task_completion(i)

				if error != OK:
					printerr("Something went wrong waiting for task completion! %s" % error)

				_threads.remove_at(_threads.find(i))

			if _threads.is_empty():
				_update_video(video)

				if enable_auto_play:
					play()


## Start the video playback. This will play until reaching the end of the video and then pause and go back to the start.
func play() -> void:
	if video != null and !is_open() and is_playing:
		return
	is_playing = true

	if enable_audio and audio_player.stream.get_length() != 0:
		audio_player.set_stream_paused(false)
		audio_player.play((current_frame + 1) / _frame_rate)
		audio_player.set_stream_paused(!is_playing)

	playback_started.emit()


## Pausing the video.
func pause() -> void:
	is_playing = false
	
	if enable_audio and audio_player.stream != null:
		audio_player.set_stream_paused(true)

	playback_paused.emit()


## Ensures the audio playback is in sync with the video
func _sync_audio_video() -> void:
	if  _time_elapsed < 1.20:
		return
	elif enable_audio and audio_player.stream.get_length() != 0:
		var audio_offset: float = audio_player.get_playback_position() + AudioServer.get_time_since_last_mix() - (current_frame + 1) / _frame_rate

		if abs(audio_player.get_playback_position() + AudioServer.get_time_since_last_mix() - (current_frame + 1) / _frame_rate) > AUDIO_OFFSET_THRESHOLD:
			if debug: print("Audio Sync: time correction: ", audio_offset)
			audio_player.seek((current_frame + 1) / _frame_rate)
			audio_player.pitch_scale = playback_speed
		elif audio_speed_to_sync:
			if is_zero_approx(audio_player.pitch_scale - playback_speed):
				if audio_offset > AUDIO_OFFSET_THRESHOLD / 2:
					audio_player.pitch_scale = playback_speed * 0.99
					if debug: print("Audio Sync: slow down")
				elif audio_offset < -AUDIO_OFFSET_THRESHOLD / 2:
					audio_player.pitch_scale = playback_speed * 1.01
					if debug: print("Audio Sync: speed up")
			else:
				if not (audio_player.pitch_scale > playback_speed) != not (audio_offset < 0):
					audio_player.pitch_scale = playback_speed
					if debug: print("Audio Sync: back to normal")


#------------------------------------------------ GETTERS
## Getting the total amount of frames found in the video file.
func get_video_frame_count() -> int:
	return _frame_count


## Getting the framerate of the video
func get_video_framerate() -> float:
	return _frame_rate


## Getting the length of the video in seconds
func get_video_length() -> int:
	return int(_frame_count / _frame_rate)


## Getting the current playback position of the video in seconds
func get_current_playback_position() -> int:
	return int(current_frame / _frame_rate)


## Getting the rotation in degrees of the video
func get_video_rotation() -> int:
	return _rotation


## Check the alpha value of a video to know if this video has alpha or not
func is_video_alpha() -> bool:
	return _has_alpha


## Getting the title of a stream.
func get_stream_title(stream: int) -> String:
	if not is_open():
		printerr("Video is not open!")
		return ""

	return video.get_stream_metadata(stream).get("title")


## Getting the language of a stream.
func get_stream_language(stream: int) -> String:
	if not is_open():
		printerr("Video is not open!")
		return ""

	return video.get_stream_metadata(stream).get("language")


## Checking to see if the video is open or not, trying to run functions without checking if open can crash your project.
func is_open() -> bool:
	return video != null and video.is_open()


func _get_img_tex(image_data: PackedByteArray, width: int, height: int, r8: bool = true) -> ImageTexture:
	var format: Image.Format = Image.FORMAT_R8 if r8 else Image.FORMAT_RG8
	var image: Image = Image.create_from_data(width, height, false, format, image_data)

	return ImageTexture.create_from_image(image)


#------------------------------------------------ SETTERS
func _set_current_frame(new_current_frame: int) -> void:
	current_frame = new_current_frame
	frame_changed.emit(current_frame)


func _set_frame_image() -> void:
	RenderingServer.texture_2d_update(y_texture.get_rid(), video.get_y_data(), 0)
	RenderingServer.texture_2d_update(u_texture.get_rid(), video.get_u_data(), 0)
	RenderingServer.texture_2d_update(v_texture.get_rid(), video.get_v_data(), 0)

	if _has_alpha:
		RenderingServer.texture_2d_update(a_texture.get_rid(), video.get_a_data(), 0)


func set_playback_speed(new_playback_value: float) -> void:
	playback_speed = clampf(new_playback_value, 0.5, 2)
	_frame_time = (1.0 / _frame_rate) / playback_speed

	if enable_audio and audio_player.stream != null:
		audio_player.pitch_scale = playback_speed
		_set_pitch_adjust()

		if is_playing:
			audio_player.play(current_frame * (1.0 / _frame_rate))


func set_pitch_adjust(new_pitch_value: bool) -> void:
	pitch_adjust = new_pitch_value
	_set_pitch_adjust()


func _set_pitch_adjust() -> void:
	if pitch_adjust:
		_audio_pitch_effect.pitch_scale = clamp(1.0 / playback_speed, 0.5, 2.0)
	elif _audio_pitch_effect.pitch_scale != 1.0:
		_audio_pitch_effect.pitch_scale = 1.0


func set_audio_stream(stream: int) -> void:
	if not is_open():
		printerr("Video is not open!")
		return
	
	if not stream in audio_streams:
		printerr("Invalid audio stream!")
		return

	if enable_audio:
		_open_audio(stream)
		if is_playing and audio_player.stream.get_length() != 0:
			audio_player.set_stream_paused(false)
			audio_player.play(current_frame / _frame_rate)
			audio_player.set_stream_paused(!is_playing)


#------------------------------------------------ MISC
## Converts the given duration as seconds in a formatted string. (hh):mm:ss
func duration_to_formatted_string(duration_in_seconds: float) -> String:
	var hours: int = floori(duration_in_seconds / 3600.0)
	var minutes: int = floori(duration_in_seconds / 60.0) % 60
	var seconds: int = floori(duration_in_seconds) % 60

	if hours == 0:
		return "%02d:%02d" % [minutes, seconds]
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func _open_video() -> void:
	if video.open(path):
		printerr("Error opening video!")


func _open_audio(stream_id: int = -1) -> void:
	var stream: AudioStreamFFmpeg = AudioStreamFFmpeg.new()

	if stream.open(path, stream_id) != OK:
		printerr("Failed to open AudioStreamFFmpeg for: %s" % path)
		return

	audio_player.stream = stream


func _print_stream_info(streams: PackedInt32Array) -> void:
	for i: int in range(len(streams)):
		var metadata: Dictionary = video.get_stream_metadata(streams[i])
		var title: String = metadata.get("title")
		var language: String = metadata.get("language")

		if title == "":
			title = "Track " + str(i + 1)
		if language != "":
			title += " - %s" % language

		print("- %s" % title)


func _print_system_debug() -> void:
	print_rich("[b]System info")
	print("OS name: ", OS.get_name())
	print("Distro name: ", OS.get_distribution_name())
	print("OS version: ", OS.get_version())
	print_rich("Memory info:\n\t", OS.get_memory_info())
	print("CPU name: ", OS.get_processor_name())
	print("Threads count: ", OS.get_processor_count())


func _print_video_debug() -> void:
	print_rich("[b]Video debug info")
	print("Extension: ", path.get_extension())
	print("Resolution: ", _resolution)
	print("Actual resolution: ", video.get_actual_resolution())
	print("Pixel format: ", video.get_pixel_format())
	print("Color profile: ", video.get_color_profile())
	print("Framerate: ", _frame_rate)
	print("Duration (in frames): ", _frame_count)
	print("Padding: ", _padding)
	print("Rotation: ", _rotation)
	print("Alpha: ", _has_alpha)
	print("Full color range: ", video.is_full_color_range())
	print("Interlaced flag: ", video.get_interlaced())
	print("Using sws: ", video.is_using_sws())
	print("Sar: ", video.get_sar())

	if video_streams.size() != 0:
		print_rich("Video streams: [i](%s)" % video_streams.size())
		_print_stream_info(video_streams)
	else:
		print("No video streams found.")

	if audio_streams.size() != 0:
		print_rich("Audio streams: [i](%s)" % audio_streams.size())
		_print_stream_info(audio_streams)
	else:
		print("No audio streams found.")

	if subtitle_streams.size() != 0:
		print_rich("Subtitle streams: [i](%s)" % subtitle_streams.size())
		_print_stream_info(subtitle_streams)
	else:
		print("No subtitle streams found.")
	
	if chapters.size() != 0:
		print_rich("Chapters: [i](%s)" % chapters.size())
		for i: int in range(chapters.size()):
			var title: String = chapters[i].title
			if title == "":
				title = "Chapter " + str(i + 1)
			print("- %s-%s - %s" % [
				duration_to_formatted_string(chapters[i].start),
				duration_to_formatted_string(chapters[i].end),
				title
			])
	else:
		print("No chapters found.")



class Chapter:
	var start: float ## Start of the chapter in seconds.
	var end: float ## End of the chapter in seconds.
	var title: String

	func _init(_start: float, _end: float, _title: String) -> void:
		start = _start
		end = _end
		title = _title
