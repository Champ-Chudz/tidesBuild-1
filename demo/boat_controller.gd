extends FloatingBody

# Demo skiff: WASD driving on top of FloatingBody buoyancy. W/S
# thrust along the hull, A/D yaw torque. Top speed emerges from
# thrust against FloatingBody's water drag rather than a speed cap,
# so the wake always matches real way.
#
# --autodrive in the user args holds throttle with gentle turn for
# unattended capture runs (the --shots rig).

@export var thrust := 2500.0
@export var steer_torque := 900.0


func _ready() -> void:
	super()
	# Review flag: detach the chase camera and park it overhead
	# looking straight down, so a still capture shows the trail's
	# actual curvature along the track.
	if "--fixedcam" in OS.get_cmdline_user_args():
		var cam: Camera3D = $Camera3D
		cam.top_level = true
		cam.global_position = Vector3(0.0, 50.0, -12.0)
		cam.global_rotation = Vector3(-PI / 2.0, 0.0, 0.0)


func _physics_process(delta: float) -> void:
	super(delta)
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
	if "--autodrive" in OS.get_cmdline_user_args():
		throttle = 1.0
		# Weave in slow S-curves so capture runs show the churn trail
		# bending BOTH ways, not one endless circle.
		steer = 0.5 * sin(Ocean.time * TAU / 10.0)
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() > 0.001:
		apply_central_force(fwd.normalized() * thrust * throttle)
	apply_torque(Vector3.UP * steer_torque * steer)
