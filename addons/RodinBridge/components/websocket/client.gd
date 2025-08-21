@tool
class_name RBWSClient extends Node

var host := "ws://localhost"
var port := 60080
var suffix := ""
var socket := WebSocketPeer.new()
var dict_pool: Dictionary = {}

var is_ws_connected := false
var is_ws_ready := false
var ws_closed := false

static func get_client_pool(key) ->  RBWSClient:
	return RBSettings.fetch("client").get(key)

static func set_client_pool(key, client) -> void:
	RBSettings.fetch("client")[key] = client

signal on_recv(data: String)

func _init(host="ws://localhost", port=60080, suffix="") -> void:
	self.host = host
	self.port = port
	self.suffix = suffix

func H() -> String:
	return "客户端[%s]: " % RBUtils.T()

func get_url() -> String:
	return "%s:%s%s" % [host, port, suffix]

func try_connect() -> bool:
	if self.ws_closed:
		return false
	if self.is_ws_connected:
		return true
	if not on_recv.is_connected(self.print_json):
		on_recv.connect(self.print_json)
	if not on_recv.is_connected(self.update_dict_pool):
		on_recv.connect(self.update_dict_pool)
	var url = self.get_url()
	print(self.H() + "🎯目标地址->%s" % url)
	if self.socket.connect_to_url(url) != OK:
		printerr(self.H() + "❌构建失败: ", url)
		# 连接失败.
		if Engine.is_editor_hint():
			self.set_process(false)
		return false
	else:
		print(self.H() + "✅构建成功->", url)
		# 连接成功.
		self.is_ws_connected = true
	return true

func update_dict_pool(message: String) -> void:
	var json = JSON.new()
	json.parse(message)
	if json.data == null or  "____id" not in json.data:
		return
	self.dict_pool[json.data["____id"]] = json.data

func consume_dict(id: String) -> Dictionary:
	if id not in self.dict_pool:
		return {}
	var data = self.dict_pool[id]
	self.dict_pool.erase(id)
	return data

func print_json(message: String) -> void:
	var dict = JSON.parse_string(message)
	var event_data = dict.get("data", null)
	if event_data == null:
		event_data = str(dict)
	var time = RBUtils.T()
	var text = self.H() + event_data
	# print(text)
	if self.has_node("%TextClient"):
		%TextClient.text += time + event_data + "\n"
	
func _process(_delta: float) -> void:
	if not self.is_ws_connected:
		return
	socket.poll()
	var state = socket.get_ready_state()
	match state:
		WebSocketPeer.STATE_CONNECTING:
			print(self.H() + "📡正在连接")
		WebSocketPeer.STATE_OPEN:
			if not self.is_ws_ready:
				print(self.H() + "✅连接成功")
				self.is_ws_ready = true
			while socket.get_available_packet_count():
				var data = socket.get_packet().get_string_from_utf8()
				on_recv.emit(data)
		WebSocketPeer.STATE_CLOSING:
			print(self.H() + "正在关闭")
		WebSocketPeer.STATE_CLOSED:
			self.is_ws_connected = false
			var code = socket.get_close_code()
			var reason = socket.get_close_reason()
			print(self.H() + "关闭, 代码：%d，原因 %s" % [code, reason])
			set_process(false)

func _on_button_ping_pressed() -> void:
	var data = {
		"type": "ping",
		"data": "来自客户端"
	}
	self.send(data)

func send(data: Dictionary) -> void:
	if not self.is_ws_ready:
		return
	var text = JSON.stringify(data)
	var bytes = JSON.stringify(data).to_ascii_buffer()
	socket.outbound_buffer_size = bytes.size()
	socket.send_text(text)
	# 分包发送.
	#var len = bytes.size()
	#var current = 0
	#return
	#while current < len:
		#var end = current + 1 << 20
		#if end > len:
			#end = len
		#socket.put_packet(bytes.slice(current, end))
		#current = end

func send_with_uid(data: Dictionary) -> String:
	var id = RBUtils.I()
	data["____id"] = id
	self.send(data)
	return id

func send_and_recv_dict(data: Dictionary, timeout: float = 2) -> Dictionary:
	timeout = max(0.1, timeout) * 1000
	var ts = Time.get_ticks_msec()
	var id = self.send_with_uid(data)
	while true:
		await self.on_recv
		var message = self.consume_dict(id)
		if message:
			return message
		if Time.get_ticks_msec() - ts > timeout:
			return {}
	return {}

func _exit_tree() -> void:
	socket.close()
