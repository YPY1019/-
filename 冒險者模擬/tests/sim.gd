extends SceneTree

## 平衡模擬（開發用，不是遊戲的一部分）。
## 不同的數值、境界和招式組合，每種敵人打很多場（滿血開打），看勝率。
## 電腦玩家見 bot.gd。
## 執行：Godot.exe --headless --path . --script res://tests/sim.gd

const Bot := preload("res://tests/bot.gd")
const N := 300

const T1 := ["parry", "sweep_kick", "heavy"]
const T2 := ["redirect", "disarm", "break_free"]
const T3 := ["vital", "combo"]
const WILD := ["sand", "shout"]


func _init() -> void:
	# 名字、力量、敏捷、境界（0 起算）、會的招
	var setups := [
		["10/10 什麼都不會", 10, 10, 0, []],
		["10/10 第1階", 10, 10, 0, T1],
		["13/13 第1階", 13, 13, 0, T1],
		["15/15 第1階", 15, 15, 0, T1],
		["15/15 第1+2階", 15, 15, 0, T1 + T2],
		["15/15 二境 1+2", 15, 15, 1, T1 + T2],
		["18/15 二境 1+2", 18, 15, 1, T1 + T2],
		["20/15 二境 全部", 20, 15, 1, T1 + T2 + T3 + WILD],
		["20/15 三境 全部", 20, 15, 2, T1 + T2 + T3 + WILD],
		["21/15 三境 全部", 21, 15, 2, T1 + T2 + T3 + WILD],
		["23/15 三境 全部", 23, 15, 2, T1 + T2 + T3 + WILD],
		["15/20 二境 全部", 15, 20, 1, T1 + T2 + T3 + WILD],
	]
	for s in setups:
		var line := "%-14s" % s[0]
		for id in EnemyData.ORDER + ["master"]:
			var wins := 0
			var hp_sum := 0
			var rounds := 0
			var bot := Bot.new()
			for i in N:
				var b := _battle(s[1], s[2], s[3], s[4], id, i)
				var r := bot.play(b)
				rounds += r["rounds"]
				if r["outcome"] in ["win", "survive"]:
					wins += 1
					hp_sum += r["hp"]
			line += " | %s %3d%% 剩%3d 回%4.1f" % [
				EnemyData.ENEMIES[id]["name"], 100 * wins / N, hp_sum / maxi(1, wins), float(rounds) / N]
		print(line)
	quit()


func _battle(str_v: int, agi_v: int, realm: int, moves: Array, enemy_id: String, rng_seed: int) -> Battle:
	var hero := Adventurer.new()
	hero.stats = {"str": str_v, "agi": agi_v}
	hero.realm = realm
	for m in moves:
		hero.learn(m)
	var me := hero.to_combatant(true)
	var b := Battle.new([me], [Combatant.from_enemy(enemy_id)], rng_seed)
	if enemy_id == SchoolData.MASTER_ENEMY:
		me.yield_hp = roundi(me.max_hp * SchoolData.SPAR_YIELD)
		b.round_limit = SchoolData.SPAR_ROUNDS
	return b
