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
## 境界（玩家方）：戰報照境界換寫法
var realm := 0
## 架勢（SchoolData.STANCE 的 id），空的是沒有。braced：剛擋下一招，下一劍比較重
var stance := ""
var braced := false

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


## 學來的招被挑中的權重（打法裡的一般出手大多是 15～40）
const MOVE_W := 18
const MOVE_W_ULT := 25


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
	if d.has("moves") or d.has("move_pool"):
		c.enemy_def = d.duplicate()
		var kinds: Array = d.get("kinds", [])
		var moves: Array = d.get("moves", []).duplicate()
		# 從 move_pool 隨機挑幾招：同一種對手，每次碰上的人會的不一樣
		var pool: Array = d.get("move_pool", []).duplicate()
		pool.shuffle()
		moves.append_array(pool.slice(0, d.get("pool_n", 0)))
		add_moves(c.enemy_def, moves, kinds[0] if not kinds.is_empty() else "")
	return c


## 世界上的人：招和戰報用他的打法（style），數值、血量、武器用他自己的。
## 對手打你多痛看招（打法），武器只帶來特效。
## place：在哪裡打（場景）。lethal = false：只是打傷他，倒下的句子換成沒死的
static func from_person(p: Person, place: String, lethal := true) -> Combatant:
	var c := from_enemy(p.style)
	var d: Dictionary = c.enemy_def.duplicate()
	d["title"] = p.title
	d["scene"] = MapData.PLACES[place]["scene"]
	# 打法資料的登場句是寫給那個有名字的人的；別人（外地來的、孩子）用一般的
	d["start"] = p.start_lines if not p.start_lines.is_empty() else ["{name}拔出{weapon}，擺好了架勢。", "{name}看著你，慢慢把{weapon}舉了起來。"]
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
	# 打法本身的出手，加上他自己會的招（打法資料裡的 moves 不算，那是給沒有名字的人用的）
	d["actions"] = EnemyData.ENEMIES[p.style]["actions"]
	add_moves(d, p.learned, WeaponData.get_def(p.weapon)["kind"])
	return c


## 世界上的人跟你用同一套招：他會的招（有 act 的、拿著的武器用得出來的）加進他的出手裡
static func add_moves(d: Dictionary, learned: Array, kind: String) -> void:
	var actions: Dictionary = d["actions"].duplicate()
	for id in learned:
		var m: Dictionary = MoveData.MOVES[id]
		var kinds: Array = m.get("weapons", [])
		if not m.has("act") or not (kinds.is_empty() or kinds.has(kind)):
			continue
		var a: Dictionary = m["act"].duplicate(true)
		a["move"] = id
		a["w"] = MOVE_W_ULT if m.get("ult", false) else MOVE_W
		if not a.has("stat"):
			a["stat"] = m["stat"]
		actions["m_" + id] = a
	d["actions"] = actions


func is_alive() -> bool:
	return hp > yield_hp and not fled


func action_def(id: String) -> Dictionary:
	return enemy_def["actions"][id]


func fill(text: String) -> String:
	return text.format({"name": display_name, "pron": pron, "weapon": weapon, "guard": guard_item})
