extends CharacterBody3D

@export var speed: float = 2.0
@export var wander_radius: float = 8.0
@export var wander_wait_time: float = 2.0
var player: CharacterBody3D = null
var wander_target: Vector3
var wandering: bool = false
var wander_timer: float = 0.0
var random = RandomNumberGenerator.new()#This is what chooses the direction for wandering
											#I do feel this is implied, but I need idiots to understand this
#Ready for our extremely fun NavigationMesh implementation /s
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D#Handy dandy navigation agent!

func _ready() -> void:
	random.randomize()
	choose_wander_target()

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
		
		#Makes the enemy smoothly look toward the player
		var look_target = Vector3(player.global_position.x, global_position.y, player.global_position.z)
		if global_position.distance_to(look_target) > 0.1:
			look_at(look_target, Vector3.UP)
	else:
		# Wander when player is not detected
		wander(delta)

		#(This is the old code, keeping for safekeeping)Stop horizontal movement if player is out of range
		#velocity.x = move_toward(velocity.x, 0, speed)
		#velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

#Triggered when a physics body enters the sphere radius
func _on_area_3d_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = body

#Triggered when a physics body leaves the sphere radius
func _on_area_3d_detection_body_exited(body: Node3D) -> void:
	if body == player:
		player = null
		choose_wander_target() 
		
#Random wandering behavior
func wander(delta: float) -> void:

	if not wandering:
		wander_timer += delta

		#Wait before choosing another destination
		if wander_timer >= wander_wait_time:
			choose_wander_target()

		return#I'm hungry INNA MINUTE

	#Calculate direction toward wandering destination
	var direction = global_position.direction_to(wander_target)

	direction.y = 0
	direction = direction.normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	#Face the wandering direction, how even the enemies explore our game!
	var look_target = Vector3(
		wander_target.x,
		global_position.y,
		wander_target.z
	)

	if global_position.distance_to(look_target) > 0.1:
		look_at(look_target, Vector3.UP)

	# Check whether destination has been reached
	var distance = global_position.distance_to(wander_target)

	if distance < 0.5:
		wandering = false#You made it!
		wander_timer = 0.0#Break time

		velocity.x = 0#Hold your horses
		velocity.z = 0


#Chooses a random wandering destination
func choose_wander_target() -> void:

	var angle = random.randf_range(0.0, TAU)#like the 40k blue guys!
	var distance = random.randf_range(2.0, wander_radius)

	var offset = Vector3(#Oh boy, math!
		cos(angle) * distance,
		0,
		sin(angle) * distance
	)

	wander_target = global_position + offset
	wandering = true
	wander_timer = 0.0


#FUTURE NAVIGATION MESH IMPLEMENTATION
#This function'll expanded to use NavigationAgent3D to find paths around obstacles(What I am here to do)
func navigate_to_target(target: Vector3) -> void:

	navigation_agent.target_position = target

	#Future implementation:
	#var next_position = navigation_agent.get_next_path_position()
	#Moves toward next_position instead of target directly(So this whole thing... y'know, does it's job
