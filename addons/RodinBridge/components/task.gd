@tool
class_name RBTask extends Node

enum TaskStatus {
	NONE,
	PENDING,
	CONNECTING,
	PROCESSING,
	TIMEOUT,
	SUCCEEDED,
	FAILED,
	SKIPPED,
	EXIT,
}

var status := TaskStatus.PENDING:
	set(v):
		status = v
		match v:
			TaskStatus.CONNECTING:
				on_connecting.emit(v)
			TaskStatus.PROCESSING:
				on_processing.emit(v)
			TaskStatus.TIMEOUT:
				on_timeout.emit(v)
			TaskStatus.SUCCEEDED:
				on_succeeded.emit(v)
			TaskStatus.FAILED:
				on_failed.emit(v)
			TaskStatus.SKIPPED:
				on_skipped.emit(v)
			TaskStatus.EXIT:
				on_exit.emit(v)
	get:
		return status


var last_status: TaskStatus = TaskStatus.NONE
var timeout := 1000
var start_time := 0
var data := {}
var client: GDClient = null
var id: String = ""
var proc: RBProc = null
var running := false
var subprocess = null
var skip_marked = false
var submitted = false

signal on_connecting(s: TaskStatus)
signal on_processing(s: TaskStatus)
signal on_timeout(s: TaskStatus)
signal on_succeeded(s: TaskStatus)
signal on_failed(s: TaskStatus)
signal on_skipped(s: TaskStatus)
signal on_exit(s: TaskStatus)
signal on_task_removed

func _init() -> void:
	self.id = RBUtils.gen_id()
	self.client = GDClient.new()
	add_child(self.client)

func _ready() -> void:

	print(self.H() + "➕添加成功")
	
	on_connecting.connect(print_info)
	on_processing.connect(print_info)
	on_timeout.connect(print_info)
	on_succeeded.connect(print_info)
	on_failed.connect(print_info)
	on_skipped.connect(print_info)
	on_exit.connect(print_info)

func _exit_tree() -> void:
	self.remove()

func _process(delta: float) -> void:
	if self.status != TaskStatus.CONNECTING:
		return
	if not self.client.ws_ready():
		self.client.ensure_connect()
		return
	if self.submitted:
		return
	
	print(self.H() + "❓尝试提交....")
	if (self.client.submit_task(self.data, self.id)):
		self.submitted = true
	print(self.H() + "✈️提交成功")
	self.job()

func H() -> String:
	return "任务[%s] -> " % self.id

func set_data(d: Dictionary) -> void:
	if not (d is Dictionary):
		printerr("提交数据格式不正确")
		return
	data = d

func is_running() -> bool:
	return self.status in [TaskStatus.CONNECTING, TaskStatus.PROCESSING]

func is_timeout() -> bool:
	return status == TaskStatus.TIMEOUT

func is_finished() -> bool:
	return self.status in [
		TaskStatus.SUCCEEDED,
		TaskStatus.FAILED,
		TaskStatus.TIMEOUT,
		TaskStatus.TIMEOUT,
		TaskStatus.EXIT,
	]

func has_subprocess() -> bool:
	if await client.any_client_connected():
		return true
	self.clean_subprocess()
	return false

func clean_subprocess() -> void:
	pass

func print_info(state: TaskStatus) -> void:
	if state == last_status:
		return
	print(self.H() + "📊当前状态 %s" % TaskStatus.find_key(state))
	last_status = state

func push() -> void:
	RBTaskManager.add_task(self)

func remove() -> void:
	self.skip()

func run() -> void:
	if self.is_running() or self.is_timeout():
		return
	print(self.H() + "🟡任务运行")
	self.start_time = Time.get_ticks_msec()
	self.status = TaskStatus.CONNECTING

func skip() -> void:
	if self.skip_marked:
		return
	self.client.skip_task(self.id)
	self.skip_marked = true
	self.on_task_removed.emit()

func job() -> void:
	print(self.H() + "⏳开始等待")
	var _last_status = null
	while self.is_running():
		await self.get_tree().create_timer(1).timeout
		if self.skip_marked:
			self.status = TaskStatus.SKIPPED
			break
		if self.elapsed() > self.timeout and self.status == TaskStatus.CONNECTING:
			self.status = TaskStatus.TIMEOUT
			break
		if self.status == TaskStatus.SKIPPED:
			break
		var _status = await self.client.query_task_status(self.id)
		if _status != _last_status:
			print(self.H() + "当前状态值 %s" % _status)
			_last_status = _status

		if _status in ["not_found", "failed"]:
			self.status = TaskStatus.FAILED
			break
		elif _status == "processing":
			self.status = TaskStatus.PROCESSING
		elif _status == "succeeded":
			self.status = TaskStatus.SUCCEEDED
			break
		elif _status == "pending":
			pass
	if self.status == TaskStatus.SKIPPED:
		self.skip()
	# if self.status in [TaskStatus.SUCCEEDED, TaskStatus.FAILED]:
	# 	await self.client.fetch_task_result(self.id)
	self.status = TaskStatus.EXIT
	self.client.clear_task(self.id)
	print(self.H() + "🎉任务结束 %s" % self.status_info())

func status_info() -> String:
	return TaskStatus.find_key(self.status)

func task_info() -> String:
	return self.H() + "状态[%s] -> 耗时[%.2fs]" % [self.status_info(), self.elapsed()]

func info() -> String:
	return "状态[%s] -> 耗时[%.2fs]" % [self.status_info(), self.elapsed()]

func elapsed() -> float:
	return (Time.get_ticks_msec() - start_time) * 0.001
