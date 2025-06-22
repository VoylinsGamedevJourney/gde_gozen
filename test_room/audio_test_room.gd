extends Control

@onready var player: AudioStreamPlayer = $AudioStreamPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if get_window().files_dropped.connect(_on_audio_drop):
		printerr("Couldn't connect files_dropped!")

	
func _on_audio_drop(a_files: PackedStringArray) -> void:
	print("loading audio ...")
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.mix_rate = 44100
	stream.stereo = true
	stream.format = AudioStreamWAV.FORMAT_16_BITS

	stream.data = GoZenAudio.get_audio_data(a_files[0])

	player.stream = stream
	print("Audio loaded")
	player.play()

