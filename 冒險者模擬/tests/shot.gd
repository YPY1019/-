extends SceneTree

## 截圖檢查（開發用）：打開主畫面、打幾回合，各截一張圖。
## 執行：Godot.exe --path . --script res://tests/shot.gd -- <輸出資料夾>


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Control = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	main.hero.learn("sweep_kick")
	main.hero.learn("vital")
	main._show_prep()
	await _frames(3)
	root.get_texture().get_image().save_png(out + "/prep.png")
	main._start_battle("bandit_leader")
	for i in 3:
		main._on_move(["sweep_kick", "vital", "dodge"][i])
	await _frames(3)
	root.get_texture().get_image().save_png(out + "/battle.png")
	main._start_battle("bear")
	while not main.battle.is_over():
		main._on_move({"opening": "vital", "smash": "dodge"}.get(main.foe_c.intent["type"], "defend"))
	await _frames(3)
	root.get_texture().get_image().save_png(out + "/end.png")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
