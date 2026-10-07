class_name LifeView
extends CenterContainer

## 這一生：怎麼開始、打倒了誰、學會什麼、拿到什麼、幾歲死。照時間一行一行列。
## 死後出現。臨終時選好了接手的人，就能換他接著玩（世界還在，記得上一個人）；也可以重新開始。

signal continue_requested
signal restart_requested
## 死得突然（被人殺了），沒來得及交代：在這裡選誰接著玩
signal heir_picked(person_id: String)

var title_label: Label
var text: RichTextLabel
var continue_button: Button
var pick_row: HBoxContainer


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := UiKit.vbox(16)
	box.custom_minimum_size = Vector2(760, 620)
	add_child(box)
	title_label = UiKit.label("", 30)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.add_theme_font_size_override("normal_font_size", 19)
	text.add_theme_constant_override("line_separation", 8)
	panel.add_child(text)
	box.add_child(panel)
	pick_row = UiKit.hbox(12)
	pick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(pick_row)
	var row := UiKit.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	continue_button = UiKit.button("", 260, 50)
	continue_button.pressed.connect(func(): continue_requested.emit())
	row.add_child(continue_button)
	var again := UiKit.button("重新開始", 190, 50)
	again.pressed.connect(func(): restart_requested.emit())
	row.add_child(again)
	box.add_child(row)


## heir：接手的人。沒有（死得突然）就從 candidates 裡選一個；都沒有就只能重新開始
func show_life(world: World, h: Person, heir: Person, candidates: Array = []) -> void:
	UiKit.clear(pick_row)
	if heir == null:
		for p in candidates.slice(0, 3):
			var b := UiKit.button("接著玩：%s" % p.display_name, 220, 50)
			b.pressed.connect(func(): heir_picked.emit(p.id))
			pick_row.add_child(b)
	title_label.text = "這一生：%s" % h.display_name
	title_label.add_theme_color_override("font_color", Color(UiKit.MSG_COLOR["big"]))
	text.clear()
	# 兩欄：左邊年紀，右邊發生的事
	var rows := []
	if world.lives.is_empty():
		rows.append([0, "帶著一把舊鐵劍來到北境的霜溪城"])
	for e in h.history:
		rows.append([e["month"], world.fmt(e["text"])])
	if h.dead:
		rows.append([h.died_at, "死在%s" % MapData.place_name(h.location)])
	var bb := "[table=2]"
	for r in rows:
		bb += "[cell][color=#9aa3ad]%s　[/color][/cell][cell]%s。[/cell]" % [LifeData.date_text(h.age_at(r[0]), r[0]), r[1]]
	text.append_text(bb + "[/table]")
	# 之前的人
	if not world.lives.is_empty():
		var before := world.lives.map(func(id): return world.person(id).display_name)
		text.append_text("\n[color=#9aa3ad]在%s之前：%s[/color]" % [h.display_name, "、".join(before)])
	continue_button.visible = heir != null
	if heir != null:
		continue_button.text = "接著玩：%s" % heir.display_name
