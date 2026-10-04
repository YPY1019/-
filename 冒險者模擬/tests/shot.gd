extends SceneTree

## 截圖檢查（開發用）：打開主畫面、打幾回合，各截一張圖。
## 執行：Godot.exe --path . --script res://tests/shot.gd -- <輸出資料夾>


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Control = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	for m in ["sweep_kick", "parry", "vital", "break_free", "shout"]:
		main.hero.learn(m)
	main._show_prep()
	await _frames(3)
	root.get_texture().get_image().save_png(out + "/prep.png")
	main._start_battle("bear")
	for i in 3:
		main._on_move(main.hero_c.hand[0])
	await _frames(3)
	root.get_texture().get_image().save_png(out + "/battle.png")
	# 隨便亂按，確認不會壞掉
	for enemy in EnemyData.ORDER:
		main._start_battle(enemy)
		while not main.battle.is_over():
			var hand: Array = main.hero_c.hand
			main._on_move(hand[randi() % hand.size()])
	await _frames(3)
	root.get_texture().get_image().save_png(out + "/end.png")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
