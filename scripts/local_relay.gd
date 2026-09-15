extends Node
const Rooms = preload("res://scripts/local_rooms.gd")
const Avatars = preload("res://scripts/avatar_catalog.gd")
const FILES := {"/":"index.html", "/controller.js":"controller.js", "/room-code.js":"room-code.js", "/avatars.js":"avatars.js", "/reward.css":"reward.css"}
const BOONS := ["stitch","spark","stride","charge","guard","mend"]
var server_url := ""
var browser_url := ""
var http_listener := TCPServer.new()
var socket_listener := TCPServer.new()
var http_clients: Array = []
var sockets: Dictionary = {}
var rooms = Rooms.new()
var serial := 0
var asset_cache: Dictionary = {}

func _ready() -> void: rooms.outgoing.connect(send)

func start_server() -> Dictionary:
	if http_listener.is_listening(): return {"url":server_url}
	# Separate native listeners keep HTTP serving small and let Godot handle the
	# WebSocket handshake/framing. The page discovers its socket port automatically.
	if http_listener.listen(8787,"0.0.0.0") != OK and http_listener.listen(0,"0.0.0.0") != OK:
		return {"error":"Не удалось открыть подключение телефонов."}
	var port := http_listener.get_local_port()
	if socket_listener.listen(port+1 if port<65535 else 0,"0.0.0.0") != OK and socket_listener.listen(0,"0.0.0.0") != OK:
		stop_server();return {"error":"Не удалось открыть управление телефонами."}
	browser_url="http://127.0.0.1:%d" % port
	server_url="ws://127.0.0.1:%d" % socket_listener.get_local_port()
	return {"url":server_url}

func _process(dt: float) -> void:
	while http_listener.is_connection_available():
		var tcp := http_listener.take_connection()
		if http_clients.size()>=24: tcp.disconnect_from_host();continue
		http_clients.append({"tcp":tcp,"request":PackedByteArray(),"response":PackedByteArray(),"sent":0,"age":0.0})
	for client in http_clients.duplicate():
		var tcp: StreamPeerTCP = client.tcp
		tcp.poll();client.age+=dt
		if tcp.get_status()!=StreamPeerTCP.STATUS_CONNECTED or client.age>10:
			tcp.disconnect_from_host();http_clients.erase(client);continue
		if client.response.is_empty():
			var available := tcp.get_available_bytes()
			if available>0:
				if client.request.size()+available>8192: tcp.disconnect_from_host();http_clients.erase(client);continue
				var packet := tcp.get_partial_data(available)
				if packet[0]!=OK: tcp.disconnect_from_host();http_clients.erase(client);continue
				client.request.append_array(packet[1])
				var request: String = client.request.get_string_from_utf8()
				if request.contains("\r\n\r\n"): client.response=http_response(request)
		else:
			var end := mini(client.sent+65536,client.response.size())
			var sent := tcp.put_partial_data(client.response.slice(client.sent,end))
			client.sent+=int(sent[1])
			if sent[0]!=OK or client.sent==client.response.size(): tcp.disconnect_from_host();http_clients.erase(client)
	while socket_listener.is_connection_available():
		var tcp := socket_listener.take_connection()
		if sockets.size()>=24:tcp.disconnect_from_host();continue
		var socket := WebSocketPeer.new()
		socket.inbound_buffer_size=524288;socket.outbound_buffer_size=524288;socket.heartbeat_interval=10.0
		if socket.accept_stream(tcp)!=OK:tcp.disconnect_from_host();continue
		serial+=1;rooms.add_peer(serial)
		sockets[serial]={"socket":socket,"age":0.0,"window":0.0,"messages":0}
	for id in sockets.keys():
		var client: Dictionary = sockets[id]
		var socket: WebSocketPeer = client.socket
		socket.poll();client.age+=dt;client.window+=dt
		if client.window>=1:client.window=0.0;client.messages=0
		if socket.get_ready_state()==WebSocketPeer.STATE_CONNECTING and client.age>10:socket.close(-1)
		if socket.get_ready_state()==WebSocketPeer.STATE_CLOSED:rooms.remove_peer(id);sockets.erase(id);continue
		while socket.get_ready_state()==WebSocketPeer.STATE_OPEN and socket.get_available_packet_count()>0:
			var packet := socket.get_packet();client.messages+=1
			if client.messages>100:socket.close(1008,"Too many messages");break
			if not socket.was_string_packet():continue
			var data = JSON.parse_string(packet.get_string_from_utf8())
			if data is Dictionary:rooms.receive(id,data)

func send(id: int, data: Dictionary) -> void:
	if not sockets.has(id):return
	var socket: WebSocketPeer = sockets[id].socket
	if socket.get_ready_state()==WebSocketPeer.STATE_OPEN and socket.get_current_outbound_buffered_amount()<262144:
		socket.send_text(JSON.stringify(data))

func http_response(request: String) -> PackedByteArray:
	var parts := request.get_slice("\r\n",0).split(" ")
	if parts.size()!=3 or parts[0]!="GET":return response(405,"text/plain","Method not allowed".to_utf8_buffer())
	var path: String = parts[1].get_slice("?",0)
	if path=="/connection-config.js":
		var config := {"websocketPort":socket_listener.get_local_port(),"controller":true}
		return response(200,"text/javascript",("globalThis.ORDO_CONNECTION="+JSON.stringify(config)+";").to_utf8_buffer())
	if path=="/health":return response(200,"application/json",JSON.stringify({"ok":true,"rooms":rooms.rooms.size()}).to_utf8_buffer())
	if asset_cache.has(path):return asset_cache[path]
	var resource := ""
	var mime := "text/plain"
	if FILES.has(path):
		resource="res://relay/public/"+FILES[path]
		mime="text/html" if path=="/" else ("text/css" if path.ends_with(".css") else "text/javascript")
	elif path in ["/icons/icon-32.png", "/icons/icon-180.png", "/icons/icon-192.png", "/icons/icon-512.png"]:
		resource="res://assets/icons/web/"+path.get_file();mime="image/png"
	elif path.begins_with("/avatars/") and path.ends_with(".png") and Avatars.IDS.has(path.trim_prefix("/avatars/").trim_suffix(".png")):
		resource="res://assets"+path;mime="image/png"
	elif path.begins_with("/boons/") and path.ends_with(".png") and BOONS.has(path.trim_prefix("/boons/").trim_suffix(".png")):
		resource="res://assets"+path;mime="image/png"
	if resource=="":return response(404,"text/plain","Not found".to_utf8_buffer())
	var body := PackedByteArray()
	if FileAccess.file_exists(resource):body=FileAccess.get_file_as_bytes(resource)
	elif mime=="image/png" and ResourceLoader.exists(resource):
		var texture: Texture2D=load(resource);body=texture.get_image().save_png_to_buffer()
	if body.is_empty():return response(404,"text/plain","Not found".to_utf8_buffer())
	var result := response(200,mime,body);asset_cache[path]=result;return result

func response(status: int, mime: String, body: PackedByteArray) -> PackedByteArray:
	var headers := "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n" % [status,"OK" if status==200 else "Error",mime,body.size()]
	var bytes := headers.to_utf8_buffer();bytes.append_array(body);return bytes

func stop_server() -> void:
	http_listener.stop();socket_listener.stop()
	for client in http_clients:client.tcp.disconnect_from_host()
	for client in sockets.values():client.socket.close(-1)
	http_clients.clear();sockets.clear();rooms.peers.clear();rooms.rooms.clear();asset_cache.clear()
	server_url="";browser_url=""

func _exit_tree() -> void:stop_server()
