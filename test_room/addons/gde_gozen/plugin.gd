@tool
class_name GoZenServer
extends EditorPlugin
## GoZenServer is only used for adding the node to the node list.



func _enter_tree() -> void:
	add_custom_type(
			"VideoPlayback", "Control",
			load("res://addons/gde_gozen/video_playback.gd"),
			load("res://addons/gde_gozen/icon.webp"))


func _exit_tree() -> void:
	remove_custom_type("VideoPlayback")

