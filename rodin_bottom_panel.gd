@tool
class_name RodinButtomPanel extends Control

@onready var save_btn := %"Save GLTF"
@onready var submit_btn := %Submit

var ws_server := RBWSServer.new()
var task_manager := RBTaskManager.new()

var port_range: Array[int] = [61883, 61893]

signal on_prop_changed(value, name: String)

func _ready() -> void:
	if RBUtils.in_editor(self):
		return
	task_manager.name = "TaskManager"
	ws_server.name = "WS Server"
	add_child(task_manager)
	add_child(ws_server)
	self.ws_server.try_connect(self.port_range)

	save_btn.pressed.connect(on_save_btn_click)
	submit_btn.pressed.connect(on_submit_btn_click)
	on_prop_changed.connect(RBProps.instance().on_prop_event)
	%Timer.timeout.connect(RBProps.instance().update_material_config)
	self.bind_props_event()
	if has_node("%LoadTestBtn"):
		%LoadTestBtn.pressed.connect(load_model_test)
	%zh_CN.pressed.connect(to_cn)
	%en.pressed.connect(to_en)

func to_cn() -> void:
	TranslationServer.set_locale("zh_CN")

func to_en() -> void:
	TranslationServer.set_locale("en")
	
func _process(delta: float) -> void:
	%ComptibleBrowserError.update()

func load_model_test() -> void:
	RBRodinLoader.load_rodin_model({}, true)

func bind_props_event() -> void:
	var bind_v = {
		%ConditionOption: "condition_type",
		%ModeOption: "mode",
	}
	for w in bind_v:
		w.option_trigger.connect(bind_on_prop_changed.bind(bind_v[w]))

	var bind = [
		%ImageBox,
		%VoxelBox,
		%PointCloudBox,
		%TextToBox,
		%TextInput,
		%GenTypeOption,
		%GenTypeBox,
		%MatBox,
	]
	for w in bind:
		w.option_trigger.connect(bind_on_prop_changed)

func bind_on_prop_changed(value, prop: String) -> void:
	on_prop_changed.emit(value, prop)

func on_submit_btn_click() -> void:
	var util = RBUtils.new()
	add_child(util)

	var task = RBTask.new()
	var url = util.get_rodin_host()
	var connecting = func(status: RBTask.TaskStatus) -> void:
		if await task.has_subprocess():
			return
		task.subprocess = util.open_browser(url)

	var rodin_prop = RBProps.instance()
	var m_type = rodin_prop.condition_type
	var data := {
		"type": m_type,  # 任务类型 Mesh / Image
		"id": task.id,  # 任务id
		"prompt": rodin_prop.prompt,  # text提示词
		"config": rodin_prop.dump_config(),
		"image": %ImageList.prepare_images(),
		"condition": {},
	}
	if RBUtils.is_mesh_selected() and m_type != "image":
		data["condition"] = self.prepare_mesh()
	task.set_data(data)
	task.on_connecting.connect(connecting)
	task.push()
	%TaskList.push_task(task)

func is_mesh_selected() -> bool:
	return false

func prepare_mesh() -> Dictionary:
	var mesh_data = self.save_gltf()

	var buffer = "data:model/glb;base64," + Marshalls.raw_to_base64(mesh_data)
	var data = {
		"format": "glb",  # 文件格式
		"length": buffer.length(),  # 文件长度
		"md5": buffer.md5_text(),  # 文件md5
		"content": buffer,  # base64编码
	}
	return data

func on_save_btn_click() -> void:
	save_gltf()

func save_gltf() -> PackedByteArray:
	#print(EditorInterface.get_edited_scene_root())
	#print(EditorInterface.get_selected_paths()) # 
	var selected_nodes = RBUtils.get_editor_interface().get_selection().get_selected_nodes()
	var gltf_document_save := GLTFDocument.new()
	var gltf_state_save := GLTFState.new()
	# 1. 从内存获取:
	#gltf_document_save.append_from_buffer([], "", gltf_state_save)
	# 2. 从场景获取:
	var meshes := {}
	for obj in selected_nodes:
		if not (obj is Node3D):
			continue
		var mesh: Node3D = obj
		meshes[mesh] = Transform3D(mesh.global_transform)
		#mesh.rotation.x = deg_to_rad(90)
		## mesh.rotation.y = r.z
		## mesh.rotation.z = r.x
		#mesh.global_position.y = p.z
		#mesh.global_position.z = p.y
		gltf_document_save.append_from_scene(obj, gltf_state_save)
	
	var path = RBUtils.get_temp_dir().path_join("rodin_temp.glb")
	gltf_document_save.write_to_filesystem(gltf_state_save, path)
	for mesh in meshes:
		mesh.global_transform = meshes[mesh]
	printerr("临时导出: ", path)
	return FileAccess.get_file_as_bytes(path)
	
