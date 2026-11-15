extends Control

@onready var bar: ProgressBar = $ProgressBar

var path := ""
var progress := []

func _ready() -> void:
	path = LoadingScene.target_path
	ResourceLoader.load_threaded_request(path)

func _process(_delta: float) -> void:
	var status := ResourceLoader.load_threaded_get_status(path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			bar.value = progress[0] * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed: PackedScene = ResourceLoader.load_threaded_get(path)
			get_tree().change_scene_to_packed(packed)
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Failed to load: " + path)
			set_process(false)
