extends CharacterBody3D

@onready var camera = $Camera3D
@onready var body = $"."

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var PlayerSensitivity = 0.005
var active := false


func _physics_process(delta: float) -> void:
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

	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = maxf(velocity.y, 0.0)
	move_and_slide()

func _ready() -> void:
	_set_controlled(player)
	floor_snap_length = 0.5
	floor_stop_on_slope = true
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB and Global.InControlZone == true and controlled != boat:
		_set_controlled(boat)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB and controlled == boat:
		_set_controlled(player)

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and active:
		if event is InputEventMouseMotion:
			body.rotate_y(-event.relative.x * PlayerSensitivity)
			camera.rotate_x(-event.relative.y * PlayerSensitivity)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))




func _on_rise_button_pressed() -> void:
	Ocean.start_drain(1.0)

func _on_lower_button_pressed() -> void:
	Ocean.start_drain(-1.0)

func _on_stop_button_pressed() -> void:
	Ocean.stop_drain()


@onready var boat: FloatingBody = $"../FloatingBody"
@onready var player: CharacterBody3D = $"."


var controlled: Node3D




func _set_controlled(target: Node3D) -> void:
	controlled = target
	boat.active = (target == boat)
	player.active = (target == player)
	if target == player:
		target.get_node("Camera3D").make_current()
	elif target == boat:
		target.get_node("Camera3D").make_current()
