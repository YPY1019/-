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
	_fight(main, "bandit_leader")
	await create_timer(2.8).timeout
	_save(out + "/battle.png")
	main.battle_view._skip()
	await _frames(3)
	_save(out + "/settle_first.png")
	await _back(main)

	# 第二次打同一個
	main.town.hero.hp = main.town.hero.max_hp()
	main.town.hero.learn("heavy")
	_fight(main, "bandit_leader")
	main.battle_view._skip()
	await _frames(3)
	_save(out + "/settle_again.png")
	await _back(main)
	await _frames(3)
	_save(out + "/town_after.png")

	# 師傅的考驗
	main._start_spar()
	main.battle_view._skip()
	await _frames(3)
	_save(out + "/spar.png")
	await _back(main)

	# 按撤退
	main.town.hero.hp = main.town.hero.max_hp()
	_fight(main, "bear")
	main.battle_view._request_flee()
	main.battle_view._skip()
	await _frames(3)
	_save(out + "/flee.png")
	await _back(main)

	# 每種委託都打一次，確認不會壞掉
	for enemy in EnemyData.ORDER:
		main.town.hero.hp = main.town.hero.max_hp()
		_fight(main, enemy)
		main.battle_view._skip()
		await _back(main)
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
	_fight(main, "merc_captain")
	main.battle_view._skip()
	await _frames(3)
	_save(out + "/named.png")
	# 劍譜在戰利品裡：拿走
	if main.town.loot.has("sunder_book"):
		main._take_loot("sunder_book")
		await _frames(3)
		_save(out + "/book_loot.png")
	await _back(main)
	await _frames(3)
	_save(out + "/book_town.png")
	# 讀秘笈：等的畫面跳到一半、跳完
	main.town_view._act(main.town.read_book("sunder_book"))
	await create_timer(2.2).timeout
	_save(out + "/wait_read.png")
	await create_timer(3.0).timeout
	_save(out + "/wait_read_done.png")
	await _frames(3)
	_save(out + "/book_read.png")
	h.hp = h.max_hp()
	_fight(main, "black_knight")
	main.battle_view._skip()
	await _back(main)
	var tabs2: TabContainer = main.town_view.find_children("*", "TabContainer", true, false)[0]
	tabs2.current_tab = 2
	await _frames(3)
	_save(out + "/weapons.png")
	tabs2.current_tab = 0
	await _frames(3)
	_save(out + "/board.png")
	# 老了：身體掉下來，打一場看戰報
	h.month = LifeData.life_months() - 30
	h.hp = h.max_hp()
	main.town_view.refresh()
	await _frames(3)
	_save(out + "/old_town.png")
	_fight(main, "bear")
	main.battle_view._skip()
	await _frames(3)
	_save(out + "/old_battle.png")
	await _back(main)
	# 壽命用完：休養到死，看這一生
	h.month = LifeData.life_months() - 1
	h.hp = 1
	main.town_view._act(main.town.rest(3))
	await create_timer(3.0).timeout
	_save(out + "/death_wait.png")
	await create_timer(2.0).timeout
	_save(out + "/life.png")
	quit()


## 出發（跳過路上的等）再開打
func _fight(main: Node, enemy: String) -> void:
	main.town.depart(enemy)
	main.town.take_wait()
	main._start_commission(enemy)


## 回城。打輸要躺的那段，等它跳完
func _back(main: Node) -> void:
	main._back_to_town()
	while main.blocker.visible:
		await create_timer(0.2).timeout


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
