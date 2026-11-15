extends Node2D

func _on_button_2_pressed() -> void:
	LoadingScene.load_scene("res://main.tscn")


func _on_button_pressed() -> void:
	get_tree().quit()
