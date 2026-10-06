extends SceneTree

## 強者榜準不準（開發用）：世界過幾年後，每個人跟幾個標準對手打，看實際勝率跟 power() 排的順序合不合。
## 執行：Godot --headless --path . --script res://tests/rank_check.gd -- [亂數種子] [幾年]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[0]) if args.size() > 0 else 1
	var years := int(args[1]) if args.size() > 1 else 6
	var w := World.new(seed)
	var h := w.make_hero("你", "他")
	h.dies_at = 99999
	for m in years * 12:
		w.tick()
	w.news.clear()
	# 標準對手：幾個不同強度的冒險者（全學招）
	var refs := []
	for s in [[13, 12, 1, "steel_sword"], [16, 14, 2, "steel_sword"], [19, 17, 3, "steel_sword"], [22, 20, 4, "steel_sword"]]:
		var r := Person.new()
		r.stats = {"str": s[0], "agi": s[1]}
		r.realm = s[2]
		r.weapon = s[3]
		for mv in ["knee", "fallstone", "shed", "dust", "deflect", "lh_cross", "lh_half"]:
			if MoveData.usable(mv, r.weapon):
				r.learn(mv)
		refs.append(r)
	var rows := []
	for p in w.others():
		var wins := 0
		var n := 0
		for r in refs:
			for i in 6:
				var b := Battle.new([r.to_combatant(true)], [Combatant.from_person(p, MapData.HOME, true)], seed * 1000 + n)
				var res := AutoPilot.new().play(b)
				n += 1
				if b.outcome != "win":
					wins += 1
		rows.append([p, float(wins) / n])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	for r in rows:
		var p: Person = r[0]
		print("%-6s %s 力%d 敏%d 血%d 強%.1f 勝率%.2f %s" % [p.display_name, p.realm_text(), p.body("str"), p.body("agi"), p.max_hp(), p.power(), r[1], WeaponData.get_def(p.weapon)["name"]])
	quit()
