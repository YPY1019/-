class_name UiKit
extends RefCounted

## 畫面共用的小工具和顏色。

const MSG_COLOR := {
	"info": "#c9ccd1",
	"good": "#9be39b",
	"bad": "#ff8a8a",
	"big": "#ffd479",
}


static func label(text: String, size := 18, alpha := 1.0, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.modulate = Color(1, 1, 1, alpha)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func heading(text: String) -> Label:
	return label(text, 24)


static func button(text: String, min_width := 150, height := 44) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, height)
	return b


static func bar(fill_color: Color, height := 18) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size.y = height
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	b.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#2c3038")
	b.add_theme_stylebox_override("background", bg)
	return b


static func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## 訊息清單 → 一行一行的 BBCode
static func messages_bbcode(msgs: Array) -> String:
	var lines := []
	for m in msgs:
		lines.append("[color=%s]%s[/color]" % [MSG_COLOR.get(m["kind"], "#ffffff"), m["text"]])
	return "\n".join(lines)
