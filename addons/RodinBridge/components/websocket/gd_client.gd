@tool
class_name GDClient extends Node

var ws: RBWSClient = null
var ws_server: RBWSServer = null

func _ready() -> void:
	var server_type = RBWSServer.ServerType.PLUGIN
	if RBUtils.in_game(self):
		server_type = RBWSServer.ServerType.GAME
	if RBUtils.in_plugin(self):
		server_type = RBWSServer.ServerType.PLUGIN
	var ws: RBWSClient = RBWSClient.get_client_pool(server_type)
	var ws_server: RBWSServer = RBWSServer.get_server_pool(server_type)
	self.ws = ws
	self.ws_server = ws_server

	if self.ws.is_inside_tree():
		return
	self.get_tree().root.add_child(self.ws)

func ws_ready() -> bool:
	return self.ws.is_ws_connected and self.ws.is_ws_ready

func ensure_connect() -> bool:
	if not self.ws_ready():
		self.try_connect()
	return self.ws_ready()

func try_connect() -> void:
	if not self.ws_server.launched:
		return
	if self.ws_ready():
		return
	self.ws.port = self.ws_server.port
	self.ws.host = self.ws_server.host
	self.ws.try_connect()

func submit_task(data: Dictionary, id: String) -> bool:
	if not self.ensure_connect():
		printerr("Rodin: 服务未就绪")
		return false
	var event = {
		"type": "submit_task",
		"sid": id,
		"data": data,
	}
	self.ws.send(event)
	return true

func skip_task(id: String) -> void:
	if not self.ensure_connect():
		printerr("Rodin: 服务未就绪")
		return
	
	var event = {
		"type": "skip_task",
		"sid": id,
	}
	print("任务[%s] -> skip_task" % id)
	self.ws.send(event)

func query_task_status(id: String) -> String:
	if not self.ensure_connect():
		printerr("Rodin: 服务未就绪")
		return ""

	var event = {
		"type": "query_task_status",
		"sid": id,
	}
	var res = await self.ws.send_and_recv_dict(event)
	return res.get("status", "error")

	# self.ws.send(event)
	# await self.ws.on_recv
	# var res = self.ws.consume_dict()
	# return res.get("status", "error")

func fetch_task_result(id: String) -> Dictionary:
	if not self.ensure_connect():
		printerr("Rodin: 服务未就绪")
		return {}
	
	var event = {
		"type": "fetch_task_result",
		"sid": id,
	}
	var result = await self.ws.send_and_recv_dict(event)
	return result
	# self.ws.send(event)
	# await self.ws.on_recv
	# return self.ws.consume_message()

func clear_task(id: String) -> void:
	if not self.ensure_connect():
		printerr("Rodin: 服务未就绪")
		return
	var event = {
		"type": "clear_task",
		"sid": id,
	}
	self.ws.send(event)
	
func any_client_connected() -> bool:
	if not self.ensure_connect():
		return false
	var event := {
		"type": "any_client_connected"
	}
	var res = await self.ws.send_and_recv_dict(event)
	return res.get("status", "error") == "ok"

	# self.ws.send(event)
	# await self.ws.on_recv # 如何保证时效性???
	# var res := self.ws.consume_dict()
	# return res.get("status", "error") == "ok"
