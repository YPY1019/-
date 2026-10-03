class_name Battle
extends RefCounted

## 一場戰鬥的規則。不碰畫面：收指令，吐出「事件清單」給畫面顯示。
##
## 進口：Battle.new(我方, 敵方)，我方是從 Adventurer.to_combatant() 來的。
## 出口：result() —— 勝負或撤退、剩多少血、打了幾回合。
##
## 每回合順序：敵人先擺出動作（描述）→ 玩家看描述選招 → 玩家先出手 → 敵人出手。
## 敵人下一個動作看它的習慣（EnemyData 的 habits），會受你這回合的應對影響。
## 程式寫成可以多人參戰；目前文字都是用「你」寫的，加同伴時要改。

var allies: Array[Combatant] = []
var enemies: Array[Combatant] = []
var round_no := 0
## "" = 還在打；win / lose / flee
var outcome := ""
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
		var known: bool = m["basic"] or (actor.adventurer != null and actor.adventurer.knows(id))
		list.append({"id": id, "name": m["name"], "desc": m["desc"], "basic": m["basic"], "known": known})
	return list


## choices：我方 Combatant -> {"move": 招式 id, "target": 敵方 Combatant}
func play_round(choices: Dictionary) -> Array:
	var ev := []
	ev.append(_ev("round", "第 %d 回合" % round_no))

	# 1. 我方先出手
	var done := {}
	for ally in allies:
		if not ally.is_alive() or not choices.has(ally):
			continue
		var move_id: String = choices[ally]["move"]
		var target: Combatant = choices[ally].get("target")
		if target == null or not target.is_alive():
			target = _first_alive(enemies)
		done[ally] = {"move": move_id, "bad": ally.bad_position}
		_resolve_offense(ally, move_id, target, ev)

	# 2. 敵人出手
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var target: Combatant = enemy.intent["target"]
		enemy.last_player_move = done[target]["move"] if done.has(target) else ""
		var power: float = MoveData.INTENT_POWER[enemy.intent["type"]]
		if power <= 0.0 or target == null or not target.is_alive():
			continue
		if enemy.charged:
			power *= EnemyData.CHARGE_MULT
			enemy.charged = false
		var entry := {"take": 1.0, "hit": true}
		if done.has(target):
			entry = MoveData.entry(done[target]["move"], enemy.intent["type"], done[target]["bad"], enemy.big)
		var take: float = entry.get("take", 0.0)
		if take <= 0.0:
			continue
		if entry.get("hit", false):
			ev.append(_ev("action", enemy.fill(enemy.enemy_def["intents"][enemy.intent["type"]]["hit"])))
		if done.has(target) and done[target]["bad"]:
			take *= MoveData.BAD_POSITION_TAKE
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
	return {"outcome": outcome, "rounds": round_no, "hp": hero.hp, "max_hp": hero.max_hp}


# ---- 內部 ----

func _resolve_offense(ally: Combatant, move_id: String, target: Combatant, ev: Array) -> void:
	var m: Dictionary = MoveData.MOVES[move_id]
	var entry := MoveData.entry(move_id, target.intent["type"], ally.bad_position, target.big)
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
			target.forced_next = "tripped"
		"guard_broken":
			target.forced_next = "guard_broken"
		"smash_missed":
			target.forced_next = "smash_missed"

	ally.bad_position = m.get("bad_position", false)

	if not target.is_alive():
		ev.append(_ev("info", "%s倒下了。" % target.display_name))
	elif not target.raging and target.enemy_def.has("rage"):
		var rage: Dictionary = target.enemy_def["rage"]
		if target.hp < target.max_hp * rage["hp_below"]:
			target.raging = true
			ev.append(_ev("info", rage["text"]))


func _choose_intents(ev: Array) -> void:
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var next := _next_intent(enemy)
		var type: String = next["type"]
		var text: String = next["text"]
		if enemy.charged and MoveData.INTENT_POWER[type] > 0.0:
			text += enemy.enemy_def.get("charged_tell", "")
		enemy.intent = {"type": type, "text": text, "target": _random_alive(allies)}
		enemy.recent_intents.append(type)
		if enemy.recent_intents.size() > 2:
			enemy.recent_intents.pop_front()
		ev.append(_ev("tell", text))


## 依序：被逼出來的破綻 → 習慣 → 隨機
func _next_intent(enemy: Combatant) -> Dictionary:
	var d: Dictionary = enemy.enemy_def
	if enemy.forced_next != "":
		var cause := enemy.forced_next
		enemy.forced_next = ""
		return {"type": "opening", "text": enemy.fill(EnemyData.FORCED_OPENING[cause])}
	for h in d.get("habits", []):
		if not _habit_matches(enemy, h):
			continue
		if h.has("chance") and rng.randf() >= h["chance"]:
			continue
		if h.get("charge", false):
			enemy.charged = true
		var type: String = h["then"]
		return {"type": type, "text": h.get("tell", d["intents"][type]["tell"])}
	var type := _pick_intent(enemy)
	return {"type": type, "text": d["intents"][type]["tell"]}


func _habit_matches(enemy: Combatant, h: Dictionary) -> bool:
	var recent := enemy.recent_intents
	if h.has("last") and (recent.is_empty() or recent.back() != h["last"]):
		return false
	if h.has("last_seq"):
		var seq: Array = h["last_seq"]
		if recent.size() != seq.size():
			return false
		for i in seq.size():
			if recent[i] != seq[i]:
				return false
	if h.has("player") and not h["player"].has(enemy.last_player_move):
		return false
	if h.has("rage") and h["rage"] != enemy.raging:
		return false
	return true


## 依權重隨機挑，但同一招不連出三次
func _pick_intent(enemy: Combatant) -> String:
	var weights := {}
	if enemy.raging:
		weights = enemy.enemy_def["rage"]["weights"]
	else:
		for t in enemy.enemy_def["intents"]:
			weights[t] = enemy.enemy_def["intents"][t]["w"]
	var banned := ""
	if enemy.recent_intents.size() == 2 and enemy.recent_intents[0] == enemy.recent_intents[1]:
		banned = enemy.recent_intents[0]
	var total := 0
	for t in weights:
		if t != banned:
			total += weights[t]
	var roll := rng.randi_range(1, total)
	for t in weights:
		if t == banned or weights[t] <= 0:
			continue
		roll -= weights[t]
		if roll <= 0:
			return t
	return weights.keys()[0]


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
