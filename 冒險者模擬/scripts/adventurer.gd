class_name Adventurer
extends RefCounted

## 冒險者本人：戰鬥以外也會存在的資料（數值、血量、錢、會的招、跟師傅學到哪）。
## 戰鬥時轉成 Combatant 帶進去。

var display_name := "你"
var day := 1
var money := TownData.START_MONEY
var hp := 0

## 基礎數值和長到一半的經驗
var stats := {"str": GrowthData.START, "agi": GrowthData.START, "con": GrowthData.START}
var exp := {"str": 0.0, "agi": 0.0, "con": 0.0}
## 現在卡在第幾層瓶頸（GrowthData.CAPS 的索引）
var cap_tier := 0

## 學會的招式 id。基本招式不用學。
var learned: Array[String] = []
## 偷學：招式 id -> 被打中幾次
var steal_hits := {}
## 師傅認可到第幾階（第 1 階交學費就教，所以一開始是 1）
var approved_tier := 1
## 打贏過的敵人
var beaten: Array[String] = []
## 打倒食人魔了沒
var cleared := false


func _init() -> void:
	hp = max_hp()


func max_hp() -> int:
	return GrowthData.max_hp(stats["con"])


func cap() -> int:
	return GrowthData.CAPS[cap_tier]


func at_cap(stat: String) -> bool:
	return stats[stat] >= cap()


func power(stat: String) -> float:
	return GrowthData.power(stats[stat])


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
		if stat == "con":
			hp += GrowthData.HP_PER_CON
	if at_cap(stat):
		exp[stat] = 0.0
	return gained


## full = 不管現在的血量，用滿血（木劍過招用）
func to_combatant(full := false) -> Combatant:
	var c := Combatant.new()
	c.display_name = display_name
	c.side = Combatant.Side.ALLY
	c.controlled = true
	c.max_hp = max_hp()
	c.hp = c.max_hp if full else hp
	c.adventurer = self
	return c
