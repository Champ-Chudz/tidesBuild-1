extends CharacterBody3D

@onready var camera = $Camera3D
@onready var body = $"."

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var PlayerSensitivity = 0.005
var active := false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir := Vector2.ZERO
	if active:
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY
		input_dir = Input.get_vector("A_Input", "D_Input", "W_Input", "S_Input")

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Input.MOUSE_MODE_CAPTURED and active:
		if event is InputEventMouseMotion:
			body.rotate_y(-event.relative.x * PlayerSensitivity)
			camera.rotate_x(-event.relative.y * PlayerSensitivity)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))
