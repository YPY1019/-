class_name EncounterDialog
extends Control

## 跳出來的對話：一段文字、幾個選項。有人找上門、走到委託的地方遇到怪物、休養要休多久，都用它。
## 只負責顯示和按鈕：選項和結果都由 Town 決定。

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


## who：找上門的人。options：[[id, 按鈕的字]]。選了發 chosen
func ask(who: Person, text: String, options: Array) -> void:
	show_choice(("%s %s" % [who.title, who.display_name]).strip_edges(), Color(who.realm_color()), text, options,
		func(c): chosen.emit(c))


## 一般的選擇：選了呼叫 on_choose(選項 id)
func show_choice(title: String, color: Color, text: String, options: Array, on_choose: Callable) -> void:
	name_label.text = title
	name_label.visible = title != ""
	name_label.add_theme_color_override("font_color", color)
	text_label.text = text
	text_label.visible = text != ""
	UiKit.clear(button_row)
	for o in options:
		var b := UiKit.button(o[1], 150, 48)
		b.pressed.connect(func():
			visible = false
			on_choose.call(o[0]))
		button_row.add_child(b)
	visible = true
