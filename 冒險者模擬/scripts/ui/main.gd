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
	margin.add_child(battle_view)

	town_view.add_messages([
		{"kind": "big", "text": "你帶著一把舊鐵劍和 %d 銀來到北境的小城。城裡有冒險者公會的委託板、一間北境劍術的道場，還有一間只賣普通貨的武器店。" % town.hero.money},
		{"kind": "info", "text": "戰鬥會自己打，你只要決定接哪個委託、學什麼、買什麼。打的時候可以調速度、隨時撤退，也可以設血剩多少就自動撤退。"},
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
	var me: Combatant = battle.allies[0]
	_show_battle("（木劍過招：撐過 %d 回合就通過。血量掉到 %d 就算輸。）" % [SchoolData.SPAR_ROUNDS, me.yield_hp])


func _show_battle(note: String) -> void:
	town_view.visible = false
	battle_view.visible = true
	battle_view.begin(battle, note)


func _on_battle_ended() -> void:
	play_log.battle_end(battle)
	_settled = town.finish_commission(battle) if fight_kind == "commission" else town.finish_spar(battle)
	battle_view.show_settlement(_settled)


func _back_to_town() -> void:
	battle_view.visible = false
	town_view.visible = true
	town_view.add_messages(_settled)
	_settled = []
	town_view.refresh()


func _on_town_messages(msgs: Array) -> void:
	play_log.messages(msgs)
	play_log.status(town.hero)


## 打到一半關掉遊戲，也把這場寫進試玩紀錄
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and battle != null and not battle.is_over() and battle_view.visible:
		play_log.battle_end(battle)
