@tool
class_name RBProc extends Node

var pid: int = -1
var is_dead: bool = false

func create(path: String, args: PackedStringArray) -> void:
	pid = OS.create_process(path, args)

func kill() -> Error:
	if is_dead:
		return OK
	var state = OS.kill(pid)
	is_dead = state == OK
	return state

func try_kill() -> Error:
	return OS.kill(pid)

func close() -> void:
	print("删除RBProc")
	print("    状态: %s -> %s" % [pid, str(try_kill())])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("关闭")
		close()
