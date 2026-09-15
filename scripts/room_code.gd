extends RefCounted
const DIGITS := "0123456789"

static func normalize(value: String) -> String:
	return value.strip_edges().replace(" ","").replace("-","")

static func valid_prefix(value: String) -> bool:
	if value.length()>6: return false
	for i in value.length():
		if not DIGITS.contains(value[i]): return false
	return true

static func valid(value: String) -> bool:
	var code := normalize(value)
	return code.length()==6 and valid_prefix(code)
