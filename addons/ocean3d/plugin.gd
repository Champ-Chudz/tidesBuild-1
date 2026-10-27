@tool
extends EditorPlugin

# Ocean3D editor plugin. Registers the Ocean autoload when the plugin
# is enabled, and the FloatingBody probe gizmo for every editor
# session. Everything else in the kit is plain nodes and resources
# that work the moment the autoload exists.

const AUTOLOAD_NAME := "Ocean"
const AUTOLOAD_PATH := "res://addons/ocean3d/ocean.gd"

var _gizmos: EditorNode3DGizmoPlugin


func _enter_tree() -> void:
	_gizmos = preload("floating_body_gizmo.gd").new()
	add_node_3d_gizmo_plugin(_gizmos)


func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(_gizmos)
	_gizmos = null


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
