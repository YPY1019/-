extends SceneTree

## 截圖檢查（開發用）：打開主畫面，城鎮、道場、武器店、戰鬥、結算各截一張圖，再每種委託打一輪確認不會壞掉。
## 執行：Godot.exe --path . --script res://tests/shot.gd -- <輸出資料夾>


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Control = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	_save(out + "/town.png")

	var tabs: TabContainer = main.town_view.find_children("*", "TabContainer", true, false)[0]
	main.town.hero.money = 300
	main.town_view.add_messages(main.town.learn_move("parry"))
	tabs.current_tab = 1
	await _frames(3)
	_save(out + "/dojo.png")
	main.town.hero.stats["str"] = 12
	main.town_view.refresh()
	tabs.current_tab = 2
	await _frames(3)
	_save(out + "/shop.png")
	main.town_view.add_messages(main.town.buy_weapon("steel_sword"))
	tabs.current_tab = 0

	# 自動播放幾回合
	main._start_commission("bandit_leader")
	await create_timer(2.8).timeout
	_save(out + "/battle.png")
	main.battle_view._skip()
	await _frames(3)
	_save(out + "/settle_first.png")
	main._back_to_town()

	# 第二次打同一個
	main.town.hero.hp = main.town.hero.max_hp()
	main.town.hero.learn("heavy")
	main._start_commission("bandit_leader")
	main.battle_view._skip()
	await _frames(3)
	_save(out + "/settle_again.png")
	main._back_to_town()
	await _frames(3)
	_save(out + "/town_after.png")

	# 師傅的考驗
	main._start_spar()
	main.battle_view._skip()
	await _frames(3)
	_save(out + "/spar.png")
	main._back_to_town()

	# 按撤退
	main.town.hero.hp = main.town.hero.max_hp()
	main._start_commission("bear")
	main.battle_view._request_flee()
	main.battle_view._skip()
	await _frames(3)
	_save(out + "/flee.png")
	main._back_to_town()

	# 每種委託都打一次，確認不會壞掉
	for enemy in EnemyData.ORDER:
		main.town.hero.hp = main.town.hero.max_hp()
		main._start_commission(enemy)
		main.battle_view._skip()
		main._back_to_town()
	await _frames(3)
	_save(out + "/end.png")
	# 有名的強者：用強一點的角色打，看絕學、稀有的劍、升境的寫法
	var h: Adventurer = main.town.hero
	h.stats = {"str": 18, "agi": 18}
	h.realm = 1
	h.approved_tier = 2
	h.hp = h.max_hp()
	main.town_view.refresh()
	await _frames(3)
	_save(out + "/board_before.png")
	main._start_commission("merc_captain")
	main.battle_view._skip()
	await _frames(3)
	_save(out + "/named.png")
	# 劍譜在戰利品裡：拿走
	if main.town.loot.has("sunder_book"):
		main._take_loot("sunder_book")
		await _frames(3)
		_save(out + "/book_loot.png")
	main._back_to_town()
	await _frames(3)
	_save(out + "/book_town.png")
	main.town_view.add_messages(main.town.read_book("sunder_book"))
	await _frames(3)
	_save(out + "/book_read.png")
	h.hp = h.max_hp()
	main._start_commission("black_knight")
	main.battle_view._skip()
	main._back_to_town()
	var tabs2: TabContainer = main.town_view.find_children("*", "TabContainer", true, false)[0]
	tabs2.current_tab = 2
	await _frames(3)
	_save(out + "/weapons.png")
	tabs2.current_tab = 0
	await _frames(3)
	_save(out + "/board.png")
	quit()


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
