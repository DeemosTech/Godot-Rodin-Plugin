@tool
class_name RBWSServer extends Node

enum ServerType {
	PLUGIN,
	GAME,
}

var host = "127.0.0.1"
var port = 60080
var launched := false
var handler_registed := false
var server_type: ServerType = ServerType.PLUGIN

var tcp_server := TCPServer.new()
var _sockets: Dictionary = {}

var handlers: Dictionary = {}
var _submit_tasks: Dictionary = {}
var _processing_tasks: Dictionary = {}
var _failed_tasks: Dictionary = {}
var _succeeded_task: Dictionary = {}
var _disconnect_sids: Dictionary = {}
var _alive_clients: Array = []

static func get_compatible_browser() -> bool:
	return RBSettings.fetch("server").get("compatible_browser")

static func set_compatible_browser(value) -> void:
	RBSettings.fetch("server")["compatible_browser"] = value

static func get_server_pool(key) -> RBWSServer:
	return RBSettings.fetch("server").get(key)

static func set_server_pool(key, value) -> void:
	RBSettings.fetch("server")[key] = value

signal on_recv(socket: WebSocketPeer, data: String)

func _ready() -> void:
	if RBUtils.in_plugin(self):
		self.port = 61883
		self.server_type = ServerType.PLUGIN
	if RBUtils.in_game(self):
		self.port = 60080
		self.server_type = ServerType.GAME
	print(self.H() + "端口范围 ", [self.port, self.port + 10])
	self.set_server_pool(self.server_type, self)
	self.try_connect([self.port, self.port + 10])

func try_connect(prange: Array[int] = []) -> bool:
	self.init_handler()
	if self.launched:
		return true
	print(self.H() + "⏳启动中...")
	for p in range(prange[0], prange[1] + 1):
		if tcp_server.listen(p, host) != OK:
			print(self.H() + "❌服务启动失败: %s:%s" % [host, p])
		else:
			print(self.H() + "🟢服务启动成功: %s:%s" % [host, p])
			self.launched = true
			self.port = p
			break
	self.set_process(self.launched)
	return self.launched

func init_handler() -> void:
	if self.handler_registed:
		return
	self.handler_registed = true
	self.on_recv.connect(call_handler)
	self.reg_handler("unknown", self.default_handler)
	self.reg_handler("_default", self.default)
	self.reg_handler("hello_client", self.hello)
	self.reg_handler("rodin_auth", self.auth)
	self.reg_handler("close_server", self.close)
	
	# web 接口
	self.reg_handler("web_connect", self.web_connect)
	self.reg_handler("send_model", self.send_model)
	self.reg_handler("fetch_task", self.fetch_task)
	self.reg_handler("fetch_material_config", self.fetch_material_config)
	self.reg_handler("fail_task", self.fail_task)
	self.reg_handler("ping_client_return", self.ping_client_return)
	self.reg_handler("fetch_host_info", self.fetch_host_info)

	# 本机接口
	self.reg_handler("submit_task", self.submit_task)
	self.reg_handler("skip_task", self.skip_task)
	self.reg_handler("query_sid_dead", self.query_sid_dead)
	self.reg_handler("query_task_status", self.query_task_status)
	self.reg_handler("fetch_task_result", self.fetch_task_result)
	self.reg_handler("clear_task", self.clear_task)
	self.reg_handler("any_client_connected", self.any_client_connected)

func H() -> String:
	return "服务端[%s]: " % RBUtils.T()

func log_json(message: String) -> void:
	var dict: Dictionary = JSON.parse_string(message)
	var event_type = dict.get("type", "unknown")
	var event_data = dict.get("data", "unknown")
	var time = RBUtils.T()
	var text = self.H() + "处理请求 " + event_type
	print(text)
	if self.has_node("%TextServer"):
		%TextServer.text += time + event_data + "\n"

func reg_handler(etype, handler) -> void:
	handlers[etype] = handler

func unreg_handler(etype) -> void:
	handlers.erase(etype)

func call_handler(socket, message: String) -> void:
	var dict: Dictionary = JSON.parse_string(message)
	var event_type = dict.get("type", "unknown")
	var handler = handlers.get(event_type, default_handler)
	handler.call(socket, dict)

func get_sid(path: String) -> String:
	if typeof(path) != TYPE_STRING:
		return RBUtils.gen_id()
	return path.split("id=")[1] if "id=" in path else RBUtils.gen_id()

func _process(_delta: float) -> void:
	while tcp_server.is_connection_available():
		var conn: StreamPeerTCP = tcp_server.take_connection()
		var path = conn.get_connected_host()
		var sid = self.get_sid(path)
		# print(self.H() + "SID: %s %s" % [path, sid])
		var socket := WebSocketPeer.new()
		socket.accept_stream(conn)
		socket.inbound_buffer_size = 1 << 30 - 1 # 29 -> 512MB
		self._sockets[socket] = conn
	
	var to_remove := []
	for s in self._sockets:
		s.poll()

		var state = s.get_ready_state()
	
		if state == WebSocketPeer.STATE_OPEN:
			while s.get_available_packet_count():
				on_recv.emit(s, s.get_packet().get_string_from_utf8())
		elif state == WebSocketPeer.STATE_CLOSING:
			print(self.H() + "客户端正在关闭: ", self._sockets[s])
		elif state == WebSocketPeer.STATE_CLOSED:
			print(self.H() + "客户端已经关闭: ", self._sockets[s])
			var code = s.get_close_code()
			var reason = s.get_close_reason()
			print(self.H() + "关闭, 代码：%d，原因 %s" % [code, reason])
			to_remove.append(s)
		elif state == WebSocketPeer.STATE_CONNECTING:
			pass
			# print(self.H() + "客户端正在连接: ", self._sockets[s])
	for k in to_remove:
		k.close()
		var sid = self.get_sid(k.get_requested_url())
		self._disconnect_sids[sid] = null
		self._sockets.erase(k)
	
func on_button_pong_pressed() -> void:
	var data = {
		"type": "pong",
		"data": "来自服务器"
	}
	for socket in self._sockets:
		self.send(socket, data)

func send(socket: WebSocketPeer, data: Dictionary) -> Error:
	var json = JSON.stringify(data)
	var bytes = json.to_utf8_buffer()
	socket.outbound_buffer_size = bytes.size()
	return socket.send_text(json)
	#return socket.send_text(JSON.stringify(data))

func _exit_tree() -> void:
	for socket in _sockets:
		socket.get_connected_host()
		socket.close()
	tcp_server.stop()

func pop_task_all(sid):
	print(self.H() + "🗑️任务移除 [%s]" % sid)
	self._submit_tasks.erase(sid)
	self._processing_tasks.erase(sid)
	self._succeeded_task.erase(sid)
	self._failed_tasks.erase(sid)

########################### HANDLER ############################

func default_handler(socket: WebSocketPeer, event: Dictionary) -> void:
	var etype = event.get("type", "unknown")
	var edata = event.get("data", "unknown")
	self.log_json(JSON.stringify({"type": etype, "data": edata}))

func default(socket: WebSocketPeer, event: Dictionary) -> void:
	print("默认消息: ", event)
	var e = {
		"type": "default",
		"data": event,
	}
	if "____id" in event:
		e["____id"] = event["____id"]
	self.send(socket, e)

func hello(socket: WebSocketPeer, event: Dictionary) -> void:
	print("Server Reiceived: ", event)
	var e = {
		"type": "hello_server",
		"data": "Hello Client!",
	}
	if "____id" in event:
		e["____id"] = event["____id"]
	self.send(socket, e)

func auth(socket: WebSocketPeer, event: Dictionary) -> void:
	var e = {
		"type": "rodin_auth_return",
		"data": "OK",
	}
	if "____id" in event:
		e["____id"] = event["____id"]
	self.send(socket, e)

func close(socket: WebSocketPeer, event: Dictionary) -> void:
	print("Server Closing: ", event)
	tcp_server.stop()
	socket.close()
	self.launched = false

func web_connect(socket: WebSocketPeer, event: Dictionary) -> void:
	var e = {
		"type": "web_connect_return",
		"data": "OK",
	}
	if "____id" in event:
		e["____id"] = event["____id"]
	self.send(socket, e)

func send_model(socket: WebSocketPeer, event: Dictionary) -> void:
	var data = event.get("data", {})
	
	var files = data.get("files", null)
	var sid = data.get("sid", null)
	var browser = data.get("browser", null)
	
	if sid == null:
		sid = event.get("sid", null)
	if sid:
		print("Received model from: ", sid)
	self.pop_task_all(sid)
	var request_info: Array = [socket.get_connected_host(), socket.get_connected_port()]
	if sid:
		print(self.H() + "✅任务完成 %s: " % sid, request_info)
		self._succeeded_task[sid] = {}
	else:
		print(self.H() + "📥收到模型 ", request_info)
	
	if files == null:
		var fail_event = {
			"type": "send_model_return",
			"sid": null,
			"data": "Fail",
		}
		if "____id" in event:
			fail_event["____id"] = event["____id"]
		if self.send(socket, fail_event) != OK:
			printerr("发送失败")
		print("Sent send model return (fail): ", fail_event)
		if browser:
			if browser == "Firefox" or browser == "Safari":
				self.set_compatible_browser(true)
			else:
				self.set_compatible_browser(false)
		return
	RBRodinLoader.load_rodin_model(event)
	var e = {
		"type": "send_model_return",
		"sid": sid,
		"data": "OK",
	}
	self.send(socket, e)
	print("Sent send model return: \n", RBUtils.print_tree_str(e))

func fetch_task(socket: WebSocketPeer, event: Dictionary) -> void:
	var e = {
		"type": "fetch_task_return",
		"task": null,
	}
	var sid = null
	for k in self._submit_tasks:
		var v =  self._submit_tasks[k]
		if not v: continue
		sid = k
		e["task"] = v
		e["sid"] = k
		self._processing_tasks[k] = v
		break
	# printerr("Task fetched %s: %s" % [sid, socket.get_requested_url()])
	if "____id" in event:
		e["____id"] = event["____id"]
	self.send(socket, e)

func fetch_material_config(socket: WebSocketPeer, event: Dictionary) -> void:
	var e = {
		"type": "fetch_material_config_return",
		"config": RBCtx.instance().config,
		"condition_type": RBCtx.instance().condition_type,
	}
	if "____id" in event:
		e["____id"] = event["____id"]
	self.send(socket, e)

func fail_task(socket: WebSocketPeer, event: Dictionary) -> void:
	var sid = event.get("sid", null)
	self.pop_task_all(sid)
	printerr("Task failed by %s: %s" % [sid, socket.get_requested_url()])
	self._failed_tasks[sid] = event.get("data", null)

func ping_client_return(socket: WebSocketPeer, event: Dictionary) -> void:
	if event.get("status") != "ok":
		return
	self._alive_clients.append(socket)

func fetch_host_info(socket: WebSocketPeer, event: Dictionary) -> void:
	var e = {
		"type": "host_type_return",
		"data": {
			"exe": "Godot",
			"version": Engine.get_version_info(),
		}
	}
	if "____id" in event:
		e["____id"] = event["____id"]
	self.send(socket, e)

func submit_task(socket: WebSocketPeer, event: Dictionary) -> void:
	var sid = event.get("sid", null)
	if sid == null:
		return
	print(self.H() + "📥收到任务\n%s" % RBUtils.print_tree_str(event))
	self._submit_tasks[sid] = event.get("data", {})

func skip_task(socket: WebSocketPeer, event: Dictionary) -> void:
	var sid = event.get("sid", null)
	var e = {
		"type": "skip_task_return",
		"data": "none",
	}
	self.pop_task_all(sid)
	e["data"] = "skipped"
	if "____id" in event:
		e["____id"] = event["____id"]
	self.send(socket, e)

func query_sid_dead(socket: WebSocketPeer, event: Dictionary) -> void:
	var sid = event.get("sid", null)
	var e = {
		"type": "query_sid_dead_return",
		"dead": sid in self._disconnect_sids,
	}
	if "____id" in event:
		e["____id"] = event["____id"]
	self.send(socket, e)

func query_task_status(socket: WebSocketPeer, event: Dictionary) -> void:
	var sid = event.get("sid", null)
	var e = {
		"type": "query_task_status_return",
		"status": "",
	}
	if sid in self._submit_tasks:
		e["status"] = "pending"
	if sid in self._processing_tasks:
		e["status"] = "processing"
	if sid in self._failed_tasks:
		e["status"] = "failed"
	if sid in self._succeeded_task:
		e["status"] = "succeeded"
	if sid == null:
		e["status"] = "not_found"
	if "____id" in event:
		e["____id"] = event["____id"]
	self.send(socket, e)

func fetch_task_result(socket: WebSocketPeer, event: Dictionary) -> void:
	var sid = event.get("sid", null)
	var e = {
		"type": "fetch_task_result_return",
		"result": null,
		"status": "not_found",
	}
	if sid in self._succeeded_task:
		e["result"] = self._succeeded_task[sid]
		e["status"] = "succeeded"
		self._succeeded_task.erase(sid)
	if sid in self._failed_tasks:
		e["result"] = self._failed_tasks[sid]
		e["status"] = "failed"
		self._failed_tasks.erase(sid)
	if sid == null:
		e["status"] = "not_found"
	if "____id" in event:
		e["____id"] = event["____id"]
	self.send(socket, e)

func clear_task(socket: WebSocketPeer, event: Dictionary) -> void:
	var sid = event.get("sid", null)
	self.pop_task_all(sid)

func any_client_connected(socket: WebSocketPeer, event: Dictionary) -> void:
	var e = {
		"type": "ping_client",
	}
	var has_client := false
	for s in self._sockets:
		if s != socket:
			has_client = true
			break
		# if "____id" in event:
		# 	e["____id"] = event["____id"]
		# if self.send(s, e) != OK:
		# 	await self.on_recv
		# 	continue

	await self.get_tree().create_timer(0.2).timeout
	e = {
		"type": "any_client_connected_return",
		"status": null if not has_client else "ok",
	}
	self._alive_clients.clear()
	if "____id" in event:
		e["____id"] = event["____id"]
	self.send(socket, e)
