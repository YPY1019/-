extends Control

## 原型第 2 段：城鎮 ⇄ 戰鬥。
## 這裡只負責切換畫面；城鎮規則在 Town，戰鬥規則在 Battle。

var town := Town.new()
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
	margin.add_child(town_view)
	battle_view = BattleView.new()
	battle_view.ended.connect(_on_battle_ended)
	battle_view.closed.connect(_back_to_town)
	margin.add_child(battle_view)

	town_view.add_messages([
		{"kind": "big", "text": "你帶著一把劍和 %d 銀來到北境的小城。城裡有冒險者公會的委託板，也有一間北境劍術的道場。" % town.hero.money},
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
	_show_battle("")


func _start_spar() -> void:
	fight_kind = "spar"
	battle = town.start_spar()
	var me: Combatant = battle.allies[0]
	_show_battle("（木劍過招：撐過 %d 回合就通過。血量掉到 %d 就算輸。）" % [SchoolData.SPAR_ROUNDS, me.yield_hp])


func _show_battle(note: String) -> void:
	town_view.visible = false
	battle_view.visible = true
	battle_view.begin(battle, note)


func _on_battle_ended() -> void:
	_settled = town.finish_commission(battle) if fight_kind == "commission" else town.finish_spar(battle)
	battle_view.show_settlement(_settled)


func _back_to_town() -> void:
	battle_view.visible = false
	town_view.visible = true
	town_view.add_messages(_settled)
	_settled = []
	town_view.refresh()
