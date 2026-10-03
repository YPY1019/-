class_name Adventurer
extends RefCounted

## 冒險者本人：戰鬥以外也會存在的資料（會的招式、熟練度）。
## 戰鬥時轉成 Combatant 帶進去。

var display_name := "你"
var max_hp := 100
var atk := 10
## 學會的招式 -> 熟練度 0～100。基本招式不用學，也沒有熟練度。
var proficiency := {}


func knows(move_id: String) -> bool:
	return MoveData.MOVES[move_id]["basic"] or proficiency.has(move_id)


func learn(move_id: String, p := 0) -> void:
	proficiency[move_id] = clampi(p, 0, 100)


func forget(move_id: String) -> void:
	proficiency.erase(move_id)


func to_combatant() -> Combatant:
	var c := Combatant.new()
	c.display_name = display_name
	c.side = Combatant.Side.ALLY
	c.controlled = true
	c.max_hp = max_hp
	c.hp = max_hp
	c.atk = atk
	c.adventurer = self
	return c
