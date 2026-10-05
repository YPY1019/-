class_name AutoPilot
extends RefCounted

## 自動戰鬥：冒險者自己挑招。每回合從手上挑「眼前最划算」的招（成功、失敗的結果按機率算平均）。
## 它不懂對手的習慣，也不會想下一步。不會自己撤退（撤退是玩家按的）；模擬可以設 retreat_at 代替玩家按。
## 模擬（tests/）也用它。

## 血剩最大血量的這個比例（含）以下就撤（模擬用）。0 = 不撤
var retreat_at := 0.0
## 每招「能挑」和「被挑中」的次數（模擬看平衡用）
var offered := {}
var picked := {}


## 一口氣打完（模擬用）
func play(b: Battle) -> Dictionary:
	var me: Combatant = b.allies[0]
	var foe: Combatant = b.enemies[0]
	b.start()
	while not b.is_over() and b.round_no < 60:
		b.play_round({me: {"move": choose(b, me, foe), "target": foe}})
	return b.result()


func choose(b: Battle, me: Combatant, foe: Combatant) -> String:
	if retreat_at > 0.0 and me.hp <= me.max_hp * retreat_at and me.yield_hp == 0 and b.can_flee(me):
		return MoveData.FLEE
	for id in me.hand:
		offered[id] = offered.get(id, 0) + 1
	var best := me.hand[0]
	var best_score := -INF
	for id in me.hand:
		var score := value(b, me, foe, id)
		if score > best_score:
			best_score = score
			best = id
	picked[best] = picked.get(best, 0) + 1
	return best


## 這招的期望值：成功、失敗按機率平均
func value(b: Battle, me: Combatant, foe: Combatant, id: String) -> float:
	var p := b.fail_chance(me, id, foe)
	var v := _value_of(b, me, foe, id, b.move_result(me, id, foe, false))
	if p > 0.0:
		v = (1.0 - p) * v + p * _value_of(b, me, foe, id, b.move_result(me, id, foe, true))
	return v


func _value_of(b: Battle, me: Combatant, foe: Combatant, id: String, e: Dictionary) -> float:
	var it: Dictionary = foe.intent
	var m: Dictionary = MoveData.MOVES[id]
	var deal := b.damage_out(me, id, foe, e.get("deal", 0.0))
	if not m.get("pierce", false) and me.weapon_fx != "rend":
		deal *= EnemyData.ARMOR_MULT[foe.armor]
	# 對手這回合打過來多痛
	var hit := 0.0
	var on_hit := ""
	if it["phase"] == "hold":
		hit = b.damage_in(foe, me, foe.action_def(foe.holding)["hold"]["power"], "str")
	elif it["phase"] in ["do", "strike"] and it["action"] != "":
		var a := foe.action_def(it["action"])
		hit = b.damage_in(foe, me, a.get("power", 0.0), EnemyData.action_stat(a, a["type"]))
		on_hit = a.get("on_hit", "")
	var take: float = e.get("take", 1.0 if hit > 0.0 or on_hit != "" else 0.0)
	var typical := b.damage_in(foe, me, 1.0, "str")
	var bonus := 0.0
	if take > 0.0:
		match on_hit:
			"held":
				bonus -= 20.0
			"shaken", "blind":
				bonus -= 8.0
			"off_balance":
				bonus -= 4.0
	match e.get("effect", ""):
		"trip", "break", "stagger", "scare", "interrupt":
			bonus += 18.0
		"disarm":
			bonus += 15.0
		"blind":
			bonus += 8.0
		"escape":
			bonus += 15.0
	if m.get("self", "") == "off_balance":
		bonus -= 0.3 * typical  # 下回合不能閃避、選項少一個
		if it["phase"] == "windup" and not (e.get("effect", "") == "interrupt"):
			bonus -= 0.6 * typical * foe.action_def(it["action"]).get("power", 1.0)  # 對方蓄勢的重招下回合打下來，躲不掉
	return deal + bonus - take * hit


func usage() -> String:
	var parts := []
	for id in offered:
		parts.append("%s %d%%" % [MoveData.MOVES[id]["name"], 100 * picked.get(id, 0) / offered[id]])
	return "、".join(parts)
