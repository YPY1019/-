class_name EncounterDialog
extends Control

## 有人找上門：先跳一個對話（他說什麼、你怎麼回），選了才決定打不打。
## 只負責顯示和按鈕：選項和結果都由 Town 決定（Town.comer_options / answer_comer）。

## 選了哪一個（選項的 id）
signal chosen(choice: String)

var text_label: Label
var name_label: Label
var button_row: HBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(620, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#23272e")
	style.border_color = Color("#4a505a")
	style.set_border_width_all(2)
	style.set_content_margin_all(22)
	frame.add_theme_stylebox_override("panel", style)
	center.add_child(frame)
	var box := UiKit.vbox(16)
	frame.add_child(box)
	name_label = UiKit.label("", 24)
	box.add_child(name_label)
	text_label = UiKit.label("", 19, 0.9, true)
	text_label.custom_minimum_size.x = 570
	box.add_child(text_label)
	button_row = UiKit.hbox(12)
	box.add_child(button_row)


## who：找上門的人。options：[[id, 按鈕的字]]
func ask(who: Person, text: String, options: Array) -> void:
	name_label.text = ("%s %s" % [who.title, who.display_name]).strip_edges()
	name_label.add_theme_color_override("font_color", Color(who.realm_color()))
	text_label.text = text
	UiKit.clear(button_row)
	for o in options:
		var b := UiKit.button(o[1], 170, 48)
		b.pressed.connect(func():
			visible = false
			chosen.emit(o[0]))
		button_row.add_child(b)
	visible = true
