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
var traits: Array = []
var weapon := ""
var guard_item := ""

## 敵人資料（敵人才有）
var enemy_def := {}
## 冒險者本人（玩家方才有）
var adventurer: Adventurer

## ---- 玩家方 ----
## 這回合手上的招（抽到的 + 基本招）
var hand: Array[String] = []
## 這回合手上的招為什麼變少（給畫面看）
var hand_note := ""
## 下回合的狀態：off_balance 站不穩、blind 眼睛進沙、shaken 嚇到
var next_status: Array[String] = []
## 被抱住了
var held := false

## ---- 敵人 ----
## 這回合要做的事：{"action", "type", "phase": windup/strike/do/forced/hold, "text", "target"}
var intent := {}
## 蓄勢中的招，下回合打下來
var pending := ""
## 下回合被逼出來的破綻原因（trip 等），空字串 = 沒有
var forced_next := ""
## 正在抱住對手的招，空字串 = 沒有
var holding := ""
var hold_rounds := 0
var disarmed := false
var blinded := false
var raging := false
var recent_actions: Array[String] = []
## 對手上回合用的招（習慣會看這個）
var last_player_move := ""


static func from_enemy(id: String) -> Combatant:
	var d: Dictionary = EnemyData.ENEMIES[id]
	var c := Combatant.new()
	c.display_name = d["name"]
	c.side = Side.ENEMY
	c.max_hp = d["hp"]
	c.hp = d["hp"]
	c.atk = d["atk"]
	c.armor = d["armor"]
	c.traits = d["traits"]
	c.weapon = d["weapon"]
	c.guard_item = d["guard"]
	c.enemy_def = d
	return c


func is_alive() -> bool:
	return hp > 0


func action_def(id: String) -> Dictionary:
	return enemy_def["actions"][id]


func fill(text: String) -> String:
	return text.format({"name": display_name, "weapon": weapon, "guard": guard_item})
