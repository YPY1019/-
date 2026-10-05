class_name Adventurer
extends RefCounted

## 冒險者本人：戰鬥以外也會存在的資料（年紀、數值、境界、血量、錢、會的招、跟師傅學到哪）。
## 戰鬥時轉成 Combatant 帶進去。

var display_name := "你"
## 出道以來過了幾個月（年紀、壽命從這裡算，見 LifeData）
var month := 0
## 這一生的壽命：從出道到死一共幾個月（看不到，見 LifeData）
var life_months := 0
## 壽命用完了
var dead := false
## 這一輩子發生的事（結局的生平用）：[{"month", "text"}]
var history: Array = []
var money := TownData.START_MONEY
var hp := 0

## 基礎數值（練出來的底子）和長到一半的經驗。老了以後現在的身體會比底子低，見 body()
var stats := {"str": GrowthData.START, "agi": GrowthData.START}
var exp := {"str": 0.0, "agi": 0.0}
## 境界（從 0 算）。境界就是瓶頸：衝破一次瓶頸就升一境
var realm := 0

## 學會的招式 id。基本招式不用學。
var learned: Array[String] = []
## 偷學：招式 id -> 被打中幾次
var steal_hits := {}
## 師傅認可到第幾階（第 1 階交學費就教，所以一開始是 1）
var approved_tier := 1
## 身上的秘笈（BookData）。讀完就學會裡面的招，書還留著
var books: Array[String] = []
## 師傅交代的事：劍譜拿回去給師傅看過了沒
var errand_reported := false
## 打贏過的敵人
var beaten: Array[String] = []
## 拿著的武器和身上有的武器（買的、從人身上拿的）
var weapon := WeaponData.START
var owned_weapons: Array[String] = [WeaponData.START]


func _init() -> void:
	hp = max_hp()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	life_months = LifeData.roll_life_months(rng)


# ---------- 年紀 ----------

func age() -> int:
	return LifeData.age_at(month)


func date_text() -> String:
	return LifeData.date_text(month)


## 離壽命用完還有幾個月
func months_left() -> int:
	return maxi(0, life_months - month)


## 這一項老了掉幾點
func decline(stat: String) -> int:
	return LifeData.decline(stat, age())


## 現在的身體：底子減掉老了掉的。戰鬥、成長、學招的門檻都看這個
func body(stat: String) -> int:
	return maxi(1, stats[stat] - decline(stat))


func body_stats() -> Dictionary:
	var out := {}
	for s in GrowthData.STATS:
		out[s] = body(s)
	return out


## 記一筆生平
func note(text: String) -> void:
	history.append({"month": month, "text": text})


# ---------- 血量、境界、數值 ----------

## 血量 = 境界 ＋ 其他加減（之後的裝備、年紀、舊傷）
func max_hp() -> int:
	return GrowthData.REALM_HP[realm] + hp_bonus()


func hp_bonus() -> int:
	return 0


func cap() -> int:
	return GrowthData.CAPS[realm]


## 瓶頸看底子
func at_cap(stat: String) -> bool:
	return stats[stat] >= cap()


## 有任何一項卡在瓶頸
func stuck() -> bool:
	return GrowthData.STATS.any(func(s): return at_cap(s))


func can_break_through() -> bool:
	return realm < GrowthData.CAPS.size() - 1


## 升一境：血量上限跳一截，身上的傷不變
func break_through() -> void:
	var old_max := max_hp()
	realm += 1
	hp += max_hp() - old_max


## 用比較高的那項算前中後段（看現在的身體）
func realm_text() -> String:
	return GrowthData.realm_text(realm, maxi(body("str"), body("agi")))


func realm_color() -> String:
	return GrowthData.REALM_COLORS[realm]


func knows(move_id: String) -> bool:
	return MoveData.is_basic(move_id) or learned.has(move_id)


func learn(move_id: String) -> void:
	if not learned.has(move_id):
		learned.append(move_id)


## 長 1 點要多少經驗（看境界）
func exp_need() -> float:
	return GrowthData.EXP_PER_POINT[realm]


## 加經驗，回傳長了幾點。到瓶頸就停住。
func add_exp(stat: String, amount: float) -> int:
	var gained := 0
	exp[stat] += amount
	while exp[stat] >= exp_need() and not at_cap(stat):
		exp[stat] -= exp_need()
		stats[stat] += 1
		gained += 1
	if at_cap(stat):
		exp[stat] = 0.0
	return gained


## 力量夠才拿得動。看底子：拿慣的劍，老了也還拿得動
func can_wield(weapon_id: String) -> bool:
	return stats["str"] >= WeaponData.get_def(weapon_id)["str"]


## full = 不管現在的血量，用滿血（木劍過招用）
func to_combatant(full := false) -> Combatant:
	var c := Combatant.new()
	c.display_name = display_name
	c.side = Combatant.Side.ALLY
	c.controlled = true
	# 自動戰鬥試驗：冒險者自己挑招
	c.auto = true
	c.max_hp = max_hp()
	c.hp = c.max_hp if full else hp
	c.stats = body_stats()
	for s in GrowthData.STATS:
		if decline(s) > 0:
			c.aged[s] = decline(s)
	c.attack_mult = WeaponData.get_def(weapon)["power"]
	c.weapon = WeaponData.get_def(weapon)["name"]
	c.weapon_fx = WeaponData.fx(weapon)
	c.adventurer = self
	return c
