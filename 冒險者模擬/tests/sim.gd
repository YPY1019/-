extends SceneTree

## 平衡模擬（開發用，不是遊戲的一部分）。
## 不同的數值、境界、招式和武器組合，每種敵人打很多場（滿血開打，自動戰鬥），看勝率。
## 執行：Godot.exe --headless --path . --script res://tests/sim.gd

const N := 300

const T1 := ["parry", "sweep_kick", "heavy"]
const T2 := ["redirect", "disarm", "break_free", "vital", "combo"]
const ULT := ["sunder"]
const WILD := ["sand", "shout"]


func _init() -> void:
	# 名字、力量、敏捷、境界（0 起算）、會的招、武器
	var setups := [
		["10/10 什麼都不會", 10, 10, 0, [], "old_sword"],
		["10/10 基礎", 10, 10, 0, T1, "old_sword"],
		["12/12 基礎 大刀", 12, 12, 0, T1, "bandit_blade"],
		["13/13 基礎 鋼劍", 13, 13, 0, T1, "steel_sword"],
		["15/15 基礎 鋼劍", 15, 15, 0, T1, "steel_sword"],
		["15/15 進階 鋼劍", 15, 15, 0, T1 + T2, "steel_sword"],
		["15/15 進階 騎士", 15, 15, 0, T1 + T2, "knight_sword"],
		["16/15 二境 進階 騎士", 16, 15, 1, T1 + T2, "knight_sword"],
		["16/15 二境 斷岳 騎士", 16, 15, 1, T1 + T2 + ULT, "knight_sword"],
		["16/15 二境 斷岳 赤牙", 16, 15, 1, T1 + T2 + ULT, "red_fang"],
		["16/16 二境 斷岳 騎士", 16, 16, 1, T1 + T2 + ULT, "knight_sword"],
		["17/17 二境 斷岳 騎士", 17, 17, 1, T1 + T2 + ULT, "knight_sword"],
		["18/18 二境 斷岳 赤牙", 18, 18, 1, T1 + T2 + ULT, "red_fang"],
		["20/18 二境 斷岳 赤牙", 20, 18, 1, T1 + T2 + ULT, "red_fang"],
		["18/16 二境 斷岳 騎士", 18, 16, 1, T1 + T2 + ULT, "knight_sword"],
		["18/16 二境 斷岳 赤牙", 18, 16, 1, T1 + T2 + ULT + WILD, "red_fang"],
		["20/17 二境 斷岳 赤牙", 20, 17, 1, T1 + T2 + ULT + WILD, "red_fang"],
		["20/17 二境 斷岳 喪鐘", 20, 17, 1, T1 + T2 + ULT + WILD, "knell"],
		["20/17 三境 斷岳 喪鐘", 20, 17, 2, T1 + T2 + ULT + WILD, "knell"],
	]
	var ids := ["wolf", "bandit_leader", "deserter", "bear", "merc_captain", "black_knight", "ogre", "master"]
	for s in setups:
		var line := "%-18s" % s[0]
		for id in ids:
			var wins := 0
			var fled := 0
			var hp_sum := 0
			var rounds := 0
			var ults := 0
			var pilot := AutoPilot.new()
			for i in N:
				var b := _battle(s[1], s[2], s[3], s[4], s[5], id, i)
				var r := pilot.play(b)
				rounds += r["rounds"]
				ults += r["used"].count("sunder")
				if r["outcome"] in ["win", "survive"]:
					wins += 1
					hp_sum += r["hp"]
				elif r["outcome"] == "flee":
					fled += 1
			line += " | %s %3d%% 剩%3d 回%4.1f" % [
				EnemyData.ENEMIES[id]["name"].substr(0, 2), 100 * wins / N, hp_sum / maxi(1, wins), float(rounds) / N]
			if ults > 0:
				line += " 斷%.1f" % (float(ults) / N)
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
