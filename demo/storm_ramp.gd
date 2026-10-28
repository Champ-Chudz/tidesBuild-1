extends Node3D

# Storm demo driver: ping-pongs Ocean.storm_scale between calm (1.0)
# and the active profile's storm_scale_max over one period, so the
# sea swells and settles forever. OceanSurface's storm styling reads
# the same value for the water; this script grades the SKY and SUN by
# the same rage, because an ocean mirrors its sky at grazing angles:
# a raging sea under a sunny sky reads as bright bands on every wave
# face, and no water material can fix a wrong sky. The label shows
# the live number: this whole demo is ONE variable.

@export var period := 16.0

const FAIR_TOP := Color(0.25, 0.46, 0.72)
const FAIR_HORIZON := Color(0.71, 0.79, 0.85)
const STORM_TOP := Color(0.23, 0.27, 0.32)
const STORM_HORIZON := Color(0.44, 0.47, 0.51)

var _sky_mat: ProceduralSkyMaterial


func _ready() -> void:
	_sky_mat = $WorldEnvironment.environment.sky.sky_material


func _process(_delta: float) -> void:
	var cap: float = Ocean.profile.storm_scale_max
	var f := 0.5 - 0.5 * cos(TAU * fmod(Ocean.time, period) / period)
	Ocean.storm_scale = lerpf(1.0, cap, f)
	var rage: float = clampf((Ocean.storm_scale - 1.0) / maxf(cap - 1.0, 0.001), 0.0, 1.0)
	_sky_mat.sky_top_color = FAIR_TOP.lerp(STORM_TOP, rage)
	_sky_mat.sky_horizon_color = FAIR_HORIZON.lerp(STORM_HORIZON, rage)
	_sky_mat.ground_horizon_color = _sky_mat.sky_horizon_color
	$Sun.light_energy = lerpf(1.0, 0.55, rage)
	$Sun.light_color = Color(1, 1, 1).lerp(Color(0.75, 0.8, 0.88), rage)
	$UI/Label.text = "Ocean.storm_scale = %.2f  (1.0 calm .. %.1f full rage)\nOne variable drives waves, sea color, sky, and sun together." \
		% [Ocean.storm_scale, cap]
