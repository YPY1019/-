class_name Battle
extends RefCounted

## 一場戰鬥的規則。不碰畫面：收指令，吐出「事件清單」給畫面顯示。
##
## 進口：Battle.new(我方, 敵方)，我方是從 Adventurer.to_combatant() 來的。
## 出口：result() —— 勝負或撤退、剩多少血、打了幾回合。
##
## 每回合：
##   1. 對手擺出招（描述）
##   2. 你從會的招裡「想到」幾招（抽招），加上永遠能用的基本招。剋制對手這招的，比較容易想到。
##   3. 你先出手，對手後出手。
## 對手的招可能讓你下回合想到的招變少（眼睛進沙、被嚇到、被抱住）。
## 程式寫成可以多人參戰；文字目前都用「你」寫，加同伴時要改。

## 每回合最多出現幾個選項。會的招不超過這個數，就全部出現（學了新招只會多一個選項，不會變弱）
const HAND_MAX := 5
## 剋制對手這招的，抽到的機會是一般的幾倍
const GOOD_WEIGHT := 3.0
## 用了等於白費的招，抽到的機會是一般的幾倍
const WASTED_WEIGHT := 0.2
## 對手眼睛進沙時，下一次攻擊打偏的機率
const BLIND_MISS_CHANCE := 0.6
## 被抱住時「掙扎」成功的機率
const STRUGGLE_CHANCE := 0.5
## 最多被抱住幾回合，之後對手會把你甩開
const HOLD_MAX := 2

const ATTACK_TYPES := ["sweep", "thrust", "smash", "grab", "trick", "roar", "hold"]

var allies: Array[Combatant] = []
var enemies: Array[Combatant] = []
var round_no := 0
## "" = 還在打；win / lose / flee
var outcome := ""
## true = 對手先擺招（你看得到牠要做什麼）；false = 雙方同時出手，出手後才知道
var telegraph := true
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
		ev.append(_ev("scene", e.fill(_pick(e.enemy_def["scene"]))))
		ev.append(_ev("action", e.fill(_pick(e.enemy_def["start"]))))
	round_no = 1
	_choose_intents(ev)
	_deal_hands()
	return ev


## 給畫面用：這回合手上的招
func hand_options(actor: Combatant) -> Array:
	var list := []
	for id in actor.hand:
		var m: Dictionary = MoveData.MOVES[id]
		list.append({"id": id, "name": m["name"], "desc": m["desc"], "basic": MoveData.is_basic(id)})
	return list


## 撤退不是招式，永遠可以選，除非被抱住
func can_flee(actor: Combatant) -> bool:
	return not actor.held


## choices：我方 Combatant -> {"move": 招式 id, "target": 敵方 Combatant}
func play_round(choices: Dictionary) -> Array:
	var ev := []
	ev.append(_ev("round", "第 %d 回合" % round_no))

	# 不擺招時，對手的動作在這時候才揭曉
	if not telegraph:
		for enemy in enemies:
			if enemy.is_alive():
				ev.append(_ev("action", enemy.intent["text"]))

	# 1. 我方先出手
	var done := {}
	for ally in allies:
		if not ally.is_alive() or not choices.has(ally):
			continue
		var target: Combatant = choices[ally].get("target")
		if target == null or not target.is_alive():
			target = _first_alive(enemies)
		var move_id: String = choices[ally]["move"]
		if not ally.hand.has(move_id) and not (move_id == MoveData.FLEE and can_flee(ally)):
			push_error("招式 %s 不能用" % move_id)
			move_id = ally.hand[0]
		done[ally] = _player_act(ally, move_id, target, ev)

	# 2. 對手出手
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var target: Combatant = enemy.intent["target"]
		var d: Dictionary = done.get(target, {})
		enemy.last_player_move = d.get("move", "")
		_enemy_act(enemy, target, d, ev)

	# 3. 結束了沒
	if _all_dead(enemies):
		outcome = "win"
		ev.append(_ev("end", "你贏了！"))
	elif _all_dead(allies):
		outcome = "lose"
		ev.append(_ev("end", "你眼前一黑，倒了下去。"))
	else:
		for ally in done:
			if done[ally]["move"] == "flee" and not ally.held:
				outcome = "flee"
				ev.append(_ev("end", "你逃掉了。"))
	if outcome == "":
		round_no += 1
		_choose_intents(ev)
		_deal_hands()
	return ev


func is_over() -> bool:
	return outcome != ""


func result() -> Dictionary:
	var hero := allies[0]
	return {"outcome": outcome, "rounds": round_no, "hp": hero.hp, "max_hp": hero.max_hp}


# ---- 抽招 ----

func _deal_hands() -> void:
	for ally in allies:
		if not ally.is_alive() or not ally.controlled:
			continue
		var notes := []
		ally.hand.clear()
		if ally.held:
			for id in MoveData.HELD:
				if MoveData.is_basic(id) or ally.adventurer.knows(id):
					ally.hand.append(id)
			notes.append("你被抱住了。")
		else:
			# 一般招和學來的招放在同一個池子裡抽，沒有永遠都在的招
			var pool: Array = MoveData.BASIC + ally.adventurer.learned
			var n := mini(pool.size(), HAND_MAX)
			if ally.next_status.has("off_balance"):
				n -= 1
				pool.erase("dodge")
				notes.append("你腳步還沒站穩，架勢也還沒收回來。")
			if ally.next_status.has("blind"):
				n = mini(n, 1)
				notes.append("你眼睛進了沙，什麼都看不清楚。")
			if ally.next_status.has("shaken"):
				n = 1
				pool = pool.filter(func(id): return MoveData.is_basic(id))
				notes.append("你被嚇得腦中一片空白。")
			ally.hand.assign(_draw(pool, maxi(n, 1), _first_alive(enemies)))
		ally.next_status.clear()
		ally.hand_note = "　".join(notes)


## 從會的招裡抽 n 招。至少一個攻擊類、一個防守類（抽得到的話），剩下的隨機。
func _draw(pool: Array, n: int, foe: Combatant) -> Array:
	var left := pool.duplicate()
	var out := []
	if n >= 2:
		for group in [MoveData.OFFENSE, MoveData.DEFENSE]:
			var id := _weighted_pick(left.filter(func(m): return group.has(m)), foe)
			if id != "":
				out.append(id)
				left.erase(id)
	while out.size() < n and not left.is_empty():
		var id := _weighted_pick(left, foe)
		out.append(id)
		left.erase(id)
	return out


## 剋制對手這招的比較容易出現；用了等於白費的（沒傷害、沒效果、又照樣挨打）很少出現。
## 這樣學了新招不會把有用的招擠掉。
func _weighted_pick(candidates: Array, foe: Combatant) -> String:
	if candidates.is_empty():
		return ""
	var weights := []
	var total := 0.0
	for id in candidates:
		var w := 1.0
		if foe != null and not MoveData.is_basic(id):
			# 擺招時看對手這一招；不擺招時看對手會的所有招（你只知道牠的路數）
			var types := [foe.intent["type"]]
			if not telegraph:
				types = _action_types(foe)
			var good := false
			var wasted := true
			for t in types:
				var e := MoveData.entry(id, t, foe.traits)
				good = good or e.get("good", false)
				var useless: bool = (e.get("deal", 0.0) <= 0.0 and not e.has("effect")) \
						or (MoveData.DEFENSE.has(id) and e.get("take", 0.0) >= 1.0)  # 防守招卻擋不住
				wasted = wasted and useless
			if good:
				w = GOOD_WEIGHT
			elif wasted:
				w = WASTED_WEIGHT
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates[-1]


func _action_types(foe: Combatant) -> Array:
	var types := []
	for id in foe.enemy_def["actions"]:
		var a: Dictionary = foe.enemy_def["actions"][id]
		var t: String = "windup" if a.get("windup", false) else a["type"]
		if not types.has(t):
			types.append(t)
		if a.get("windup", false) and not types.has(a["type"]):
			types.append(a["type"])
	return types


# ---- 玩家出手 ----

func _player_act(ally: Combatant, move_id: String, target: Combatant, ev: Array) -> Dictionary:
	var e: Dictionary
	if move_id == "struggle":
		if rng.randf() < STRUGGLE_CHANCE:
			e = {"take": 0.0, "effect": "escape", "text": ["你拼命一扭，掙脫了出來！", "你咬牙一掙，終於從{name}手裡脫身。"]}
		else:
			e = {"take": 1.0, "hit": true, "text": ["你掙扎了半天，還是被死死勒住。"]}
	else:
		e = MoveData.entry(move_id, target.intent["type"], target.traits)
	var m: Dictionary = MoveData.MOVES[move_id]
	ev.append(_ev("action", target.fill(_pick(e["text"]))))

	if e.get("deal", 0.0) > 0.0:
		_damage_enemy(target, ally.atk * e["deal"], m.get("pierce", false), ev)

	if target.is_alive():
		match e.get("effect", ""):
			"trip", "break", "interrupt", "stagger", "scare":
				target.forced_next = e["effect"]
			"disarm":
				target.disarmed = true
			"blind":
				target.blinded = true
			"escape":
				ally.held = false
				target.holding = ""
				target.hold_rounds = 0
	if m.has("self"):
		ally.next_status.append(m["self"])
	return {"move": move_id, "entry": e}


# ---- 對手出手 ----

func _enemy_act(enemy: Combatant, target: Combatant, d: Dictionary, ev: Array) -> void:
	var it := enemy.intent
	match it["phase"]:
		"forced":
			pass
		"windup":
			# 蓄勢沒被打斷的話，下回合打下來
			if enemy.forced_next == "":
				enemy.pending = it["action"]
		"hold":
			if enemy.holding == "":
				return  # 你這回合掙脫了
			var hold: Dictionary = enemy.action_def(enemy.holding)["hold"]
			_land(enemy, target, d, hold["power"], hold["hit"], "", ev)
			enemy.hold_rounds += 1
		_:
			var a := enemy.action_def(it["action"])
			if a.get("pickup", false):
				enemy.disarmed = false
			if ATTACK_TYPES.has(a["type"]):
				_land(enemy, target, d, a.get("power", 1.0), a["hit"], a.get("on_hit", ""), ev)


## 對手的攻擊打到你身上
func _land(enemy: Combatant, target: Combatant, d: Dictionary, power: float, hits: Array, on_hit: String, ev: Array) -> void:
	if target == null or not target.is_alive():
		return
	if enemy.blinded:
		enemy.blinded = false
		if rng.randf() < BLIND_MISS_CHANCE:
			ev.append(_ev("action", enemy.fill(_pick(EnemyData.BLIND_MISS))))
			return
	var e: Dictionary = d.get("entry", {})
	var take := 1.0
	var show_hit := true
	if e.has("take"):
		take = e["take"]
		show_hit = e.get("hit", false)
	if take <= 0.0:
		return
	if show_hit:
		ev.append(_ev("action", enemy.fill(_pick(hits))))
	if power > 0.0:
		var dmg := maxi(1, roundi(enemy.atk * power * take * _spread()))
		target.hp = maxi(0, target.hp - dmg)
		ev.append({"kind": "damage_in", "text": "你", "amount": dmg})
		var hurt := _hurt_line(target, dmg)
		if hurt != "":
			ev.append(_ev("pain", hurt))
	match on_hit:
		"":
			pass
		"held":
			target.held = true
			enemy.holding = enemy.intent["action"]
			enemy.hold_rounds = 0
		_:
			target.next_status.append(on_hit)


func _damage_enemy(enemy: Combatant, raw: float, pierce: bool, ev: Array) -> void:
	var mult := raw * _spread()
	if not pierce:
		mult *= EnemyData.ARMOR_MULT[enemy.armor]
	var dmg := maxi(1, roundi(mult))
	enemy.hp = maxi(0, enemy.hp - dmg)
	ev.append({"kind": "damage_out", "text": enemy.display_name, "amount": dmg})
	if not enemy.is_alive():
		ev.append(_ev("info", "%s倒下了。" % enemy.display_name))
		return
	var pain: Dictionary = enemy.enemy_def["pain"]
	if enemy.hp <= enemy.max_hp * 0.25:
		ev.append(_ev("pain", enemy.fill(_pick(pain["dying"]))))
	elif dmg >= 15:
		ev.append(_ev("pain", enemy.fill(_pick(pain["heavy"]))))
	elif rng.randf() < 0.5:
		ev.append(_ev("pain", enemy.fill(_pick(pain["light"]))))
	if not enemy.raging and enemy.enemy_def.has("rage"):
		var rage: Dictionary = enemy.enemy_def["rage"]
		if enemy.hp < enemy.max_hp * rage["hp_below"]:
			enemy.raging = true
			ev.append(_ev("info", rage["text"]))


# ---- 對手選下一招 ----

func _choose_intents(ev: Array) -> void:
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var target: Combatant = enemy.intent.get("target", null)
		if target == null or not target.is_alive():
			target = _random_alive(allies)
		var intent := {"target": target}

		if enemy.holding != "" and enemy.hold_rounds >= HOLD_MAX:
			ev.append(_ev("info", enemy.fill("{name}把你甩到一邊。")))
			enemy.holding = ""
			target.held = false

		if enemy.holding != "":
			var hold: Dictionary = enemy.action_def(enemy.holding)["hold"]
			intent.merge({"action": enemy.holding, "type": "hold", "phase": "hold", "text": enemy.fill(_pick(hold["tell"]))})
		elif enemy.forced_next != "":
			intent.merge({"action": "", "type": "opening", "phase": "forced",
				"text": enemy.fill(_pick(EnemyData.FORCED_OPENING[enemy.forced_next]))})
			enemy.forced_next = ""
			enemy.pending = ""
			_remember(enemy, "forced")
		elif enemy.pending != "":
			var a := enemy.action_def(enemy.pending)
			intent.merge({"action": enemy.pending, "type": a["type"], "phase": "strike", "text": enemy.fill(_pick(a["strike_tell"]))})
			_remember(enemy, enemy.pending)
			enemy.pending = ""
		else:
			var pick := _pick_action(enemy)
			var id: String = pick["id"]
			var a := enemy.action_def(id)
			var text: String = pick["tell"] if pick["tell"] != "" else _pick(a["tell"])
			if a.get("windup", false):
				intent.merge({"action": id, "type": "windup", "phase": "windup", "text": enemy.fill(text)})
			else:
				intent.merge({"action": id, "type": a["type"], "phase": "do", "text": enemy.fill(text)})
				_remember(enemy, id)
		enemy.intent = intent
		if telegraph:
			ev.append(_ev("tell", intent["text"]))


func _remember(enemy: Combatant, id: String) -> void:
	enemy.recent_actions.append(id)
	if enemy.recent_actions.size() > 2:
		enemy.recent_actions.pop_front()


func _available(enemy: Combatant, id: String) -> bool:
	var a := enemy.action_def(id)
	if enemy.disarmed:
		return not a.get("armed", false)
	return not a.get("unarmed", false)


## 先看習慣，沒有符合的才依權重隨機
func _pick_action(enemy: Combatant) -> Dictionary:
	var d: Dictionary = enemy.enemy_def
	for h in d.get("habits", []):
		if _habit_matches(enemy, h) and _available(enemy, h["then"]):
			if h.has("chance") and rng.randf() >= h["chance"]:
				continue
			return {"id": h["then"], "tell": h.get("tell", "")}

	var weights := {}
	for id in d["actions"]:
		var w: int = d["actions"][id]["w"]
		if enemy.raging and not enemy.disarmed:
			w = d["rage"]["weights"].get(id, 0)
		if w > 0 and _available(enemy, id):
			weights[id] = w
	# 同一招不連出三次（除非只剩它）
	var recent := enemy.recent_actions
	if recent.size() == 2 and recent[0] == recent[1] and weights.has(recent[0]) and weights.size() > 1:
		weights.erase(recent[0])
	if weights.is_empty():
		for id in d["actions"]:
			if _available(enemy, id):
				return {"id": id, "tell": ""}
	var total := 0
	for id in weights:
		total += weights[id]
	var roll := rng.randi_range(1, total)
	for id in weights:
		roll -= weights[id]
		if roll <= 0:
			return {"id": id, "tell": ""}
	return {"id": weights.keys()[0], "tell": ""}


func _habit_matches(enemy: Combatant, h: Dictionary) -> bool:
	var recent := enemy.recent_actions
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


# ---- 小工具 ----

func _pick(list: Array) -> String:
	return list[rng.randi_range(0, list.size() - 1)]


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


## 你受傷後的反應：快撐不住、重傷、或偶爾一句輕傷
func _hurt_line(target: Combatant, dmg: int) -> String:
	if target.hp <= 0:
		return ""
	if target.hp <= target.max_hp * 0.25:
		return _pick(MoveData.HURT["critical"])
	if dmg >= 20:
		return _pick(MoveData.HURT["heavy"])
	if rng.randf() < 0.4:
		return _pick(MoveData.HURT["light"])
	return ""
