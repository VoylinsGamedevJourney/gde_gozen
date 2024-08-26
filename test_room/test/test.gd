extends Control


var path: String = "/storage/Youtube/02 - Gamedev Journey/Videos/2. SPONSOR_READ/Sponsor_read_full.mp4"
var video_playback: VideoPlayback = null


func _ready() -> void:
	video_playback = get_node("VideoPlayback")
	video_playback.video_path = path
	video_playback.on_play_pause()
