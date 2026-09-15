@tool
extends EditorExportPlugin
func _get_name() -> String:return "ControllerWebAssets"
func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	for name in ["index.html","controller.js","connection-config.js","room-code.js","avatars.js","reward.css"]:
		var path: String = "res://relay/public/"+name
		add_file(path,FileAccess.get_file_as_bytes(path),false)
