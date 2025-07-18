@tool 
class_name TaskList extends VBoxContainer

var task_item_sce: PackedScene = preload("./task_item.tscn")

func push_task(task: RBTask=null) -> void:
	var task_item: TaskItem = task_item_sce.instantiate()
	task_item.set_task(task)
	add_child(task_item)
