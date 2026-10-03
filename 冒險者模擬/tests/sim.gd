extends SceneTree

## 平衡模擬（開發用，不是遊戲的一部分）。
## 用一個「會看描述、挑當下最划算的招」的電腦玩家，每種敵人打很多場，看勝率。
## 這個電腦玩家不懂敵人的習慣，只看眼前這一回合，所以真人應該打得比它好。
## 執行：Godot.exe --headless --path . --script res://tests/sim.gd

const N := 500
const LEARNABLE := ["sweep_kick", "parry", "heavy", "vital"]


func _init() -> void:
	var setups := [["只有基本招", []]]
	for m in LEARNABLE:
		setups.append(["只學" + MoveData.MOVES[m]["name"], [m]])
	setups.append(["四招全會", LEARNABLE])
	for s in setups:
		var line := "%-8s" % s[0]
		for id in EnemyData.ORDER:
			var wins := 0
			var hp_sum := 0
			var rounds := 0
			for i in N:
				var hero := Adventurer.new()
				for m in s[1]:
					hero.learn(m)
				var me := hero.to_combatant()
				var foe := Combatant.from_enemy(id)
				var b := Battle.new([me], [foe], i)
				b.start()
				while not b.is_over() and b.round_no < 100:
					b.play_round({me: {"move": _pick(me, foe), "target": foe}})
				var r := b.result()
				rounds += r["rounds"]
				if r["outcome"] == "win":
					wins += 1
					hp_sum += r["hp"]
			line += " | %s 勝%3d%% 剩血%3d 回合%4.1f" % [
				EnemyData.ENEMIES[id]["name"], 100 * wins / N,
				hp_sum / maxi(1, wins), float(rounds) / N]
		print(line)
	quit()


func _pick(me: Combatant, foe: Combatant) -> String:
	var best := "attack"
	var best_score := -INF
	for id in MoveData.ORDER:
		if id == "flee" or not me.adventurer.knows(id):
			continue
		var e := MoveData.entry(id, foe.intent["type"], me.bad_position, foe.big)
		var score := _value(me, foe, id, e)
		if score > best_score:
			best_score = score
			best = id
	return best


func _value(me: Combatant, foe: Combatant, id: String, e: Dictionary) -> float:
	var m: Dictionary = MoveData.MOVES[id]
	var deal: float = e.get("deal", 0.0) * me.atk
	if not m.get("pierce", false):
		deal *= EnemyData.ARMOR_MULT[foe.armor]
	if me.bad_position:
		deal *= MoveData.BAD_POSITION_MULT
	var power: float = MoveData.INTENT_POWER[foe.intent["type"]]
	if foe.charged:
		power *= EnemyData.CHARGE_MULT
	var take: float = e.get("take", 0.0) * foe.atk * power
	if me.bad_position:
		take *= MoveData.BAD_POSITION_TAKE
	var bonus := 0.0
	match e.get("effect", ""):
		"trip":
			bonus = 20.0
		"guard_broken":
			bonus = 20.0
		"smash_missed":
			bonus = 10.0
	if m.get("bad_position", false):
		bonus -= 0.4 * foe.atk + 3.0
	return deal + bonus - take
