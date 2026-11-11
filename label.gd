extends Label

@onready var timer: Timer = $"../../TideupTimer"
@onready var label: Label = self

func _process(delta: float) -> void:
	var time_left: float = timer.time_left
	var seconds: int = int(time_left) % 60
	var minutes: int = int(time_left) / 60
	
	# Format as MM:SS with leading zeros
	label.text = "%02d:%02d\n" % [minutes, seconds] + "Till the Tide returns!"
