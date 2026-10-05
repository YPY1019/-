class_name WaitView
extends CenterContainer

## 等的畫面：花時間的事（出發、學招、讀秘笈、休養、養傷），月份一格一格往上跳，
## 中間穿插幾句手寫片段，跳完才給結果。不能跳過，整段幾秒鐘。
## 結果有大事（讀完秘笈、死去）就停著等玩家按，其他的結果出現一下就自己回去。
## 只負責顯示，時間在 Town 裡已經過完了。演完發出 finished。

signal finished

## 每個月跳多快：整段的秒數 = 月數 × SEC_PER_MONTH，限制在最短和最長之間
const SEC_PER_MONTH := 0.3
const MIN_SEC := 1.2
const MAX_SEC := 4.0
## 最多寫幾句季節
const SEASON_LINES_MAX := 2
## 一般的結果停多久才自己回去
const RESULT_HOLD := 1.4

var title_label: Label
var date_label: Label
var life_label: Label
var bar: ProgressBar
var lines_box: VBoxContainer
var result_label: RichTextLabel
var go_button: Button
var timer: Timer

var _from := 0
var _months := 0
var _tick := 0
var _schedule := {}
var _results: Array = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := UiKit.vbox(14)
	box.custom_minimum_size.x = 720
	add_child(box)
	title_label = UiKit.label("", 22, 0.7)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	date_label = UiKit.label("", 46)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(date_label)
	life_label = UiKit.label("", 18, 0.6)
	life_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(life_label)
	bar = UiKit.bar(Color("#c9b8a6"), 6)
	box.add_child(bar)
	lines_box = UiKit.vbox(10)
	lines_box.custom_minimum_size.y = 170
	box.add_child(lines_box)
	result_label = RichTextLabel.new()
	result_label.bbcode_enabled = true
	result_label.fit_content = true
	result_label.add_theme_font_size_override("normal_font_size", 19)
	# 結果和按鈕的位置先留好，出現時畫面不會跳
	result_label.custom_minimum_size.y = 110
	box.add_child(result_label)
	var row := CenterContainer.new()
	row.custom_minimum_size.y = 48
	go_button = UiKit.button("繼續", 170, 48)
	go_button.pressed.connect(func(): finished.emit())
	row.add_child(go_button)
	box.add_child(row)
	timer = Timer.new()
	timer.timeout.connect(_on_tick)
	add_child(timer)
	_rng.randomize()


## w：Town.take_wait() 拿到的那一段。results：跳完才給的結果（訊息清單）
func play(w: Dictionary, results: Array) -> void:
	_from = w["from"]
	_months = w["months"]
	_results = results
	_tick = 0
	title_label.text = w["title"]
	UiKit.clear(lines_box)
	result_label.clear()
	go_button.visible = false
	bar.max_value = maxi(1, _months)
	bar.value = 0
	_schedule = _make_schedule(w["kind"])
	_show_date()
	if _months <= 0:
		_end()
		return
	timer.wait_time = clampf(_months * SEC_PER_MONTH, MIN_SEC, MAX_SEC) / _months
	timer.start()


## 第幾格寫哪一句：第一格寫剛開始的，中間換季寫季節，最後一格寫快結束的
func _make_schedule(kind: String) -> Dictionary:
	var lines: Dictionary = LifeData.WAIT_LINES[kind]
	var s := {1: _pick(lines["start"])}
	var seasons := 0
	for i in range(2, _months):
		var m := LifeData.month_of_year(_from + i)
		if m % 3 == 0 and seasons < SEASON_LINES_MAX:
			s[i] = _pick(LifeData.SEASON_LINES[LifeData.SEASONS[m]])
			seasons += 1
	if _months >= 3 and not lines["end"].is_empty():
		s[_months] = _pick(lines["end"])
	return s


func _on_tick() -> void:
	_tick += 1
	bar.value = _tick
	_show_date()
	if _schedule.has(_tick):
		var l := UiKit.label(_schedule[_tick], 19, 0.0, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lines_box.add_child(l)
		create_tween().tween_property(l, "modulate:a", 0.85, 0.4)
	if _tick >= _months:
		timer.stop()
		_end()


func _show_date() -> void:
	var month := _from + _tick
	date_label.text = LifeData.date_text(month)
	var left := maxi(0, LifeData.life_months() - month)
	life_label.text = "壽命 %d・還剩 %s" % [LifeData.LIFESPAN, LifeData.span_text(left)] if left > 0 else "壽命 %d" % LifeData.LIFESPAN


## 跳完：給結果。有大事就等玩家按，沒有就停一下自己回去
func _end() -> void:
	await get_tree().create_timer(0.4).timeout
	var shown := _results.filter(func(m): return m["kind"] != "info")
	if not shown.is_empty():
		result_label.append_text(UiKit.messages_bbcode(shown))
	if shown.any(func(m): return m["kind"] in ["epic", "big"]):
		go_button.visible = true
		return
	await get_tree().create_timer(RESULT_HOLD if not shown.is_empty() else 0.3).timeout
	finished.emit()


func _pick(list: Array) -> String:
	return list[_rng.randi_range(0, list.size() - 1)]
