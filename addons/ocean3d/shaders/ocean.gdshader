shader_type spatial;
render_mode cull_disabled;

// Must mirror ocean.gd exactly. OceanSurface pushes the wave table and
// time into these uniforms so physics and visuals stay in sync.
// waves[i] = (direction_degrees, steepness, wavelength_meters)
// Array size must match OceanWaveProfile.MAX_WAVES.
uniform vec3 waves[4];
uniform float t = 0.0;

// Storm amplitude multiplier, mirrors Ocean.storm_scale (see ocean.gd).
// OceanSurface pushes it every frame so the visible sea swells with
// the physics sea. 1.0 = calm.
uniform float storm_scale = 1.0;

uniform vec3 deep_color : source_color = vec3(0.012, 0.09, 0.16);
uniform vec3 shallow_color : source_color = vec3(0.10, 0.38, 0.44);
// Roughness and specular are storm-driven by OceanSurface's storm
// styling: a calm sea is a near-mirror (low roughness, high specular)
// that throws sharp sun glints; a storm sea goes rough and matte so
// the chop scatters those glints into a dull sheen instead of
// blooming hotspots.
uniform float roughness_value : hint_range(0.0, 1.0) = 0.08;
uniform float specular_value : hint_range(0.0, 1.0) = 0.6;

// Visual LOD only, physics never fades: displacement ramps to zero
// between these camera distances so the detail tile's edge is dead
// flat and meets the flat horizon skirt without a seam. Nothing
// physical reads the water surface past this ring. The horizon skirt
// sets disp_scale to 0 (always flat, so its coarse grid never
// undersamples the wave field into noise).
uniform float disp_scale : hint_range(0.0, 1.0) = 1.0;
uniform float disp_fade_start = 90.0;
uniform float disp_fade_end = 126.0;

// Horizon skirt only (0 = off): drop fragments within this radius of
// the camera. The skirt rides below sea level, and without the hole
// it renders as an opaque lid half a meter under a submerged camera.
// The near tile fully covers this footprint, so nothing is lost.
uniform float hole_radius = 0.0;

// Wake foam (visual only, near tile): painted in fragment from hull
// uniforms pushed by WakeEmitter each frame, so foam rides the
// displaced surface for free and no third copy of the wave math
// exists anywhere. hull_half_len <= 0 disables the whole block (the
// horizon skirt and boatless scenes leave it 0).
uniform vec2 hull_center = vec2(0.0);
uniform vec2 hull_fwd = vec2(0.0, -1.0);   // hull AXIS (sign-free use only)
uniform vec2 wake_dir = vec2(0.0, -1.0);   // actual motion direction
uniform float hull_half_len = 0.0;
uniform float hull_half_beam = 2.0;
uniform float wake_speed = 0.0;
// 1 = color-code the foam terms for review runs (ring green, trail
// white, bow red); set from WakeEmitter's debug toggle.
uniform float foam_debug = 0.0;

// Churn breadcrumbs: recent hull positions dropped by WakeEmitter,
// NEWEST FIRST, so the trail is painted along the boat's actual path.
// xy = world xz of the drop, z = birth time on the same clock as t.
// Array size must match WakeEmitter.TRAIL_MAX.
uniform vec3 trail_pts[24];
uniform int trail_count = 0;
uniform float trail_max_age = 8.0;

varying vec2 world_xz;

const float G = 9.8;

float foam_hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float foam_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = foam_hash(i);
	float b = foam_hash(i + vec2(1.0, 0.0));
	float c = foam_hash(i + vec2(0.0, 1.0));
	float d = foam_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 gerstner(vec2 xz) {
	vec3 p = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float ang = radians(waves[i].x);
		vec2 dir = vec2(cos(ang), sin(ang));
		float steepness = waves[i].y;
		float k = 6.28318530718 / waves[i].z;
		float c = sqrt(G / k);
		float a = steepness * storm_scale / k;
		float f = k * (dot(dir, xz) - c * t);
		p.x += dir.x * a * cos(f);
		p.y += a * sin(f);
		p.z += dir.y * a * cos(f);
	}
	return p;
}

void vertex() {
	// The ocean tiles follow the camera: translated every frame, never
	// rotated or scaled. Waves evaluate at WORLD xz, so the mesh slides
	// under a world-fixed wave field and vertices never swim.
	vec2 xz = VERTEX.xz + MODEL_MATRIX[3].xz;
	world_xz = xz;
	float fade = disp_scale
		* (1.0 - smoothstep(disp_fade_start, disp_fade_end,
			distance(xz, CAMERA_POSITION_WORLD.xz)));
	vec3 d = gerstner(xz) * fade;
	VERTEX += d;
}

void fragment() {
	if (hole_radius > 0.0
			&& distance(world_xz, CAMERA_POSITION_WORLD.xz) < hole_radius) {
		discard;
	}
	// Normals from finite differences on the wave field, per fragment and
	// at FULL amplitude on both tiles, independent of the displacement
	// fade. Shading therefore stays continuous across the detail tile's
	// flat rim and the horizon skirt; a flat-normal skirt washes to
	// shallow_color at grazing angles and draws a pale band short of
	// the horizon.
	// The step widens with distance, low-passing wave detail that has
	// gone sub-pixel; otherwise the far field shades as glitter noise.
	float e = 0.6 + distance(world_xz, CAMERA_POSITION_WORLD.xz) * 0.012;
	vec3 dc = gerstner(world_xz);
	vec3 tx = vec3(e, 0.0, 0.0) + gerstner(world_xz + vec2(e, 0.0)) - dc;
	vec3 tz = vec3(0.0, 0.0, e) + gerstner(world_xz + vec2(0.0, e)) - dc;
	vec3 n_world = normalize(cross(tz, tx));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep_color, shallow_color, fres);
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	SPECULAR = specular_value;

	// Whitecaps: foam on the biggest crests. Height relative to the
	// sea's theoretical max amplitude picks the tops (dc is already
	// full-amplitude on both tiles, so caps run to the horizon); the
	// gate keys off total steepness times storm scale, so a calm sea
	// stays clean and a heavy sea caps progressively. Two noise
	// octaves break the caps into drifting patches.
	float max_amp = 0.0;
	float sum_steep = 0.0;
	for (int i = 0; i < 4; i++) {
		max_amp += waves[i].y * storm_scale / (6.28318530718 / waves[i].z);
		sum_steep += waves[i].y;
	}
	if (max_amp > 0.001) {
		float cap_gate = smoothstep(0.30, 0.70, sum_steep * storm_scale);
		// Breaking = high AND steep. Height alone smears foam across
		// the broad tops of long swells (a 70m wave's "crest" is a
		// 30m-wide band); the slope gate (surface normal tipping past
		// ~25 degrees) confines caps to water that is actually
		// pitching over, which lives on the short chop.
		float crest = smoothstep(0.25, 0.70, dc.y / max_amp)
			* smoothstep(0.97, 0.90, n_world.y);
		// Gust patches: a huge, slow-drifting selector so only SOME
		// big waves break. Most crests pass clean; the ones inside a
		// patch foam hard.
		float pick = smoothstep(0.42, 0.72,
			foam_noise(world_xz * 0.028 + vec2(t * 0.05, t * 0.038)));
		// Three octaves, the second rotated 45 degrees so the value
		// noise grids never align: soft ragged streaks, not blocks.
		float n1 = foam_noise(world_xz * 0.33 + vec2(t * 0.28, -t * 0.2));
		vec2 rxz = vec2(world_xz.x - world_xz.y, world_xz.x + world_xz.y)
			* 0.7071;
		float n2 = foam_noise(rxz * 1.1 + vec2(-t * 0.35, t * 0.3));
		float n3 = foam_noise(world_xz * 2.9 + vec2(t * 0.5, t * 0.42));
		float cap_n = n1 * (0.55 * n2 + 0.45 * n3);
		float cap = cap_gate * crest * pick
			* smoothstep(0.06, 0.55, cap_n) * 0.9;
		ALBEDO = mix(ALBEDO, vec3(0.90, 0.94, 0.95), cap);
		ROUGHNESS = mix(ROUGHNESS, 0.9, cap);

		// Wind streaks: elongated foam lanes raked along the dominant
		// wave direction, the classic heavy-weather tell. Gated harder
		// than the caps, so only a genuinely raging sea shows them.
		float ang0 = radians(waves[0].x);
		vec2 wdir = vec2(cos(ang0), sin(ang0));
		float along = dot(world_xz, wdir);
		float across = dot(world_xz, vec2(-wdir.y, wdir.x));
		float lane_n = foam_noise(vec2(along * 0.05 + t * 0.12,
				across * 0.9))
			* foam_noise(vec2(along * 0.13 - t * 0.07, across * 1.7));
		float streak_gate = smoothstep(0.55, 0.85, sum_steep * storm_scale);
		// Rare and faint on purpose: only the peaks of the lane noise,
		// only inside the same gust patches where waves break, at half
		// strength. Streaks season the sea; they must never stripe it.
		float streak = streak_gate * smoothstep(0.45, 0.80, lane_n)
			* pick * (1.0 - crest) * 0.05;
		ALBEDO = mix(ALBEDO, vec3(0.82, 0.88, 0.90), streak);
		ROUGHNESS = mix(ROUGHNESS, 0.75, streak);
	}

	// Hull contact foam and the stern wake. The ring hugs the hull
	// footprint even at rest; the churn trail scales with way on.
	if (hull_half_len > 0.5) {
		vec2 rel = world_xz - hull_center;
		float speedf = clamp((wake_speed - 0.3) / 1.4, 0.0, 1.0);

		// Waterline ring: a soft metre-scale band hugging the footprint
		// rectangle, oriented by the hull AXIS (abs() both ways, so the
		// axis sign never matters; an ellipse band ballooned into a blob
		// past the pointed ends).
		float ax = abs(dot(rel, hull_fwd));
		float ay = abs(dot(rel, vec2(-hull_fwd.y, hull_fwd.x)));
		float dx = max(ax - hull_half_len * 0.80, 0.0);
		float dy = max(ay - hull_half_beam * 0.80, 0.0);
		float d = length(vec2(dx, dy));
		float ring = (1.0 - smoothstep(0.25, 1.0, d))
			* (0.16 + 0.30 * speedf);

		// Churn trail: foam painted along the boat's ACTUAL PATH, the
		// breadcrumb polyline (hull position is the live head, then
		// newest crumb to oldest). Each stretch fades and widens with
		// age, so a turning boat leaves a curved, spreading wash
		// instead of a straight band along current velocity.
		float trail = 0.0;
		if (trail_count > 0 && speedf > 0.0) {
			vec2 prev = hull_center;
			float prev_age = 0.0;
			for (int i = 0; i < 24; i++) {
				if (i >= trail_count) { break; }
				vec2 p = trail_pts[i].xy;
				float age = clamp(t - trail_pts[i].z, 0.0, trail_max_age);
				vec2 seg = p - prev;
				float len2 = max(dot(seg, seg), 0.0001);
				float u = clamp(dot(world_xz - prev, seg) / len2, 0.0, 1.0);
				float d = distance(world_xz, prev + seg * u);
				float seg_age = mix(prev_age, age, u) / trail_max_age;
				float width = hull_half_beam * (0.8 + 2.4 * seg_age);
				float fade = (1.0 - seg_age) * (1.0 - seg_age);
				trail = max(trail,
					(1.0 - smoothstep(width * 0.4, width, d)) * fade);
				prev = p;
				prev_age = age;
			}
			// Patchy churn, not a painted slab: the wash breaks into
			// streaks that drift and dissolve.
			trail *= (0.55 + 0.45 * foam_noise(world_xz * 1.1
				+ vec2(-t * 0.2, t * 0.25))) * 0.7 * speedf;
		}

		// Entry foam: a pool at the LEADING end of the hull axis
		// (whichever end currently leads along the motion), so a hard
		// turn keeps the bow wash on the bow instead of smearing it
		// toward the slip direction.
		float bow = 0.0;
		if (speedf > 0.0) {
			float lead = dot(hull_fwd, wake_dir) >= 0.0 ? 1.0 : -1.0;
			vec2 bow_pt = hull_center + hull_fwd * hull_half_len * 0.92 * lead;
			float db = distance(world_xz, bow_pt);
			bow = (1.0 - smoothstep(hull_half_beam * 0.4,
				hull_half_beam * 1.3, db)) * 0.5 * speedf;
		}

		// Patchy break-up: the ring especially must read as lapping foam
		// bits, not a painted pad.
		ring *= smoothstep(0.30, 0.72,
			foam_noise(world_xz * 0.8 + vec2(t * 0.2, t * 0.15)));
		float n = foam_noise(world_xz * 1.9 + vec2(t * 0.45, -t * 0.3));
		float foam = clamp((ring + trail + bow) * (0.5 + 0.8 * n), 0.0, 1.0);
		vec3 foam_col = vec3(0.90, 0.94, 0.95);
		if (foam_debug > 0.5) {
			float tot = max(ring + trail + bow, 0.001);
			foam_col = (vec3(0.1, 0.9, 0.1) * ring + vec3(1.0) * trail
				+ vec3(0.95, 0.1, 0.1) * bow) / tot;
		}
		ALBEDO = mix(ALBEDO, foam_col, foam);
		ROUGHNESS = mix(ROUGHNESS, 0.85, foam);
	}
}
