@tool
class_name RBSettings extends Node

var _settings := {
	"task_manager_inst": RBTaskManager.new(),
	"loader_cur_location": Vector3.ZERO,
	"ctx_inst": RBCtx.new(),
	"props_inst": RBProps.new(),
	"client": {
		RBWSServer.ServerType.PLUGIN: RBWSClient.new(),
		RBWSServer.ServerType.GAME: RBWSClient.new(),
	},
	"server": {
		"compatible_browser": false,
		RBWSServer.ServerType.PLUGIN: null,
		RBWSServer.ServerType.GAME: null,
	},
	"editor_interface": null
}

static func instance() -> RBSettings:
	return ProjectSettings.get("rodin_setting_inst")

static func init() -> void:
	var s := ProjectSettings
	var settings := [
		{
			"path": "application/RodinBridge/api",
			"default": "https://hyper3d.ai/?show=plugin",
			# "info": {
			#     "name": "API URL",
			#     "type": TYPE_STRING,
			#     "hint": PROPERTY_HINT_ENUM,
			#     "hint_string": "one,two,three"
			# }
		},
		{
			"path": "rodin_setting_inst",
			"default": RBSettings.new(),
		},
	]

	for setting in settings:
		var key = setting["path"]
		var default_value = setting["default"]

		if not s.has_setting(key):
			s.set(key, default_value)

		if s.has_method("set_as_basic"):
			s.call("set_as_basic", key, true)
		s.set_initial_value(key, default_value)

static func fetch(path: String) -> Variant:
	return instance()._settings.get(path)

static func push(path: String, value: Variant) -> void:
	instance()._settings[path] = value
