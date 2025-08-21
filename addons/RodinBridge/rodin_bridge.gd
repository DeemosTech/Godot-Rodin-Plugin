@tool
class_name RodinBridge extends EditorPlugin

var panel: Control = preload("./rodin_bottom_panel.tscn").instantiate()
var task_manager: RBTaskManager = RBTaskManager.new()

const TRANSLATION_DOMAIN := "com.rodin.rodin_bridge"


func _enter_tree() -> void:
	init_translation()
	init_settings()
	add_control_to_bottom_panel(panel, "Rodin Bridge")
	add_child(task_manager)

func init_settings() -> void:
	# printerr("Godot Engine: %x" % Engine.get_version_info().hex)
	RBSettings.init()
	await self.get_tree().create_timer(0.2).timeout
	self.set_eidtor_interface.call_deferred()

func init_translation() -> void:
	return
	#var domain := TranslationServer.get_or_add_domain(TRANSLATION_DOMAIN)
	#domain.add_translation(preload("res://addons/RodinBridge/asset/text"))
	#domain.add_translation(preload("res://addons/RodinBridge/asset/text"))
	#panel.set_translation_domain(TRANSLATION_DOMAIN)

func set_eidtor_interface() -> void:
	var e = self.get_editor_interface()
	RBSettings.instance()._settings["editor_interface"] = e

func _exit_tree() -> void:
	remove_control_from_bottom_panel(panel)
	panel.queue_free()
	task_manager.queue_free()

func _handles(object: Object) -> bool:
	return true

func _edit(object: Object) -> void:
	return
	if object is MeshInstance3D:
		make_bottom_panel_item_visible(panel)
