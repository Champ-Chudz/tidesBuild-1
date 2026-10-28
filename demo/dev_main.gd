extends Node3D

# Dev host entry scene. User-arg flags, Driftline style:
#   --kittest    attach the harness, print the verdict, quit
#   --props      instantiate the floating_props demo scene
#   --boat       instantiate the powered_boat demo scene
#   --autodrive  hold throttle + gentle turn (boat capture runs)
#   --storm      instantiate the storm_demo ramp scene
#   --shots      attach the screenshot rig (3 PNGs to telemetry/,
#                quit); combine with a demo flag, windowed runs only
#   --quitafter N  quit after N seconds; for --write-movie clip runs
# Demo scenes stay flag-free and buyer-clean; review plumbing lives
# here and in tests/.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--kittest" in args:
		add_child(load("res://tests/kittest.gd").new())
		return
	if "--modelprobe" in args:
		add_child(load("res://tests/modelprobe.gd").new())
		return
	if "--boatprobe" in args:
		add_child(load("res://tests/boatprobe.gd").new())
		return
	if "--props" in args:
		add_child(load("res://demo/floating_props.tscn").instantiate())
	if "--boat" in args:
		add_child(load("res://demo/powered_boat.tscn").instantiate())
	if "--storm" in args:
		add_child(load("res://demo/storm_demo.tscn").instantiate())
	# Marketing/capture runs: hide the demo scenes' on-screen labels.
	if "--clean" in args:
		for c in get_children():
			var ui := c.get_node_or_null("UI")
			if ui != null:
				ui.visible = false
	if "--shots" in args:
		add_child(load("res://tests/shotcap.gd").new())
	var qi := args.find("--quitafter")
	if qi >= 0 and qi + 1 < args.size():
		_quit_after(float(args[qi + 1]))


func _quit_after(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	get_tree().quit()
