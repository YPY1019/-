extends SceneTree

## 平衡模擬（開發用，不是遊戲的一部分）。
## 不同的數值和招式組合，每種敵人打很多場（滿血開打），看勝率。
## 電腦玩家見 bot.gd。
## 執行：Godot.exe --headless --path . --script res://tests/sim.gd

const Bot := preload("res://tests/bot.gd")
const N := 300

const T1 := ["parry", "sweep_kick", "heavy"]
const T2 := ["redirect", "disarm", "break_free"]
const T3 := ["vital", "combo"]


func _init() -> void:
	var setups := [
		["數值10 什麼都不會", 10, []],
		["數值10 第1階", 10, T1],
		["數值13 什麼都不會", 13, []],
		["數值13 第1階", 13, T1],
		["數值15 第1階", 15, T1],
		["數值15 第1+2階", 15, T1 + T2],
		["數值18 第1+2階", 18, T1 + T2],
		["數值18 全部", 18, T1 + T2 + T3 + ["sand", "shout"]],
		["數值20 全部", 20, T1 + T2 + T3 + ["sand", "shout"]],
	]
	for s in setups:
		var line := "%-14s" % s[0]
		for id in EnemyData.ORDER + ["master"]:
			var wins := 0
			var hp_sum := 0
			var rounds := 0
			var bot := Bot.new()
			for i in N:
				var b := _battle(s[1], s[2], id, i)
				var r := bot.play(b)
				rounds += r["rounds"]
				if r["outcome"] in ["win", "survive"]:
					wins += 1
					hp_sum += r["hp"]
			line += " | %s %3d%% 剩%3d 回%4.1f" % [
				EnemyData.ENEMIES[id]["name"], 100 * wins / N, hp_sum / maxi(1, wins), float(rounds) / N]
		print(line)
	quit()


func _battle(stat: int, moves: Array, enemy_id: String, rng_seed: int) -> Battle:
	var hero := Adventurer.new()
	for k in hero.stats:
		hero.stats[k] = stat
	for m in moves:
		hero.learn(m)
	var me := hero.to_combatant(true)
	var b := Battle.new([me], [Combatant.from_enemy(enemy_id)], rng_seed)
	if enemy_id == SchoolData.MASTER_ENEMY:
		me.yield_hp = roundi(me.max_hp * SchoolData.SPAR_YIELD)
		b.round_limit = SchoolData.SPAR_ROUNDS
	return b
