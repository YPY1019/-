extends Control

## 原型：城鎮 ⇄ 等的畫面 ⇄ 戰鬥，壽命用完（或打倒食人魔）時看這一生。
## 這裡只負責切換畫面；城鎮規則在 Town，戰鬥規則在 Battle。

var town := Town.new()
var play_log := PlayLog.new()
var town_view: TownView
var battle_view: BattleView
var wait_view: WaitView
var life_view: LifeView
var battle: Battle
## 現在打的是 commission 委託 / spar 師傅的考驗
var fight_kind := ""
var _settled := []
## 等的畫面演完要做的事
var _after_wait := Callable()
## 打倒食人魔的那一生已經看過了
var _clear_shown := false


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
	town_view.commission_requested.connect(_depart)
	town_view.spar_requested.connect(_start_spar)
	town_view.wait_requested.connect(_on_wait_requested)
	town_view.messages_added.connect(_on_town_messages)
	margin.add_child(town_view)
	battle_view = BattleView.new()
	battle_view.ended.connect(_on_battle_ended)
	battle_view.closed.connect(_back_to_town)
	battle_view.loot_taken.connect(_take_loot)
	battle_view.equip_requested.connect(_equip)
	margin.add_child(battle_view)
	wait_view = WaitView.new()
	wait_view.finished.connect(_on_wait_finished)
	margin.add_child(wait_view)
	life_view = LifeView.new()
	life_view.restart_requested.connect(func(): get_tree().reload_current_scene())
	life_view.continue_requested.connect(_show.bind(town_view))
	margin.add_child(life_view)

	town_view.add_messages([
		{"kind": "big", "text": "你 %d 歲，帶著一把舊鐵劍和 %d 銀來到北境的小城。城裡有冒險者公會的委託板、北境劍術的道場和一間武器店。" % [LifeData.START_AGE, town.hero.money]},
		{"kind": "info", "text": "目標：壽命用完之前，打倒食人魔。每個月生活費 %d 銀。" % TownData.LIVING_COST},
	])
	_show(town_view)
	town_view.refresh()


func _make_theme() -> Theme:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei UI", "Microsoft JhengHei", "Noto Sans CJK TC", "PingFang TC"])
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 20
	return t


## 一次只顯示一個畫面
func _show(view: Control) -> void:
	for v in [town_view, battle_view, wait_view, life_view]:
		v.visible = v == view
	if view == town_view:
		town_view.refresh()


# ---------- 等的畫面 ----------

## w：Town.take_wait() 那一段。results：跳完才給的結果。after：演完之後
func _wait(w: Dictionary, results: Array, after: Callable) -> void:
	_after_wait = after
	_show(wait_view)
	wait_view.play(w, results)


func _on_wait_finished() -> void:
	if not _after_wait.is_valid():
		return
	var after := _after_wait
	_after_wait = Callable()
	after.call()


## 城裡花時間的事（學招、讀秘笈、休養）：演完才寫進紀錄
func _on_wait_requested(w: Dictionary, msgs: Array) -> void:
	_wait(w, msgs, func():
		town_view.add_messages(msgs)
		_to_town_or_end())


## 回城。壽命用完了就看這一生
func _to_town_or_end() -> void:
	if town.hero.dead:
		life_view.show_life(town.hero)
		_show(life_view)
	elif town.hero.cleared and not _clear_shown:
		_clear_shown = true
		life_view.show_life(town.hero)
		_show(life_view)
	else:
		_show(town_view)


# ---------- 委託 ----------

## 出發：路上的時間先演，到了才開打
func _depart(enemy_id: String) -> void:
	var msgs := town.depart(enemy_id)
	_wait(town.take_wait(), msgs.filter(func(m): return m["kind"] == "epic"), func():
		town_view.add_messages(msgs)
		if town.hero.dead:
			_to_town_or_end()
		else:
			_start_commission(enemy_id))


func _start_commission(enemy_id: String) -> void:
	fight_kind = "commission"
	battle = town.start_commission()
	play_log.battle_start("委託：%s" % EnemyData.ENEMIES[enemy_id]["name"], battle)
	_show_battle()


func _start_spar() -> void:
	fight_kind = "spar"
	battle = town.start_spar()
	play_log.battle_start("師傅的考驗：接住我三招", battle)
	_show_battle()


func _show_battle() -> void:
	_show(battle_view)
	battle_view.begin(battle)


func _on_battle_ended() -> void:
	play_log.battle_end(battle)
	_settled = town.finish_commission(battle) if fight_kind == "commission" else town.finish_spar(battle)
	battle_view.show_settlement(_settled)
	if not town.loot.is_empty():
		battle_view.show_loot(town.hero, town.loot)


## 拿到的東西接在結算後面，回城時一起寫進城裡的紀錄
func _take_loot(id: String) -> void:
	var msgs := town.take_loot(id)
	_settled.append_array(msgs)
	battle_view.show_settlement(msgs)
	battle_view.refresh_loot(town.hero, town.loot)


func _equip(id: String) -> void:
	play_log.messages(town.equip(id))
	battle_view.refresh_loot(town.hero, town.loot)


## 回城。打輸了要先躺幾個月（演等的畫面；結算已經寫在戰報下面，只有死去要再寫）
func _back_to_town() -> void:
	town.clear_loot()
	var msgs := _settled + town.return_to_town()
	_settled = []
	var w := town.take_wait()
	if w.is_empty():
		town_view.add_messages(msgs)
		_to_town_or_end()
		return
	_wait(w, msgs.filter(func(m): return m["kind"] == "epic"), func():
		town_view.add_messages(msgs)
		_to_town_or_end())


func _on_town_messages(msgs: Array) -> void:
	play_log.messages(msgs)
	play_log.status(town.hero)


## 打到一半關掉遊戲，也把這場寫進試玩紀錄
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and battle != null and not battle.is_over() and battle_view.visible:
		play_log.battle_end(battle)
