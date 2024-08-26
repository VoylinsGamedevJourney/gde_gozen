extends Control



func _on_button_pressed() -> void:
	if $VideoPlayback.is_playing:
		$VideoPlayback.pause()
		$VideoPlayback2.pause()
		$VideoPlayback3.pause()
		$VideoPlayback4.pause()
		$VideoPlayback5.pause()
	else:
		$VideoPlayback.play()
		$VideoPlayback2.play()
		$VideoPlayback3.play()
		$VideoPlayback4.play()
		$VideoPlayback5.play()
