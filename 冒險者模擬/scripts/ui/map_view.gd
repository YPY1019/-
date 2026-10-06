class_name MapView
extends HBoxContainer

## 地圖分頁：左邊是地圖（用程式畫：地名、路、路上要走幾個月、你在哪、你這裡有幾個人、你接下的事在哪），
## 右邊是點選的地方：你在這裡就看得到有誰；不在就只有聽說的（幾個月前聽說的）。接下的委託、要找的人標在地圖上。
## 遠不遠、要不要去，玩家看地圖自己判斷。只負責顯示和按鈕，規則都在 Town。

signal travel_requested(place: String)
signal fight_requested(person_id: String)
signal monster_requested(enemy_id: String)
signal person_selected(person_id: String)

var town: Town
var canvas: MapCanvas
var side: VBoxContainer
var selected := ""


func _init(p_town: Town) -> void:
	town = p_town
	add_theme_constant_override("separation", 12)
	canvas = MapCanvas.new(town)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_stretch_ratio = 1.6
	canvas.place_clicked.connect(select)
	add_child(canvas)
	side = UiKit.vbox(8)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(side)
	add_child(scroll)


func select(place: String) -> void:
	selected = place
	refresh()


func refresh() -> void:
	if selected == "":
		selected = town.hero.location
	canvas.selected = selected
	canvas.queue_redraw()
	UiKit.clear(side)
	var h := town.hero
	var here := selected == h.location
	side.add_child(UiKit.heading(MapData.place_name(selected)))
	if here:
		side.add_child(UiKit.label("你在這裡。", 16, 0.6))
	else:
		var months := MapData.distance(h.location, selected)
		var go := UiKit.button("走過去", 200)
		go.disabled = h.dying()
		go.pressed.connect(func(): travel_requested.emit(selected))
		var row := UiKit.hbox(0)
		row.add_child(go)
		side.add_child(row)
	if MapData.is_city(selected):
		side.add_child(UiKit.label("冒險者公會、練武場、獅心劍庭、武器店、旅店。", 16, 0.6, true))

	# 委託的怪物：你在這裡看得到；不在這裡，接下了才知道在哪。劍庭要你來打的人也是
	var monsters := town.monsters_at(selected).filter(func(id): return here or town.took_job(id))
	monsters.append_array(town.duels_at(selected))
	if not monsters.is_empty():
		side.add_child(HSeparator.new())
		for id in monsters:
			var e: Dictionary = EnemyData.ENEMIES[id]
			var dg := EnemyData.danger(id)
			var row := UiKit.hbox(8)
			var n := UiKit.label("%s　%s %s" % [e["name"], dg["stars"], dg["stage"]], 18)
			n.add_theme_color_override("font_color", Color(dg["color"]))
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(n)
			if town.took_job(id):
				row.add_child(UiKit.label("你接下了", 15, 0.7))
			if here:
				var b := UiKit.button("去找", 90, 36)
				b.pressed.connect(func(): monster_requested.emit(id))
				row.add_child(b)
			side.add_child(row)

	side.add_child(HSeparator.new())
	if not here:
		_heard_here()
		return
	var people := town.world.at(selected)
	if people.is_empty():
		side.add_child(UiKit.label("沒看到什麼人。", 16, 0.6))
	for p in people:
		var row := UiKit.hbox(8)
		var name_button := LinkButton.new()
		name_button.text = ("%s %s" % [p.title, p.display_name]).strip_edges()
		name_button.add_theme_font_size_override("font_size", 18)
		name_button.add_theme_color_override("font_color", Color(p.realm_color()))
		name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_button.pressed.connect(func(): person_selected.emit(p.id))
		row.add_child(name_button)
		side.add_child(row)



## 你不在這裡：只寫聽說在這裡的人（最後聽說他在這裡，幾個月前）
func _heard_here() -> void:
	var list := heard_at(town, selected)
	if list.is_empty():
		side.add_child(UiKit.label("沒聽說有誰在這裡。", 16, 0.6))
		return
	side.add_child(UiKit.label("聽說", 16, 0.6))
	for p in list:
		var row := UiKit.hbox(8)
		var name_button := LinkButton.new()
		name_button.text = ("%s %s" % [p.title, p.display_name]).strip_edges()
		name_button.add_theme_font_size_override("font_size", 18)
		name_button.add_theme_color_override("font_color", Color(p.realm_color()))
		name_button.pressed.connect(func(): person_selected.emit(p.id))
		row.add_child(name_button)
		side.add_child(row)


## 最後聽說在這個地方的人（活著的、不是你）
static func heard_at(t: Town, place: String) -> Array:
	var out := []
	for id in t.hero.heard:
		var p := t.world.person(id)
		if p != null and not p.dead and t.hero.heard[id]["place"] == place:
			out.append(p)
	return out


## 「三個月前」「這個月」
static func heard_when(t: Town, id: String) -> String:
	var ago: int = t.world.month() - t.hero.heard[id]["month"]
	return "這個月" if ago <= 0 else "%s前" % LifeData.span_text(ago)


## 你在找的人（接下的懸賞、在公會打聽的人、劍庭要你討伐的人）
static func tracked(t: Town) -> Array:
	var out := []
	for id in t.world.bounties:
		if t.took_bounty(id):
			out.append(id)
	for id in t.hero.inquired:
		if t.hero.inquired[id] >= t.world.month() and not out.has(id):
			out.append(id)
	for j in t.hero.school_jobs:
		var job: Dictionary = SchoolData.JOBS[j]
		if job["kind"] == "kill" and not out.has(job["target"]):
			out.append(job["target"])
	return out


## 地圖本身：用程式畫
class MapCanvas extends Control:
	signal place_clicked(place: String)

	const ROAD := Color("#5a616c")
	const PLACE := Color("#c9ccd1")
	const CITY := Color("#ffd479")
	const HERO := Color("#9be39b")
	const PICK := Color("#ffffff")
	const DOT_R := 4.0

	var town: Town
	var selected := ""

	func _init(p_town: Town) -> void:
		town = p_town
		custom_minimum_size = Vector2(420, 360)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _pos(place: String) -> Vector2:
		var margin := Vector2(60, 34)
		return margin + MapData.PLACES[place]["pos"] * (size - margin * 2)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#22262d"))
		var font := get_theme_default_font()
		for r in MapData.ROADS:
			var a := _pos(r[0])
			var b := _pos(r[1])
			draw_line(a, b, ROAD, 2.0, true)
			var mid := (a + b) / 2
			draw_string(font, mid + Vector2(-4, -4), str(r[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8a919c"))
		var h := town.hero
		for id in MapData.PLACES:
			var p := _pos(id)
			var city := MapData.is_city(id)
			var radius := 11.0 if city else 8.0
			if id == selected:
				draw_circle(p, radius + 5, PICK, false, 2.0, true)
			draw_circle(p, radius, CITY if city else PLACE)
			if id == h.location:
				draw_circle(p, radius + 9, HERO, false, 3.0, true)
			var name: String = MapData.place_name(id)
			var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			draw_string(font, p + Vector2(-w / 2, -radius - 8), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#e6e8eb"))
			# 你這裡的人：一個人一個點，用境界的顏色（別的地方看不到）
			var people := town.world.at(id) if id == h.location and h.travel_left == 0 else []
			for i in people.size():
				var dot := p + Vector2(-((people.size() - 1) * 5.0) + i * 10.0, radius + 10)
				draw_circle(dot, DOT_R, Color(people[i].realm_color()))
			# 你接下的委託的怪物、劍庭要你去打的人：一個小三角
			var jobs := town.monsters_at(id).filter(func(m): return town.took_job(m) or id == h.location)
			if not jobs.is_empty() or not town.duels_at(id).is_empty():
				var t := p + Vector2(radius + 8, 0)
				draw_colored_polygon(PackedVector2Array([t + Vector2(0, -6), t + Vector2(6, 5), t + Vector2(-6, 5)]), Color("#d0574f"))
			# 你在找的人：最後聽說他在哪，寫上名字
			var row := 0
			for tid in MapView.tracked(town):
				var info: Dictionary = h.heard.get(tid, {})
				if info.get("place", "") != id:
					continue
				var who := town.world.person(tid)
				if who == null or who.dead:
					continue
				var at := p + Vector2(-radius - 6, radius + 24 + row * 18)
				draw_string(font, at, "✕ " + who.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ff8a8a"))
				row += 1

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var best := ""
			var best_d := 40.0
			for id in MapData.PLACES:
				var d := _pos(id).distance_to(event.position)
				if d < best_d:
					best_d = d
					best = id
			if best != "":
				place_clicked.emit(best)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
