extends SceneTree

## 亂按測試（開發用）：打開主畫面，隨機做玩家會做的事（學招、接委託、走路、路上的事、打架、休養、打聽、換招、劍庭），
## 看會不會當掉或卡住。路上的事機率調成很高。
## 執行：Godot --headless --path . --script res://tests/smoke.gd -- [亂數種子] [做幾件事]

var main: Control


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[0]) if args.size() > 0 else 1
	var steps := int(args[1]) if args.size() > 1 else 300
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var town: Town = main.town
	town.road_boost = 4.0
	var tv: TownView = main.town_view
	for i in steps:
		var h := town.hero
		if h.dead:
			if main.life_view.visible:
				# 被人殺了（沒有安排後事）：挑第一個能接手的人
				if town.heir_id == "":
					town.choose_heir(town.heir_candidates()[0].id)
				main._continue_as_heir()
			await process_frame
			continue
		if main.blocker.visible:
			await create_timer(0.05).timeout
			continue
		# 有對話就隨便選一個
		if main.encounter.visible:
			var row: HBoxContainer = main.encounter.button_row
			var buttons := row.get_children()
			(buttons[rng.randi_range(0, buttons.size() - 1)] as Button).emit_signal("pressed")
			await process_frame
			continue
		if main.battle_view.visible:
			main.battle_view._skip()
			await process_frame
			if main.battle_view.fate_box.visible:
				main.battle_view._choose_fate(rng.randf() < 0.5)
			for id in town.loot.duplicate():
				main._take_loot(id)
			main._close_battle()
			await process_frame
			continue
		if h.dying():
			var c := town.heir_candidates()
			if not c.is_empty():
				main._heir_chosen(c[0].id)
			await process_frame
			continue
		match rng.randi_range(0, 9):
			0:
				for id in TownData.TRAINING:
					tv._act(town.learn_training(id))
			1:
				for id in town.board():
					town.accept_job(id)
				for id in town.world.bounties:
					town.accept_bounty(id)
			2, 3:
				var places := MapData.PLACES.keys()
				main._travel(places[rng.randi_range(0, places.size() - 1)])
			4:
				var jobs := town.monsters_at(h.location)
				if not jobs.is_empty():
					main._meet_monster(jobs[0])
			5:
				var ppl := town.people_here()
				if not ppl.is_empty():
					main._fight_person(ppl[rng.randi_range(0, ppl.size() - 1)].id)
			6:
				if town.in_city() and h.hp < h.max_hp():
					tv._on_rest_choice("full")
			7:
				var r := town.world.ranking()
				if not r.is_empty():
					tv.add_messages(town.ask_about(r[-1].id))
				for id in h.learned:
					town.toggle_equip(id)
			8:
				if town.spar_state()["ok"]:
					main._start_spar()
				elif town.trial_state()["ok"]:
					main._start_trial()
				for id in town.school_jobs():
					town.accept_school_job(id)
				tv.add_messages(town.turn_in("guild"))
				tv.add_messages(town.turn_in("school"))
			9:
				tv.refresh()
				main.person_panel.show_person(h.id)
				main.person_panel.close()
		await process_frame
	print("done: ", town.hero.display_name, " ", town.hero.age(), " 歲 ", town.world.month(), " 月")
	quit()
