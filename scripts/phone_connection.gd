extends RefCounted

# Accept the actual browser endpoint or a shared HTTP/WebSocket origin. Do not expose socket paths,
# query parameters or a loopback address that would point at the phone itself.
static func describe(server_url: String, local_addresses: PackedStringArray) -> Dictionary:
	var pattern := RegEx.new()
	pattern.compile("^(ws|wss|http|https)://(\\[[^\\]]+\\]|[^/:?#@]+)(:[0-9]+)?(?:[/?#]|$)")
	var matched := pattern.search(server_url.strip_edges())
	if matched == null: return {"urls":PackedStringArray(), "local":false}
	var scheme := "https://" if matched.get_string(1) in ["wss","https"] else "http://"
	var host := matched.get_string(2).to_lower()
	var port := matched.get_string(3)
	var local := host in ["localhost", "[::1]", "0.0.0.0", "[::]"] or host.begins_with("127.")
	if not local: return {"urls":PackedStringArray([scheme + host + port]), "local":false}
	var urls := PackedStringArray()
	for address in local_addresses:
		if not address.is_valid_ip_address() or address.contains(":"): continue
		if address.begins_with("127.") or address.begins_with("169.254.") or address == "0.0.0.0": continue
		var url := scheme + address + port
		if not urls.has(url): urls.append(url)
	return {"urls":urls, "local":true}
