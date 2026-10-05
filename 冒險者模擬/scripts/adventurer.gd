class_name Adventurer
extends RefCounted

## 冒險者本人：戰鬥以外也會存在的資料（數值、境界、血量、錢、會的招、跟師傅學到哪）。
## 戰鬥時轉成 Combatant 帶進去。

var display_name := "你"
var day := 1
var money := TownData.START_MONEY
var hp := 0

## 基礎數值和長到一半的經驗
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
## 打贏過的敵人
var beaten: Array[String] = []
## 每種敵人上次打的結果（委託板用）：敵人 id -> Town._fight_record() 的內容
var last_fights := {}
## 自動撤退線：血剩最大血量的這個比例（含）以下就撤。0 = 不自動撤
var retreat_at := 0.2
## 拿著的武器和買過的武器
var weapon := WeaponData.START
var owned_weapons: Array[String] = [WeaponData.START]
## 打倒食人魔了沒
var cleared := false


func _init() -> void:
	hp = max_hp()


## 血量 = 境界 ＋ 其他加減（之後的裝備、年紀、舊傷）
func max_hp() -> int:
	return GrowthData.REALM_HP[realm] + hp_bonus()


func hp_bonus() -> int:
	return 0


func cap() -> int:
	return GrowthData.CAPS[realm]


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


## 用比較高的那項算前中後段
func realm_text() -> String:
	return GrowthData.realm_text(realm, maxi(stats["str"], stats["agi"]))


func realm_color() -> String:
	return GrowthData.REALM_COLORS[realm]


func knows(move_id: String) -> bool:
	return MoveData.is_basic(move_id) or learned.has(move_id)


func learn(move_id: String) -> void:
	if not learned.has(move_id):
		learned.append(move_id)


## 加經驗，回傳長了幾點。到瓶頸就停住。
func add_exp(stat: String, amount: float) -> int:
	var gained := 0
	exp[stat] += amount
	while exp[stat] >= GrowthData.EXP_PER_POINT and not at_cap(stat):
		exp[stat] -= GrowthData.EXP_PER_POINT
		stats[stat] += 1
		gained += 1
	if at_cap(stat):
		exp[stat] = 0.0
	return gained


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
	c.stats = stats.duplicate()
	c.attack_mult = WeaponData.get_def(weapon)["power"]
	c.adventurer = self
	return c
