class_name MapData
extends RefCounted

## 地圖：一座城（住的地方）和附近幾個地方，只有地名和路。只有資料和換算。
## 地名、遠近是 Claude 的建議，試玩時調。
## pos：畫在地圖上的位置（0～1，畫面再放大）。
## scene：在這裡開打時的場景（隨機一句）。
## 路（ROADS）：兩個地方之間走幾個月。沒有直接連的，就沿路走（走最近的路）。
## 城裡才能休養、學招、讀秘笈、買武器；其他地方只有人和怪物。

const HOME := "frost"

const PLACES := {
	"frost": {"name": "霜溪城", "pos": Vector2(0.47, 0.47), "city": true,
		"scene": ["城外的空地，城牆上有幾個衛兵在看。", "下雨的巷子，水從屋簷一直滴下來。", "清晨的廣場，噴水池邊一個人都沒有。"]},
	"pasture": {"name": "牧羊村", "pos": Vector2(0.2, 0.45),
		"scene": ["村外的草坡，羊群早就被趕回圈裡了。", "牧羊村的石牆邊，風很大。"]},
	"lodge": {"name": "獵人小屋", "pos": Vector2(0.24, 0.16),
		"scene": ["山腳的林子裡，獵人小屋只剩半面牆。", "松林裡很暗，地上鋪滿了松針。"]},
	"coast": {"name": "北岸漁村", "pos": Vector2(0.55, 0.07),
		"scene": ["燒焦的漁村，海風把灰吹得到處都是。", "海邊的礁石灘，浪一直打上來。"]},
	"old_wall": {"name": "舊城牆", "pos": Vector2(0.84, 0.2),
		"scene": ["舊城牆的斷口，石頭上長滿了青苔。", "倒塌的城樓下，風從破洞裡灌進來。"]},
	"wheat": {"name": "麥田鎮", "pos": Vector2(0.75, 0.45),
		"scene": ["麥田邊的小路，麥穗長得比人還高。", "鎮上的酒館後面，地上都是空酒桶。"]},
	"bridge": {"name": "石橋", "pos": Vector2(0.45, 0.7),
		"scene": ["石橋上，橋下的河水很急。", "橋頭的收費亭，木欄杆被砍斷了一半。"]},
	"south_road": {"name": "南山道", "pos": Vector2(0.22, 0.86),
		"scene": ["荒涼的山道，兩邊都是岩壁。", "官道旁的破廟前，地上還散著被搶過的行李。"]},
	"relay": {"name": "舊王家驛站", "pos": Vector2(0.78, 0.76),
		"scene": ["廢棄的驛站。屋頂破了一個大洞，夕陽照在地上。", "驛站的馬廄，乾草堆裡還有馬骨頭。"]},
	"fortress": {"name": "山口要塞", "pos": Vector2(0.55, 0.95),
		"scene": ["山口的舊要塞，城牆上的旗子早就燒掉了。", "要塞的中庭，地上的石板裂了好幾道縫。"]},
}

## [地方, 地方, 走幾個月]
const ROADS := [
	["frost", "pasture", 1],
	["frost", "bridge", 1],
	["frost", "wheat", 2],
	["frost", "lodge", 2],
	["pasture", "lodge", 1],
	["pasture", "south_road", 2],
	["bridge", "south_road", 1],
	["bridge", "relay", 2],
	["lodge", "coast", 2],
	["coast", "old_wall", 2],
	["wheat", "old_wall", 1],
	["wheat", "relay", 2],
	["relay", "fortress", 2],
	["south_road", "fortress", 2],
]


static func place_name(id: String) -> String:
	return PLACES[id]["name"]


static func is_city(id: String) -> bool:
	return PLACES[id].get("city", false)


## 從 a 走到 b 要幾個月（沿路走最近的）
static func distance(a: String, b: String) -> int:
	if a == b:
		return 0
	return _distances(a).get(b, 99)


## 從 a 出發，到每個地方最近要幾個月（小小的地圖，直接算）
static func _distances(from: String) -> Dictionary:
	var dist := {from: 0}
	var todo := [from]
	while not todo.is_empty():
		# 挑最近的那個往外走
		var best: String = todo[0]
		for p in todo:
			if dist[p] < dist[best]:
				best = p
		todo.erase(best)
		for r in ROADS:
			var other := ""
			if r[0] == best:
				other = r[1]
			elif r[1] == best:
				other = r[0]
			if other == "":
				continue
			var d: int = dist[best] + r[2]
			if not dist.has(other) or d < dist[other]:
				dist[other] = d
				if not todo.has(other):
					todo.append(other)
	return dist
