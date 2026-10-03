class_name Combatant
extends RefCounted

## 戰鬥中的一個人或怪物。戰鬥結束就丟掉。

enum Side { ALLY, ENEMY }

var display_name := ""
var side := Side.ENEMY
## true = 玩家下指令；false = 自動行動（敵人，之後的同伴）
var controlled := false
var max_hp := 1
var hp := 1
var atk := 0
var armor := "none"
var big := false
var weapon := ""
var guard_item := ""

## 敵人資料（敵人才有）
var enemy_def := {}
## 冒險者本人（玩家方才有）
var adventurer: Adventurer

## 這回合要做的動作：{"type": 動作類型, "text": 描述, "target": Combatant}
var intent := {}
## 下回合被逼出來的破綻原因（例如 tripped），空字串 = 沒有
var forced_next := ""
var recent_intents: Array[String] = []
## 對手上回合用的招（敵人的習慣會看這個）
var last_player_move := ""
## 發狂了（敵人）
var raging := false
## 蓄力中，下一次攻擊特別重（敵人）
var charged := false
## 閃避後位置不好
var bad_position := false


static func from_enemy(id: String) -> Combatant:
	var d: Dictionary = EnemyData.ENEMIES[id]
	var c := Combatant.new()
	c.display_name = d["name"]
	c.side = Side.ENEMY
	c.max_hp = d["hp"]
	c.hp = d["hp"]
	c.atk = d["atk"]
	c.armor = d["armor"]
	c.big = d["big"]
	c.weapon = d["weapon"]
	c.guard_item = d["guard"]
	c.enemy_def = d
	return c


func is_alive() -> bool:
	return hp > 0


func fill(text: String) -> String:
	return text.format({"name": display_name, "weapon": weapon, "guard": guard_item})
