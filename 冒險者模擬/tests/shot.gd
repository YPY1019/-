extends SceneTree

## 截圖檢查（開發用）：打開主畫面，走一遍「世界是活的」會碰到的畫面，各截一張圖，確認不會壞掉。
## 委託板、地圖、人物面板、接懸賞（家人傳話）、走路、打委託、打人（拿東西、家人來報仇）、被搶、
## 世界過了幾年、病倒、安排後事、這一生、換人接著玩。
## 執行（要有畫面）：Godot --path . --script res://tests/shot.gd -- <輸出資料夾>

var main: Control
var out := ""


func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	_save("01_town")
	var tv: TownView = main.town_view
	var town: Town = main.town
	var w: World = town.world
	var h: Person = town.hero
	# 路上的事另外截一張，其他時候不要碰上（不然會擋住流程）
	town.road_chance = 0.0

	# 委託板、地圖、人物
	tv.tabs.current_tab = 0
	await _frames(3)
	_save("02_board")
	tv.show_map()
	await _frames(3)
	_save("03_map")
	tv.show_person("roderick")
	await _frames(3)
	_save("04_person")
	h.money = 500
	main.person_panel.inquiry_done.emit(town.inquire("roderick"))
	main.person_panel.refresh()
	await _frames(3)
	_save("04_person_inquired")
	tv.show_map()
	await _frames(3)
	_save("04_map_inquired")
	main.person_panel.close()

	# 練武場、獅心劍庭：學一招、接庭主三招入門
	tv.tabs.current_tab = tv.training_view.get_index()
	await _frames(3)
	_save("04a_training")
	tv._ask_rest()
	await _frames(3)
	_save("04a2_rest_dialog")
	main.encounter.visible = false
	tv._act(town.learn_training("fallstone"))
	await _idle()
	h.stats = {"str": 12, "agi": 12}
	# 選拔在春天
	while not SchoolData.SELECTION_MONTHS.has(LifeData.month_of_year(w.month())):
		w.clock.month += 1
	main._start_spar()
	main.battle_view._skip()
	await _frames(3)
	_save("04b_spar")
	main._close_battle()
	await _idle()
	tv.tabs.current_tab = tv.school_view.get_index()
	await _frames(3)
	_save("04c_school")
	tv.show_person(w.hero_id)
	await _frames(3)
	_save("04d_me_panel")
	main.person_panel.tabs.current_tab = 1
	main.person_panel.move_kind = "劍"
	main.person_panel.refresh()
	await _frames(3)
	_save("04e_me_moves")
	main.person_panel.close()

	# 接下布蘭的懸賞：葛雷森傳話
	tv.add_messages(town.accept_bounty("bran"))
	tv._act(town.rest(1)) if h.hp < h.max_hp() else null
	h.hp = h.max_hp() - 10
	tv._act(town.rest(1))
	await _idle()
	_save("05_warned")

	# 接委託：在公會接下，走到牧羊村，在地圖上動手打野狼
	h.hp = h.max_hp()
	tv.add_messages(town.accept_job("wolf"))
	main._travel("pasture")
	await _idle()
	_save("05b_wolf_event")
	main.encounter.visible = false
	town.road = {"id": "caravan", "place": "pasture", "step": "start"}
	main._road_dialog()
	await _frames(3)
	_save("05a_road_event")
	town.answer_road("0")
	main._road_dialog()
	await _frames(3)
	_save("05a2_road_event_step2")
	main.encounter.visible = false
	town.road = {}
	main._meet_monster("wolf")
	await _frames(3)
	main.encounter.visible = false
	main._answer_monster("fight", "wolf")
	await _until(func(): return main.battle_view.visible)
	await create_timer(1.5).timeout
	_save("06_battle_wolf")
	main.battle_view._skip()
	await _frames(3)
	_save("07_settle_wolf")
	main._close_battle()
	await _idle()
	_save("08_after_wolf")

	# 變強，去找布蘭
	h.stats = {"str": 19, "agi": 18}
	h.realm = 1
	for m in ["knee", "fallstone", "shed", "lh_cross", "lh_pommel", "lh_half", "deflect", "needle"]:
		h.learn(m)
	h.hp = h.max_hp()
	var bran := w.person("bran")
	main._travel("bridge")
	await _idle()
	bran.travel_left = 0
	bran.location = "bridge"
	bran.stay_left = 99
	_save("09_at_bridge")
	main._fight_person("bran")
	await _frames(3)
	main.battle_view._skip()
	await _frames(3)
	_save("10_bran_done")
	main._fate_chosen(true)
	await _frames(3)
	_save("10b_bran_fate")
	for id in town.loot.duplicate():
		main._take_loot(id)
	await _frames(3)
	_save("11_bran_loot")
	main._close_battle()
	await _idle()
	_save("12_after_bran")

	# 葛雷森來找你：讓他走到你這裡
	var gray := w.person("grayson")
	gray.target = w.hero_id
	gray.rest_left = 0
	gray.travel_left = 0
	gray.location = h.location
	main._after_time()
	await _frames(3)
	_save("13a_grayson_dialog")
	main.encounter.visible = false
	main._answer_comer("fight")
	await _frames(3)
	await create_timer(1.5).timeout
	_save("13_grayson_comes")
	main.battle_view._skip()
	await _frames(3)
	_save("14_grayson_done")
	main._close_battle()
	await _idle()
	_save("15_after_grayson")
	tv.show_person("grayson")
	await _frames(3)
	_save("16_grayson_panel")
	main.person_panel.close()

	# 劍庭的委託、公開比試
	tv.add_messages(town.accept_school_job("roderick"))
	tv.add_messages(town.accept_school_job("impostor"))
	tv.add_messages(town.accept_school_job("deliver"))
	tv.show_map()
	await _frames(3)
	_save("15b_map_tracked")
	main._travel("pasture")
	await _idle()
	_save("15c_pasture_impostor")
	main.encounter.visible = false
	main._answer_monster("fight", "impostor")
	main.battle_view._skip()
	await _frames(3)
	_save("15d_impostor")
	main._close_battle()
	await _idle()
	main._travel("wheat")
	await _idle()
	main._travel(MapData.HOME)
	await _idle()
	h.school = SchoolData.ID
	h.rank = max(h.rank, 1)
	h.merit_total = 40
	h.merit = 40
	h.hp = h.max_hp()
	main._start_trial()
	main.battle_view._skip()
	await _frames(3)
	_save("16a_trial")
	main._close_battle()
	await _idle()
	tv.tabs.current_tab = tv.school_view.get_index()
	await _frames(3)
	_save("16b_school_after")
	tv.tabs.current_tab = 0
	await _frames(3)
	_save("16b2_board_claims")
	tv.tabs.current_tab = tv.people_view.get_index()
	await _frames(3)
	_save("16b3_people")
	main.person_panel.show_person("grayson")
	main.person_panel.tabs.current_tab = 1
	main.person_panel.refresh()
	await _frames(3)
	_save("16c_grayson_moves")
	main.person_panel.close()

	# 世界過了幾年
	h.dies_at = 99999
	h.hp = h.max_hp()
	for i in 8:
		town._pass_months(12)
	tv.refresh()
	tv.tabs.current_tab = 0
	await _frames(3)
	_save("17_board_later")
	tv.show_map()
	await _frames(3)
	_save("18_map_later")
	tv.show_person("roderick")
	await _frames(3)
	_save("19_roderick_later")
	main.person_panel.close()

	# 快死了：休養到病倒
	h.dies_at = w.month() + LifeData.DYING_MONTHS + 2
	h.hp = 10
	main._travel("pasture") if h.location == MapData.HOME else null
	await _idle()
	tv._act(town.rest(5)) if town.in_city() else main._travel(MapData.HOME)
	await _idle()
	_save("20_deathbed")
	var cands := town.heir_candidates()
	main._heir_chosen(cands[0].id)
	await _until(func(): return main.life_view.visible)
	await _frames(3)
	_save("21_life")
	main._continue_as_heir()
	await _frames(3)
	_save("22_heir_town")
	tv.show_person(w.lives[0])
	await _frames(3)
	_save("23_old_hero_panel")
	main.person_panel.close()
	quit()


func _save(name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## 等跳年月跳完
func _idle() -> void:
	await _frames(2)
	while main.blocker.visible:
		await create_timer(0.2).timeout
	await _frames(3)


func _until(cond: Callable) -> void:
	while not cond.call():
		await create_timer(0.2).timeout
