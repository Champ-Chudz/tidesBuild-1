extends Label3D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	text = "Press E to put down loot\n" + "loot down:" + str(Global.lootInBoat)
