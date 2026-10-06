class_name Combatant
extends RefCounted

## 戰鬥中的一個人或怪物。戰鬥結束就丟掉。

enum Side { ALLY, ENEMY }

var display_name := ""
var side := Side.ENEMY
## true = 用冒險者會的招（玩家方）；false = 自動行動（敵人，之後的同伴）
var controlled := false
## true = 自動挑招（自動戰鬥試驗）：不抽招，會的招全部都能挑
var auto := false
## 打出去的傷害倍率（武器）
var attack_mult := 1.0
var max_hp := 1
var hp := 1
## 血量掉到這裡（含）就算倒下。木劍過招時不是 0
var yield_hp := 0
## 基礎數值 {"str", "agi"}。戰鬥時同一項跟同一項比
var stats := {}
var armor := "none"
var traits: Array = []
var weapon := ""
## 武器（WeaponData 的 id）和特效（fx）。有名的強者拿著稀有的劍，打你時也會發動
var weapon_id := ""
var weapon_fx := ""
var guard_item := ""
## 他／牠
var pron := "牠"

## 敵人資料和 id（敵人才有）
var enemy_id := ""
var enemy_def := {}
## 人（玩家方是你；敵方是世界上的人，怪物沒有）
var person: Person
## 老了身體掉了幾點：數值 -> 點數（只放有掉的）。戰報偶爾寫一句
var aged := {}
## 這場寫過幾句老了的樣子
var aged_said := 0
## 快死的徵兆有多明顯（0～1）：戰報偶爾寫喘、咳
var omen := 0.0

## ---- 玩家方 ----
## 這回合手上的招（抽到的 + 基本招）
var hand: Array[String] = []
## 這回合手上的招為什麼變少（給畫面看）
var hand_note := ""
## 下回合的狀態：off_balance 站不穩、blind 眼睛進沙、shaken 嚇到
var next_status: Array[String] = []
## 被抱住了
var held := false
## 這場用過的招（算基礎數值成長用）
var used: Array[String] = []
## 這場被敵人招牌招打中幾次：你偷學的招 id -> 次數
var sig_hits := {}

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
## 怕了、逃走了（算你贏）
var fled := false
## 寫過「快撐不住了」的樣子（之後少寫，不然每回合都一樣）
var said_dying := false
## 劍的特效在你身上發動過了（第一次砍中一定發動，你才知道它多可怕）
var fx_shown := false
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
	c.stats = {"str": d["str"], "agi": d["agi"]}
	c.armor = d["armor"]
	c.traits = d["traits"]
	c.weapon = d["weapon"]
	c.guard_item = d["guard"]
	c.pron = d.get("pron", "牠")
	if d.has("loot"):
		c.weapon_id = d["loot"]
		c.weapon_fx = WeaponData.fx(d["loot"])
	c.enemy_def = d
	c.enemy_id = id
	return c


## 世界上的人：招和戰報用他的打法（style），數值、血量、武器用他自己的。
## 對手打你多痛看招（打法），武器只帶來特效。
## place：在哪裡打（場景）。lethal = false：只是打傷他，倒下的句子換成沒死的
static func from_person(p: Person, place: String, lethal := true) -> Combatant:
	var c := from_enemy(p.style)
	var d: Dictionary = c.enemy_def.duplicate()
	d["title"] = p.title
	d["scene"] = MapData.PLACES[place]["scene"]
	if not p.start_lines.is_empty():
		d["start"] = p.start_lines
	if not lethal:
		d["win_text"] = "{name}倒在地上，撐了幾次都爬不起來。"
	d.erase("hide_hp")
	c.enemy_def = d
	c.person = p
	c.display_name = p.display_name
	c.pron = p.pron
	c.stats = p.body_stats()
	c.max_hp = p.max_hp()
	c.hp = p.hp
	var w := WeaponData.get_def(p.weapon)
	c.weapon = w.get("noun", w["name"])
	c.weapon_id = p.weapon
	c.weapon_fx = WeaponData.fx(p.weapon)
	return c


func is_alive() -> bool:
	return hp > yield_hp and not fled


func action_def(id: String) -> Dictionary:
	return enemy_def["actions"][id]


func fill(text: String) -> String:
	return text.format({"name": display_name, "pron": pron, "weapon": weapon, "guard": guard_item})
