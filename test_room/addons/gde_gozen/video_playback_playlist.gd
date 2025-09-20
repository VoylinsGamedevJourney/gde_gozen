@tool
class_name VideoPlaybackPlaylist
extends VideoPlayback
## This node is still a work in progress!
## [br]
## Adding a lot of video files to the playback list might cause a lag spike in beginning of running the game due to all the video loading which is happening.


@export var playback_list: PackedStringArray = []: set = _set_playback_list ## The list of all the videos you'd want to play in a loop.
@export var randomize: bool = false ## Randomize the playback order.

var _playlist_threads: PackedInt64Array = []

var _videos: Dictionary[String, GoZenVideo] = {}
var _audio: Dictionary[String, AudioStreamWAV] = {}

var _current_video: String = ""



func _ready() -> void:
	if !is_node_ready():
		await ready
	if !get_tree().root.is_node_ready():
		await get_tree().root.ready

	# Load in list.
	for video_path: String in playback_list:
		add_video(video_path)


func _process(delta: float) -> void:
	if !_playlist_threads.is_empty():
		for i: int in _playlist_threads:
			if WorkerThreadPool.is_task_completed(i):
				WorkerThreadPool.wait_for_task_completion(i)
				_playlist_threads.remove_at(_playlist_threads.find(i))

	if playback_list.is_empty() or is_playing:
		return

	# If the player stopped, we set and play the next video.



## Check if videos got removed or added.
func _set_playback_list(new_list: PackedStringArray) -> void:
	for path: String in new_list:
		if path not in playback_list:
			add_video(path)

	playback_list = new_list

	for path: String in _videos.keys():
		if path not in playback_list:
			remove_video(path)


func _open_video_for_list(new_path: String) -> void:
	if video.open(new_path):
		printerr("Error opening video!")


func _open_audio_for_list(new_path: String) -> void:
	var data: PackedByteArray = GoZenAudio.get_audio_data(new_path)
	if data.size() != 0:
		audio_player.stream.data = data
	else:
		printerr("Audio data for video '%s' was 0!" % new_path)
		enable_audio = false


func add_video(new_path: String) -> void:
	if new_path == "" or new_path.ends_with(".tscn"):
		return

	_videos[new_path] = GoZenVideo.new()
	
	if enable_audio:
		_audio[new_path] = AudioStreamWAV.new()
		_audio[new_path].mix_rate = 44100
		_audio[new_path].stereo = true
		_audio[new_path].format = AudioStreamWAV.FORMAT_16_BITS

	if debug:
		video.enable_debug()
	else:
		video.disable_debug()

	if new_path.split(":")[0] == "uid":
		new_path = ResourceUID.get_id_path(ResourceUID.text_to_id(new_path))

	_playlist_threads.append(WorkerThreadPool.add_task(_open_video_for_list.bind(new_path)))
	if enable_audio:
		_playlist_threads.append(WorkerThreadPool.add_task(_open_audio_for_list.bind(new_path)))


func remove_video(path: String) -> void:
	if path in playback_list:
		playback_list.remove_at(playback_list.find(path))

	if path in _videos:
		_videos[path].close()
		_videos.erase(path)
	if path in _audio:
		_audio.erase(path)

