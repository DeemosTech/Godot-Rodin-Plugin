@tool
class_name RBUtils extends Node

static func T() -> String:
	return Time.get_time_string_from_system()

static func I() -> String:
	return Time.get_date_string_from_system() + str(randi())

static func gen_id(len: int = -1) -> String:
	var time = Time.get_unix_time_from_system()
	return str(time).md5_text().substr(0, len)

static func get_temp_dir() -> String:
	if OS.has_method("get_temp_dir"):
		return OS.call("get_temp_dir")
	var temp_dir = OS.get_cache_dir()
	if temp_dir.is_empty():
		push_error("未找到临时目录!")
		return ""
	return temp_dir

static func get_editor_interface():
	var interface = RBSettings.fetch("editor_interface")
	if not interface:
		interface = EditorInterface
	return interface

func find_browser_path() -> String:
	match OS.get_name():
		"Windows":
			return find_browser_path_win()
		"macOS":
			return "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return "google-chrome-stable"
	return ""

func find_browser_path_win() -> String:
	var browser_paths = [
		"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\chrome.exe",
		"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\msedge.exe"
	]
	
	var hives = [
		"HKEY_LOCAL_MACHINE",
		"HKEY_CURRENT_USER",
	]
	
	for hive in hives:
		for path in browser_paths:
			var full_path = hive + "\\" + path
			var result = _read_registry(full_path)
			if result != "" and FileAccess.file_exists(result):
				return result
	
	printerr("Chrome or Edge not found!")
	return "chrome.exe"

func _read_registry(path: String) -> String:
	var output: Array[String] = []
	var exit_code = OS.execute("reg", ["query", path, "/ve"], output, true)	
	if exit_code != 0:
		return ""

	var regex = RegEx.new()
	regex.compile("[A-Za-z]:[^\\n\"]*?\\.exe")
	# 解析注册表输出
	for line in output:
		var result = regex.search(line)
		if not result:
			continue
		return result.get_string().strip_edges().replace("\"", "")
	return ""

func open_browser(url: String) -> RBProc:
	var path = find_browser_path()
	if path.is_empty():
		printerr("未找到浏览器!")
		return null
	var args: PackedStringArray = []
	args.append(url)
	args.append("--no-first-run")
	args.append("--no-default-browser-check")
	var proc = RBProc.new()
	add_child(proc)
	proc.create(path, args)
	return proc

static func get_rodin_host() -> String:
	return ProjectSettings.get("application/RodinBridge/api")

static func in_plugin(node) -> bool:
	var edit_sce_root = node.get_tree().edited_scene_root
	if edit_sce_root != null && edit_sce_root in [node, node.owner]:
		return false
	return true and Engine.is_editor_hint()

static func in_editor(node=null) -> bool:
	return not in_plugin(node) and Engine.is_editor_hint()

static func in_game(node) -> bool:
	return not in_plugin(node) and not in_editor(node)

static func is_mesh_selected() -> bool:
	if not Engine.is_editor_hint():
		return false

	var selected_nodes = RBUtils.get_editor_interface().get_selection().get_selected_nodes()
	if selected_nodes.is_empty():
		# print("未选择Mesh节点")
		return false
	for obj in selected_nodes:
		if obj is Node3D:
			return true
	return false

static func print_tree_str(data, exclude_keys = [], indent = 0, limit = 40) -> String:
	var tree_str = ""
	
	# 处理字典类型
	if typeof(data) == TYPE_DICTIONARY:
		for key in data:
			# 跳过排除的键
			if key in exclude_keys:
				continue
				
			tree_str += _indent(indent) + str(key) + ":" + "\n"
			tree_str += print_tree_str(
				data[key], 
				exclude_keys, 
				indent + 4,
				limit
			)
	
	# 处理数组类型
	elif typeof(data) == TYPE_ARRAY:
		for index in range(data.size()):
			tree_str += _indent(indent) + "[%d]:" % index + "\n"
			tree_str += print_tree_str(
				data[index], 
				exclude_keys, 
				indent + 4,
				limit
			)
	
	# 处理基本类型
	else:
		var content = str(data)
		# 截断过长的内容
		if content.length() > limit:
			content = content.left(limit) + "..."
		tree_str += _indent(indent) + content + "\n"
	
	return tree_str

static func _indent(level: int) -> String:
	return " ".repeat(level)
