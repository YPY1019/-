extends SceneTree

## 平衡模擬（開發用，不是遊戲的一部分）。
## 電腦玩家每回合從手上挑「眼前最划算」的招，每種敵人打很多場，看勝率。
## 它不懂對手的習慣，也不會想下一步，真人應該打得比它好。
## 執行：Godot.exe --headless --path . --script res://tests/sim.gd

const N := 400

## 每招「出現在選項裡」和「被選中」的次數（抓永遠被選、永遠沒人選的招）
var offered := {}
var picked := {}


func _init() -> void:
	var setups := [["什麼都不會", []]]
	for m in MoveData.LEARNABLE:
		setups.append(["只會" + MoveData.MOVES[m]["name"], [m]])
	setups.append(["會3招(掃腿撥擋卸力)", ["sweep_kick", "parry", "redirect"]])
	setups.append(["會6招", ["sweep_kick", "parry", "redirect", "heavy", "vital", "break_free"]])
	setups.append(["10招全會", MoveData.LEARNABLE])
	var usage := []
	for s in setups:
		var line := "%-12s" % s[0]
		for id in EnemyData.ORDER:
			var wins := 0
			var hp_sum := 0
			var rounds := 0
			offered.clear()
			picked.clear()
			for i in N:
				var hero := Adventurer.new()
				for m in s[1]:
					hero.learn(m)
				var me := hero.to_combatant()
				var foe := Combatant.from_enemy(id)
				var b := Battle.new([me], [foe], i)
				b.start()
				while not b.is_over() and b.round_no < 60:
					b.play_round({me: {"move": _pick(me, foe), "target": foe}})
				var r := b.result()
				rounds += r["rounds"]
				if r["outcome"] == "win":
					wins += 1
					hp_sum += r["hp"]
			line += " | %s 勝%3d%% 剩%3d 回%4.1f" % [
				EnemyData.ENEMIES[id]["name"], 100 * wins / N,
				hp_sum / maxi(1, wins), float(rounds) / N]
			if s[0] in ["10招全會", "什麼都不會", "只會重擊"]:
				usage.append("　%s（%s）：%s" % [s[0], EnemyData.ENEMIES[id]["name"], _usage()])
		print(line)
	print("各招被選中的比例（選中/出現在選項裡）：")
	for u in usage:
		print(u)
	quit()


func _pick(me: Combatant, foe: Combatant) -> String:
	for id in me.hand:
		offered[id] = offered.get(id, 0) + 1
	var best := me.hand[0]
	var best_score := -INF
	for id in me.hand:
		if id == "flee":
			continue
		var score := _value(me, foe, id)
		if score > best_score:
			best_score = score
			best = id
	picked[best] = picked.get(best, 0) + 1
	return best


func _value(me: Combatant, foe: Combatant, id: String) -> float:
	var it: Dictionary = foe.intent
	if id == "struggle":
		return 0.5 * 15.0 - 0.5 * foe.atk * 0.7
	var e := MoveData.entry(id, it["type"], foe.traits)
	var m: Dictionary = MoveData.MOVES[id]
	var deal: float = e.get("deal", 0.0) * me.atk
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
	return deal + bonus - take * foe.atk * power


func _usage() -> String:
	var parts := []
	for id in offered:
		parts.append("%s %d%%" % [MoveData.MOVES[id]["name"], 100 * picked.get(id, 0) / offered[id]])
	return "、".join(parts)
