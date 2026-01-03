extends Control

@onready var player: AudioStreamPlayer = $AudioStreamPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if get_window().files_dropped.connect(_on_audio_drop):
		printerr("Couldn't connect files_dropped!")

	
func _on_audio_drop(a_files: PackedStringArray) -> void:
	print("loading audio ...")
	var stream: AudioStreamFFmpeg = AudioStreamFFmpeg.new()

	if stream.open(a_files[0]) != OK:
		return print("Error opening file!")

	player.stream = stream
	print("Audio loaded")
	player.play()
