extends SceneTree

## 平衡模擬（開發用，不是遊戲的一部分）。
## 不同的數值、境界、招式和武器組合，每種敵人打很多場（滿血開打，自動戰鬥），看勝率。
## 執行：Godot.exe --headless --path . --script res://tests/sim.gd

const N := 300

const T1 := ["parry", "sweep_kick", "heavy"]
const T2 := ["redirect", "disarm", "break_free"]
const T3 := ["vital", "combo"]
const WILD := ["sand", "shout"]


func _init() -> void:
	# 名字、力量、敏捷、境界（0 起算）、會的招、武器
	var setups := [
		["10/10 什麼都不會", 10, 10, 0, [], "old_sword"],
		["10/10 基礎", 10, 10, 0, T1, "old_sword"],
		["12/12 基礎 鋼劍", 12, 12, 0, T1, "steel_sword"],
		["15/15 基礎", 15, 15, 0, T1, "old_sword"],
		["15/15 基礎 鋼劍", 15, 15, 0, T1, "steel_sword"],
		["15/15 基礎 騎士", 15, 15, 0, T1, "knight_sword"],
		["15/15 進階", 15, 15, 0, T1 + T2, "old_sword"],
		["15/15 進階 鋼劍", 15, 15, 0, T1 + T2, "steel_sword"],
		["15/15 進階 騎士", 15, 15, 0, T1 + T2, "knight_sword"],
		["15/15 二境 進階 騎士", 15, 15, 1, T1 + T2, "knight_sword"],
		["18/15 二境 全部 騎士", 18, 15, 1, T1 + T2 + T3 + WILD, "knight_sword"],
		["20/15 二境 進階 騎士", 20, 15, 1, T1 + T2, "knight_sword"],
		["20/15 二境 全部 騎士", 20, 15, 1, T1 + T2 + T3 + WILD, "knight_sword"],
		["20/15 二境 全部 秘銀", 20, 15, 1, T1 + T2 + T3 + WILD, "mithril_sword"],
	]
	for s in setups:
		var line := "%-18s" % s[0]
		for id in EnemyData.ORDER + ["master"]:
			var wins := 0
			var fled := 0
			var hp_sum := 0
			var rounds := 0
			var pilot := AutoPilot.new()
			for i in N:
				var b := _battle(s[1], s[2], s[3], s[4], s[5], id, i)
				var r := pilot.play(b)
				rounds += r["rounds"]
				if r["outcome"] in ["win", "survive"]:
					wins += 1
					hp_sum += r["hp"]
				elif r["outcome"] == "flee":
					fled += 1
			line += " | %s %3d%% 逃%2d%% 剩%3d 回%4.1f" % [
				EnemyData.ENEMIES[id]["name"], 100 * wins / N, 100 * fled / N, hp_sum / maxi(1, wins), float(rounds) / N]
		print(line)
	quit()


func _battle(str_v: int, agi_v: int, realm: int, moves: Array, weapon: String, enemy_id: String, rng_seed: int) -> Battle:
	var hero := Adventurer.new()
	hero.stats = {"str": str_v, "agi": agi_v}
	hero.realm = realm
	hero.weapon = weapon
	for m in moves:
		hero.learn(m)
	var me := hero.to_combatant(true)
	var b := Battle.new([me], [Combatant.from_enemy(enemy_id)], rng_seed)
	if enemy_id == SchoolData.MASTER_ENEMY:
		me.yield_hp = roundi(me.max_hp * SchoolData.SPAR_YIELD)
		b.round_limit = SchoolData.SPAR_ROUNDS
	return b
