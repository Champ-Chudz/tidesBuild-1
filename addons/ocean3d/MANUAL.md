# Ocean3D Manual

Water, waves and buoyancy for Godot 4. One Gerstner wave function
drives both the visual surface and the physics, so what you see is
exactly what floating bodies feel.

- [Install and quickstart](#install-and-quickstart)
- [How it works](#how-it-works)
- [OceanWaveProfile](#oceanwaveprofile)
- [The Ocean autoload](#the-ocean-autoload)
- [OceanSurface](#oceansurface)
- [FloatingBody](#floatingbody)
- [WakeEmitter](#wakeemitter)
- [Whitecaps and wind streaks](#whitecaps-and-wind-streaks)
- [FAQ](#faq)
- [Demo scenes](#demo-scenes)

## Install and quickstart

1. Copy `addons/ocean3d/` into your project.
2. Project > Project Settings > Plugins: enable **Ocean3D**. This
   registers the `Ocean` autoload.
3. New 3D scene. Add an **OceanSurface** node.
4. Pick a **Wave Profile** on it in the Inspector (start with
   `profiles/calm.tres`).
5. Add a **FloatingBody** node. Give it a `CollisionShape3D` child
   (any shape) and a `MeshInstance3D` child so you can see it.
6. On the FloatingBody, set **Probe Points**: one per corner of the
   hull footprint, e.g. `(-0.5, 0, -0.5)`, `(0.5, 0, -0.5)`,
   `(-0.5, 0, 0.5)`, `(0.5, 0, 0.5)`. Cyan crosses appear in the
   viewport as you type.
7. Set the body's position a couple of meters above y = 0. Sea level
   is world y = 0, always.
8. Add a `Camera3D` and a `DirectionalLight3D`. A `WorldEnvironment`
   with a sky is strongly recommended: water is mostly a mirror for
   its sky (see the FAQ).
9. Press play. The body drops, splashes into a bob, and settles at
   its equilibrium draft, riding the waves.
10. Swap the profile on the OceanSurface for `lively.tres` or
    `storm.tres` and run again: a different sea, zero code.

## How it works

The same Gerstner wave sum is evaluated in two places:

1. `ocean.gd` (the `Ocean` autoload), in GDScript, for physics.
   `FloatingBody` probes sample `Ocean.get_height`.
2. `shaders/ocean.gdshader`, for visuals (vertex displacement).

`OceanSurface` pushes the wave table, time, and storm scale into the
shader every frame, so the two never disagree. This is the core
contract of the kit: **physics must never feel a wave the eye cannot
see, and vice versa.** If you modify the wave math on one side,
change the other side in the same commit.

One deliberate visual-only divergence: the shader fades displacement
to zero far from the camera so the detail tile can meet the flat
horizon skirt without a seam. Nothing physical should read the
surface out there (and in practice nothing does: your gameplay
happens near the camera).

## OceanWaveProfile

A resource holding the wave table. One entry per wave:
`Vector3(direction_degrees, steepness, wavelength_meters)`.

Amplitude is derived: `a = steepness * storm_scale / k` with
`k = TAU / wavelength`. Two consequences worth internalizing:

- **Longer waves are taller at the same steepness.** Steepness is a
  slope measure, not a height. Stretch wavelengths to grow the sea
  without making it break.
- **The stability rule:** keep `steepness_sum() * storm_scale` under
  about **0.9**, or crests fold over themselves and buoyancy sampling
  gets unstable. `is_stable_at()` checks it; the Ocean autoload warns
  once if you assign an unstable combination. `storm_scale_max` on
  the profile declares the highest storm scale the profile is
  designed for (advisory, used by the warning and by OceanSurface's
  storm styling).

`MAX_WAVES` is 4 and must match the shader's fixed `waves[4]` uniform
array. Entries past 4 are ignored on BOTH sides; short tables are
zero-padded. This is not a stylistic limit: it keeps the
physics-visual mirror exact.

Shipped presets:

| Preset | Character | storm_scale_max |
| --- | --- | --- |
| `calm.tres` | gentle 0.25m swell, near-mirror sea | 3.0 |
| `lively.tres` | ~1m working sea | 1.2 |
| `storm.tres` | heavy static sea, use as-is | 1.0 |
| `swell.tres` | long 70m swell + chop; built to be storm-scaled to ~8m seas | 3.5 |

Swap profiles at runtime freely (`Ocean.profile = load(...)`). Waves
are a pure function of position and time, so there is no state to
migrate; the sea simply becomes the new sea.

## The Ocean autoload

- `Ocean.get_height(x, z) -> float`: water surface height at a world
  column. This is what buoyancy uses.
- `Ocean.get_height_at(x, z, time)`: same at an arbitrary time.
- `Ocean.get_displacement(x, z)` / `get_displacement_at(...)`: the
  full 3D Gerstner offset, if you need horizontal drift.
- `Ocean.get_surface_velocity_y(x, z)`: vertical velocity of the
  surface, by finite difference. Convenience form for one-off
  queries; FloatingBody does its own cheaper per-probe differencing.
- `Ocean.storm_scale`: amplitude multiplier on every wave, 1.0 =
  calm. Drive it from your weather system; visuals and physics grow
  together.
- `Ocean.time`: the wave clock (seconds, advances in
  `_physics_process`).

**Determinism:** height is a pure function of `(x, z, time, profile,
storm_scale)`. Two machines that agree on those inputs agree on the
sea exactly, which makes the kit friendly to lockstep or
server-authoritative networking.

## OceanSurface

The drop-in visual ocean: a dense camera-following detail tile plus a
huge flat horizon skirt riding just below sea level. The shader
evaluates waves in world space, so the tiles slide under a
world-fixed wave field and vertices never swim.

Knobs (geometry ones are read once at `_ready`; the rest are live):

| Export | Meaning |
| --- | --- |
| `wave_profile` | assigned to `Ocean.profile` on ready when set |
| `tile_size` / `tile_subdiv` | detail tile extent and grid density |
| `aabb_pad` | vertical culling pad; size past your tallest crest |
| `disp_fade_start` / `disp_fade_end` | displacement fades to zero between these camera distances; keep `end` inside `tile_size / 2` |
| `far_size` / `far_subdiv` / `far_drop` | horizon skirt extent, grid, and depth below sea level |
| storm styling block | fair-to-storm color/roughness/specular lerp driven by `Ocean.storm_scale` against the profile's cap; turn off to grade the sea yourself through `material` |

**Size the stage to the sea.** The defaults (260m tile, fade at
90-126m) suit waves up to ~30m long. Long storm swell needs a bigger
stage or the fade flattens geometry exactly where the eye lives: the
storm demo runs `tile_size 700`, `tile_subdiv 320`, fade at 300-340
for its 70m waves. If a big sea ever "reads calm", check the fade
first.

**A sea mirrors its sky.** At grazing angles water reflects the sky
at full strength no matter what roughness or specular you set
(Fresnel approaches 1, and a blurred bright sky reflects just as
bright as a sharp one). If wave faces show pale sheets, your sky is
too bright for your sea state. No water material fixes a wrong sky:
grade the sky and sun with your weather, the way
`demo/storm_ramp.gd` drives sky colors and sun energy from the same
rage variable as the water.

## FloatingBody

Multi-probe buoyancy on `RigidBody3D`. Each probe samples the water
height under it and applies lift proportional to depth; probes at the
corners give pitch and roll for free as waves pass underneath. Probe
points draw as cyan crosses in the editor viewport.

- **Resting draft** is `Ocean.GRAVITY / buoyancy_strength` meters
  (36.0 gives ~0.27m), independent of mass. Size it per body against
  hull height: this sets absolute draft, not relative density, so
  small bodies (a barrel) need much higher values.
- **Probe height matters.** Probes at the hull BOTTOM raise the ride
  by half the hull height compared to centered probes. The demo raft
  uses bottom probes to keep its thin deck dry; with centered probes
  the same raft rides awash and reads waterlogged. If a body looks
  soggy, lower its probes before touching strength.
- **probe_weights** (optional, parallel array): per-probe share of
  total lift. A builder game can weight probes by the buoyancy of
  the hull section nearest each one.
- **The damping trio.** `water_linear_drag` fakes hull resistance
  (raise for a heavier, wallowing feel). `water_angular_drag` calms
  rocking. `vertical_damping` is the special one: it damps each probe
  against the moving water surface, not the world, which is what
  lets small bodies ride waves instead of pogo-sticking through them
  (undamped) or hanging still while crests wash over (world-frame
  damping). Critical damping is about `2 * sqrt(buoyancy_strength)`.
- The component sets damp mode REPLACE: the engine's world default
  damping silently COMBINES with per-body damp otherwise, a hidden
  brake that caps top speed on heavy hulls.
- Frozen bodies receive no forces (forces on a frozen body pile up in
  the physics server and release as one giant kick on unfreeze).

## WakeEmitter

Wake foam and bow spray for one hull. The foam itself is painted by
the ocean shader from uniforms this node pushes, so it rides the
displaced surface for free; the spray is a `GPUParticles3D` it builds
and drives.

- `body`: the hull. `RigidBody3D` (FloatingBody included) reports
  velocity directly; any other `Node3D` gets position-differenced.
- `surface`: the OceanSurface. Left empty, the first one in the scene
  is found via group.
- The **churn trail follows the boat's actual path**: breadcrumbs
  drop every `trail_spacing` meters while making way, and the shader
  paints foam along the polyline, widening and fading over
  `trail_max_age` seconds. Trail reach is at most
  `24 * trail_spacing` meters.
- The waterline **ring** hugs the hull footprint (`hull_length` x
  `hull_beam`) even at rest; **entry foam** and **spray** sit at the
  leading end of the hull axis, so hard turns keep the bow wash on
  the bow.
- Spray reacts to the sea as well as the throttle: a bow closing on a
  rising surface throws extra spray.
- `debug_foam` color-codes the terms for review: ring green, trail
  white, bow red.
- **One WakeEmitter per scene.** The ocean material carries a single
  hull uniform set; the last emitter to push wins. Fleet wake is a
  planned shader upgrade, not a checkbox.

## Whitecaps and wind streaks

Automatic, on any sea heavy enough, in every scene:

- **Whitecaps** form where water is high AND steep (breaking), picked
  inside slow-drifting gust patches so only some big waves foam. The
  master gate is `steepness_sum * storm_scale`: below ~0.30 the sea
  stays clean (calm preset), above ~0.70 caps come in fully.
- **Wind streaks**, elongated foam lanes along the dominant wave
  direction, appear only on genuinely raging seas (gate 0.55-0.85)
  and are deliberately rare and faint.

Tuning lives at the top of the whitecap block in
`shaders/ocean.gdshader`; every threshold is a plain `smoothstep`
with a comment.

## FAQ

**Which renderers?** Forward+ is the primary target and what all
screenshots use. Compatibility (GLES3) is tested and works: the
shader compiles, physics is identical, foam and whitecaps render. The
image tone-maps differently there (brighter, more saturated), so
retune sea colors for your target renderer rather than expecting
pixel parity.

**Which Godot versions?** Built and tested on Godot 4.7 (Forward+,
Jolt physics). The code uses no 4.7-exclusive API and is expected to
run on 4.4+, but 4.7 is what the harness runs on.

**Performance?** The default detail tile is a 190x190 grid (~36k
vertices) evaluating 4 Gerstner waves in vertex; fragments do ~13
wave evaluations (per-fragment normals plus foam). Comfortable for
desktop GPUs. The physics side costs one `get_height` per probe per
tick (a 4-probe body is negligible; a 100-probe hull is still fine).
Cheapest big lever: `tile_subdiv`.

**Multiple oceans / lakes at different heights?** No. One `Ocean`
autoload means one world sea at y = 0. That is the design; it is not
a hidden limitation.

**Networked games?** The sea is deterministic (see the Ocean
autoload section). Sync `Ocean.time`, the profile, and `storm_scale`,
and every client computes identical water.

**My object pogo-sticks / gets washed over.** Read the damping trio
notes in FloatingBody. Pogo = raise `vertical_damping`; hanging
still while crests pass = you damped against the world somewhere.

**My storm looks calm.** Check `disp_fade_start/end` against your
wavelengths (see "Size the stage to the sea"), then check your sky
("A sea mirrors its sky").

**Waves look glitchy / crests spike.** You broke the stability rule:
`steepness_sum * storm_scale` past ~0.9 folds crests over. The Ocean
autoload warned you once in the log.

## Demo scenes

- `demo/floating_props.tscn`: three float characters (crate, barrel,
  raft with bottom probes). Start here.
- `demo/powered_boat.tscn`: WASD skiff with the full wake stack.
- `demo/storm_demo.tscn`: one variable (`Ocean.storm_scale`) driving
  waves, sea color, sky, and sun through a calm-to-rage cycle.

Demo models are CC0 (see CREDITS.md at the repo root); the demos are
examples, not part of the addon API.
