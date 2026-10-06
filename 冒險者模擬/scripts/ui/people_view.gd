class_name PeopleView
extends ScrollContainer

## 人物分頁：世界上有名字的人，名字用境界的顏色，旁邊寫在哪裡。點名字打開人物面板（PersonPanel）。
## 只負責顯示，規則都在 Town。

signal person_requested(person_id: String)

var town: Town
var box: VBoxContainer


func _init(p_town: Town) -> void:
	town = p_town
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	box = UiKit.vbox(4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)


func refresh() -> void:
	var w := town.world
	UiKit.clear(box)
	var alive: Array = w.others()
	alive.sort_custom(func(a, b): return a.power() > b.power())
	var grid := _grid()
	for p in alive:
		_entry(grid, p, 1.0)
	var gone: Array = w.people.values().filter(func(p): return p.dead)
	if not gone.is_empty():
		box.add_child(HSeparator.new())
		box.add_child(UiKit.label("死了的人", 17, 0.5))
		var g2 := _grid()
		for p in gone:
			_entry(g2, p, 0.5)


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 4)
	box.add_child(g)
	return g


## 一個人：名字（境界顏色，點了開面板）＋在哪
func _entry(grid: GridContainer, p: Person, alpha: float) -> void:
	var row := UiKit.hbox(8)
	row.custom_minimum_size.x = 270
	var b := LinkButton.new()
	b.text = ("%s %s" % [p.title, p.display_name]).strip_edges()
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(p.realm_color(), alpha))
	b.pressed.connect(func(): person_requested.emit(p.id))
	row.add_child(b)
	var where := ""
	if not p.dead:
		where = "往%s" % MapData.place_name(p.travel_to) if p.travel_left > 0 else MapData.place_name(p.location)
	row.add_child(UiKit.label(where, 15, 0.55))
	grid.add_child(row)
