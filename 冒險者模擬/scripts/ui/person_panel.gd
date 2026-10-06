class_name PersonPanel
extends Control

## 人物面板（參考龍胤立志傳、鬼谷八荒）：點任何人的名字就蓋在畫面上跳出來。你和世界上的人用同一個面板。
## 左邊：頭像框（還沒有美術，用境界顏色的框和名字的第一個字）、身分資料、按鈕（動手、去找他）。
## 右邊分頁：屬性、武學、物品、關係、經歷。
## show don't tell：別人的面板不寫數字（身體只寫印象）；武學只列你跟他交過手、看過的招；物品寫樣子不寫名字；
## 經歷只寫世界上的人知道的事。不寫背景故事說明。
## 只負責顯示和按鈕，規則都在 Town。

signal travel_requested(place: String)
signal fight_requested(person_id: String)

const ROLE_NAMES := {"villain": "亡命之徒", "hunter": "冒險者", "duelist": "決鬥家", "settled": "隱居",
	"youth": "平民", "follower": "手下", "master": "庭主"}
## 身體的印象（別人的面板）：數值到這裡（含）以上就用這個說法
## 看得出來的身體（寫看到的樣子，不寫評語）
const STR_WORDS := [[26, "肩背厚得像門板"], [22, "手臂比常人粗一圈"], [18, "腕骨粗，兵器握得很穩"], [15, "肩膀結實"], [12, "身板紮實"], [0, "身板單薄"]]
const AGI_WORDS := [[26, "走路沒有聲音"], [22, "腳步很輕，重心從來不亂"], [18, "轉身很快，腳下不拖"], [15, "腳步俐落"], [12, "動作靈便"], [0, "腳步有點拖"]]
## 武學分頁照武器分：[分頁名, 這一頁的武器類別]。通用頁放不挑武器的招
const KIND_TABS := [["通用", []], ["劍", ["sword", "greatsword"]], ["刀斧", ["axe", "blade"]], ["細劍", ["rapier"]], ["錘", ["hammer"]]]

var town: Town
var person_id := ""
var portrait: PanelContainer
var portrait_char: Label
var name_label: Label
var info_grid: GridContainer
var button_box: VBoxContainer
var tabs: TabContainer
var stats_box: VBoxContainer
var moves_box: VBoxContainer
var items_box: VBoxContainer
var rel_box: VBoxContainer
var story_box: VBoxContainer
## 武學分頁現在看哪一類武器
var move_kind := "通用"


func _init(p_town: Town) -> void:
	town = p_town
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(1120, 640)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#23272e")
	style.border_color = Color("#4a505a")
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	frame.add_theme_stylebox_override("panel", style)
	center.add_child(frame)
	var row := UiKit.hbox(22)
	frame.add_child(row)

	# 左：頭像、身分、按鈕
	var left := UiKit.vbox(10)
	left.custom_minimum_size.x = 330
	row.add_child(left)
	portrait = PanelContainer.new()
	portrait.custom_minimum_size = Vector2(150, 150)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_char = UiKit.label("", 64)
	portrait_char.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_char.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.add_child(portrait_char)
	left.add_child(portrait)
	name_label = UiKit.label("", 26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(name_label)
	info_grid = GridContainer.new()
	info_grid.columns = 4
	info_grid.add_theme_constant_override("h_separation", 10)
	info_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(info_grid)
	button_box = UiKit.vbox(8)
	left.add_child(button_box)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var close_button := UiKit.button("關閉", 120)
	close_button.pressed.connect(close)
	left.add_child(close_button)

	# 右：分頁
	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(tabs)
	stats_box = _page("屬性")
	moves_box = _page("武學")
	items_box = _page("物品")
	rel_box = _page("關係")
	story_box = _page("經歷")


func show_person(id: String) -> void:
	person_id = id
	move_kind = "通用"
	visible = true
	refresh()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()


func refresh() -> void:
	if not visible:
		return
	var p := town.world.person(person_id)
	var me := p.id == town.world.hero_id
	var color := Color(p.realm_color())
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#1b1e23")
	frame.border_color = color
	frame.set_border_width_all(4)
	portrait.add_theme_stylebox_override("panel", frame)
	portrait_char.text = p.display_name.substr(0, 1)
	portrait_char.add_theme_color_override("font_color", color)
	name_label.text = ("%s %s" % [p.title, p.display_name]).strip_edges() if not me else "%s（你）" % p.display_name
	name_label.add_theme_color_override("font_color", color)
	_build_info(p)
	_build_buttons(p, me)
	_build_stats(p, me)
	_build_moves(p, me)
	_build_items(p, me)
	_build_relations(p)
	_build_story(p)


# ---------- 身分 ----------

func _build_info(p: Person) -> void:
	UiKit.clear(info_grid)
	var school := SchoolData.school_name(p.school) if p.rank > 0 else "無"
	var where := ""
	var me := p.id == town.world.hero_id
	if p.dead:
		where = "%d 歲死在%s" % [p.age_at(p.died_at), MapData.place_name(p.location)]
	elif me:
		where = MapData.place_name(p.location)
	elif town.hero.heard.has(p.id):
		# 別人：最後聽說他在哪
		where = "%s（%s）" % [MapData.place_name(town.hero.heard[p.id]["place"]), MapView.heard_when(town, p.id)]
	else:
		where = "不知道"
	var realm := p.realm_text() if not p.dead else "—"
	_info("性別", "女" if p.pron == "她" else "男", "流派", school)
	_info("年紀", "%d 歲" % p.age() if not p.dead else "—", "身分", _identity(p))
	_info("在哪", where, "境界", realm, Color(p.realm_color()))


func _info(k1: String, v1: String, k2: String, v2: String, c2 := Color.WHITE) -> void:
	info_grid.add_child(UiKit.label(k1, 16, 0.55))
	var a := UiKit.label(v1, 17)
	a.custom_minimum_size.x = 110
	info_grid.add_child(a)
	info_grid.add_child(UiKit.label(k2, 16, 0.55))
	var b := UiKit.label(v2, 17)
	b.add_theme_color_override("font_color", c2)
	info_grid.add_child(b)


## 身分：流派的階位；不是流派的人寫他過什麼日子
func _identity(p: Person) -> String:
	if SchoolData.rank_name(p) != "":
		return SchoolData.rank_name(p)
	if p.id == town.world.hero_id or town.world.lives.has(p.id):
		return "冒險者"
	return ROLE_NAMES.get(p.role, "冒險者")


func _build_buttons(p: Person, me: bool) -> void:
	UiKit.clear(button_box)
	if me or p.dead:
		return
	var h := town.hero
	if town.can_fight(p.id):
		var f := UiKit.button("動手", 200)
		f.pressed.connect(func():
			close()
			fight_requested.emit(p.id))
		button_box.add_child(f)
	elif h.heard.has(p.id) and h.heard[p.id]["place"] != h.location:
		# 去最後聽說他在的地方（不一定還在）
		var place: String = h.heard[p.id]["place"]
		var go := UiKit.button("去%s（%s）" % [MapData.place_name(place), LifeData.span_text(MapData.distance(h.location, place))], 260)
		go.disabled = h.dying()
		go.pressed.connect(func():
			close()
			travel_requested.emit(place))
		button_box.add_child(go)
	if town.world.wanted(p.id):
		var w := UiKit.label("公會懸賞%s。" % p.pron, 16)
		w.add_theme_color_override("font_color", Color(TownView.GOLD))
		button_box.add_child(w)


# ---------- 屬性 ----------

func _build_stats(p: Person, me: bool) -> void:
	UiKit.clear(stats_box)
	if p.dead:
		stats_box.add_child(UiKit.label("已經不在了。", 18, 0.6))
		return
	for s in GrowthData.STATS:
		var row := UiKit.hbox(14)
		var n := UiKit.label(GrowthData.NAMES[s], 20)
		n.custom_minimum_size.x = 60
		row.add_child(n)
		if me:
			var v := UiKit.label(str(p.body(s)), 20)
			v.custom_minimum_size.x = 36
			if p.decline(s) > 0:
				v.add_theme_color_override("font_color", Color(TownView.AGED))
				v.tooltip_text = "最好的時候 %d" % p.stats[s]
				v.mouse_filter = Control.MOUSE_FILTER_STOP
			row.add_child(v)
			var bar := UiKit.bar(Color("#7fa7d9"), 10)
			bar.custom_minimum_size.x = 220
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.max_value = p.exp_need()
			bar.value = p.exp[s]
			row.add_child(bar)
			if p.at_cap(s):
				var cap := UiKit.label("瓶頸", 16)
				cap.add_theme_color_override("font_color", Color(TownView.GOLD))
				row.add_child(cap)
		else:
			row.add_child(UiKit.label(_word(STR_WORDS if s == "str" else AGI_WORDS, p.body(s)), 20, 0.9))
		stats_box.add_child(row)
	if me:
		stats_box.add_child(UiKit.label("血量 %d / %d" % [p.hp, p.max_hp()], 18, 0.8))
		if p.school == SchoolData.ID:
			stats_box.add_child(UiKit.label("劍庭的貢獻 %d" % p.merit, 18, 0.8))
	var stance := SchoolData.stance_of(p)
	if stance != "" and (me or _known_moves(p, me).size() >= SchoolData.stance_def(stance)["need"]):
		stats_box.add_child(HSeparator.new())
		stats_box.add_child(UiKit.heading("架勢"))
		var st := UiKit.label(SchoolData.stance_def(stance)["name"], 19)
		st.add_theme_color_override("font_color", Color(GrowthData.GRADE_COLORS[2]))
		st.tooltip_text = SchoolData.stance_def(stance)["desc"]
		st.mouse_filter = Control.MOUSE_FILTER_STOP
		stats_box.add_child(st)


func _word(words: Array, value: int) -> String:
	for w in words:
		if value >= w[0]:
			return w[1]
	return words[-1][1]


# ---------- 武學 ----------
# 照武器分頁；每招一個圓圈（外框是等級顏色），同一派的招用線串起來。
# 你自己：劍庭的招全部列出來，還沒學的灰掉（看得出這一派還有什麼）。別人：只列你跟他交過手、看過的招。

func _build_moves(p: Person, me: bool) -> void:
	UiKit.clear(moves_box)
	var known := _known_moves(p, me)
	if not me and known.is_empty():
		var why := "你沒見過%s出手。" % p.pron if not town.hero.fought.has(p.id) else "你沒見過%s用什麼有名堂的招。" % p.pron
		moves_box.add_child(UiKit.label(why, 18, 0.6))
		return
	var bar := UiKit.hbox(6)
	moves_box.add_child(bar)
	for k in KIND_TABS:
		var b := UiKit.button(k[0], 80, 36)
		b.toggle_mode = true
		b.button_pressed = move_kind == k[0]
		b.pressed.connect(func():
			move_kind = k[0]
			_build_moves(p, me))
		bar.add_child(b)
	moves_box.add_child(HSeparator.new())
	var kinds: Array = []
	for k in KIND_TABS:
		if k[0] == move_kind:
			kinds = k[1]
	if kinds.is_empty():
		if me:
			_icon_row("人人都會", MoveData.BASIC.duplicate(), p)
		var general := known.filter(func(id): return MoveData.MOVES[id].get("weapons", []).is_empty())
		_icon_row("通用", general, p)
		return
	var any := false
	# 流派的招串成一條線：你自己那一派全部列出來（還沒學的灰掉），其他的只列會的
	for school in SchoolData.SCHOOLS:
		var chain := SchoolData.chain(school).filter(func(id): return _in_kinds(id, kinds))
		var shown := chain if me and p.school == school else chain.filter(func(id): return known.has(id))
		if not shown.is_empty():
			_icon_row(SchoolData.school_name(school), shown, p, true)
			any = true
	var other := known.filter(func(id): return MoveData.school(id) == "" and _in_kinds(id, kinds))
	if not other.is_empty():
		_icon_row("不屬於流派", other, p)
		any = true
	if not any:
		moves_box.add_child(UiKit.label("沒有。", 18, 0.6))


func _in_kinds(id: String, kinds: Array) -> bool:
	for k in MoveData.MOVES[id].get("weapons", []):
		if kinds.has(k):
			return true
	return false


## 這個人會的招（人人都會的不算）。別人：只算你看過他用的；同一派的人互相知道
func _known_moves(p: Person, me: bool) -> Array:
	var list := []
	var seen: Array = town.hero.seen.get(p.id, [])
	for id in MoveData.LEARNABLE:
		if not p.knows(id):
			continue
		if me or seen.has(id) or (p.school != "" and p.school == town.hero.school and MoveData.school(id) == p.school):
			list.append(id)
	return list


## 一排招的圓圈。chain = true：中間畫線串起來（同一派從低到高）
func _icon_row(title: String, ids: Array, p: Person, chain := false) -> void:
	if ids.is_empty():
		return
	moves_box.add_child(UiKit.label(title, 17, 0.7))
	var row := UiKit.hbox(0)
	for i in ids.size():
		if chain and i > 0:
			var line := ColorRect.new()
			line.color = Color("#5a616c")
			line.custom_minimum_size = Vector2(28, 3)
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(line)
		elif i > 0:
			var gap := Control.new()
			gap.custom_minimum_size.x = 16
			row.add_child(gap)
		row.add_child(_move_icon(ids[i], p.knows(ids[i])))
	moves_box.add_child(row)


## 一招：等級顏色的圓圈，裡面是招名的第一個字，下面是招名。滑鼠移上去看說明
func _move_icon(id: String, learned: bool) -> Control:
	var m: Dictionary = MoveData.MOVES[id]
	var box := UiKit.vbox(4)
	box.custom_minimum_size.x = 86
	var icon := MoveIcon.new()
	icon.text = m["name"].substr(0, 1)
	icon.ring = Color(MoveData.color(id)) if learned else Color("#4a505a")
	icon.dim = not learned
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.tooltip_text = _move_tip(id)
	box.add_child(icon)
	var n := UiKit.label(m["name"], 15, 1.0 if learned else 0.45)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(n)
	return box


func _move_tip(id: String) -> String:
	var m: Dictionary = MoveData.MOVES[id]
	var school: String = SchoolData.school_name(MoveData.school(id)) if MoveData.school(id) != "" else ("通用" if MoveData.MOVES[id].get("weapons", []).is_empty() else "失傳的招")
	var lines := ["%s（%s・%s）" % [m["name"], GrowthData.GRADE_NAMES[MoveData.grade(id)], school], m.get("desc", "")]
	var req: Dictionary = SchoolData.REQ.get(id, {})
	for s in req:
		lines.append("%s要 %d" % [GrowthData.NAMES[s], req[s]])
	return "\n".join(lines)


## 招的圓圈
class MoveIcon extends Control:
	var text := ""
	var ring := Color.WHITE
	var dim := false

	func _init() -> void:
		custom_minimum_size = Vector2(64, 64)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var c := size / 2
		draw_circle(c, 30, Color("#1b1e23"))
		draw_circle(c, 30, ring, false, 4.0, true)
		var font := get_theme_default_font()
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
		draw_string(font, c + Vector2(-w.x / 2, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ring if not dim else Color("#6a707a"))


# ---------- 物品 ----------

func _build_items(p: Person, me: bool) -> void:
	UiKit.clear(items_box)
	if p.dead:
		items_box.add_child(UiKit.label("已經不在了。", 18, 0.6))
		return
	for w in p.owned_weapons:
		var def := WeaponData.get_def(w)
		var text: String = def["name"] if me else def.get("look", def["name"])
		if w == p.weapon:
			text += "（拿著）" if me else ""
		var l := UiKit.label(text, 18, 1.0, true)
		if me:
			l.add_theme_color_override("font_color", Color(WeaponData.color(w)))
			l.tooltip_text = UiKit.weapon_tooltip(def)
			l.mouse_filter = Control.MOUSE_FILTER_STOP
		items_box.add_child(l)
	for b in p.books:
		if me:
			items_box.add_child(UiKit.book_label(b, 18))
		else:
			items_box.add_child(UiKit.label("懷裡有%s。" % BookData.get_def(b)["look"], 18, 1.0, true))
	if me:
		items_box.add_child(UiKit.label("%d 銀" % p.money, 18, 0.8))


# ---------- 關係 ----------

func _build_relations(p: Person) -> void:
	UiKit.clear(rel_box)
	var w := town.world
	var any := false
	for r in p.relations:
		var o := w.person(r)
		if o == null:
			continue
		rel_box.add_child(UiKit.label("%s：%s%s" % [World.RELATION_NAMES[p.relations[r]], w.who(r), "（死了）" if o.dead else ""], 18))
		any = true
	if p.school != "" and p.rank > 0:
		for o in w.others():
			if o != p and o.school == p.school and o.rank > 0 and not p.relations.has(o.id):
				rel_box.add_child(UiKit.label("同門：%s" % w.who(o.id), 18, 0.85))
				any = true
	if not p.dead:
		for g in p.grudges:
			var l := UiKit.label("仇人：%s" % w.who(g), 18)
			l.add_theme_color_override("font_color", Color(UiKit.MSG_COLOR["bad"]))
			rel_box.add_child(l)
			any = true
	if not any:
		rel_box.add_child(UiKit.label("沒聽說%s跟誰有關係。" % p.pron, 18, 0.6))


# ---------- 經歷 ----------

func _build_story(p: Person) -> void:
	UiKit.clear(story_box)
	var heard := p.history.filter(func(e): return e["public"])
	if heard.is_empty():
		story_box.add_child(UiKit.label("沒聽說%s做過什麼。" % p.pron, 18, 0.6))
		return
	for i in range(heard.size() - 1, -1, -1):
		var e: Dictionary = heard[i]
		story_box.add_child(UiKit.label("%s，%s。" % [_when(e["month"]), town.world.fmt(e["text"])], 17, 0.85, true))


## 「今年」「去年」「3 年前」
func _when(month: int) -> String:
	var years := LifeData.year_of(town.world.month()) - LifeData.year_of(month)
	match years:
		0:
			return "今年"
		1:
			return "去年"
	return "%d 年前" % years


func _page(title: String) -> VBoxContainer:
	var box := UiKit.vbox(10)
	var s := ScrollContainer.new()
	s.name = title
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(box)
	tabs.add_child(s)
	return box
