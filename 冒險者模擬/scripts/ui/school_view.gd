class_name SchoolView
extends ScrollContainer

## 城裡學招的地方，兩種（kind）：
##   training 練武場：老兵收錢教通用招。
##   school 獅心劍庭：入門考驗、劍庭的委託（貢獻）、用貢獻換招、公開比試升階位、庭主交代的劍譜。
## 只負責顯示和按鈕，規則都在 Town。花時間的事交給 act（TownView._act）。

signal spar_requested
signal trial_requested
signal person_requested(person_id: String)

var town: Town
var kind := ""
var act: Callable
var box: VBoxContainer


func _init(p_town: Town, p_kind: String, p_act: Callable) -> void:
	town = p_town
	kind = p_kind
	act = p_act
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	box = UiKit.vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)


func refresh() -> void:
	UiKit.clear(box)
	if kind == "training":
		_build_training()
	else:
		_build_school()


# ---------- 練武場 ----------

func _build_training() -> void:
	box.add_child(UiKit.label(TownData.TRAINER_TEXT, 17, 0.8, true))
	box.add_child(HSeparator.new())
	for id in TownData.TRAINING:
		var st := town.training_state(id)
		box.add_child(_move_row(id, st, "學（%d 銀・%s）" % [st["cost"], LifeData.span_text(st["months"])],
			func(): act.call(town.learn_training(id))))


# ---------- 獅心劍庭 ----------

func _build_school() -> void:
	var h := town.hero
	# 你在劍庭的位置
	var head := UiKit.hbox(16)
	var status := "你不是劍庭的人。" if not town.member() else "你是劍庭的%s。" % SchoolData.RANKS[h.rank]
	if h.expelled:
		status = "你被逐出了劍庭。"
	head.add_child(UiKit.label(status, 19))
	if h.merit > 0 or town.member():
		head.add_child(UiKit.label("貢獻 %d" % h.merit, 19, 0.8))
	var head_button := LinkButton.new()
	head_button.text = "庭主"
	head_button.add_theme_font_size_override("font_size", 19)
	head_button.pressed.connect(func(): person_requested.emit(SchoolData.HEAD))
	head.add_child(head_button)
	box.add_child(head)

	# 入門考驗、公開比試
	var spar := town.spar_state()
	if not spar["passed"] and not h.expelled:
		box.add_child(UiKit.label("劍庭門口的告示：每年 %s選拔新學徒。" % SchoolData.selection_text(), 17, 0.8, true))
		var b := UiKit.button("參加選拔", 230)
		b.disabled = not spar["ok"]
		b.tooltip_text = spar["why"]
		b.pressed.connect(func(): spar_requested.emit())
		box.add_child(_wrap(b))
	else:
		var tr := town.trial_state()
		if tr["rank"] < SchoolData.RANKS.size():
			var who := "庭主" if tr["rank"] == 3 else (town.world.who(tr["opponent"]) if tr["opponent"] != "" else "劍庭的熟手")
			var b := UiKit.button("公開比試：升%s（對手：%s）" % [SchoolData.RANKS[tr["rank"]], who], 360)
			b.disabled = not tr["ok"]
			b.tooltip_text = tr["why"]
			b.pressed.connect(func(): trial_requested.emit())
			box.add_child(_wrap(b))

	# 劍庭的事
	box.add_child(UiKit.heading("劍庭的事"))
	var done := town.claims("school")
	if not done.is_empty():
		var row := UiKit.hbox(12)
		var l := UiKit.label("辦完了%d件事。" % done.size(), 17, 1.0, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var tb := UiKit.button("交差", 110, 44)
		tb.pressed.connect(func(): act.call(town.turn_in("school")))
		row.add_child(tb)
		box.add_child(row)
	var jobs := town.school_jobs()
	if jobs.is_empty():
		box.add_child(UiKit.label("現在沒有。", 17, 0.6))
	for id in jobs:
		var j: Dictionary = SchoolData.JOBS[id]
		var row := UiKit.hbox(12)
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiKit.label(j["text"], 17, 0.9, true))
		info.add_child(UiKit.label("貢獻 %d" % j["merit"], 15, 0.6))
		row.add_child(info)
		if j["kind"] == "watch":
			var wb := UiKit.button("守夜（%s）" % LifeData.span_text(j["months"]), 160, 44)
			wb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			wb.disabled = not town.in_city()
			wb.pressed.connect(func(): act.call(town.watch(id)))
			row.add_child(wb)
		elif town.took_school_job(id):
			var l := UiKit.label("你接下了", 17)
			l.add_theme_color_override("font_color", Color("#9be39b"))
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(l)
		else:
			var b := UiKit.button("接下", 110, 44)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.pressed.connect(func(): act.call(town.accept_school_job(id)))
			row.add_child(b)
		box.add_child(row)

	# 換招
	box.add_child(UiKit.heading("換招"))
	for id in SchoolData.MOVES:
		var st := town.school_move_state(id)
		box.add_child(_move_row(id, st, "換（貢獻 %d・%s）" % [st["merit"], LifeData.span_text(st["months"])],
			func(): act.call(town.learn_school_move(id))))
	# 絕學在劍譜裡，讀完才列出招名
	if h.knows(SchoolData.ULT):
		box.add_child(_move_row(SchoolData.ULT, {"learned": true}, "", Callable()))


## 一招一行：招名（等級顏色，滑鼠移上去看說明）、數值門檻、按鈕
func _move_row(id: String, st: Dictionary, button_text: String, on_learn: Callable) -> HBoxContainer:
	var m: Dictionary = MoveData.MOVES[id]
	var row := UiKit.hbox(12)
	var n := UiKit.label(m["name"], 19, 1.0 if st["learned"] or st.get("ok", false) else 0.55)
	n.add_theme_color_override("font_color", Color(MoveData.color(id)))
	n.tooltip_text = m["desc"]
	n.mouse_filter = Control.MOUSE_FILTER_STOP
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	if st["learned"]:
		row.add_child(UiKit.label("學會了", 16, 0.6))
		return row
	var req: Dictionary = SchoolData.REQ.get(id, {})
	for s in req:
		var tag := UiKit.label("%s %d" % [GrowthData.NAMES[s], req[s]], 15, 0.6)
		if town.hero.body(s) < req[s]:
			tag.add_theme_color_override("font_color", Color(TownView.BAD))
		row.add_child(tag)
	var b := UiKit.button(button_text, 220)
	b.disabled = not st["ok"]
	b.tooltip_text = "、".join(st["why"])
	b.pressed.connect(on_learn)
	row.add_child(b)
	return row


func _wrap(c: Control) -> HBoxContainer:
	var row := UiKit.hbox(0)
	row.add_child(c)
	return row
