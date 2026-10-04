extends Control

## 原型第 1 段的畫面：挑敵人 → 戰鬥 → 結果。
## 只負責顯示和按鈕，規則都在 Battle。

const COLOR := {
	"round": "#8a8f98",
	"tell": "#ffd479",
	"fail": "#ff9e7a",
	"damage_out": "#9be39b",
	"damage_in": "#ff8a8a",
	"info": "#a0c4ff",
	"pain": "#c9b8a6",
	"end": "#ffffff",
}

var hero := Adventurer.new()
var battle: Battle
var hero_c: Combatant
var foe_c: Combatant
var last_enemy_id := ""

# 選擇畫面
var prep_screen: Control
var learn_checks := {}  # move_id -> CheckBox

# 戰鬥畫面
var battle_screen: Control
var hero_bar: ProgressBar
var hero_hp_label: Label
var hero_status: Label
var foe_bar: ProgressBar
var foe_hp_label: Label
var foe_name_label: Label
var log_label: RichTextLabel
var tell_label: Label
var hint_label: Label
var move_box: VBoxContainer
var basic_row: HBoxContainer
var tech_row: HBoxContainer
var end_box: HBoxContainer


func _ready() -> void:
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = Color("#1d2026")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	prep_screen = _build_prep_screen()
	battle_screen = _build_battle_screen()
	margin.add_child(prep_screen)
	margin.add_child(battle_screen)
	_show_prep()


func _make_theme() -> Theme:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei UI", "Microsoft JhengHei", "Noto Sans CJK TC", "PingFang TC"])
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 20
	return t


# ---------- 選擇畫面 ----------

func _build_prep_screen() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.text = "原型第 1 段：一場戰鬥"
	title.add_theme_font_size_override("font_size", 30)
	root.add_child(title)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 48)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# 左：敵人
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	left.add_child(_heading("挑一個敵人來打"))
	for id in EnemyData.ORDER:
		var d: Dictionary = EnemyData.ENEMIES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var b := Button.new()
		b.text = d["name"]
		b.custom_minimum_size = Vector2(160, 48)
		b.pressed.connect(_start_battle.bind(id))
		row.add_child(b)
		var l := Label.new()
		l.text = d["blurb"]
		l.modulate = Color(1, 1, 1, 0.7)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		left.add_child(row)

	# 右：測試用的招式設定
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(right)
	cols.add_child(scroll)
	right.add_child(_heading("測試用：你會的招式"))
	var note := Label.new()
	note.text = "正式版要找師傅學。建議一開始什麼都不勾，打輸了再勾一招，體驗「學到新招」。\n戰鬥時，攻擊、防禦、閃避人人都會。會的招總共 5 招以內就全部出現；超過的話每回合挑 5 個，剋制對手那招的比較容易出現，用了也白費的很少出現，而且至少一個攻擊類、一個防守類。撤退永遠可以選。"
	note.modulate = Color(1, 1, 1, 0.7)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(note)

	for id in MoveData.LEARNABLE:
		var m: Dictionary = MoveData.MOVES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var check := CheckBox.new()
		check.text = m["name"]
		check.custom_minimum_size.x = 150
		check.toggled.connect(func(on): hero.learn(id) if on else hero.forget(id))
		row.add_child(check)
		var desc := Label.new()
		desc.text = m["desc"]
		desc.modulate = Color(1, 1, 1, 0.6)
		desc.add_theme_font_size_override("font_size", 16)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)
		right.add_child(row)
		learn_checks[id] = check
	return root


func _show_prep() -> void:
	for id in learn_checks:
		learn_checks[id].set_pressed_no_signal(hero.knows(id))
	prep_screen.visible = true
	battle_screen.visible = false


# ---------- 戰鬥畫面 ----------

func _build_battle_screen() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)

	# 上：雙方血量
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 40)
	root.add_child(top)
	var hero_col := _hp_column("你", Color("#5fbf6a"))
	hero_bar = hero_col["bar"]
	hero_hp_label = hero_col["hp"]
	hero_status = Label.new()
	hero_status.add_theme_color_override("font_color", Color("#ff9e7a"))
	hero_status.add_theme_font_size_override("font_size", 16)
	hero_col["box"].add_child(hero_status)
	top.add_child(hero_col["box"])
	var foe_col := _hp_column("", Color("#d0574f"))
	foe_bar = foe_col["bar"]
	foe_hp_label = foe_col["hp"]
	foe_name_label = foe_col["name"]
	top.add_child(foe_col["box"])

	# 中：戰鬥紀錄
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_child(log_label)
	root.add_child(log_panel)

	# 敵人現在的動作
	tell_label = Label.new()
	tell_label.add_theme_color_override("font_color", Color(COLOR["tell"]))
	tell_label.add_theme_font_size_override("font_size", 24)
	tell_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(tell_label)

	# 下：招式按鈕
	move_box = VBoxContainer.new()
	move_box.add_theme_constant_override("separation", 8)
	root.add_child(move_box)
	tech_row = HBoxContainer.new()
	basic_row = HBoxContainer.new()
	for row in [tech_row, basic_row]:
		row.add_theme_constant_override("separation", 10)
		move_box.add_child(row)

	hint_label = Label.new()
	hint_label.modulate = Color(1, 1, 1, 0.6)
	hint_label.add_theme_font_size_override("font_size", 16)
	root.add_child(hint_label)

	# 結束後的按鈕
	end_box = HBoxContainer.new()
	end_box.add_theme_constant_override("separation", 10)
	var again := Button.new()
	again.text = "再打一次"
	again.custom_minimum_size = Vector2(170, 52)
	again.pressed.connect(func(): _start_battle(last_enemy_id))
	end_box.add_child(again)
	var back := Button.new()
	back.text = "回到選擇"
	back.custom_minimum_size = Vector2(170, 52)
	back.pressed.connect(_show_prep)
	end_box.add_child(back)
	root.add_child(end_box)
	return root


func _start_battle(enemy_id: String) -> void:
	last_enemy_id = enemy_id
	hero_c = hero.to_combatant()
	foe_c = Combatant.from_enemy(enemy_id)
	battle = Battle.new([hero_c], [foe_c])
	log_label.clear()
	foe_name_label.text = foe_c.display_name
	prep_screen.visible = false
	battle_screen.visible = true
	_append(battle.start())
	_refresh_battle()


func _on_move(id: String) -> void:
	if battle == null or battle.is_over():
		return
	_append(battle.play_round({hero_c: {"move": id, "target": foe_c}}))
	_refresh_battle()


func _append(events: Array) -> void:
	for e in events:
		var text: String = e["text"]
		match e["kind"]:
			"round":
				log_label.append_text("\n[color=%s]── %s ──[/color]\n" % [COLOR["round"], text])
			"tell":
				log_label.append_text("[color=%s][b]%s[/b][/color]\n" % [COLOR["tell"], text])
			"action":
				log_label.append_text(text + "\n")
			"end":
				log_label.append_text("\n[b][font_size=26]%s[/font_size][/b]\n" % text)
			_:
				log_label.append_text("[color=%s]%s[/color]\n" % [COLOR.get(e["kind"], "#ffffff"), text])


func _refresh_battle() -> void:
	hero_bar.max_value = hero_c.max_hp
	hero_bar.value = hero_c.hp
	hero_hp_label.text = "%d / %d" % [hero_c.hp, hero_c.max_hp]
	hero_status.text = "" if battle.is_over() else hero_c.hand_note
	foe_bar.max_value = foe_c.max_hp
	foe_bar.value = foe_c.hp
	foe_hp_label.text = "%d / %d" % [foe_c.hp, foe_c.max_hp]

	var over := battle.is_over()
	move_box.visible = not over
	hint_label.visible = not over
	end_box.visible = over
	tell_label.text = "" if over else "▶ " + foe_c.intent["text"]
	if over:
		return
	# 手上的招每回合都不同，重新排按鈕
	for row in [tech_row, basic_row]:
		for child in row.get_children():
			child.queue_free()
	# 所有選項都是抽出來的，排成一排
	basic_row.visible = false
	for opt in battle.hand_options(hero_c):
		var b := Button.new()
		b.text = opt["name"]
		b.tooltip_text = opt["desc"]
		b.custom_minimum_size = Vector2(150, 52)
		b.pressed.connect(_on_move.bind(opt["id"]))
		b.mouse_entered.connect(_show_hint.bind(opt["id"]))
		tech_row.add_child(b)
	# 撤退跟招式分開，放在最右邊
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tech_row.add_child(spacer)
	var flee := Button.new()
	flee.text = "撤退"
	flee.custom_minimum_size = Vector2(120, 52)
	flee.disabled = not battle.can_flee(hero_c)
	flee.pressed.connect(_on_move.bind(MoveData.FLEE))
	flee.mouse_entered.connect(_show_hint.bind(MoveData.FLEE))
	tech_row.add_child(flee)
	hint_label.text = ""


func _show_hint(id: String) -> void:
	var m: Dictionary = MoveData.MOVES[id]
	hint_label.text = "%s：%s" % [m["name"], m["desc"]]


# ---------- 小工具 ----------

func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	return l


func _hp_column(name_text: String, fill_color: Color) -> Dictionary:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var hp := Label.new()
	head.add_child(hp)
	box.add_child(head)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 18
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	return {"box": box, "bar": bar, "hp": hp, "name": name_label}
