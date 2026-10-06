class_name TavernView
extends ScrollContainer

## 酒館分頁（城裡才有）：世界上發生的事都是傳聞，想知道才來聽（2026-10-07 決定：資訊推少、自己去聽多）。
## 新的在上面，照多久以前分段。人的名字用境界的顏色，點了打開人物面板。
## 只負責顯示，傳聞在 World.rumors。

signal person_requested(person_id: String)

## 最多列幾條
const MAX_LINES := 60
const INTRO := "旅店樓下的酒館。爐火邊坐著幾個剛從外地回來的人，桌上的酒換了一輪又一輪，話也一直沒停。"

var town: Town
var box: VBoxContainer
var text: RichTextLabel


func _init(p_town: Town) -> void:
	town = p_town
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	box = UiKit.vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)
	box.add_child(UiKit.label(INTRO, 16, 0.7, true))
	box.add_child(HSeparator.new())
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 17)
	text.meta_underlined = false
	text.meta_clicked.connect(func(meta): person_requested.emit(str(meta)))
	box.add_child(text)


func refresh() -> void:
	var w := town.world
	var list: Array = w.rumors.duplicate()
	list.reverse()
	list = list.slice(0, MAX_LINES)
	var lines := []
	var last := ""
	for e in list:
		var when := _when(w.month() - e["month"])
		if when != last:
			if last != "":
				lines.append("")
			lines.append("[color=#8a919c]%s[/color]" % when)
			last = when
		lines.append(_bbcode(e["raw"]))
	if lines.is_empty():
		lines.append("[color=#8a919c]今天沒什麼人說話。[/color]")
	text.text = "\n".join(lines)


## 多久以前的事（大概）
func _when(ago: int) -> String:
	if ago <= 0:
		return "這個月"
	if ago == 1:
		return "上個月"
	if ago < 6:
		return "前幾個月"
	if ago < 12:
		return "半年多以前"
	if ago < 24:
		return "一年多以前"
	return "兩年多以前"


## 傳聞的文字：{p:id} 換成名字（境界顏色、點得開）；你就寫「你」
func _bbcode(raw: String) -> String:
	var w := town.world
	var out := ""
	var rest := raw
	while true:
		var i := rest.find("{p:")
		if i < 0:
			break
		var j := rest.find("}", i)
		var id := rest.substr(i + 3, j - i - 3)
		out += rest.substr(0, i)
		var p := w.person(id)
		if id == w.hero_id or p == null:
			out += w.who(id)
		else:
			out += "[url=%s][color=%s]%s[/color][/url]" % [id, p.realm_color(), p.display_name]
		rest = rest.substr(j + 1)
	return out + rest
