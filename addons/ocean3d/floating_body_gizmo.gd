@tool
extends EditorNode3DGizmoPlugin

# Draws each FloatingBody probe point as a small cross in the 3D
# editor, so probe layouts can be judged at a glance while placing
# them. Registered by plugin.gd; redraws when the probe arrays change
# (the exports call update_gizmos) or the body moves.

const CROSS := 0.18


func _init() -> void:
	create_material("probes", Color(0.35, 0.8, 1.0))


func _get_gizmo_name() -> String:
	return "FloatingBody probes"


func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is FloatingBody


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var body := gizmo.get_node_3d() as FloatingBody
	if body == null or body.probe_points.is_empty():
		return
	var lines := PackedVector3Array()
	for p in body.probe_points:
		lines.append(p + Vector3(-CROSS, 0, 0))
		lines.append(p + Vector3(CROSS, 0, 0))
		lines.append(p + Vector3(0, -CROSS, 0))
		lines.append(p + Vector3(0, CROSS, 0))
		lines.append(p + Vector3(0, 0, -CROSS))
		lines.append(p + Vector3(0, 0, CROSS))
	gizmo.add_lines(lines, get_material("probes", gizmo))
