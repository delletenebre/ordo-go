extends RefCounted
const IDS := ["manas","kanykei","bakai","semetei","aichurok","almambet","ilbirs","bugu","saikal","janyl","akshumkar","tulpar"]
const LABELS := ["Манас","Каныкей","Бакай","Семетей","Айчүрөк","Алмамбет","Илбирс","Бугу","Сайкал","Жаңыл Мырза","Акшумкар","Тулпар"]
const ART := [preload("res://assets/avatars/manas.png"),preload("res://assets/avatars/kanykei.png"),preload("res://assets/avatars/bakai.png"),preload("res://assets/avatars/semetei.png"),preload("res://assets/avatars/aichurok.png"),preload("res://assets/avatars/almambet.png"),preload("res://assets/avatars/ilbirs.png"),preload("res://assets/avatars/bugu.png"),preload("res://assets/avatars/saikal.png"),preload("res://assets/avatars/janyl.png"),preload("res://assets/avatars/akshumkar.png"),preload("res://assets/avatars/tulpar.png")]

static func index(id: String) -> int:
	return maxi(0,IDS.find(id))

static func title(id: String) -> String:
	return LABELS[index(id)]

static func texture(id: String) -> Texture2D:
	return ART[index(id)]
