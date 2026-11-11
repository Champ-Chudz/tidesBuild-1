extends Timer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start(20)


func _on_timeout() -> void:
	Ocean.start_drain(-5.0)
