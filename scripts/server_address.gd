extends RefCounted

static func normalize(value: String) -> String:
	var address := value.strip_edges().to_lower()
	for prefix in ["wss://", "ws://", "https://", "http://"]:
		if address.begins_with(prefix):
			address = address.trim_prefix(prefix)
			break
	return address.trim_suffix("/")

static func valid(value: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^(\\[[0-9a-f:]+\\]|[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?)(?::([0-9]{1,5}))?$")
	var matched := pattern.search(value)
	if matched == null: return false
	var host := matched.get_string(1)
	if host.begins_with("[") and not host.substr(1, host.length()-2).is_valid_ip_address(): return false
	var port := matched.get_string(2)
	return port.is_empty() or (int(port)>0 and int(port)<=65535)

static func candidates(value: String) -> PackedStringArray:
	var address := normalize(value)
	if not valid(address): return PackedStringArray()
	return PackedStringArray(["wss://" + address, "ws://" + address])
