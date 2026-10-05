class_name UiKit
extends RefCounted

## 畫面共用的小工具和顏色。

const MSG_COLOR := {
	"info": "#c9ccd1",
	"good": "#9be39b",
	"bad": "#ff8a8a",
	"big": "#ffd479",
	"epic": "#ffe9a8",
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
		if m["kind"] == "epic":
			# 一輩子記得的大事：字大一點，前後空一行
			lines.append("\n[font_size=22][color=%s]%s[/color][/font_size]\n" % [MSG_COLOR["epic"], m["text"]])
		else:
			lines.append("[color=%s]%s[/color]" % [MSG_COLOR.get(m["kind"], "#ffffff"), m["text"]])
	return "\n".join(lines)


## 秘笈的名字：書名號、品級的顏色，滑鼠移上去看說明和要讀幾天
static func book_label(id: String, size := 18) -> Label:
	var b := BookData.get_def(id)
	var l := label("《%s》" % b["name"], size)
	l.add_theme_color_override("font_color", Color(BookData.color(id)))
	l.tooltip_text = "%s\n讀完要 %d 天" % [b["desc"], b["days"]]
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	return l


## 武器的滑鼠提示：說明，加上想查才看的數字
static func weapon_tooltip(w: Dictionary) -> String:
	var lines := [w["desc"], "傷害 ×%.1f" % w["power"]]
	if w["str"] > 0:
		lines.append("力量 %d 才拿得動" % w["str"])
	return "\n".join(lines)
