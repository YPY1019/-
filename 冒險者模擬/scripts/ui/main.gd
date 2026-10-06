extends Control

## 原型：主畫面 ⇄ 戰鬥，死後看這一生，再換一個人接著玩（沒有通關）。花時間的事在主畫面裡演（年月往上跳）。
## 這裡只負責切換畫面和流程；規則在 Town（你能做的事）、World（世界自己過日子）、Battle（戰鬥）。
##
## 花了時間之後（_after_time）：死了 → 這一生；病倒了 → 安排後事；有人找上門 → 開打；都沒有 → 回主畫面。

var town := Town.new()
var play_log := PlayLog.new()
var town_view: TownView
var battle_view: BattleView
## 等的時候擋住所有按鈕（透明，蓋在最上面）
var blocker: Control
var life_view: LifeView
var person_panel: PersonPanel
var encounter: EncounterDialog
## 找上門、正在跟你說話的人
var _comer: Person
var battle: Battle
## 現在打的是 monster 委託的怪物（和劍庭要你去打的人）/ person 世界上的人 / spar 劍庭的選拔 / trial 劍庭的公開比試
var fight_kind := ""
var _settled := []
## 死去那一句停多久，才換到「這一生」
const DEATH_PAUSE := 2.5


func _ready() -> void:
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = Color("#1d2026")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	town_view = TownView.new(town)
	town_view.monster_requested.connect(_meet_monster)
	town_view.fight_requested.connect(_fight_person)
	town_view.travel_requested.connect(_travel)
	town_view.spar_requested.connect(_start_spar)
	town_view.trial_requested.connect(_start_trial)
	town_view.person_requested.connect(func(id): person_panel.show_person(id))
	town_view.heir_chosen.connect(_heir_chosen)
	town_view.wait_requested.connect(_on_wait_requested)
	town_view.messages_added.connect(_on_town_messages)
	margin.add_child(town_view)
	battle_view = BattleView.new()
	battle_view.ended.connect(_on_battle_ended)
	battle_view.closed.connect(_close_battle)
	battle_view.loot_taken.connect(_take_loot)
	battle_view.equip_requested.connect(_equip)
	battle_view.fate_chosen.connect(_fate_chosen)
	margin.add_child(battle_view)
	life_view = LifeView.new()
	life_view.continue_requested.connect(_continue_as_heir)
	life_view.restart_requested.connect(func(): get_tree().reload_current_scene())
	margin.add_child(life_view)
	person_panel = PersonPanel.new(town)
	person_panel.travel_requested.connect(_travel)
	person_panel.fight_requested.connect(_fight_person)
	person_panel.inquiry_done.connect(func(msgs): town_view.add_messages(msgs))
	add_child(person_panel)
	encounter = EncounterDialog.new()
	encounter.chosen.connect(_answer_comer)
	add_child(encounter)
	town_view.dialog = encounter
	blocker = Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	add_child(blocker)

	var h := town.hero
	town_view.add_messages([
		{"kind": "big", "text": "你叫%s，%d 歲，帶著一把舊鐵劍和 %d 銀來到北境的霜溪城。城裡有冒險者公會、練武場、獅心劍庭和一間武器店。" % [h.display_name, h.age(), h.money]},
	])
	_show(town_view)


func _make_theme() -> Theme:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei UI", "Microsoft JhengHei", "Noto Sans CJK TC", "PingFang TC"])
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 20
	return t


## 一次只顯示一個畫面。refresh = false：主畫面先不更新（等的時候，跳完才更新）
func _show(view: Control, refresh := true) -> void:
	for v in [town_view, battle_view, life_view]:
		v.visible = v == view
	if view == town_view and refresh:
		town_view.refresh()


# ---------- 等（花時間的事） ----------

## w：Town.take_wait() 那一段。在主畫面裡跳年月，跳的時候按鈕按不了。after：跳完之後
func _wait(w: Dictionary, after: Callable) -> void:
	_show(town_view, false)
	blocker.visible = true
	town_view.play_wait(w, func():
		blocker.visible = false
		after.call())


## 城裡花時間的事（學招、讀秘笈、休養）：跳完才寫結果
func _on_wait_requested(w: Dictionary, msgs: Array) -> void:
	_wait(w, func():
		town_view.add_messages(msgs)
		_after_time())


## 花了時間之後：死了看這一生；有人找上門就開打；不然回主畫面（病倒了主畫面會換成安排後事）
func _after_time() -> void:
	if town.hero.dead:
		_show(town_view)
		blocker.visible = true
		await get_tree().create_timer(DEATH_PAUSE).timeout
		blocker.visible = false
		var heir := town.world.person(town.heir_id) if town.heir_id != "" else null
		life_view.show_life(town.world, town.hero, heir)
		_show(life_view)
		return
	var comer := town.comer()
	if comer != null:
		# 先跳對話：他說什麼、你怎麼回
		_show(town_view)
		_comer = comer
		encounter.ask(comer, town.comer_text(comer), town.comer_options(comer))
		return
	_show(town_view)


func _answer_comer(choice: String) -> void:
	var p := _comer
	_comer = null
	var r := town.answer_comer(p, choice)
	town_view.add_messages([{"kind": "bad", "text": town.comer_text(p)}] + r["msgs"])
	if r["fight"]:
		_start_person(p.id, "找上門來")


# ---------- 走路、委託、找人打 ----------

## 走到別的地方：路上的時間先跳，到了打開地圖
func _travel(place: String) -> void:
	var msgs := town.travel(place)
	if msgs.is_empty() and town.road.is_empty():
		return
	_walk_then(msgs)


## 走路的時間跳完：路上碰上事就跳出來；不然到了
func _walk_then(msgs: Array) -> void:
	var w := town.take_wait()
	var after := func():
		town_view.add_messages(msgs)
		if not town.road.is_empty() and not town.hero.dying() and not town.hero.dead:
			_road_dialog()
		else:
			_arrived()
	if w.is_empty():
		after.call()
	else:
		_wait(w, after)


## 到了：打開地圖；有人找上門先處理；走到接了委託的地方，碰上了
func _arrived() -> void:
	if not town.hero.dying() and not town.hero.dead:
		town_view.show_map()
	_after_time()
	if town_view.visible and not encounter.visible and not town.hero.dying() and not town.hero.dead:
		var jobs := town.jobs_here()
		if not jobs.is_empty():
			_meet_monster(jobs[0])


## 路上碰上的事
func _road_dialog() -> void:
	_show(town_view)
	var ev := town.road_event()
	encounter.show_choice(ev["title"], Color.WHITE, ev["text"], ev["options"], _answer_road)


func _answer_road(choice: String) -> void:
	var r := town.answer_road(choice)
	town_view.add_messages(r["msgs"])
	var fight: String = r["fight"]
	if fight.begins_with("enemy:"):
		_start_monster(fight.substr(6))
	elif fight.begins_with("person:"):
		_start_person(fight.substr(7), "路上")
	else:
		_continue_road(r["extra"])


## 路上的事處理完，走完剩下的路
func _continue_road(extra := 0) -> void:
	_walk_then(town.continue_travel(extra))


## 走到委託的地方、或在地圖上按「去找」：先跳出看到的情況，再決定打不打
func _meet_monster(enemy_id: String) -> void:
	var ev := town.monster_event(enemy_id)
	var e: Dictionary = EnemyData.ENEMIES[enemy_id]
	var dg := EnemyData.danger(enemy_id)
	encounter.show_choice(ev["title"], Color(dg["color"]), ev["text"], ev["options"], _answer_monster.bind(enemy_id))


func _answer_monster(choice: String, enemy_id: String) -> void:
	var r := town.answer_monster(enemy_id, choice)
	town_view.add_messages(r["msgs"])
	if r["fight"]:
		_start_monster(enemy_id)


func _start_monster(enemy_id: String) -> void:
	fight_kind = "monster"
	battle = town.start_monster(enemy_id)
	play_log.battle_start("委託：%s" % EnemyData.ENEMIES[enemy_id]["name"], battle)
	_show_battle()


func _fight_person(id: String) -> void:
	if town.can_fight(id):
		_start_person(id, "動手")


func _start_person(id: String, why: String) -> void:
	fight_kind = "person"
	battle = town.start_person(id)
	play_log.battle_start("%s：%s" % [why, town.world.who(id)], battle)
	_show_battle()


func _start_spar() -> void:
	fight_kind = "spar"
	battle = town.start_spar()
	play_log.battle_start("劍庭的選拔", battle)
	_show_battle()


func _start_trial() -> void:
	fight_kind = "trial"
	battle = town.start_trial()
	play_log.battle_start("公開比試", battle)
	_show_battle()


func _show_battle() -> void:
	_show(battle_view)
	battle_view.begin(battle)


func _on_battle_ended() -> void:
	play_log.battle_end(battle)
	match fight_kind:
		"monster":
			_settled = town.finish_monster(battle)
		"person":
			_settled = town.finish_person(battle)
		"trial":
			_settled = town.finish_trial(battle)
		_:
			_settled = town.finish_spar(battle)
	battle_view.show_settlement(_settled)
	# 打贏了人：先決定殺不殺，再看他身上的東西
	if fight_kind == "person" and town.fate_pending != null:
		battle_view.show_fate(town.fate_pending.pron)
	elif not town.loot.is_empty():
		battle_view.show_loot(town.hero, town.loot)


## 殺了他，還是放他走
func _fate_chosen(kill: bool) -> void:
	var msgs := town.decide_fate(kill)
	_settled.append_array(msgs)
	battle_view.show_settlement(msgs)
	if not town.loot.is_empty():
		battle_view.show_loot(town.hero, town.loot)


## 拿到的東西接在結算後面，回主畫面時一起寫進紀錄
func _take_loot(id: String) -> void:
	var msgs := town.take_loot(id)
	_settled.append_array(msgs)
	battle_view.show_settlement(msgs)
	battle_view.refresh_loot(town.hero, town.loot)


func _equip(id: String) -> void:
	play_log.messages(town.equip(id))
	battle_view.refresh_loot(town.hero, town.loot)


## 離開戰鬥畫面。打輸了要先躺幾個月（在主畫面裡跳年月），跳完才寫結算
func _close_battle() -> void:
	# 沒選就離開：放他走
	if town.fate_pending != null:
		_settled.append_array(town.decide_fate(false))
	town.clear_loot()
	var msgs := _settled + town.after_fight()
	_settled = []
	var w := town.take_wait()
	# 路上打完（沒被打倒）：接著走
	if w.is_empty() and not town.road.is_empty():
		town_view.add_messages(msgs)
		_show(town_view)
		_continue_road()
		return
	if w.is_empty():
		town_view.add_messages(msgs)
		_after_time()
		return
	_wait(w, func():
		town_view.add_messages(msgs)
		_after_time())


# ---------- 臨終、換人 ----------

## 選好接手的人：躺到最後
func _heir_chosen(id: String) -> void:
	town.choose_heir(id)
	var p := town.world.person(id)
	var msgs := town.wait_out()
	msgs.push_front({"kind": "big", "text": "你把%s叫到床邊，把東西交給了%s。" % [p.display_name, p.pron]})
	_wait(town.take_wait(), func():
		town_view.add_messages(msgs)
		_after_time())


func _continue_as_heir() -> void:
	var msgs := town.succeed()
	town_view.add_messages(msgs)
	_show(town_view)
	town_view.show_map()


func _on_town_messages(msgs: Array) -> void:
	play_log.messages(msgs)
	play_log.status(town.hero)


## 打到一半關掉遊戲，也把這場寫進試玩紀錄
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and battle != null and not battle.is_over() and battle_view.visible:
		play_log.battle_end(battle)
