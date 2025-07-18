@tool 
class_name RBTaskManager extends Node

static func instance() -> RBTaskManager:
	return RBSettings.fetch("task_manager_inst")

var _tasks: Array[RBTask] = []

var timer: Timer = null

func _ready() -> void:
	timer = Timer.new()
	timer.autostart = true
	timer.wait_time = 1
	add_child(timer)
	timer.timeout.connect(timer_proc)

func timer_proc() -> void:
	var rm_list: Array[int] = []
	var tasks =  instance()._tasks
	for i in range(tasks.size()):
		var task = tasks[i]
		if not task or task.is_finished():
			rm_list.append(i)
			continue
		task.run()
	rm_list.reverse()
	for i in rm_list:
		var task = tasks[i]
		tasks.remove_at(i)
		if is_instance_valid(task):
			task.remove()

static func task_infos() -> Array[String]:
	var infos := []
	for task in instance()._tasks:
		if task.status == RBTask.TaskStatus.PENDING:
			continue
		infos.append(task.task_info())
	return infos

static func add_task(task: RBTask) -> void:
	instance()._tasks.append(task)
