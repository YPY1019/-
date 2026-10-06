extends SceneTree

## 平衡模擬（開發用，不是遊戲的一部分）。
## 不同的數值、境界、招式和武器組合，打委託的怪物和世界上有名字的人（開局時的身體）很多場（滿血開打，自動戰鬥），看勝率。
## 執行：Godot.exe --headless --path . --script res://tests/sim.gd

const N := 150

const T1 := ["parry", "sweep_kick", "heavy"]
const T2 := ["redirect", "disarm", "break_free", "vital", "combo"]
const ULT := ["sunder"]
const ULT2 := ["sunder", "falcon"]
const ULT3 := ["sunder", "falcon", "bastion"]

var _world: World


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
		["18/16 二境 斷岳 赤牙", 18, 16, 1, T1 + T2 + ULT, "red_fang"],
		["20/17 二境 斷岳 赤牙", 20, 17, 1, T1 + T2 + ULT, "red_fang"],
		["20/17 二境 斷岳 喪鐘", 20, 17, 1, T1 + T2 + ULT, "knell"],
		["20/17 三境 斷岳 喪鐘", 20, 17, 2, T1 + T2 + ULT, "knell"],
		# 只練力量（2026-10-05 第三次試玩的路線）
		["17/10 二境 基礎 騎士", 17, 10, 1, T1, "knight_sword"],
		["18/10 二境 進階 騎士", 18, 10, 1, T1 + T2, "knight_sword"],
		["19/10 二境 斷岳 赤牙", 19, 10, 1, T1 + T2 + ULT, "red_fang"],
		["20/10 二境 斷岳 喪鐘", 20, 10, 1, T1 + T2 + ULT, "knell"],
		# 第三境：拿到後面的武器和秘笈
		["21/19 三境 斷岳 喪鐘", 21, 19, 2, T1 + T2 + ULT, "knell"],
		["21/19 三境 二絕 喪鐘", 21, 19, 2, T1 + T2 + ULT2, "knell"],
		["21/19 三境 二絕 碎門", 21, 19, 2, T1 + T2 + ULT2, "gatebreaker"],
		["23/21 三境 斷岳 喪鐘", 23, 21, 2, T1 + T2 + ULT, "knell"],
		["23/21 三境 二絕 喪鐘", 23, 21, 2, T1 + T2 + ULT2, "knell"],
		["23/21 三境 二絕 守夜", 23, 21, 2, T1 + T2 + ULT2, "nightwatch"],
		["25/23 三境 二絕 守夜", 25, 23, 2, T1 + T2 + ULT2, "nightwatch"],
	]
	# 怪物用 EnemyData 的 id，人用 PeopleData 的 id（開局時的身體；後來才來的人用剛來時的身體）
	var ids := ["bear", "bran", "roderick", "ulf", "yvette", "black_knight", "ogre", "grayson", "leonard", "varen"]
	_world = World.new(1)
	for id in PeopleData.PEOPLE:
		if _world.person(id) == null:
			_world._spawn(id)
	# 加參數只跑名字裡有這段字的組合：-- "/10"
	var only := OS.get_cmdline_user_args()
	if not only.is_empty():
		setups = setups.filter(func(s): return s[0].contains(only[0]))
	for s in setups:
		var line := "%-18s" % s[0]
		for id in ids:
			var wins := 0
			var fled := 0
			var hp_sum := 0
			var rounds := 0
			var ults := 0
			var pilot := AutoPilot.new()
			pilot.retreat_at = 0.2
			for i in N:
				var b := _battle(s[1], s[2], s[3], s[4], s[5], id, i)
				var r := pilot.play(b)
				rounds += r["rounds"]
				for u in ULT3:
					ults += r["used"].count(u)
				if r["outcome"] in ["win", "survive"]:
					wins += 1
					hp_sum += r["hp"]
				elif r["outcome"] == "flee":
					fled += 1
			var short: String = EnemyData.ENEMIES[id]["name"] if EnemyData.ENEMIES.has(id) else _world.person(id).display_name
			line += " | %s %3d%% 剩%3d 回%4.1f" % [short.substr(0, 2), 100 * wins / N, hp_sum / maxi(1, wins), float(rounds) / N]
			if ults > 0:
				line += " 斷%.1f" % (float(ults) / N)
		print(line)
	quit()


func _battle(str_v: int, agi_v: int, realm: int, moves: Array, weapon: String, enemy_id: String, rng_seed: int) -> Battle:
	var hero := Person.new()
	hero.stats = {"str": str_v, "agi": agi_v}
	# 境界照數值算（6 層，見 GrowthData）。setups 裡寫的境界只是名字
	hero.realm = GrowthData.realm_of_value(maxi(str_v, agi_v))
	hero.weapon = weapon
	# 數值不到門檻的招學不到（跟道場一樣）
	for m in moves:
		var req: Dictionary = SchoolData.REQ.get(m, {})
		if req.keys().all(func(s): return hero.stats[s] >= req[s]):
			hero.learn(m)
	var me := hero.to_combatant(true)
	var foe: Combatant
	if EnemyData.ENEMIES.has(enemy_id):
		foe = Combatant.from_enemy(enemy_id)
	else:
		var p := _world.person(enemy_id)
		p.hp = p.max_hp()
		foe = Combatant.from_person(p, p.location)
	var b := Battle.new([me], [foe], rng_seed)
	if enemy_id == SchoolData.SPAR_ENEMY:
		me.yield_hp = roundi(me.max_hp * SchoolData.SPAR_YIELD)
		b.round_limit = SchoolData.SPAR_ROUNDS
	return b
