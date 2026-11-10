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

	#Wait for the navigation map to synchronize.
	await get_tree().physics_frame

	var navigation_map = navigation_agent.get_navigation_map()

	#Keep waiting until the navigation map is ready.
	while NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		await get_tree().physics_frame

	choose_wander_target()


func _physics_process(delta: float) -> void:

	if player:
		#Calculate the direction toward the player
		#NavigationAgent3D now calculates a path instead of moving directly toward the player.

		var player_position = player.global_position

		#Only update the destination when the player has moved enough.
		if navigation_agent.target_position.distance_to(player_position) > 0.5:
			navigation_agent.target_position = player_position

	else:
		#Wander when player is not detected
		wander(delta)

	#Follow the calculated navigation path.
	move_toward_navigation_target()

	#Apply gravity so the enemy stays on the floor.
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0

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
		velocity.x = 0
		velocity.z = 0

		wander_timer += delta

		#Wait before choosing another destination
		if wander_timer >= wander_wait_time:
			choose_wander_target()

		return#I'm hungry INNA MINUTE


#Moves the enemy along the navigation path.
func move_toward_navigation_target() -> void:

	#Get the next point along the calculated path.
	var next_position = navigation_agent.get_next_path_position()

	#Check whether the navigation destination has been reached.
	if navigation_agent.is_navigation_finished():

		if not player and wandering:
			wandering = false#You made it!
			wander_timer = 0.0#Break time

		velocity.x = 0#Hold your horses
		velocity.z = 0
		return

	#Calculate direction toward the next navigation point.
	var direction = global_position.direction_to(next_position)

	direction.y = 0
	direction = direction.normalized()

	#Set horizontal velocity
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	#Makes the enemy smoothly look toward the direction it is moving.
	var look_target = Vector3(
		global_position.x + direction.x,
		global_position.y,
		global_position.z + direction.z
	)

	if direction.length() > 0.01:
		look_at(look_target, Vector3.UP)


#Chooses a random wandering destination
#Chooses a random wandering destination
func choose_wander_target() -> void:

	var angle = random.randf_range(0.0, TAU)#like the 40k blue guys!
	var distance = random.randf_range(2.0, wander_radius)

	var offset = Vector3(#Oh boy, math!
		cos(angle) * distance,
		0,
		sin(angle) * distance
	)

	var candidate = global_position + offset

	#Find the closest valid point on the NavigationMesh.
	var navigation_map = navigation_agent.get_navigation_map()

	wander_target = NavigationServer3D.map_get_closest_point(
		navigation_map,
		candidate
	)

	#Don't accept an invalid destination.
	if wander_target == Vector3.ZERO:
		wandering = false
		return

	#Tell the NavigationAgent3D where to navigate.
	navigation_agent.target_position = wander_target

	wandering = true
	wander_timer = 0.0
