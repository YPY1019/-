class_name PeopleView
extends HBoxContainer

## 人物分頁：左邊是世界上有名字的人（名字用境界的顏色），右邊是點選的人的面板：
## 在哪、多強、幾歲、看起來怎樣、身上帶著什麼（寫樣子不寫名字，要自己認出那把劍）、跟誰有關係、聽說他做過的事。
## 聽說的事只寫世界上的人知道的（傳聞沒說是誰下的手，這裡也不寫）。
## 只負責顯示和按鈕，規則都在 Town。

signal travel_requested(place: String)
signal fight_requested(person_id: String)

var town: Town
var list_box: VBoxContainer
var detail: VBoxContainer
var selected := ""


func _init(p_town: Town) -> void:
	town = p_town
	add_theme_constant_override("separation", 12)
	list_box = UiKit.vbox(2)
	var list_scroll := _scroll(list_box)
	list_scroll.custom_minimum_size.x = 230
	list_scroll.size_flags_horizontal = Control.SIZE_FILL
	add_child(list_scroll)
	detail = UiKit.vbox(8)
	add_child(_scroll(detail))


func select(id: String) -> void:
	selected = id
	refresh()


func refresh() -> void:
	var w := town.world
	UiKit.clear(list_box)
	var alive := w.others()
	alive.sort_custom(func(a, b): return a.power() > b.power())
	for p in alive:
		list_box.add_child(_name_button(p))
	var gone := w.people.values().filter(func(p): return p.dead)
	if not gone.is_empty():
		list_box.add_child(UiKit.label("死了的人", 16, 0.5))
		for p in gone:
			list_box.add_child(_name_button(p, 0.5))
	if selected == "" or w.person(selected) == null or selected == w.hero_id:
		selected = alive[0].id if not alive.is_empty() else ""
	_build_detail()


func _name_button(p: Person, alpha := 1.0) -> Button:
	var b := Button.new()
	b.text = ("%s %s" % [p.title, p.display_name]).strip_edges()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = p.id != selected
	b.add_theme_color_override("font_color", Color(p.realm_color(), alpha))
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(select.bind(p.id))
	return b


func _build_detail() -> void:
	UiKit.clear(detail)
	if selected == "":
		return
	var w := town.world
	var p := w.person(selected)
	var head := UiKit.hbox(12)
	var n := UiKit.label(("%s %s" % [p.title, p.display_name]).strip_edges(), 26)
	n.add_theme_color_override("font_color", Color(p.realm_color()))
	head.add_child(n)
	if not p.dead:
		var r := UiKit.label(p.realm_text(), 20)
		r.add_theme_color_override("font_color", Color(p.realm_color()))
		head.add_child(r)
		head.add_child(UiKit.label("%d 歲" % p.age(), 20, 0.7))
	detail.add_child(head)

	if p.dead:
		detail.add_child(UiKit.label("%d 歲那年死在%s。" % [p.age_at(p.died_at), MapData.place_name(p.location)], 18, 0.7))
	elif p.travel_left > 0:
		detail.add_child(UiKit.label("在往%s的路上。" % MapData.place_name(p.travel_to), 18))
	else:
		detail.add_child(UiKit.label("在%s。" % MapData.place_name(p.location), 18))
	if p.blurb != "":
		detail.add_child(UiKit.label(p.blurb, 17, 0.8, true))
	if w.wanted(p.id):
		var b := UiKit.label("公會懸賞%s。" % p.pron, 17)
		b.add_theme_color_override("font_color", Color(TownView.GOLD))
		detail.add_child(b)

	if not p.dead:
		var row := UiKit.hbox(10)
		var h := town.hero
		if town.can_fight(p.id):
			var f := UiKit.button("動手", 120)
			f.pressed.connect(func(): fight_requested.emit(p.id))
			row.add_child(f)
		elif p.travel_left == 0 and p.location != h.location:
			var go := UiKit.button("去%s（%s）" % [MapData.place_name(p.location), LifeData.span_text(MapData.distance(h.location, p.location))], 220)
			go.disabled = h.dying()
			go.pressed.connect(func(): travel_requested.emit(p.location))
			row.add_child(go)
		if row.get_child_count() > 0:
			detail.add_child(row)

		detail.add_child(UiKit.heading("身上帶著"))
		for it in _carried(p):
			detail.add_child(UiKit.label(it, 17, 0.85, true))

	var rel := _relations(p)
	if not rel.is_empty():
		detail.add_child(UiKit.heading("關係"))
		for line in rel:
			detail.add_child(UiKit.label(line, 17, 0.85))

	var heard := p.history.filter(func(e): return e["public"])
	if not heard.is_empty():
		detail.add_child(UiKit.heading("聽說"))
		for i in range(heard.size() - 1, -1, -1):
			var e: Dictionary = heard[i]
			detail.add_child(UiKit.label("%s，%s。" % [_when(e["month"]), w.fmt(e["text"])], 16, 0.75, true))


## 身上帶著的東西：寫樣子，不寫名字
func _carried(p: Person) -> Array:
	var out := []
	out.append(WeaponData.get_def(p.weapon)["look"])
	for it in p.owned_weapons:
		if it != p.weapon:
			out.append("還背著" + WeaponData.get_def(it)["look"])
	for b in p.books:
		out.append("懷裡有%s。" % BookData.get_def(b)["look"])
	return out


## 關係：家人、師徒、老大手下，和仇人
func _relations(p: Person) -> Array:
	var w := town.world
	var out := []
	for r in p.relations:
		var o := w.person(r)
		if o == null:
			continue
		out.append("%s：%s%s" % [World.RELATION_NAMES[p.relations[r]], w.who(r), "（死了）" if o.dead else ""])
	if not p.dead:
		for g in p.grudges:
			out.append("仇人：%s" % w.who(g))
	return out


## 「今年」「去年」「3 年前」
func _when(month: int) -> String:
	var years := LifeData.year_of(town.world.month()) - LifeData.year_of(month)
	match years:
		0:
			return "今年"
		1:
			return "去年"
	return "%d 年前" % years


func _scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s
