extends Node

var target_path := ""

func load_scene(path: String) -> void:
	target_path = path
	get_tree().change_scene_to_file("res://load_screen.tscn")
