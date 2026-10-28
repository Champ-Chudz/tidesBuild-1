class_name WakeEmitter
extends Node3D

# Wake foam and bow spray for one hull. The foam itself is painted by
# ocean.gdshader (the hull_* uniforms, so foam rides the displaced
# surface for free); this node pushes the hull's footprint and way
# into the OceanSurface material each frame and drives a spray
# particle emitter at the entry point.
#
# The hull axis orients the waterline ring (used sign-free in the
# shader); the churn trail and entry foam follow the actual VELOCITY,
# so no bow-end sign convention can ever put the wake off the bow.
# RigidBody3D bodies report velocity directly; any other Node3D gets
# a per-frame position difference.
#
# One WakeEmitter per scene: the ocean material carries a single
# hull_* uniform set, so the LAST emitter to push wins. Wake for a
# fleet is shader work first.

# The hull to trail. RigidBody3D (FloatingBody included) uses
# linear_velocity; any other Node3D is position-differenced.
@export var body: Node3D
# The OceanSurface whose material receives the uniforms. Left empty,
# the first OceanSurface in the scene is found on ready.
@export var surface: OceanSurface

# Must match the trail_pts array size in shaders/ocean.gdshader.
const TRAIL_MAX := 24

@export_group("Hull footprint")
@export var hull_length := 4.0
@export var hull_beam := 2.0

@export_group("Churn trail")
# Meters of travel between breadcrumb drops. Smaller spacing means a
# smoother curve but a shorter reach: the trail spans at most
# TRAIL_MAX * trail_spacing meters of track.
@export var trail_spacing := 2.0
@export var trail_max_age := 8.0

@export_group("Bow spray")
@export var spray_enabled := true
# Way in m/s where spray starts, and where it saturates.
@export var spray_min_speed := 1.6
@export var spray_full_speed := 6.6

# Color-code the foam terms for review runs (ring green, trail white,
# bow red): the shader's foam_debug switch.
@export var debug_foam := false

var _spray: GPUParticles3D
var _prev_pos := Vector3.INF
# Breadcrumbs, NEWEST FIRST: (world x, world z, birth Ocean.time).
var _crumbs: Array[Vector3] = []
# Smoothed random walk for spray irregularity; raw per-frame randf
# strobes at 60 Hz.
var _spray_flicker := 0.5


func _ready() -> void:
	if surface == null:
		surface = get_tree().get_first_node_in_group("ocean3d_surface")
	if spray_enabled:
		_build_spray()


func _exit_tree() -> void:
	# Silence the foam when the emitter goes away; the uniforms would
	# otherwise keep painting a ghost wake at the last position.
	if surface != null and surface.material != null:
		surface.material.set_shader_parameter("hull_half_len", 0.0)
		surface.material.set_shader_parameter("trail_count", 0)
	_crumbs.clear()


func _process(delta: float) -> void:
	if body == null or surface == null:
		return
	var fwd3 := body.global_transform.basis.z
	var fwd2 := Vector2(fwd3.x, fwd3.z)
	if fwd2.length_squared() > 0.001:
		fwd2 = fwd2.normalized()
	var vel := _body_velocity(delta)
	var spd := vel.length()
	var m2 := Vector2(vel.x, vel.z)
	m2 = m2.normalized() if m2.length_squared() > 0.01 else fwd2
	var half_len := hull_length * 0.5
	var half_beam := hull_beam * 0.5

	# Breadcrumbs: drop a path point every trail_spacing meters of
	# travel while making way. The shader paints the churn along this
	# polyline, so the wash follows the real track through turns.
	var pos2 := Vector2(body.global_position.x, body.global_position.z)
	if spd > 0.6 and (_crumbs.is_empty()
			or Vector2(_crumbs[0].x, _crumbs[0].y).distance_to(pos2) >= trail_spacing):
		_crumbs.push_front(Vector3(pos2.x, pos2.y, Ocean.time))
		while _crumbs.size() > TRAIL_MAX:
			_crumbs.pop_back()
	while not _crumbs.is_empty() \
			and Ocean.time - _crumbs[_crumbs.size() - 1].z > trail_max_age:
		_crumbs.pop_back()

	var mat := surface.material
	mat.set_shader_parameter("hull_center", pos2)
	mat.set_shader_parameter("hull_fwd", fwd2)
	mat.set_shader_parameter("wake_dir", m2)
	mat.set_shader_parameter("hull_half_len", half_len)
	mat.set_shader_parameter("hull_half_beam", half_beam)
	mat.set_shader_parameter("wake_speed", spd)
	mat.set_shader_parameter("foam_debug", 1.0 if debug_foam else 0.0)
	var pts := PackedVector3Array()
	pts.resize(TRAIL_MAX)
	for i in _crumbs.size():
		pts[i] = _crumbs[i]
	mat.set_shader_parameter("trail_pts", pts)
	mat.set_shader_parameter("trail_count", _crumbs.size())
	mat.set_shader_parameter("trail_max_age", trail_max_age)

	if _spray == null:
		return
	# Spray sits at the LEADING end of the hull axis (same convention
	# as the shader's entry foam), not along raw velocity, so a hard
	# turn keeps it on the bow.
	var lead := 1.0 if fwd2.dot(m2) >= 0.0 else -1.0
	var bow := body.global_position \
		+ Vector3(fwd2.x, 0.0, fwd2.y) * half_len * 0.9 * lead
	bow.y = Ocean.get_height(bow.x, bow.z) + 0.15
	_spray.global_position = bow
	var f := clampf((spd - spray_min_speed)
		/ maxf(spray_full_speed - spray_min_speed, 0.1), 0.0, 1.0)
	# Wave slap: the bow closing on a rising surface throws extra
	# spray, so the emitter reacts to the sea, not just the throttle.
	var slam := 0.0
	if body is RigidBody3D:
		var closing: float = (body as RigidBody3D).linear_velocity.y \
			- Ocean.get_surface_velocity_y(bow.x, bow.z)
		slam = clampf(-closing * 0.6, 0.0, 1.0)
	_spray_flicker = lerpf(_spray_flicker, randf(), 0.12)
	var amt := clampf(f * (0.55 + 0.45 * _spray_flicker) + slam * 0.45 * f,
		0.0, 1.0)
	_spray.emitting = amt > 0.03
	_spray.amount_ratio = maxf(amt, 0.04)
	# Spray kicks up and outward from the entry, with the way on.
	var proc: ParticleProcessMaterial = _spray.process_material
	proc.direction = Vector3(m2.x, 2.2, m2.y)
	proc.initial_velocity_min = 0.8 + spd * 0.35
	proc.initial_velocity_max = 1.6 + spd * 0.55


func _body_velocity(delta: float) -> Vector3:
	if body is RigidBody3D:
		return (body as RigidBody3D).linear_velocity
	var pos := body.global_position
	if _prev_pos == Vector3.INF or delta <= 0.0:
		_prev_pos = pos
		return Vector3.ZERO
	var v := (pos - _prev_pos) / delta
	_prev_pos = pos
	return v


func _build_spray() -> void:
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(0.9, 0.15, 0.9)
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 42.0
	proc.gravity = Vector3(0.0, -8.5, 0.0)
	proc.initial_velocity_min = 1.0
	proc.initial_velocity_max = 2.0
	# Fine droplets, wide size and lifetime variance, plus turbulence:
	# spray should read as chaotic mist, not confetti.
	proc.scale_min = 0.12
	proc.scale_max = 0.55
	proc.lifetime_randomness = 0.5
	proc.turbulence_enabled = true
	proc.turbulence_noise_strength = 1.5
	proc.turbulence_noise_scale = 3.0
	proc.color = Color(0.92, 0.96, 0.98, 0.38)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.95, 0.98, 1.0, 0.4)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.roughness = 1.0
	quad.material = m

	_spray = GPUParticles3D.new()
	_spray.process_material = proc
	_spray.draw_pass_1 = quad
	_spray.amount = 240
	_spray.lifetime = 0.9
	_spray.local_coords = false
	_spray.emitting = false
	_spray.name = "BowSpray"
	add_child(_spray)
