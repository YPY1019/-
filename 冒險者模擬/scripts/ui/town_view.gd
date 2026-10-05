class_name TownView
extends VBoxContainer

## 城鎮畫面：你的狀態、委託板、北境劍術道場、休養。只負責顯示和按鈕，規則都在 Town。
## 要開打時發出 commission_requested / spar_requested，由 main 切到戰鬥畫面。

signal commission_requested(enemy_id: String)
signal spar_requested
## 城裡發生了事（寫試玩紀錄用）
signal messages_added(msgs: Array)

const BAD := "#ff8a8a"
const GOLD := "#ffd479"

var town: Town

var day_label: Label
var money_label: Label
var hp_bar: ProgressBar
var hp_label: Label
var rest_row: HBoxContainer
var me_box: VBoxContainer
var board_box: VBoxContainer
var dojo_box: VBoxContainer
var log_label: RichTextLabel


func _init(p_town: Town) -> void:
	town = p_town
	add_theme_constant_override("separation", 12)

	# 上：天數、錢、血量、休養
	var top := UiKit.hbox(28)
	add_child(top)
	day_label = UiKit.label("", 24)
	top.add_child(day_label)
	money_label = UiKit.label("", 24)
	top.add_child(money_label)
	var hp_box := UiKit.vbox(2)
	hp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_label = UiKit.label("", 18)
	hp_box.add_child(hp_label)
	hp_bar = UiKit.bar(Color("#5fbf6a"), 14)
	hp_box.add_child(hp_bar)
	top.add_child(hp_box)
	rest_row = UiKit.hbox(8)
	top.add_child(rest_row)

	# 中：左邊你的狀態，右邊委託板和道場
	var mid := UiKit.hbox(16)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(mid)
	me_box = UiKit.vbox(6)
	var me_panel := _scroll_panel(me_box)
	me_panel.custom_minimum_size.x = 380
	mid.add_child(me_panel)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(tabs)
	board_box = UiKit.vbox(10)
	var board := _scroll(board_box)
	board.name = "委託板"
	tabs.add_child(board)
	dojo_box = UiKit.vbox(8)
	var dojo := _scroll(dojo_box)
	dojo.name = "北境劍術道場"
	tabs.add_child(dojo)

	# 下：發生了什麼事
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 17)
	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size.y = 140
	log_panel.add_child(log_label)
	add_child(log_panel)


func add_messages(msgs: Array) -> void:
	if msgs.is_empty():
		return
	log_label.append_text(UiKit.messages_bbcode(msgs) + "\n")
	messages_added.emit(msgs)
	refresh()


func refresh() -> void:
	var h := town.hero
	day_label.text = "第 %d 天" % h.day
	money_label.text = "%d 銀" % h.money
	money_label.add_theme_color_override("font_color", Color(BAD) if h.money < 0 else Color(GOLD))
	hp_label.text = "血量 %d / %d" % [h.hp, h.max_hp()]
	hp_bar.max_value = h.max_hp()
	hp_bar.value = h.hp
	_build_rest()
	_build_me()
	_build_board()
	_build_dojo()


func _act(msgs: Array) -> void:
	add_messages(msgs)


# ---------- 休養 ----------

func _build_rest() -> void:
	UiKit.clear(rest_row)
	var full := town.days_to_full()
	var one := UiKit.button("休養 1 天", 130)
	one.disabled = full == 0
	one.pressed.connect(func(): _act(town.rest(1)))
	rest_row.add_child(one)
	var all := UiKit.button("休養到痊癒（%d 天）" % full if full > 0 else "不用休養", 210)
	all.disabled = full == 0
	all.pressed.connect(func(): _act(town.rest(town.days_to_full())))
	rest_row.add_child(all)


# ---------- 你 ----------

func _build_me() -> void:
	UiKit.clear(me_box)
	var h := town.hero
	if h.cleared:
		var c := UiKit.label("★ 原型通關", 22)
		c.add_theme_color_override("font_color", Color(GOLD))
		me_box.add_child(c)
	me_box.add_child(UiKit.heading("身體"))
	var realm := UiKit.label(h.realm_text(), 22)
	realm.add_theme_color_override("font_color", Color(h.realm_color()))
	me_box.add_child(realm)
	for s in GrowthData.STATS:
		var row := UiKit.hbox(10)
		var n := UiKit.label(GrowthData.NAMES[s], 18)
		n.custom_minimum_size.x = 48
		n.tooltip_text = "戰鬥時跟對手的%s比。低 %d 點以上，靠%s的招一定失敗。" % [GrowthData.NAMES[s], GrowthData.FAIL_GAP, GrowthData.NAMES[s]]
		n.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(n)
		var v := UiKit.label(str(h.stats[s]), 20)
		v.custom_minimum_size.x = 30
		row.add_child(v)
		var bar := UiKit.bar(Color("#7fa7d9"), 10)
		bar.custom_minimum_size.x = 140
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = GrowthData.EXP_PER_POINT
		bar.value = h.exp[s]
		row.add_child(bar)
		if h.at_cap(s):
			var cap := UiKit.label("瓶頸", 16)
			cap.add_theme_color_override("font_color", Color(GOLD))
			row.add_child(cap)
		me_box.add_child(row)
	if h.stuck() and h.can_break_through():
		var hint := UiKit.label("卡在瓶頸：打贏 %s 的對手，或去道場特訓" % "★".repeat(h.realm + 2), 16, 1.0, true)
		hint.add_theme_color_override("font_color", Color(GOLD))
		me_box.add_child(hint)

	me_box.add_child(UiKit.heading("會的招"))
	_move_line("一般", MoveData.BASIC)
	var school := []
	for t in SchoolData.TIERS:
		for id in t["moves"]:
			if h.knows(id):
				school.append(id)
	_move_line(SchoolData.NAME, school)
	var wild := []
	for id in h.learned:
		if SchoolData.tier_of(id) == 0:
			wild.append(id)
	_move_line("野路子", wild)

	var stealing := []
	for id in h.steal_hits:
		if not h.knows(id):
			stealing.append("%s %d/%d" % [MoveData.MOVES[id]["name"], h.steal_hits[id], TownData.STEAL_NEED])
	if not stealing.is_empty():
		me_box.add_child(UiKit.label("快偷學會了：" + "、".join(stealing), 16, 0.8, true))


func _move_line(title: String, ids: Array) -> void:
	if ids.is_empty():
		return
	var names := []
	for id in ids:
		names.append(MoveData.MOVES[id]["name"])
	me_box.add_child(UiKit.label("%s：%s" % [title, "、".join(names)], 17, 0.9, true))


# ---------- 委託板 ----------

func _build_board() -> void:
	UiKit.clear(board_box)
	var h := town.hero
	if h.hp < h.max_hp() * 0.7:
		var warn := UiKit.label("你現在帶著傷（血量 %d / %d）。血量會帶進下一場戰鬥。" % [h.hp, h.max_hp()], 17, 1.0, true)
		warn.add_theme_color_override("font_color", Color(BAD))
		board_box.add_child(warn)
	# 危險度的星數對應境界
	var legend := UiKit.hbox(14)
	for i in GrowthData.REALM_NAMES.size():
		var l := UiKit.label("%s %s" % ["★".repeat(i + 1), GrowthData.REALM_NAMES[i]], 15)
		l.add_theme_color_override("font_color", Color(GrowthData.REALM_COLORS[i]))
		legend.add_child(l)
	board_box.add_child(legend)
	for id in EnemyData.ORDER:
		var c: Dictionary = TownData.COMMISSIONS[id]
		var e: Dictionary = EnemyData.ENEMIES[id]
		var row := UiKit.hbox(16)
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dg := EnemyData.danger(id)
		var title_row := UiKit.hbox(12)
		title_row.add_child(UiKit.label(e["name"], 20))
		var stars := UiKit.label("%s %s" % [dg["stars"], dg["stage"]], 20)
		stars.add_theme_color_override("font_color", Color(dg["color"]))
		stars.tooltip_text = "危險度：大約是%s的人打得贏的" % dg["text"]
		stars.mouse_filter = Control.MOUSE_FILTER_STOP
		title_row.add_child(stars)
		if h.beaten.has(id):
			title_row.add_child(UiKit.label("（打贏過）", 18, 0.7))
		info.add_child(title_row)
		info.add_child(UiKit.label(e["blurb"], 16, 0.75, true))
		info.add_child(UiKit.label("報酬 %d 銀・來回 %d 天" % [c["reward"], c["days"]], 15, 0.6))
		info.tooltip_text = c["text"]
		info.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(info)
		var b := UiKit.button("接下", 110, 52)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): commission_requested.emit(id))
		row.add_child(b)
		board_box.add_child(row)
		board_box.add_child(HSeparator.new())


# ---------- 道場 ----------

func _build_dojo() -> void:
	UiKit.clear(dojo_box)
	var h := town.hero
	for t in SchoolData.TIERS:
		dojo_box.add_child(UiKit.heading(t["name"]))
		match t["exam"]:
			"spar":
				var st := town.spar_state()
				_exam_line(t, st["passed"])
				if not st["passed"]:
					var b := UiKit.button("接受考驗（%d 天）" % SchoolData.SPAR_DAYS, 200)
					b.disabled = not st["ok"]
					b.tooltip_text = st["why"]
					b.pressed.connect(func(): spar_requested.emit())
					var row := UiKit.hbox(12)
					row.add_child(b)
					if st["why"] != "":
						row.add_child(UiKit.label(st["why"], 16, 0.7))
					dojo_box.add_child(row)
			"bear":
				_exam_line(t, h.approved_tier >= 3)
		for id in t["moves"]:
			_move_row(id)
		dojo_box.add_child(HSeparator.new())

	dojo_box.add_child(UiKit.heading("特訓"))
	var tr := town.train_state()
	if not tr["available"]:
		dojo_box.add_child(UiKit.label("師傅：「我能帶你的，已經都帶了。」", 16, 0.7, true))
		return
	var row := UiKit.hbox(12)
	var b := UiKit.button("過瓶頸，升%s（%d 銀、%d 天）" % [GrowthData.REALM_NAMES[h.realm + 1], tr["cost"], tr["days"]], 320)
	b.disabled = not tr["ok"]
	b.tooltip_text = tr["why"]
	b.pressed.connect(func(): _act(town.train()))
	row.add_child(b)
	if tr["why"] != "":
		row.add_child(UiKit.label(tr["why"], 16, 0.7))
	dojo_box.add_child(row)


func _exam_line(t: Dictionary, passed: bool) -> void:
	var l := UiKit.label("考驗「%s」：%s" % [t["exam_name"], "已通過" if passed else t["exam_desc"]], 17, 1.0, true)
	l.add_theme_color_override("font_color", Color("#9be39b") if passed else Color(GOLD))
	dojo_box.add_child(l)


func _move_row(id: String) -> void:
	var m: Dictionary = MoveData.MOVES[id]
	var st := town.move_state(id)
	var row := UiKit.hbox(12)
	var info := UiKit.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title: String = m["name"]
	var req: Dictionary = SchoolData.REQ.get(id, {})
	for s in req:
		title += "　（%s %d）" % [GrowthData.NAMES[s], req[s]]
	var name_label := UiKit.label(title, 19, 1.0 if st["learned"] or st["ok"] else 0.5)
	info.add_child(name_label)
	info.add_child(UiKit.label(m["desc"], 15, 0.6, true))
	row.add_child(info)
	if st["learned"]:
		var done := UiKit.label("已學會", 17)
		done.add_theme_color_override("font_color", Color("#9be39b"))
		row.add_child(done)
	else:
		var price := "%d 銀、%d 天" % [st["cost"], st["days"]] if st["cost"] > 0 else "%d 天" % st["days"]
		var b := UiKit.button("學（%s）" % price, 170)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = not st["ok"]
		b.tooltip_text = "、".join(st["why"])
		b.pressed.connect(func(): _act(town.learn_move(id)))
		var col := UiKit.vbox(2)
		col.add_child(b)
		if not st["ok"]:
			var why := UiKit.label("、".join(st["why"]), 14, 0.7)
			why.custom_minimum_size.x = 170
			why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(why)
		row.add_child(col)
	dojo_box.add_child(row)


# ---------- 小工具 ----------

func _scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


func _scroll_panel(content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(_scroll(content))
	return p
