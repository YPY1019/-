extends RefCounted

## 模擬用的電腦玩家（開發用）：每回合從手上挑「眼前最划算」的招。
## 它不懂對手的習慣，也不會想下一步，真人應該打得比它好。

## 每招「出現在選項裡」和「被選中」的次數
var offered := {}
var picked := {}


func play(b: Battle) -> Dictionary:
	var me: Combatant = b.allies[0]
	var foe: Combatant = b.enemies[0]
	b.start()
	while not b.is_over() and b.round_no < 60:
		b.play_round({me: {"move": pick(me, foe), "target": foe}})
	return b.result()


func pick(me: Combatant, foe: Combatant) -> String:
	for id in me.hand:
		offered[id] = offered.get(id, 0) + 1
	var best := me.hand[0]
	var best_score := -INF
	for id in me.hand:
		var score := value(me, foe, id)
		if score > best_score:
			best_score = score
			best = id
	picked[best] = picked.get(best, 0) + 1
	return best


func value(me: Combatant, foe: Combatant, id: String) -> float:
	var it: Dictionary = foe.intent
	if id == "struggle":
		return 0.5 * 15.0 - 0.5 * foe.atk * 0.7
	var e := MoveData.entry(id, it["type"], foe.traits)
	var m: Dictionary = MoveData.MOVES[id]
	var deal: float = e.get("deal", 0.0) * me.power_of(id)
	if not m.get("pierce", false):
		deal *= EnemyData.ARMOR_MULT[foe.armor]
	var power := 0.0
	var on_hit := ""
	if it["phase"] == "hold":
		power = foe.action_def(foe.holding)["hold"]["power"]
	elif it["phase"] in ["do", "strike"] and it["action"] != "":
		var a := foe.action_def(it["action"])
		power = a.get("power", 0.0)
		on_hit = a.get("on_hit", "")
	var take: float = e.get("take", 1.0 if power > 0.0 else 0.0)
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
		bonus -= 0.3 * foe.atk  # 下回合不能閃避、選項少一個
		if it["phase"] == "windup" and not (e.get("effect", "") == "interrupt"):
			bonus -= 0.6 * foe.atk * foe.action_def(it["action"]).get("power", 1.0)  # 對方蓄勢的重招下回合打下來，躲不掉
	return deal + bonus - take * foe.atk * power


func usage() -> String:
	var parts := []
	for id in offered:
		parts.append("%s %d%%" % [MoveData.MOVES[id]["name"], 100 * picked.get(id, 0) / offered[id]])
	return "、".join(parts)
