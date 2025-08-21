@tool
class_name RBRodinLoader extends Node

static func MODEL_FMT() -> Array:
	return [ "glb", "gltf" ]

static func IMAGE_FMT() -> Array:
	return [ "png", ]

static func ALL_FMT() -> Array:
	return MODEL_FMT() + IMAGE_FMT()

static func get_current_location() -> Vector3:
	return RBSettings.fetch("loader_cur_location")

static func set_current_location(loc: Vector3) -> void:
	RBSettings.push("loader_cur_location", loc)

static func load_rodin_model(event: Dictionary, test: bool = false) -> void:
	# 存储到临时json
	var file_path = RBUtils.get_temp_dir().path_join("rodin_model_%s.json" % RBUtils.gen_id(8))
	save_temp(event, file_path)
	if test:
		file_path = "/var/folders/8j/2f2zq6j13z35gthb5mrfmzr80000gn/T/rodin_model_fa608d2d.json"
		if OS.get_name() == "Windows":
			file_path = "Y:/Godot/rodin_model_fa608d2d.json"

	event = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	#print(RBUtils.print_tree_str(event))

	var data = event.get("data", {})
	var files = data.get("files", [])
	var loc = data.get("location", [0, 0, 0])
	set_current_location(Vector3(loc[0], loc[2], -loc[1]))

	if files.is_empty():
		return
	if typeof(files) == TYPE_ARRAY:
		load_model(files[0])
	elif typeof(files) == TYPE_DICTIONARY:
		load_model_pbr(files.get("pbr", []))
		load_model_shaded(files.get("shaded", []))

static func save_temp(event: Dictionary, file_path: String) -> void:
	if event.is_empty():
		printerr("接收到的数据为空")
		return
	var fd = FileAccess.open(file_path, FileAccess.WRITE)
	fd.store_string(JSON.stringify(event))
	printerr("已存储: ", file_path)
	
static func load_model(file: Dictionary) -> void:
	var fmt = fmt_get(file)
	assert(is_model_fmt(fmt), "不支持的模型格式: %s" % fmt)
	var prefix = "data:model/%s;base64," % fmt
	var contents = content_get(file)
	var md5_hex: String = contents[0]
	var content: String = contents[1]
	assert(content.begins_with(prefix), "Rodin: [加载数据] 数据格式错误 -> %s" % content.substr(0, 50))
	content = content.substr(prefix.length())
	var buffer = Marshalls.base64_to_raw(content)

	var file_name = file.get("filename", "rodin_recv_model.%s" % fmt)
	file_name = "%s_%s" % [md5_hex, file_name]
	var model_file = RBUtils.get_temp_dir().path_join(file_name)
	FileAccess.open(model_file, FileAccess.WRITE).store_buffer(buffer)
	print("临时保存: ", model_file)
	#model_file = "res://test/base_basic_pbr (5).glb"
	load_gltf(model_file)

static func load_gltf(file: String) -> void:
	load_gltf_from_buffer(FileAccess.get_file_as_bytes(file), file)

static func load_gltf_from_buffer(buffer: PackedByteArray, file=null) -> Node3D:
	# 加载gltf场景
	# GLTFDocument 是处理将gltf数据实际加载到godot节点树的类, 其支持gltf的特性(如light/camera)
	# GLTFState 被 GLTFDocument 用来存储已加载场景的state
	var gltf_document_load = GLTFDocument.new()
	var gltf_state_load = GLTFState.new()
	gltf_state_load.set_handle_binary_image(GLTFState.HANDLE_BINARY_EMBED_AS_BASISU)

	var error = gltf_document_load.append_from_file(file, gltf_state_load)
	assert(error == OK, "Couldn't load glTF scene (error code: %s)." % error_string(error))
	
	var glb_scene: Node3D = gltf_document_load.generate_scene(gltf_state_load)
	var glb_importer_model: ImporterMeshInstance3D = glb_scene.get_child(0)
	var glb_importer_model_mesh: ImporterMesh = glb_importer_model.get_mesh()
	var model: MeshInstance3D = MeshInstance3D.new()
	model.mesh = glb_importer_model_mesh.get_mesh()
	model.material_override = glb_importer_model_mesh.get_surface_material(0)
	model.name = gltf_state_load.get_scene_name()

	model.rotation_order = 2

	var editor_scene_root = RBUtils.get_editor_interface().get_edited_scene_root()
	editor_scene_root.add_child(model)
	model.set_owner(editor_scene_root)
	model.translate(get_current_location())
	return model

static func load_model_pbr(files: Array) -> void:
	# TODO
	pass

static func load_model_shaded(model) -> void:
	# TODO
	pass

static func content_get(file: Dictionary) -> Array:
	var md5 = file.get("md5", "")
	var file_name: String = file.get("filename", "")
	var content: String = file.get("content", "")
	var md5_hex_content = content.md5_text()
	var err = "Rodin: [加载数据] 数据校验失败 -> %s %s" % [md5, md5_hex_content]
	assert(md5 == md5_hex_content, err)
	print("Rodin: [加载数据] md5验证通过 %s" % file_name)
	return [md5_hex_content, content]

static func fmt_get(file: Dictionary) -> String:
	var fmt = file.get("format", "unknown")
	assert(is_valid_fmt(fmt), "不支持的格式: %s!" % fmt)
	return fmt

static func is_valid_fmt(fmt) -> bool:
	if typeof(fmt) == TYPE_DICTIONARY:
		fmt = fmt_get(fmt)
	return fmt in ALL_FMT()

static func is_model_fmt(fmt) -> bool:
	return fmt in MODEL_FMT()
