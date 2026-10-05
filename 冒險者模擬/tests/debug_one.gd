extends SceneTree

## 印出一場戰鬥的紀錄（開發用）。會的招全部都學。
## 執行：Godot.exe --headless --path . --script res://tests/debug_one.gd -- <敵人 id> <力量> <敏捷> <境界 0 起算> <武器 id> <亂數種子>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var hero := Adventurer.new()
	hero.stats = {"str": int(args[1]), "agi": int(args[2])}
	hero.realm = int(args[3])
	hero.weapon = args[4]
	# 數值不到門檻的招學不到（跟道場一樣）
	for m in ["parry", "sweep_kick", "heavy", "redirect", "disarm", "break_free", "vital", "combo"]:
		var req: Dictionary = SchoolData.REQ.get(m, {})
		if req.keys().all(func(s): return hero.stats[s] >= req[s]):
			hero.learn(m)
	hero.learn("sunder")
	var b := Battle.new([hero.to_combatant(true)], [Combatant.from_enemy(args[0])], int(args[5]))
	AutoPilot.new().play(b)
	for l in b.record:
		print(l)
	print(b.outcome)
	quit()
