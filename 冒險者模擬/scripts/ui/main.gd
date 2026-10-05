extends Control

## 原型：城鎮 ⇄ 戰鬥，壽命用完時看這一生（沒有通關）。花時間的事在城鎮畫面裡演（年月往上跳）。
## 這裡只負責切換畫面；城鎮規則在 Town，戰鬥規則在 Battle。

var town := Town.new()
var play_log := PlayLog.new()
var town_view: TownView
var battle_view: BattleView
## 等的時候擋住所有按鈕（透明，蓋在最上面）
var blocker: Control
var life_view: LifeView
var battle: Battle
## 現在打的是 commission 委託 / spar 師傅的考驗
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
	life_view = LifeView.new()
	life_view.restart_requested.connect(func(): get_tree().reload_current_scene())
	margin.add_child(life_view)
	blocker = Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	add_child(blocker)

	town_view.add_messages([
		{"kind": "big", "text": "你 %d 歲，帶著一把舊鐵劍和 %d 銀來到北境的小城。城裡有冒險者公會的委託板、北境劍術的道場和一間武器店。" % [LifeData.START_AGE, town.hero.money]},
		{"kind": "info", "text": "每個月生活費 %d 銀。" % TownData.LIVING_COST},
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


## 一次只顯示一個畫面。refresh = false：城鎮畫面先不更新（等的時候，跳完才更新）
func _show(view: Control, refresh := true) -> void:
	for v in [town_view, battle_view, life_view]:
		v.visible = v == view
	if view == town_view and refresh:
		town_view.refresh()


# ---------- 等（花時間的事） ----------

## w：Town.take_wait() 那一段。在城鎮畫面裡跳年月，跳的時候按鈕按不了。after：跳完之後
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
		_to_town_or_end())


## 回城。壽命用完了，停一下讓人看到最後那句，再看這一生
func _to_town_or_end() -> void:
	if town.hero.dead:
		_show(town_view)
		blocker.visible = true
		await get_tree().create_timer(DEATH_PAUSE).timeout
		blocker.visible = false
		life_view.show_life(town.hero)
		_show(life_view)
	else:
		_show(town_view)


# ---------- 委託 ----------

## 出發：路上的時間先跳，到了才開打
func _depart(enemy_id: String) -> void:
	var msgs := town.depart(enemy_id)
	_wait(town.take_wait(), func():
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


## 回城。打輸了要先躺幾個月（在城鎮畫面裡跳年月），跳完才寫結算
func _back_to_town() -> void:
	town.clear_loot()
	var msgs := _settled + town.return_to_town()
	_settled = []
	var w := town.take_wait()
	if w.is_empty():
		town_view.add_messages(msgs)
		_to_town_or_end()
		return
	_wait(w, func():
		town_view.add_messages(msgs)
		_to_town_or_end())


func _on_town_messages(msgs: Array) -> void:
	play_log.messages(msgs)
	play_log.status(town.hero)


## 打到一半關掉遊戲，也把這場寫進試玩紀錄
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and battle != null and not battle.is_over() and battle_view.visible:
		play_log.battle_end(battle)
