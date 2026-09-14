class_name OrdoCatalog
extends RefCounted

const COLORS = [Color("43cfff"), Color("ffc65c"), Color("58e0a0"), Color("ff6d78")]
const NAMES = ["ТАРАН", "СТРАЖ", "ВЕТЕР", "ИСКРА"]
const SYMBOLS = ["△", "⬡", "◇", "○"]
const ABILITIES = ["Двойной удар", "Защитный купол", "Порыв ветра", "Взрыв при ударе"]
const WAVE_NAMES = ["Шорох в шерсти", "Непрошеные гости", "Хранитель перевала", "Холодные нити", "Танец мотыльков", "Белая пряха", "Пепельный караван", "Последний очаг", "Пожиратель солнца"]
const ENEMIES = {
	"coal": {"name": "Уголёк", "hp": 1, "radius": 0.34, "mass": 0.7, "speed": 2.3, "color": "333341"},
	"brute": {"name": "Камнелоб", "hp": 3, "radius": 0.49, "mass": 2.2, "speed": 1.45, "color": "635751"},
	"hopper": {"name": "Прыгун", "hp": 2, "radius": 0.34, "mass": 0.8, "speed": 2.5, "color": "665385"},
	"frost": {"name": "Иней", "hp": 2, "radius": 0.38, "mass": 1.0, "speed": 1.7, "color": "679caa"},
	"moth": {"name": "Моль", "hp": 1, "radius": 0.29, "mass": 0.5, "speed": 3.0, "color": "c1a57d"},
	"ram": {"name": "ХРАНИТЕЛЬ ПЕРЕВАЛА", "hp": 12, "radius": 0.82, "mass": 5.0, "speed": 2.5, "color": "76635a"},
	"weaver": {"name": "БЕЛАЯ ПРЯХА", "hp": 15, "radius": 0.85, "mass": 4.0, "speed": 1.6, "color": "9ca9b1"},
	"eater": {"name": "ПОЖИРАТЕЛЬ СОЛНЦА", "hp": 20, "radius": 1.0, "mass": 6.0, "speed": 2.1, "color": "492d41"},
}
const BOONS = {
	"stitch": {"name": "Крепкий шов", "text": "+1 к максимальному здоровью. Лечит 1."},
	"spark": {"name": "Жаркий уголь", "text": "+1 урон сильного столкновения."},
	"stride": {"name": "Попутный ветер", "text": "+15% к скорости броска."},
	"charge": {"name": "Запасная нить", "text": "+1 заряд способности в каждой волне."},
	"guard": {"name": "Стёганый панцирь", "text": "Блокирует первый урон каждой волны."},
	"mend": {"name": "Тёплый очаг", "text": "Восстанавливает 2 здоровья огня."},
}

static func wave_spec(wave: int, players: int, difficulty: int) -> Dictionary:
	var count := maxi(2, 2 + wave + (players - 1) * 2 + difficulty)
	var kinds: Array = []
	for i in count:
		var kind := "coal"
		if wave >= 2 and i % 4 == 1: kind = "brute"
		if wave >= 2 and i % 4 == 2: kind = "hopper"
		if wave >= 4 and i % 5 == 3: kind = "frost"
		if wave >= 5 and i % 5 == 4: kind = "moth"
		kinds.append(kind)
	var boss := ""
	if wave == 3: boss = "ram"
	if wave == 6: boss = "weaver"
	if wave == 9: boss = "eater"
	if not boss.is_empty(): kinds = kinds.slice(0, maxi(2, players + difficulty))
	return {"kinds": kinds, "boss": boss, "boss_bonus": 4 * (players - 1) + 3 * difficulty, "planning": [30.0, 24.0, 18.0][difficulty]}
