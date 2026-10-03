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
	"end": "#ffffff",
}

var hero := Adventurer.new()
var battle: Battle
var hero_c: Combatant
var foe_c: Combatant
var last_enemy_id := ""

# 選擇畫面
var prep_screen: Control
var prof_rows := {}  # move_id -> {"check": CheckBox, "spin": SpinBox, "label": Label}

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
var move_buttons := {}  # move_id -> Button
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
	cols.add_child(right)
	right.add_child(_heading("測試用：你會的招式"))
	var note := Label.new()
	note.text = "正式版要找師傅學。這裡先自己勾要會哪些招、多熟（0～100）。\n熟練度越高越不會失敗，打仗時用了會自己漲。\n攻擊、防禦、閃避、撤退不用學。"
	note.modulate = Color(1, 1, 1, 0.7)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(note)

	for id in MoveData.learnable_ids():
		var m: Dictionary = MoveData.MOVES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var check := CheckBox.new()
		check.text = m["name"]
		check.custom_minimum_size.x = 150
		check.tooltip_text = m["desc"]
		row.add_child(check)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 100
		spin.step = 5
		row.add_child(spin)
		var label := Label.new()
		label.custom_minimum_size.x = 80
		row.add_child(label)
		var desc := Label.new()
		desc.text = m["desc"]
		desc.modulate = Color(1, 1, 1, 0.6)
		desc.add_theme_font_size_override("font_size", 16)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)
		right.add_child(row)
		prof_rows[id] = {"check": check, "spin": spin, "label": label}
		check.toggled.connect(func(_on): _on_prof_changed(id))
		spin.value_changed.connect(func(_v): _on_prof_changed(id))
	return root


func _on_prof_changed(id: String) -> void:
	var r: Dictionary = prof_rows[id]
	if r["check"].button_pressed:
		hero.learn(id, int(r["spin"].value))
	else:
		hero.forget(id)
	_refresh_prof_row(id)


func _refresh_prof_rows() -> void:
	for id in prof_rows:
		var r: Dictionary = prof_rows[id]
		r["check"].set_pressed_no_signal(hero.knows(id))
		if hero.knows(id):
			r["spin"].set_value_no_signal(hero.proficiency[id])
		_refresh_prof_row(id)


func _refresh_prof_row(id: String) -> void:
	var r: Dictionary = prof_rows[id]
	var known := hero.knows(id)
	r["spin"].editable = known
	r["label"].text = MoveData.proficiency_label(hero.proficiency[id]) if known else "未學會"
	r["label"].modulate = Color.WHITE if known else Color(1, 1, 1, 0.4)


func _show_prep() -> void:
	_refresh_prof_rows()
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
	var row1 := HBoxContainer.new()
	var row2 := HBoxContainer.new()
	for row in [row1, row2]:
		row.add_theme_constant_override("separation", 10)
		move_box.add_child(row)
	for id in MoveData.ORDER:
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 52)
		b.pressed.connect(_on_move.bind(id))
		b.mouse_entered.connect(_show_hint.bind(id))
		(row1 if MoveData.MOVES[id]["basic"] else row2).add_child(b)
		move_buttons[id] = b

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
	if battle.is_over():
		_append_result()
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


func _append_result() -> void:
	var r := battle.result()
	var lines := []
	for id in r["gains"]:
		var p: int = hero.proficiency[id]
		lines.append("%s 熟練度 +%d（現在 %d，%s）" % [MoveData.MOVES[id]["name"], r["gains"][id], p, MoveData.proficiency_label(p)])
	if lines.is_empty():
		lines.append("這場沒有用到要練的招式。")
	log_label.append_text("[color=%s]%s[/color]\n" % [COLOR["info"], "\n".join(lines)])


func _refresh_battle() -> void:
	hero_bar.max_value = hero_c.max_hp
	hero_bar.value = hero_c.hp
	hero_hp_label.text = "%d / %d" % [hero_c.hp, hero_c.max_hp]
	hero_status.text = "位置不好：這回合攻擊減半，也躲不乾淨" if hero_c.bad_position and not battle.is_over() else ""
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
	for opt in battle.move_options(hero_c):
		var b: Button = move_buttons[opt["id"]]
		b.disabled = not opt["known"]
		b.tooltip_text = opt["desc"]
		if opt["basic"]:
			b.text = opt["name"]
		elif opt["known"]:
			b.text = "%s（%s %d）" % [opt["name"], MoveData.proficiency_label(opt["proficiency"]), opt["proficiency"]]
		else:
			b.text = "%s（未學會）" % opt["name"]


func _show_hint(id: String) -> void:
	var m: Dictionary = MoveData.MOVES[id]
	var extra := ""
	if not m["basic"]:
		if hero.knows(id):
			extra = "　成功率約 %d%%" % roundi(MoveData.success_chance(hero.proficiency[id]) * 100)
		else:
			extra = "　（還沒學會）"
	hint_label.text = "%s：%s%s" % [m["name"], m["desc"], extra]


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
