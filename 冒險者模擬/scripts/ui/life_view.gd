class_name LifeView
extends CenterContainer

## 這一輩子：幾歲出道、打倒了誰、學會什麼、拿到什麼、幾歲死。照時間一行一行列。
## 壽命用完時出現（只能重新開始）；打倒食人魔時也出現一次（可以繼續過日子）。

signal restart_requested
signal continue_requested

var title_label: Label
var text: RichTextLabel
var go_button: Button


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
	var row := UiKit.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	go_button = UiKit.button("繼續過日子", 190, 50)
	go_button.pressed.connect(func(): continue_requested.emit())
	row.add_child(go_button)
	var again := UiKit.button("重新開始", 190, 50)
	again.pressed.connect(func(): restart_requested.emit())
	row.add_child(again)
	box.add_child(row)


func show_life(h: Adventurer) -> void:
	title_label.text = "★ 原型通關" if h.cleared and not h.dead else "這一生"
	title_label.add_theme_color_override("font_color", Color(UiKit.MSG_COLOR["big"]))
	go_button.visible = not h.dead
	text.clear()
	# 兩欄：左邊年紀，右邊發生的事
	var rows := [[0, "帶著一把舊鐵劍來到北境的小城"]]
	for e in h.history:
		rows.append([e["month"], e["text"]])
	if h.dead:
		rows.append([h.month, "死在北境的小城"])
	var bb := "[table=2]"
	for r in rows:
		bb += "[cell][color=#9aa3ad]%s　[/color][/cell][cell]%s。[/cell]" % [LifeData.date_text(r[0]), r[1]]
	text.append_text(bb + "[/table]")
