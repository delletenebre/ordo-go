extends SceneTree
const PhoneConnection = preload("res://scripts/phone_connection.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _init() -> void:
	var addresses := PackedStringArray(["127.0.0.1", "::1", "169.254.3.4", "10.10.5.37", "192.168.1.20", "10.10.5.37"])
	var local := PhoneConnection.describe("ws://127.0.0.1:8787/socket?token=private", addresses)
	check(local.local and local.urls == PackedStringArray(["http://10.10.5.37:8787", "http://192.168.1.20:8787"]), "Loopback becomes LAN addresses with the actual port, without duplicates or socket secrets")
	for loopback in ["localhost", "[::1]", "0.0.0.0"]:
		check(PhoneConnection.describe("ws://%s:8090" % loopback, addresses).urls[0] == "http://10.10.5.37:8090", "Local address preserves custom port")
	check(PhoneConnection.describe("wss://play.example.org/ws?token=private", addresses).urls == PackedStringArray(["https://play.example.org"]), "TLS domain uses HTTPS and drops WebSocket path")
	check(PhoneConnection.describe("ws://192.168.2.15:9000", addresses).urls == PackedStringArray(["http://192.168.2.15:9000"]), "A remote LAN server keeps its own IP instead of the TV address")
	check(PhoneConnection.describe("wss://[2001:db8::2]:8443", addresses).urls == PackedStringArray(["https://[2001:db8::2]:8443"]), "IPv6 origin retains brackets and port")
	check(PhoneConnection.describe("ws://localhost:8787", PackedStringArray(["127.0.0.1","::1"])).urls.is_empty(), "No usable LAN address never advertises loopback")
	check(PhoneConnection.describe("invalid", addresses).urls.is_empty(), "Invalid server has no invented phone URL")
	print("PHONE CONNECTION: failures=", failures)
	quit(1 if failures else 0)
