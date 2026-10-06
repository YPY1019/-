class_name Battle
extends RefCounted

## 一場戰鬥的規則。不碰畫面：收指令，吐出「事件清單」給畫面顯示。
## 事件的 kind 是 "stat"、"intent"（對手一般出手的架勢）、或傷害事件的 note（雙方數值）：只寫進試玩紀錄，畫面不顯示。
##
## 進口：Battle.new(我方, 敵方)，我方是從 Person.to_combatant() 來的。
## 出口：result() —— 勝負或撤退、剩多少血、打了幾回合、用了哪些招、被招牌招打中幾次。
## 戰鬥本身不改 Person，打完由 Town 結算。
##
## 每回合：
##   1. 對手擺出招（描述）
##   2. 你從會的招裡「想到」幾招（抽招），加上永遠能用的基本招。剋制對手這招的，比較容易想到。
##   3. 你先出手，對手後出手。
## 對手的招可能讓你下回合想到的招變少（眼睛進沙、被嚇到、被抱住）。
## 基礎數值：同一項跟同一項比（見 GrowthData）。差太多招就失敗，差距也改變傷害。
## 程式寫成可以多人參戰；文字目前都用「你」寫，加同伴時要改。

## 每回合最多出現幾個選項。會的招不超過這個數，就全部出現（學了新招只會多一個選項，不會變弱）
const HAND_MAX := 5
## 剋制對手這招的，抽到的機會是一般的幾倍
const GOOD_WEIGHT := 3.0
## 用了等於白費的招，抽到的機會是一般的幾倍
const WASTED_WEIGHT := 0.2
## 對手眼睛進沙時，下一次攻擊打偏的機率
const BLIND_MISS_CHANCE := 0.6
## 最多被抱住幾回合，之後對手會把你甩開
const HOLD_MAX := 2
## 怕你的對手：血掉到這裡以下、每挨一下有這個機率逃走
const FEAR_FLEE_HP := 0.6
const FEAR_FLEE_CHANCE := 0.5
## 先吃虧：對手露出破綻時，你一般的砍法砍到他及時擋過來的兵器上的機率。
## 看你這招的數值比對手低多少：差距 0 時 GUARD_BASE，每低 1 點多 GUARD_PER_POINT
const GUARD_BASE := 0.25
const GUARD_PER_POINT := 0.1
const GUARD_MAX := 0.7
## 砍到兵器上，傷害剩這個比例
const GUARDED_DEAL := 0.35
## 你的反應句：對手那一項比你高很多、而且這一下掉了這個比例以上的血，才寫「被打飛」
const CRUSHED_HP := 0.15
## 「快撐不住」：血量剩這個比例以下（凜冬狂怒出得來，別人也是）
const LOW_HP := 0.35

const ATTACK_TYPES := ["sweep", "thrust", "smash", "grab", "trick", "roar", "hold"]
const END_TEXT := {"win": "你贏了！", "lose": "你眼前一黑，倒了下去。", "flee": "你逃掉了。", "survive": "你撐過去了。"}

var allies: Array[Combatant] = []
var enemies: Array[Combatant] = []
var round_no := 0
## 打滿幾回合就停（木劍過招用）。0 = 不限
var round_limit := 0
## "" = 還在打；win / lose / flee / survive（撐滿 round_limit）
var outcome := ""
var rng := RandomNumberGenerator.new()
## 整場的文字紀錄（試玩紀錄檔用）：發生的事，加上每回合有哪些選項、選了什麼
var record: Array[String] = []
## 這場每一句用過幾次（同一場不重複同一句，見 _pick）
var line_uses := {}


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
		if _afraid(e):
			ev.append(_ev("info", e.fill(_pick(e.enemy_def.get("fear", EnemyData.FEAR)))))
	round_no = 1
	_choose_intents(ev)
	_deal_hands()
	_record(ev)
	return ev


## 撤退不是招式，永遠可以選，除非被抱住
func can_flee(actor: Combatant) -> bool:
	return not actor.held


## choices：我方 Combatant -> {"move": 招式 id, "target": 敵方 Combatant}
func play_round(choices: Dictionary) -> Array:
	var ev := []
	ev.append(_ev("round", "第 %d 回合" % round_no))

	# 1. 我方先出手
	var done := {}
	var picks := []
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
		if ally.auto:
			picks.append("　〔%s〕" % MoveData.MOVES[move_id]["name"])
		else:
			picks.append("　〔選項：%s → 選了「%s」〕" % ["、".join(ally.hand.map(func(id): return MoveData.MOVES[id]["name"])), MoveData.MOVES[move_id]["name"]])
		done[ally] = _player_act(ally, move_id, target, ev)
		_show_age(ally, ev)

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
	elif _all_dead(allies):
		outcome = "lose"
	else:
		for ally in done:
			if done[ally]["move"] == "flee" and not ally.held:
				outcome = "flee"
		if outcome == "" and round_limit > 0 and round_no >= round_limit:
			outcome = "survive"
	if outcome != "":
		ev.append(_ev("end", _end_text()))
	else:
		round_no += 1
		_choose_intents(ev)
		_deal_hands()
	_record(ev.slice(0, 1))
	record.append_array(picks)
	_record(ev.slice(1))
	return ev


func _record(ev: Array) -> void:
	for e in ev:
		match e["kind"]:
			"round":
				record.append("── %s ──" % e["text"])
			"tell", "intent":
				record.append("▶ " + _named(e))
			"action":
				record.append(_named(e))
			"damage_in", "damage_out":
				record.append("　%s −%d（%s）" % [e["text"], e["amount"], e["note"]])
			_:
				record.append(e["text"])
	for ally in allies:
		if ally.controlled and ally.hand_note != "" and not ev.is_empty() and ev[-1]["kind"] in ["tell", "intent"]:
			record.append("　（%s）" % ally.hand_note)


func is_over() -> bool:
	return outcome != ""


func result() -> Dictionary:
	var hero := allies[0]
	return {"outcome": outcome, "rounds": round_no, "hp": hero.hp, "max_hp": hero.max_hp,
		"used": hero.used}


## 結束的句子，敵人資料裡有寫就用敵人的
func _end_text() -> String:
	if outcome == "win" and enemies[0].fled:
		return EnemyData.FLED_END
	var d: Dictionary = enemies[0].enemy_def
	return enemies[0].fill(d.get(outcome + "_text", END_TEXT[outcome]))


# ---- 抽招 ----

func _deal_hands() -> void:
	for ally in allies:
		if not ally.is_alive() or not ally.controlled:
			continue
		var notes := []
		ally.hand.clear()
		if ally.held:
			for id in MoveData.HELD:
				if MoveData.is_basic(id) or ally.person.knows(id):
					ally.hand.append(id)
			notes.append("你被抱住了。")
		else:
			# 一般招和學來的招放在同一個池子裡抽，沒有永遠都在的招
			var pool: Array = MoveData.BASIC + ally.person.learned
			# 收招慢的招（裂盾斬），用完下回合不能再用
			if not ally.used.is_empty() and MoveData.MOVES[ally.used[-1]].get("no_repeat", false):
				pool.erase(ally.used[-1])
			# 絕學要等時機才出得來（破綻、對手縮起來、重招砸下來）
			var foe := _first_alive(enemies)
			pool = pool.filter(func(id): return foe != null and ult_ready(foe, id, ally) and MoveData.usable(id, ally.weapon_id))
			# 自動戰鬥：會的招全部都能挑（學越多招越強）
			var n := pool.size() if ally.auto else mini(pool.size(), HAND_MAX)
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
			ally.hand.assign(_draw(ally, pool, maxi(n, 1), _first_alive(enemies)))
		ally.next_status.clear()
		ally.hand_note = "　".join(notes)


## 從會的招裡抽 n 招。至少一個攻擊類、一個防守類（抽得到的話），剩下的隨機。
func _draw(ally: Combatant, pool: Array, n: int, foe: Combatant) -> Array:
	var left := pool.duplicate()
	var out := []
	if n >= 2:
		for group in [MoveData.OFFENSE, MoveData.DEFENSE]:
			var id := _weighted_pick(ally, left.filter(func(m): return group.has(m)), foe)
			if id != "":
				out.append(id)
				left.erase(id)
	while out.size() < n and not left.is_empty():
		var id := _weighted_pick(ally, left, foe)
		out.append(id)
		left.erase(id)
	return out


## 剋制對手這招的比較容易出現；用了等於白費的（沒傷害、沒效果、又照樣挨打）很少出現。
## 這樣學了新招不會把有用的招擠掉。
func _weighted_pick(ally: Combatant, candidates: Array, foe: Combatant) -> String:
	if candidates.is_empty():
		return ""
	var weights := []
	var total := 0.0
	for id in candidates:
		var w := 1.0
		if foe != null and not MoveData.is_basic(id):
			var e := move_result(ally, id, foe, false)
			if e.get("good", false):
				w = GOOD_WEIGHT
			elif (e.get("deal", 0.0) <= 0.0 and not e.has("effect")) \
					or (MoveData.DEFENSE.has(id) and e.get("take", 0.0) >= 1.0):  # 防守招卻擋不住
				w = WASTED_WEIGHT
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates[-1]


# ---- 玩家出手 ----

func _player_act(ally: Combatant, move_id: String, target: Combatant, ev: Array) -> Dictionary:
	var m: Dictionary = MoveData.MOVES[move_id]
	var e := resolve(ally, move_id, target)
	# 先吃虧：對手露出破綻，還拿得起兵器擋，你的劍常常砍到兵器上（絕學不會）
	if not m.get("ult", false) and e.get("deal", 0.0) > 0.0 and big_opening(target) and can_parry(target) \
			and rng.randf() < guard_chance(ally, move_id, target):
		e = {"deal": e["deal"] * GUARDED_DEAL, "text": target.enemy_def["parry"]}
	if m.get("ult", false):
		# 絕學：先寫起手，喊出招名，再寫結果
		ev.append(_ev("action", target.fill(_pick(m["pre"]))))
		ev.append(_ev("ult", "「%s」！" % m["name"]))
	return _land_player(ally, move_id, e, target, ev)


## 老了：偶爾寫一句身體跟不上（不寫數值掉了幾點）。掉越多越常寫，一場最多幾句
## 快死了：偶爾寫一句喘、咳（徵兆越明顯越常寫，跟老了的句子一起算次數）
func _show_age(ally: Combatant, ev: Array) -> void:
	if ally.aged.is_empty() and ally.omen <= 0.0 or round_no < 2 or ally.aged_said >= LifeData.AGED_MAX_PER_FIGHT or _all_dead(enemies):
		return
	var total := 0
	var lines := []
	for s in ally.aged:
		total += ally.aged[s]
		lines.append_array(LifeData.AGED_LINES[s])
	var chance := minf(LifeData.AGED_CHANCE_MAX, total * LifeData.AGED_CHANCE_PER_POINT)
	if ally.omen > 0.0:
		chance = maxf(chance, ally.omen * LifeData.OMEN_BATTLE_CHANCE)
		lines = LifeData.OMEN_BATTLE_LINES.duplicate() if ally.omen > 0.5 or lines.is_empty() else lines + LifeData.OMEN_BATTLE_LINES
	if rng.randf() >= chance:
		return
	ally.aged_said += 1
	ev.append(_ev("action", _pick(lines)))


## 你這招的結果 e 寫出來、算傷害和效果
func _land_player(ally: Combatant, move_id: String, e: Dictionary, target: Combatant, ev: Array) -> Dictionary:
	var m: Dictionary = MoveData.MOVES[move_id]
	var line := _ev("action", target.fill(_pick(_text_for(ally, e))).replace("{my}", _noun(ally)))
	# 學來的招：戰報前面標出招名（絕學另外大字喊出來）
	if not MoveData.is_basic(move_id) and not m.get("ult", false):
		line["move"] = move_id
	ev.append(line)
	if e.get("failed", false):
		ev.append(_ev("stat", "（失敗。%s：%s）" % [GrowthData.NAMES[m["stat"]], _compare(ally, target, m["stat"])]))

	if move_id != MoveData.FLEE:
		ally.used.append(move_id)
	var deal: float = e.get("deal", 0.0)
	# 架勢：磐石劍位，剛擋下一招，這一劍借著那股勢子，比較重
	if ally.stance == "lionheart" and ally.braced and deal > 0.0 and MoveData.OFFENSE.has(move_id):
		deal *= SchoolData.STANCE["bonus"]
		ally.braced = false
		ev.append(_ev("action", target.fill(_pick(SchoolData.STANCE["lines"]))))
	# 狂戰士之血：血掉得越多，打得越重
	if ally.stance == "frostbear" and deal > 0.0:
		var st := SchoolData.stance_def("frostbear")
		if ally.hp <= ally.max_hp * st["hp_below"]:
			deal *= st["bonus"]
			if rng.randf() < 0.4:
				ev.append(_ev("action", target.fill(_pick(st["lines"]))))
	if deal > 0.0:
		_damage_enemy(ally, target, move_id, deal, ev)
	if ally.stance == "lionheart" and MoveData.DEFENSE.has(move_id) and not e.get("failed", false) and e.get("take", 1.0) < 1.0 \
			and target.intent.get("phase", "") in ["do", "strike", "hold"]:
		ally.braced = true

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


## 你這招的寫法：境界越高，剋制對手的招寫得越從容（有寫的才換）
func _text_for(ally: Combatant, e: Dictionary) -> Array:
	if ally.realm >= 4 and e.has("text_hi"):
		return e["text_hi"]
	if ally.realm >= 2 and e.has("text_mid"):
		return e["text_mid"]
	return e["text"]


## 這招碰上對手這回合的動作，結果是什麼：擲一次成不成功（失敗就換成失敗的版本，加上 failed）。
func resolve(actor: Combatant, move_id: String, foe: Combatant) -> Dictionary:
	return move_result(actor, move_id, foe, rng.randf() < fail_chance(actor, move_id, foe))


## 這招失敗的機率。招有效果（掃倒、破防、掙脫…）或能少挨打時，才有成不成功的問題；單純砍下去只差在痛不痛。
func fail_chance(actor: Combatant, move_id: String, foe: Combatant) -> float:
	var m: Dictionary = MoveData.MOVES[move_id]
	if not m.has("fail"):
		return 0.0
	var type: String = foe.intent["type"]
	var e := MoveData.entry(move_id, type, foe.traits)
	var can_fail: bool = e.has("effect") or (ATTACK_TYPES.has(type) and e.get("take", 1.0) < 1.0)
	if not can_fail:
		return 0.0
	return 1.0 - GrowthData.success_chance(gap(actor, foe, m["stat"]), m.get("odds", 0.0))


## 這招成功或失敗時的結果
func move_result(actor: Combatant, move_id: String, foe: Combatant, failed: bool) -> Dictionary:
	if failed:
		var e: Dictionary = MoveData.MOVES[move_id]["fail"].duplicate()
		e["failed"] = true
		return e
	return MoveData.entry(move_id, foe.intent["type"], foe.traits)


## 同一項比：出手的人 − 被打的人
func gap(attacker: Combatant, defender: Combatant, stat: String) -> int:
	return attacker.stats[stat] - defender.stats[stat]


## 你比對手高出多少，看對手最強的那一項
func outclass(hero: Combatant, foe: Combatant) -> int:
	var key := "str" if foe.stats["str"] >= foe.stats["agi"] else "agi"
	return hero.stats[key] - foe.stats[key]


## 對手比你弱太多，怕你（會逃）
func _afraid(foe: Combatant) -> bool:
	return not foe.enemy_def.get("no_flee", false) and outclass(allies[0], foe) >= GrowthData.OUTCLASS


## 對手這回合露出大破綻（絕學出得來）：被逼出來的破綻（嚇退不算），或自己露出來的（喘氣、卡住、撿武器）
func big_opening(foe: Combatant) -> bool:
	var it := foe.intent
	if it.get("phase", "") == "forced":
		return it.get("reason", "") != "scare"
	return it.get("type", "") == "opening"


## 這招現在出得來嗎（絕學要等時機，見 MoveData 的 when；其他招都出得來）
func ult_ready(foe: Combatant, move_id: String, ally: Combatant = null) -> bool:
	match MoveData.MOVES[move_id].get("when", ""):
		"low_hp":
			return ally != null and ally.hp <= ally.max_hp * LOW_HP
		"opening":
			return big_opening(foe)
		"closed":
			return foe.intent.get("type", "") == "guard" or foe.intent.get("phase", "") == "windup"
		"heavy":
			return foe.intent.get("phase", "") == "strike"
	return true


## 對手露出破綻時，還拿得起兵器擋你（沒被繳械、兵器沒卡住、資料裡有擋的寫法）
func can_parry(foe: Combatant) -> bool:
	if not foe.enemy_def.has("parry") or foe.disarmed:
		return false
	var id: String = foe.intent.get("action", "")
	return id == "" or not foe.action_def(id).get("no_parry", false)


## 先吃虧：對手露出破綻時，你這招砍到他兵器上的機率。你這招的數值比他低越多越常發生
func guard_chance(ally: Combatant, move_id: String, foe: Combatant) -> float:
	var g := gap(ally, foe, MoveData.MOVES[move_id]["stat"])
	return clampf(GUARD_BASE - g * GUARD_PER_POINT, 0.0, GUARD_MAX)


## 我方這招打出去的傷害（算了武器，還沒算盔甲和浮動）
func damage_out(ally: Combatant, move_id: String, foe: Combatant, deal: float) -> float:
	var m: Dictionary = MoveData.MOVES[move_id]
	var mult := GrowthData.damage_mult(gap(ally, foe, m["stat"]))
	if m.get("no_weak", false):
		mult = maxf(mult, 1.0)
	return GrowthData.BASE_DAMAGE * deal * ally.attack_mult * mult


## 對手這招打過來的傷害（還沒算你的應對和浮動）
func damage_in(enemy: Combatant, target: Combatant, power: float, stat: String) -> float:
	return GrowthData.BASE_DAMAGE * power * GrowthData.damage_mult(gap(enemy, target, stat))


## 「力量 12 對 18」：前面是你
func _compare(ally: Combatant, foe: Combatant, stat: String) -> String:
	return "你 %d，%s %d" % [ally.stats[stat], foe.display_name, foe.stats[stat]]


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
			_land(enemy, target, d, hold["power"], EnemyData.TYPE_STAT["hold"], hold["hit"], "", ev)
			enemy.hold_rounds += 1
		_:
			var a := enemy.action_def(it["action"])
			if a.get("pickup", false):
				enemy.disarmed = false
			if ATTACK_TYPES.has(a["type"]):
				_land(enemy, target, d, a.get("power", 1.0), EnemyData.action_stat(a, a["type"]), a["hit"], a.get("on_hit", ""), ev)


## 對手的攻擊打到你身上。stat：對手這招靠的數值，跟你的同一項比
func _land(enemy: Combatant, target: Combatant, d: Dictionary, power: float, stat: String, hits: Array, on_hit: String, ev: Array) -> void:
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
	# 碎門者：對手拿著它，你擋它常常擋不住一半
	if take < 1.0 and enemy.weapon_fx == "rend" and (not enemy.fx_shown or rng.randf() < WeaponData.FX_CHANCE):
		enemy.fx_shown = true
		take = (1.0 + take) / 2.0
		ev.append(_ev("fx", enemy.fill(_pick(WeaponData.FX_TEXT["rend"]["in"]))))
	# 差很多時換寫法：你高很多，打中了也不痛；對手高很多，一下就知道差多少
	var g := gap(enemy, target, stat)
	var shrug := power > 0.0 and g <= -GrowthData.OUTCLASS
	if show_hit:
		ev.append(_ev("action", enemy.fill(_pick(MoveData.HURT["shrug"] if shrug else hits))))
	if power > 0.0:
		var dmg := maxi(1, roundi(damage_in(enemy, target, power, stat) * take * _spread()))
		# 你拿著守夜人：常用護手把這一下架開
		if target.weapon_fx == "ward" and rng.randf() < WeaponData.FX_CHANCE:
			dmg = maxi(1, roundi(dmg * WeaponData.WARD_TAKE))
			ev.append(_ev("fx", enemy.fill(_pick(WeaponData.FX_TEXT["ward"]["out"]))))
		target.hp = maxi(0, target.hp - dmg)
		ev.append({"kind": "damage_in", "text": "你", "amount": dmg,
			"note": "%s %d 對 %d" % [GrowthData.NAMES[stat], target.stats[stat], enemy.stats[stat]]})
		var hurt := ""
		if g >= GrowthData.OUTCLASS and dmg >= target.max_hp * CRUSHED_HP and target.is_alive() and rng.randf() < 0.5:
			hurt = _pick(MoveData.HURT["crushed"])
		elif not shrug:
			hurt = _hurt_line(target, dmg)
		if hurt != "":
			ev.append(_ev("pain", hurt))
		_weapon_fx_in(enemy, target, dmg, ev)
	# 附加效果也看差距：你那一項比對手高越多，越常沒用
	if on_hit != "" and rng.randf() >= GrowthData.success_chance(gap(enemy, target, stat)):
		ev.append(_ev("action", enemy.fill(_pick(EnemyData.RESIST[on_hit]))))
		on_hit = ""
	match on_hit:
		"":
			pass
		"held":
			target.held = true
			enemy.holding = enemy.intent["action"]
			enemy.hold_rounds = 0
		_:
			target.next_status.append(on_hit)


## 對手拿著稀有的劍：砍中你時也會發動特效（你先挨過，才知道它多可怕）
func _weapon_fx_in(enemy: Combatant, target: Combatant, dmg: int, ev: Array) -> void:
	# 碎門者、守夜人不是砍中之後發動的（見 _land、_damage_enemy）
	if enemy.weapon_fx in ["", "rend", "ward"] or not target.is_alive():
		return
	# 第一次砍中一定發動
	if enemy.fx_shown and rng.randf() >= WeaponData.FX_CHANCE:
		return
	enemy.fx_shown = true
	ev.append(_ev("fx", enemy.fill(_pick(WeaponData.FX_TEXT[enemy.weapon_fx]["in"]))))
	match enemy.weapon_fx:
		"twin":
			var extra := WeaponData.twin_extra(dmg)
			target.hp = maxi(0, target.hp - extra)
			var src: String = WeaponData.get_def(enemy.weapon_id)["name"]
			ev.append({"kind": "damage_in", "text": "你", "amount": extra, "note": src, "src": src})
		"knell":
			if not target.next_status.has("off_balance"):
				target.next_status.append("off_balance")


## 你拿著稀有的劍：砍中對手時發動特效
func _weapon_fx_out(ally: Combatant, enemy: Combatant, dmg: int, ev: Array) -> void:
	if ally.weapon_fx in ["", "ward"] or not enemy.is_alive() or rng.randf() >= WeaponData.FX_CHANCE:
		return
	# 碎門者：砍在有甲的人身上才寫
	if ally.weapon_fx == "rend" and enemy.armor == "none":
		return
	var text: String = _pick(WeaponData.FX_TEXT[ally.weapon_fx]["out"])
	ev.append(_ev("fx", enemy.fill(text.replace("{weapon}", ally.weapon))))
	match ally.weapon_fx:
		"twin":
			var extra := WeaponData.twin_extra(dmg)
			enemy.hp = maxi(0, enemy.hp - extra)
			ev.append({"kind": "damage_out", "text": enemy.display_name, "amount": extra, "note": ally.weapon, "src": ally.weapon})
			if not enemy.is_alive():
				_fell(enemy, ev)
		"knell":
			# 下回合露出破綻（斷岳出得來）
			enemy.forced_next = "stagger"


func _damage_enemy(ally: Combatant, enemy: Combatant, move_id: String, deal: float, ev: Array) -> void:
	var m: Dictionary = MoveData.MOVES[move_id]
	var raw := damage_out(ally, move_id, enemy, deal) * _spread()
	# 碎門者砍得穿甲
	if not m.get("pierce", false) and ally.weapon_fx != "rend":
		raw *= EnemyData.ARMOR_MULT[enemy.armor]
	var dmg := maxi(1, roundi(raw))
	# 對手拿著守夜人：常用護手把你的劍架開（絕學架不開）
	if enemy.weapon_fx == "ward" and not m.get("ult", false) and (not enemy.fx_shown or rng.randf() < WeaponData.FX_CHANCE):
		enemy.fx_shown = true
		dmg = maxi(1, roundi(dmg * WeaponData.WARD_TAKE))
		ev.append(_ev("fx", enemy.fill(_pick(WeaponData.FX_TEXT["ward"]["in"]))))
	enemy.hp = maxi(0, enemy.hp - dmg)
	var s: String = m["stat"]
	ev.append({"kind": "damage_out", "text": enemy.display_name, "amount": dmg,
		"note": "%s %d 對 %d" % [GrowthData.NAMES[s], ally.stats[s], enemy.stats[s]]})
	if not enemy.is_alive():
		_fell(enemy, ev)
		return
	# 差很多時換寫法：你高很多，對手被打飛；對手高很多，砍中了也沒用
	var pain: Dictionary = enemy.enemy_def["pain"]
	var g := gap(ally, enemy, s)
	if enemy.hp <= enemy.max_hp * 0.25:
		# 快撐不住的樣子第一次一定寫，之後偶爾寫，不然每回合都一樣
		if not enemy.said_dying or rng.randf() < 0.3:
			ev.append(_ev("pain", enemy.fill(_pick(pain["dying"]))))
		enemy.said_dying = true
	elif g >= GrowthData.OUTCLASS and dmg >= 15:
		ev.append(_ev("pain", enemy.fill(_pick(EnemyData.OVERWHELMED))))
	elif g <= -GrowthData.OUTCLASS and dmg < 20:
		ev.append(_ev("pain", enemy.fill(_pick(EnemyData.UNFAZED))))
	elif dmg >= 15:
		# 每下都寫會很吵：重傷常寫、輕傷偶爾寫
		if rng.randf() < 0.6:
			ev.append(_ev("pain", enemy.fill(_pick(pain["heavy"]))))
	elif rng.randf() < 0.35:
		ev.append(_ev("pain", enemy.fill(_pick(pain["light"]))))
	# 絕學砍中不會再震出破綻（不然喪鐘＋北境裁決會一直接下去）
	if not (m.get("ult", false) and ally.weapon_fx == "knell"):
		_weapon_fx_out(ally, enemy, dmg, ev)
	if not enemy.is_alive():
		return
	# 比你弱太多的對手，挨痛了會逃
	if _afraid(enemy) and enemy.hp < enemy.max_hp * FEAR_FLEE_HP and rng.randf() < FEAR_FLEE_CHANCE:
		enemy.fled = true
		ev.append(_ev("info", enemy.fill(_pick(enemy.enemy_def.get("fear_flee", EnemyData.FEAR_FLEE)))))
		return
	if not enemy.raging and enemy.enemy_def.has("rage"):
		var rage: Dictionary = enemy.enemy_def["rage"]
		if enemy.hp < enemy.max_hp * rage["hp_below"]:
			enemy.raging = true
			ev.append(_ev("info", enemy.fill(rage["text"])))


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
			intent.merge({"action": "", "type": "opening", "phase": "forced", "reason": enemy.forced_next,
				"text":enemy.fill(_pick(EnemyData.FORCED_OPENING[enemy.forced_next]))})
			enemy.forced_next = ""
			enemy.pending = ""
			_remember(enemy, "forced")
		elif enemy.pending != "":
			var a := enemy.action_def(enemy.pending)
			intent.merge({"action": enemy.pending, "type": a["type"], "phase": "strike", "text": enemy.fill(_pick(a["strike_tell"]))})
			_remember(enemy, enemy.pending)
			enemy.pending = ""
		else:
			var pick := _pick_action(enemy, target)
			var id: String = pick["id"]
			var a := enemy.action_def(id)
			var text: String = pick["tell"] if pick["tell"] != "" else _pick(a["tell"])
			if a.get("windup", false):
				intent.merge({"action": id, "type": "windup", "phase": "windup", "text": enemy.fill(text)})
			else:
				intent.merge({"action": id, "type": a["type"], "phase": "do", "text": enemy.fill(text)})
				_remember(enemy, id)
		enemy.intent = intent
		# 一般的出手不單獨寫一行（只進試玩紀錄）；蓄勢、破綻、被抱住、對手用出學來的招，才寫進戰報
		var move: String = enemy.action_def(intent["action"]).get("move", "") if intent.get("action", "") != "" and intent["phase"] in ["do", "windup"] else ""
		var quiet: bool = intent["phase"] == "do" and intent["type"] != "opening" and move == ""
		var line := _ev("intent" if quiet else "tell", intent["text"])
		if move != "":
			line["move"] = move
			if enemy.person != null and allies[0].person != null:
				allies[0].person.saw_move(enemy.person.id, move)
		ev.append(line)


func _remember(enemy: Combatant, id: String) -> void:
	enemy.recent_actions.append(id)
	if enemy.recent_actions.size() > 2:
		enemy.recent_actions.pop_front()


func _available(enemy: Combatant, id: String, target: Combatant = null) -> bool:
	var a := enemy.action_def(id)
	match a.get("cond", ""):
		"low_hp":
			if enemy.hp > enemy.max_hp * LOW_HP:
				return false
		"foe_open":
			if target == null or not (target.held or target.next_status.has("off_balance") or target.next_status.has("blind")):
				return false
	if enemy.disarmed:
		return not a.get("armed", false)
	return not a.get("unarmed", false)


## 先看習慣，沒有符合的才依權重隨機
func _pick_action(enemy: Combatant, target: Combatant = null) -> Dictionary:
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
		if enemy.raging and not enemy.disarmed and d["actions"][id].has("move"):
			w = d["actions"][id]["w"]  # 發狂也還是會用學來的招
		if w > 0 and _available(enemy, id, target):
			weights[id] = w
	# 同一招不連出三次（除非只剩它）
	var recent := enemy.recent_actions
	if recent.size() == 2 and recent[0] == recent[1] and weights.has(recent[0]) and weights.size() > 1:
		weights.erase(recent[0])
	if weights.is_empty():
		for id in d["actions"]:
			if _available(enemy, id, target) and not d["actions"][id].has("cond"):
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

## 隨機挑一句。同一場先挑還沒用過（用得最少）的，全部用過才會重複
func _pick(list: Array) -> String:
	var least := INF
	for s in list:
		least = minf(least, line_uses.get(s, 0))
	var fresh := list.filter(func(s): return line_uses.get(s, 0) == least)
	var s: String = fresh[rng.randi_range(0, fresh.size() - 1)]
	line_uses[s] = line_uses.get(s, 0) + 1
	return s


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


## 自己武器的叫法（斧頭、大刀…）
func _noun(c: Combatant) -> String:
	if c.weapon_id == "":
		return c.weapon
	var w := WeaponData.get_def(c.weapon_id)
	return w.get("noun", w["name"])


## 試玩紀錄：有招名的句子前面標出招名
func _named(e: Dictionary) -> String:
	if e.has("move"):
		return MoveData.call_name(e["move"]) + e["text"]
	return e["text"]


## 你受傷後的反應：快撐不住、重傷、或偶爾一句輕傷
func _hurt_line(target: Combatant, dmg: int) -> String:
	if not target.is_alive():
		return ""
	if target.hp <= target.max_hp * 0.25:
		if target.said_dying and rng.randf() >= 0.3:
			return ""
		target.said_dying = true
		return _pick(MoveData.HURT["critical"])
	if dmg >= 20:
		return _pick(MoveData.HURT["heavy"]) if rng.randf() < 0.6 else ""
	if rng.randf() < 0.3:
		return _pick(MoveData.HURT["light"])
	return ""


## 對手倒下：有自己的結尾句（win_text）的，就不另外寫「倒下了」
func _fell(enemy: Combatant, ev: Array) -> void:
	if not enemy.enemy_def.has("win_text"):
		ev.append(_ev("info", "%s倒下了。" % enemy.display_name))
