extends SceneTree

## 印出你跟世界上某個人的一場戰鬥（開發用）：看他用不用得出學來的招。
## 執行：Godot --headless --path . --script res://tests/debug_person.gd -- <人 id> <力量> <敏捷> <境界 0 起算> <武器 id> <亂數種子> [你會的招，逗號分開]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var w := World.new(1)
	var hero := w.make_hero("你", "他")
	hero.stats = {"str": int(args[1]), "agi": int(args[2])}
	hero.realm = int(args[3])
	hero.weapon = args[4]
	if args.size() > 6:
		for m in args[6].split(","):
			hero.learn(m)
	var p := w.person(args[0])
	var b := Battle.new([hero.to_combatant(true)], [Combatant.from_person(p, p.location)], int(args[5]))
	AutoPilot.new().play(b)
	for l in b.record:
		print(l)
	print(b.outcome)
	print("看過：", hero.seen)
	quit()
