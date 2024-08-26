class_name VideoPlayback extends Control
## Video Playback type

@export_file var path: String: set = set_video_path

var video: Video

var texture_rect: TextureRect = TextureRect.new()
var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()

var buffers: Array[RID] = []
var uniform_sets: Array[RID] = []
var rgb_data: PackedByteArray = []

var is_playing: bool = false
var current_frame: int = 0
var time_elapsed: float = 0.0
var frame_time: float = 0
var skips: int = 0



#------------------------------------------------ TREE FUNCTIONS
func _enter_tree() -> void:
	texture_rect.anchor_right = TextureRect.ANCHOR_END
	texture_rect.anchor_bottom = TextureRect.ANCHOR_END
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(texture_rect)
	add_child(audio_player)

	buffers.resize(5)
	uniform_sets.resize(5)


func _exit_tree() -> void:
	GoZenServer.shutdown()
	if video != null:
		video.close()

	_free_buffers()
	_free_uniform_sets()

func _ready() -> void:
	if path != "":
		set_video_path(path)


#------------------------------------------------ CLEANUP CREW
func _free_buffers() -> void:
	if buffers.size() == 0:
		return
	for i: RID in buffers:
		if GoZenServer.rd.framebuffer_is_valid(i):
			GoZenServer.rd.free_rid(i)
		

func _free_uniform_sets() -> void:
	if uniform_sets.size() == 0:
		return
	for i: RID in uniform_sets:
		if GoZenServer.rd.uniform_set_is_valid(i):
			GoZenServer.rd.free_rid(i)


#------------------------------------------------ VIDEO DATA HANDLING
func set_video_path(a_path: String) -> void:
	path = a_path
	if !is_node_ready():
		return

	if !GoZenServer.running:
		GoZenServer.startup()
	if video != null:
		video.close()

	video = Video.new()
	var l_err: int = video.open(path, true)
	if !video.is_open():
		printerr("Video couldn't open! Error code: ", l_err)
		return

	audio_player.stream = video.get_audio()
	rgb_data.resize(video.get_width() * video.get_height() * 4)
	texture_rect.texture = ImageTexture.create_from_image(Image.create_empty(
			video.get_width(), video.get_height(), false, Image.FORMAT_RGBA8))

	is_playing = false
	frame_time = 1.0 / video.get_framerate()

	video.seek_frame(0)
	_free_buffers()
	buffers[0] = GoZenServer.create_storage_buffer(video.get_y())
	buffers[1] = GoZenServer.create_storage_buffer(video.get_u())
	buffers[2] = GoZenServer.create_storage_buffer(video.get_v())
	buffers[3] = GoZenServer.create_storage_buffer(rgb_data)
	buffers[4] = GoZenServer.create_storage_buffer(
			PackedInt32Array([video.get_width()]).to_byte_array())

	_free_uniform_sets()
	uniform_sets[0] = GoZenServer.create_uniform_storage_buffer(buffers[0], 0)
	uniform_sets[1] = GoZenServer.create_uniform_storage_buffer(buffers[1], 1)
	uniform_sets[2] = GoZenServer.create_uniform_storage_buffer(buffers[2], 2)
	uniform_sets[3] = GoZenServer.create_uniform_storage_buffer(buffers[3], 3)
	uniform_sets[4] = GoZenServer.create_uniform_storage_buffer(buffers[4], 4)

	var l_compute_list: int = GoZenServer.cl_begin()
	GoZenServer.cl_bind_uniform_set(l_compute_list, uniform_sets[0], 0)
	GoZenServer.cl_bind_uniform_set(l_compute_list, uniform_sets[1], 1)
	GoZenServer.cl_bind_uniform_set(l_compute_list, uniform_sets[2], 2)
	GoZenServer.cl_bind_uniform_set(l_compute_list, uniform_sets[3], 3)
	GoZenServer.cl_bind_uniform_set(l_compute_list, uniform_sets[4], 4)

	GoZenServer.cl_submit(l_compute_list, video.get_width(), video.get_height(), 1)
	texture_rect.texture.set_image(Image.create_from_data(
			video.get_width(), video.get_height(), false, Image.FORMAT_RGBA8,
			GoZenServer.rd.buffer_get_data(buffers[3])))


func seek_frame(a_frame_nr: int) -> void:
	current_frame = clamp(a_frame_nr, 0, video.get_frame_duration())
	video.seek_frame(a_frame_nr)

	audio_player.set_stream_paused(false)
	audio_player.play(current_frame / video.get_framerate())
	audio_player.set_stream_paused(!is_playing)

	update_frame()


func next_frame() -> void:
	video.next_frame()
	update_frame()


func update_frame() -> void:
	GoZenServer.buffer_update(buffers[0], video.get_y())
	GoZenServer.buffer_update(buffers[1], video.get_u())
	GoZenServer.buffer_update(buffers[2], video.get_v())

	var l_compute_list: int = GoZenServer.cl_begin()
	GoZenServer.cl_bind_uniform_set(l_compute_list, uniform_sets[0], 0)
	GoZenServer.cl_bind_uniform_set(l_compute_list, uniform_sets[1], 1)
	GoZenServer.cl_bind_uniform_set(l_compute_list, uniform_sets[2], 2)
	GoZenServer.cl_bind_uniform_set(l_compute_list, uniform_sets[3], 3)
	GoZenServer.cl_bind_uniform_set(l_compute_list, uniform_sets[4], 4)

	GoZenServer.cl_submit(l_compute_list, video.get_width(), video.get_height(), 1)

	texture_rect.texture.set_image(Image.create_from_data(
			video.get_width(), video.get_height(), false, Image.FORMAT_RGBA8,
			GoZenServer.rd.buffer_get_data(buffers[3])))


#------------------------------------------------ PLAYBACK HANDLING
func _process(a_delta: float) -> void:
	if is_playing:
		time_elapsed += a_delta
		if time_elapsed < frame_time:
			return

		skips = 0
		while time_elapsed >= frame_time:
			time_elapsed -= frame_time
			current_frame += 1
			skips += 1
		
		if current_frame >= video.get_frame_duration():
			is_playing = !is_playing
			seek_frame(0)
			audio_player.set_stream_paused(true)
		else:
			while skips != 1:
				video.next_frame()
				skips -= 1
			next_frame()


func play() -> void:
	if video != null and !video.is_open() and is_playing:
		return
	is_playing = true
	seek_frame(current_frame)


func pause() -> void:
	if video != null and !video.is_open():
		return
	is_playing = false
	audio_player.set_stream_paused(true)
