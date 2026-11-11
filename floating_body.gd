extends FloatingBody


@export var thrust := 100000.0
@export var steer_torque := 50000.0
@export var active := true
var InControlZone = false




func _physics_process(delta: float) -> void:
	super(delta)
	if not active and not "--autodrive" in OS.get_cmdline_user_args():
		return
	var throttle := 0.0
	var steer := 0.0
	if Input.is_key_pressed(KEY_W):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S):
		throttle -= 0.5
	if Input.is_key_pressed(KEY_A):
		steer += 1.0
	if Input.is_key_pressed(KEY_D):
		steer -= 1.0
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() > 0.001:
		apply_central_force(fwd.normalized() * thrust * throttle)
	apply_torque(Vector3.UP * steer_torque * steer)


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		Global.InControlZone = true

func _on_area_3d_body_exited(body: CharacterBody3D) -> void:
	Global.InControlZone = false

func _on_area_3_dlootzone_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		Global.inLootZone = true

func _on_area_3_dlootzone_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		Global.inLootZone = false
