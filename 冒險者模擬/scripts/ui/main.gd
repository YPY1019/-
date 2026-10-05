extends Control

## 原型（自動戰鬥試驗）：城鎮 ⇄ 戰鬥。
## 這裡只負責切換畫面；城鎮規則在 Town，戰鬥規則在 Battle。

var town := Town.new()
var play_log := PlayLog.new()
var town_view: TownView
var battle_view: BattleView
var battle: Battle
## 現在打的是 commission 委託 / spar 師傅的考驗
var fight_kind := ""
var _settled := []


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
	town_view.commission_requested.connect(_start_commission)
	town_view.spar_requested.connect(_start_spar)
	town_view.messages_added.connect(_on_town_messages)
	margin.add_child(town_view)
	battle_view = BattleView.new()
	battle_view.ended.connect(_on_battle_ended)
	battle_view.closed.connect(_back_to_town)
	battle_view.loot_taken.connect(_take_loot)
	battle_view.equip_requested.connect(_equip)
	margin.add_child(battle_view)

	town_view.add_messages([
		{"kind": "big", "text": "你帶著一把舊鐵劍和 %d 銀來到北境的小城。城裡有冒險者公會的委託板、北境劍術的道場和一間武器店。" % town.hero.money},
		{"kind": "info", "text": "目標：打倒食人魔。每天生活費 %d 銀。" % TownData.LIVING_COST},
	])
	_back_to_town()


func _make_theme() -> Theme:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei UI", "Microsoft JhengHei", "Noto Sans CJK TC", "PingFang TC"])
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 20
	return t


func _start_commission(enemy_id: String) -> void:
	fight_kind = "commission"
	battle = town.start_commission(enemy_id)
	play_log.battle_start("委託：%s" % EnemyData.ENEMIES[enemy_id]["name"], battle)
	_show_battle("")


func _start_spar() -> void:
	fight_kind = "spar"
	battle = town.start_spar()
	play_log.battle_start("師傅的考驗：接住我三招", battle)
	_show_battle("")


func _show_battle(note: String) -> void:
	town_view.visible = false
	battle_view.visible = true
	battle_view.begin(battle, note)


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


func _back_to_town() -> void:
	town.clear_loot()
	battle_view.visible = false
	town_view.visible = true
	town_view.add_messages(_settled + town.return_to_town())
	_settled = []
	town_view.refresh()


func _on_town_messages(msgs: Array) -> void:
	play_log.messages(msgs)
	play_log.status(town.hero)


## 打到一半關掉遊戲，也把這場寫進試玩紀錄
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and battle != null and not battle.is_over() and battle_view.visible:
		play_log.battle_end(battle)
