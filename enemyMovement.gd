extends CharacterBody3D

@export var speed: float = 5.0
var player: CharacterBody3D = null

func _physics_process(delta: float) -> void:

	if player:
		#Calculate the direction toward the player
		var direction: Vector3 = global_position.direction_to(player.global_position)
		
		#Zero out the Y axis so the enemy only chases on a flat plane (X and Z)
		direction.y = 0
		direction = direction.normalized()
		
		#Set horizontal velocity
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# Optional: Make the enemy smoothly look toward the player
		var look_target = Vector3(player.global_position.x, global_position.y, player.global_position.z)
		if global_position.distance_to(look_target) > 0.1:
			look_at(look_target, Vector3.UP)
	else:
		#Stop horizontal movement if player is out of range
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

#Triggered when a physics body enters the sphere radius
func _on_area_3d_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = body

#Triggered when a physics body leaves the sphere radius
func _on_area_3d_detection_body_exited(body: Node3D) -> void:
	if body == player:
		player = null
