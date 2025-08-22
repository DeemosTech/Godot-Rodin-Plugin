@tool
class_name TaskItem extends HBoxContainer

var Name: String :
	set(v):
		%Name.text = v
	get:
		return %Name.text

var Info: String :
	set(v):
		%Info.text = v
	get:
		return %Info.text

var task: RBTask = null

signal task_cancelled

func _ready() -> void:
	%Cancel.pressed.connect(cancel_cb)

func set_task(task: RBTask) -> void:
	self.task = task
	task.on_task_removed.connect(self.queue_free)
	self.add_child(task)
	self.Name = "Task: [%s]" % task.id

func cancel_cb() -> void:
	task_cancelled.emit()
	task.remove()
	queue_free.call_deferred()

func _process(delta: float) -> void:
	if task == null:
		return
	Info = task.info()
