@tool
extends EditorPlugin
const ControllerExport = preload("res://addons/controller_export/web_export.gd")
var exporter: EditorExportPlugin
func _enter_tree() -> void:
	exporter=ControllerExport.new();add_export_plugin(exporter)
func _exit_tree() -> void:
	if exporter != null:remove_export_plugin(exporter)
