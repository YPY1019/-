extends SceneTree

## 世界自己過日子（開發用）：玩家角色待在城裡什麼都不做，看世界上發生了什麼事、幾歲發生。
## 用來調「世界變得多快」：懸賞多久被別人撕掉、好東西落到誰手上、誰老死、誰來了。
## 執行：Godot --headless --path . --script res://tests/world.gd -- [亂數種子] [幾年]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[0]) if args.size() > 0 else 1
	var years := int(args[1]) if args.size() > 1 else 22
	var w := World.new(seed)
	var h := w.make_hero("你", "他")
	h.dies_at = 99999
	for m in years * 12:
		w.tick()
		for e in w.news:
			print("%s　%s" % [LifeData.date_text(h.age(), w.month()), e["text"]])
		w.news.clear()
	print("\n==== %d 年後 ====" % years)
	var alive: Array = w.others()
	alive.sort_custom(func(a, b): return a.power() > b.power())
	for p in alive:
		var items: Array = p.items().map(func(it): return BookData.get_def(it)["name"] if BookData.is_book(it) else WeaponData.get_def(it)["name"])
		print("%-6s %2d 歲 %s 力%d 敏%d 強%.1f 在%s %s%s" % [p.display_name, p.age(), p.realm_text(), p.body("str"), p.body("agi"), p.power(),
			MapData.place_name(p.location), "、".join(items), "　懸賞" if w.wanted(p.id) else ""])
	quit()
