extends SceneTree

## 截圖檢查（開發用）：人開口、有人來找你的畫面。酒館的傳聞、有人來找你的對話、找上門算帳（記得你）、人物面板上「跟你」。
## 執行（要有畫面）：Godot --path . --script res://tests/shot_talk.gd -- <輸出資料夾>

var main: Control
var out := ""


func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var tv: TownView = main.town_view
	var town: Town = main.town
	var w: World = town.world
	var h: Person = town.hero
	town.road_boost = 0.0
	h.dies_at = 99999

	# 世界過了兩年：紀錄裡沒有傳聞，傳聞在酒館
	for i in 24:
		town._pass_months(1)
	town.visits.budget = 0
	w.tidings.clear()
	tv.refresh()
	_save("t01_town_quiet")
	tv.tabs.current_tab = tv.tavern_view.get_index()
	await _frames(3)
	_save("t02_tavern")

	# 接下布蘭的懸賞：葛雷森來找你
	h.money = 500
	tv.add_messages(town.accept_bounty("bran"))
	town.visits.reset()
	main._after_time()
	await _frames(3)
	_save("t03_warn")
	main.encounter.visible = false
	main._answer_visit("defy")
	await _frames(3)

	# 你放過的人回來報恩（城裡）
	var hakon := w.person("hakon")
	hakon.location = MapData.HOME
	hakon.travel_left = 0
	hakon.grateful.append(h.id)
	w.remember(hakon, "spared", {"place": "relay"})
	town.visits.current = {"kind": "repay", "who": "hakon"}
	var v := town.visits.view()
	main.encounter.show_choice(v["title"], v["color"], v["text"], v["options"], main._answer_visit)
	await _frames(3)
	_save("t04_repay")
	main.encounter.visible = false
	main._answer_visit("no")
	await _frames(3)

	# 拿走你東西的人死了：有人來告訴你
	var magnus := w.person("magnus")
	h.lost_items["steel_sword"] = magnus.id
	magnus.give_item("steel_sword")
	w.remember(magnus, "beat_you", {"item": "steel_sword", "place": "wheat"})
	w.settle(w.person("roderick"), magnus, true)
	town.visits.reset()
	town.visits.approach_budget = 0
	main._after_time()
	await _frames(3)
	_save("t05_tiding_death")
	main.encounter.visible = false
	main._answer_visit("ok")
	await _frames(3)

	# 你搶過的人找上門
	var sira := w.person("sira")
	sira.location = h.location
	sira.travel_left = 0
	w.remember(sira, "robbed_by_you", {"item": "steel_sword", "place": "bridge"})
	w.add_grudge(sira, h.id, "beaten")
	sira.target = h.id
	sira.rest_left = 0
	main._after_time()
	await _frames(3)
	_save("t06_comer")
	main.encounter.visible = false
	sira.target = ""
	sira.rest_left = 10

	# 人物面板：跟你
	tv.show_person("hakon")
	main.person_panel.tabs.current_tab = 3
	main.person_panel.refresh()
	await _frames(3)
	_save("t07_panel_with_you")
	main.person_panel.close()
	quit()


func _save(name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _frames(n: int) -> void:
	for i in n:
		await process_frame
