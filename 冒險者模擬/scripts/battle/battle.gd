class_name Battle
extends RefCounted

## 一場戰鬥的規則。不碰畫面：收指令，吐出「事件清單」給畫面顯示。
##
## 進口：Battle.new(我方, 敵方)，我方是從 Adventurer.to_combatant() 來的。
## 出口：result() —— 勝負或撤退、剩多少血、漲了多少熟練度、打了幾回合。
##
## 每回合順序：敵人先擺出動作（描述）→ 玩家看描述選招 → 玩家先出手 → 敵人出手。
## 程式寫成可以多人參戰；目前文字都是用「你」寫的，加同伴時要改。

var allies: Array[Combatant] = []
var enemies: Array[Combatant] = []
var round_no := 0
## "" = 還在打；win / lose / flee
var outcome := ""
## 招式 id -> 這場漲了多少熟練度
var gains := {}
var rng := RandomNumberGenerator.new()


func _init(p_allies: Array, p_enemies: Array, rng_seed := -1) -> void:
	allies.assign(p_allies)
	enemies.assign(p_enemies)
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()


func start() -> Array:
	var ev := []
	for e in enemies:
		ev.append(_ev("info", "%s擋住了你的去路。" % e.display_name))
	round_no = 1
	_choose_intents(ev)
	return ev


## 給畫面用：這個人能選哪些招式
func move_options(actor: Combatant) -> Array:
	var list := []
	for id in MoveData.ORDER:
		var m: Dictionary = MoveData.MOVES[id]
		var opt := {"id": id, "name": m["name"], "desc": m["desc"], "basic": m["basic"], "known": true, "proficiency": -1}
		if not m["basic"]:
			opt["known"] = actor.adventurer != null and actor.adventurer.knows(id)
			if opt["known"]:
				opt["proficiency"] = actor.adventurer.proficiency[id]
		list.append(opt)
	return list


## choices：我方 Combatant -> {"move": 招式 id, "target": 敵方 Combatant}
func play_round(choices: Dictionary) -> Array:
	var ev := []
	ev.append(_ev("round", "第 %d 回合" % round_no))

	# 1. 我方先出手。成功與否只擲一次，挨打時也用同一個結果。
	var done := {}
	for ally in allies:
		if not ally.is_alive() or not choices.has(ally):
			continue
		var move_id: String = choices[ally]["move"]
		var target: Combatant = choices[ally].get("target")
		if target == null or not target.is_alive():
			target = _first_alive(enemies)
		var success := _roll_success(ally, move_id)
		done[ally] = {"move": move_id, "success": success, "bad": ally.bad_position}
		_resolve_offense(ally, move_id, success, target, ev)

	# 2. 敵人出手
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var power: float = MoveData.INTENT_POWER[enemy.intent["type"]]
		var target: Combatant = enemy.intent["target"]
		if power <= 0.0 or target == null or not target.is_alive():
			continue
		var entry := {"take": 1.0, "hit": true}
		if done.has(target):
			var d: Dictionary = done[target]
			entry = MoveData.entry(d["move"], enemy.intent["type"], d["success"], d["bad"], enemy.big)
		var take: float = entry.get("take", 0.0)
		if take <= 0.0:
			continue
		if entry.get("hit", false):
			ev.append(_ev("action", enemy.fill(enemy.enemy_def["intents"][enemy.intent["type"]]["hit"])))
		var dmg := maxi(1, roundi(enemy.atk * power * take * _spread()))
		target.hp = maxi(0, target.hp - dmg)
		ev.append(_ev("damage_in", "→ 你受到 %d 傷害" % dmg))

	# 3. 結束了沒
	if _all_dead(enemies):
		outcome = "win"
		ev.append(_ev("end", "你贏了！"))
	elif _all_dead(allies):
		outcome = "lose"
		ev.append(_ev("end", "你眼前一黑，倒了下去。"))
	else:
		for ally in done:
			if done[ally]["move"] == "flee":
				outcome = "flee"
				ev.append(_ev("end", "你逃掉了。"))
				break
	if outcome == "":
		round_no += 1
		_choose_intents(ev)
	return ev


func is_over() -> bool:
	return outcome != ""


func result() -> Dictionary:
	var hero := allies[0]
	return {
		"outcome": outcome,
		"rounds": round_no,
		"hp": hero.hp,
		"max_hp": hero.max_hp,
		"gains": gains.duplicate(),
	}


# ---- 內部 ----

func _resolve_offense(ally: Combatant, move_id: String, success: bool, target: Combatant, ev: Array) -> void:
	var m: Dictionary = MoveData.MOVES[move_id]
	var entry := MoveData.entry(move_id, target.intent["type"], success, ally.bad_position, target.big)
	if not success:
		ev.append(_ev("fail", "（%s還不熟練，失敗了）" % m["name"]))
	ev.append(_ev("action", target.fill(entry["text"])))

	var deal: float = entry.get("deal", 0.0)
	if deal > 0.0:
		var mult := deal * ally.atk * _spread()
		if not m.get("pierce", false):
			mult *= EnemyData.ARMOR_MULT[target.armor]
		if ally.bad_position:
			mult *= MoveData.BAD_POSITION_MULT
		var dmg := maxi(1, roundi(mult))
		target.hp = maxi(0, target.hp - dmg)
		ev.append(_ev("damage_out", "→ %s受到 %d 傷害" % [target.display_name, dmg]))

	match entry.get("effect", ""):
		"trip":
			if target.big:
				ev.append(_ev("action", target.fill("可是{name}太重了，晃都沒晃。")))
			else:
				target.forced_next = "tripped"
		"guard_broken":
			target.forced_next = "guard_broken"
		"smash_missed":
			target.forced_next = "smash_missed"

	ally.bad_position = success and m.get("bad_position", false)

	if not m["basic"] and ally.adventurer != null:
		var gain := MoveData.GAIN_FAIL
		if success:
			gain = MoveData.GAIN_GOOD if entry.get("good", false) else MoveData.GAIN_NORMAL
		var before: int = ally.adventurer.proficiency[move_id]
		var after := mini(100, before + gain)
		ally.adventurer.proficiency[move_id] = after
		gains[move_id] = gains.get(move_id, 0) + (after - before)

	if not target.is_alive():
		ev.append(_ev("info", "%s倒下了。" % target.display_name))


func _roll_success(actor: Combatant, move_id: String) -> bool:
	if MoveData.MOVES[move_id]["basic"] or actor.adventurer == null:
		return true
	var p: int = actor.adventurer.proficiency.get(move_id, 0)
	return rng.randf() < MoveData.success_chance(p)


func _choose_intents(ev: Array) -> void:
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var type := ""
		var text := ""
		if enemy.forced_next != "":
			type = "opening"
			text = enemy.fill(EnemyData.FORCED_OPENING[enemy.forced_next])
			enemy.forced_next = ""
		else:
			type = _pick_intent(enemy)
			text = enemy.enemy_def["intents"][type]["tell"]
		enemy.intent = {"type": type, "text": text, "target": _random_alive(allies)}
		enemy.recent_intents.append(type)
		if enemy.recent_intents.size() > 2:
			enemy.recent_intents.pop_front()
		ev.append(_ev("tell", text))


## 依權重隨機挑，但同一招不連出三次
func _pick_intent(enemy: Combatant) -> String:
	var intents: Dictionary = enemy.enemy_def["intents"]
	var banned := ""
	if enemy.recent_intents.size() == 2 and enemy.recent_intents[0] == enemy.recent_intents[1]:
		banned = enemy.recent_intents[0]
	var total := 0
	for t in intents:
		if t != banned:
			total += intents[t]["w"]
	var roll := rng.randi_range(1, total)
	for t in intents:
		if t == banned:
			continue
		roll -= intents[t]["w"]
		if roll <= 0:
			return t
	return intents.keys()[0]


func _spread() -> float:
	return rng.randf_range(0.85, 1.15)


func _first_alive(list: Array[Combatant]) -> Combatant:
	for c in list:
		if c.is_alive():
			return c
	return null


func _random_alive(list: Array[Combatant]) -> Combatant:
	var alive := list.filter(func(c): return c.is_alive())
	if alive.is_empty():
		return null
	return alive[rng.randi_range(0, alive.size() - 1)]


func _all_dead(list: Array[Combatant]) -> bool:
	return list.all(func(c): return not c.is_alive())


func _ev(kind: String, text: String) -> Dictionary:
	return {"kind": kind, "text": text}
