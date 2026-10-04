extends SceneTree

## 截圖檢查（開發用）：打開主畫面，城鎮、道場、戰鬥、結算各截一張圖，再亂按一輪確認不會壞掉。
## 執行：Godot.exe --path . --script res://tests/shot.gd -- <輸出資料夾>


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Control = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	_save(out + "/town.png")

	var tabs: TabContainer = main.town_view.find_children("*", "TabContainer", true, false)[0]
	main.town.hero.money = 200
	main.town_view.add_messages(main.town.learn_move("parry"))
	tabs.current_tab = 1
	await _frames(3)
	_save(out + "/dojo.png")
	tabs.current_tab = 0

	main._start_commission("bandit_leader")
	for i in 3:
		if not main.battle.is_over():
			main.battle_view._on_move(main.battle_view.hero_c.hand[0])
	await _frames(3)
	_save(out + "/battle.png")
	_finish(main)
	await _frames(3)
	_save(out + "/settle.png")
	main._back_to_town()
	await _frames(3)
	_save(out + "/town_after.png")

	# 師傅的考驗
	main._start_spar()
	_finish(main)
	await _frames(3)
	_save(out + "/spar.png")
	main._back_to_town()

	# 每種委託都亂按打一次，確認不會壞掉
	for enemy in EnemyData.ORDER:
		main._start_commission(enemy)
		_finish(main)
		main._back_to_town()
	await _frames(3)
	_save(out + "/end.png")
	quit()


func _finish(main: Control) -> void:
	while not main.battle.is_over():
		var hand: Array = main.battle_view.hero_c.hand
		main.battle_view._on_move(hand[randi() % hand.size()])


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
