class_name BattleView
extends VBoxContainer

## 戰鬥畫面（自動戰鬥試驗）。只負責顯示，規則都在 Battle，挑招在 AutoPilot。
## 戰鬥自己打：每隔一下打一回合，戰報一段一段出來；按「看完」一次打完。
## 戰鬥紀錄參考 CK3 單挑：開場交代場景，每回合把雙方的動作寫成一整段，數字另外放一行小字，
## 雙方的狀態用文字描述。
## 打完在右邊並排顯示「上次 vs 這次」。
##
## 打完發出 ended（外面結算後呼叫 show_settlement），按「回到城裡」發出 closed。

signal ended
signal closed

## 每回合間隔幾秒
const ROUND_SEC := 0.8

const COLOR := {
	"round": "#8a8f98",
	"scene": "#9aa3ad",
	"tell": "#ffd479",
	"damage_out": "#9be39b",
	"damage_in": "#ff8a8a",
	"info": "#a0c4ff",
	"pain": "#c9b8a6",
	"status": "#c9b8a6",
	"end": "#ffffff",
}
const BETTER := "#9be39b"
const WORSE := "#ff8a8a"
const OUTCOME_NAMES := {"win": "贏", "lose": "輸", "flee": "撤退", "survive": "撐過"}

var battle: Battle
var hero_c: Combatant
var foe_c: Combatant
var pilot := AutoPilot.new()
var timer: Timer

var hero_name_label: Label
var hero_bar: ProgressBar
var hero_hp_label: Label
var hero_status: Label
var foe_bar: ProgressBar
var foe_hp_label: Label
var foe_name_label: Label
var foe_status: Label
var log_label: RichTextLabel
var report_panel: PanelContainer
var report_box: VBoxContainer
var play_box: HBoxContainer
var end_box: HBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 12)

	# 上：雙方血量和狀態
	var top := UiKit.hbox(40)
	add_child(top)
	var hero_col := _hp_column("你", Color("#5fbf6a"))
	hero_name_label = hero_col["name"]
	hero_bar = hero_col["bar"]
	hero_hp_label = hero_col["hp"]
	hero_status = hero_col["status"]
	top.add_child(hero_col["box"])
	var foe_col := _hp_column("", Color("#d0574f"))
	foe_bar = foe_col["bar"]
	foe_hp_label = foe_col["hp"]
	foe_name_label = foe_col["name"]
	foe_status = foe_col["status"]
	top.add_child(foe_col["box"])

	# 中：左邊戰鬥紀錄，右邊打完的「上次 vs 這次」
	var mid := UiKit.hbox(12)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(mid)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_constant_override("line_separation", 6)
	var log_panel := PanelContainer.new()
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_child(log_label)
	mid.add_child(log_panel)
	report_box = UiKit.vbox(6)
	report_panel = PanelContainer.new()
	report_panel.custom_minimum_size.x = 430
	var report_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		report_margin.add_theme_constant_override("margin_" + side, 12)
	report_margin.add_child(report_box)
	report_panel.add_child(report_margin)
	mid.add_child(report_panel)

	# 下：打的時候「看完」，打完「回到城裡」
	play_box = UiKit.hbox(10)
	var skip := UiKit.button("看完", 170, 52)
	skip.pressed.connect(_skip)
	play_box.add_child(skip)
	add_child(play_box)
	end_box = UiKit.hbox(10)
	var back := UiKit.button("回到城裡", 170, 52)
	back.pressed.connect(func(): closed.emit())
	end_box.add_child(back)
	add_child(end_box)

	timer = Timer.new()
	timer.wait_time = ROUND_SEC
	timer.timeout.connect(_play_one)
	add_child(timer)


func begin(p_battle: Battle, note := "") -> void:
	battle = p_battle
	hero_c = battle.allies[0]
	foe_c = battle.enemies[0]
	log_label.clear()
	report_panel.visible = false
	# 人標境界，怪物標危險度，都用境界的顏色
	var a := hero_c.adventurer
	hero_name_label.text = "你　%s　%s" % [a.realm_text(), WeaponData.get_def(a.weapon)["name"]]
	hero_name_label.add_theme_color_override("font_color", Color(a.realm_color()))
	var dg := EnemyData.danger(foe_c.enemy_id)
	if foe_c.enemy_def.has("realm"):
		foe_name_label.text = "%s　%s" % [foe_c.display_name, dg["text"]]
	else:
		foe_name_label.text = "%s　%s %s" % [foe_c.display_name, dg["stars"], dg["stage"]]
	foe_name_label.add_theme_color_override("font_color", Color(dg["color"]))
	var hide: bool = foe_c.enemy_def.get("hide_hp", false)
	foe_bar.visible = not hide
	foe_hp_label.visible = not hide
	_append(battle.start())
	if note != "":
		log_label.append_text("[color=%s]%s[/color]\n" % [COLOR["info"], note])
	_refresh()
	timer.start()


## 打完的結算（拿到多少錢、數值成長…）接在戰鬥紀錄後面；report 是 Town.last_report（空的 = 不比）
func show_settlement(msgs: Array, report := {}) -> void:
	log_label.append_text("\n" + UiKit.messages_bbcode(msgs) + "\n")
	if not report.is_empty():
		_build_report(report)


func _play_one() -> void:
	if battle == null or battle.is_over():
		timer.stop()
		return
	var choice := pilot.choose(battle, hero_c, foe_c)
	_append(battle.play_round({hero_c: {"move": choice, "target": foe_c}}))
	_refresh()
	if battle.is_over():
		timer.stop()
		ended.emit()


func _skip() -> void:
	while battle != null and not battle.is_over():
		_play_one()


## 把事件排成段落：同一回合的敘述接成一段，傷害數字另外一行小字
func _append(events: Array) -> void:
	var para := []
	var damage := []
	for e in events:
		var text: String = e["text"]
		match e["kind"]:
			"round":
				_flush(para, damage)
				log_label.append_text("\n[color=%s]── %s ──[/color]\n" % [COLOR["round"], text])
			"scene":
				log_label.append_text("[i][color=%s]%s[/color][/i]\n" % [COLOR["scene"], text])
			"tell":
				_flush(para, damage)
				log_label.append_text("[color=%s][b]%s[/b][/color]\n" % [COLOR["tell"], text])
			"end":
				_flush(para, damage)
				log_label.append_text("\n[b][font_size=26]%s[/font_size][/b]\n" % text)
			"damage_in", "damage_out":
				damage.append("[color=%s]%s −%d[/color][color=%s]（%s）[/color]" % [COLOR[e["kind"]], text, e["amount"], COLOR["round"], e["note"]])
			"action":
				para.append(text)
			_:
				para.append("[color=%s]%s[/color]" % [COLOR.get(e["kind"], "#ffffff"), text])
	_flush(para, damage)


func _flush(para: Array, damage: Array) -> void:
	if not para.is_empty():
		log_label.append_text("".join(para) + "\n")
		para.clear()
	if not damage.is_empty():
		log_label.append_text("[font_size=16]%s[/font_size]\n" % "　".join(damage))
		damage.clear()


func _refresh() -> void:
	hero_bar.max_value = hero_c.max_hp
	hero_bar.value = hero_c.hp
	hero_hp_label.text = "%d / %d" % [hero_c.hp, hero_c.max_hp]
	foe_bar.max_value = foe_c.max_hp
	foe_bar.value = foe_c.hp
	foe_hp_label.text = "%d / %d" % [foe_c.hp, foe_c.max_hp]
	hero_status.text = _condition(hero_c, true)
	foe_status.text = _condition(foe_c, false)
	var over := battle.is_over()
	play_box.visible = not over
	end_box.visible = over


# ---------- 上次 vs 這次 ----------

func _build_report(report: Dictionary) -> void:
	UiKit.clear(report_box)
	report_panel.visible = true
	var before: Dictionary = report["before"]
	var now: Dictionary = report["now"]
	if before.is_empty():
		report_box.add_child(UiKit.heading("第一次打%s" % foe_c.display_name))
		report_box.add_child(UiKit.label("下次再打，會跟這次比。", 16, 0.6, true))
	else:
		report_box.add_child(UiKit.heading("跟上次比"))

	var grid := GridContainer.new()
	grid.columns = 3 if not before.is_empty() else 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	report_box.add_child(grid)
	var head := ["", "上次（第 %d 天）" % before.get("day", 0), "這次"] if not before.is_empty() else ["", "這次"]
	for h in head:
		grid.add_child(UiKit.label(h, 16, 0.6))

	# 每列：名稱、上次、這次、比較用的 key（見 _score；"" = 不比）
	var rows := [
		["結果", _outcome(before), _outcome(now), "outcome"],
		["回合", str(before.get("rounds", "")), str(now["rounds"]), "rounds"],
		["你掉的血", "%d / %d" % [before.get("hp_lost", 0), before.get("max_hp", 0)], "%d / %d" % [now["hp_lost"], now["max_hp"]], "hp_lost"],
		["對手剩的血", "%d%%" % roundi(before.get("foe_left", 0.0) * 100), "%d%%" % roundi(now["foe_left"] * 100), "foe_left"],
		["境界", before.get("realm", ""), now["realm"], ""],
		["力量／敏捷", "%d／%d" % [before.get("str", 0), before.get("agi", 0)], "%d／%d" % [now["str"], now["agi"]], "stats"],
		["武器", before.get("weapon", ""), now["weapon"], ""],
	]
	for row in rows:
		grid.add_child(UiKit.label(row[0], 17, 0.75))
		if not before.is_empty():
			grid.add_child(UiKit.label(row[1], 17, 0.75))
		var cell := UiKit.label(row[2], 18)
		if not before.is_empty() and row[3] != "":
			var diff := _score(row[3], now) - _score(row[3], before)
			# 回合數只在兩次都打贏時比
			var comparable: bool = row[3] != "rounds" or (now["outcome"] == "win" and before["outcome"] == "win")
			if comparable and absf(diff) > 0.001:
				cell.add_theme_color_override("font_color", Color(BETTER if diff > 0 else WORSE))
		grid.add_child(cell)

	# 多了什麼新東西
	if not before.is_empty():
		var news := []
		if now["weapon"] != before["weapon"]:
			news.append("換了%s" % now["weapon"])
		for id in now["learned"]:
			if not before["learned"].has(id):
				news.append("學會「%s」" % MoveData.MOVES[id]["name"])
		if not news.is_empty():
			var l := UiKit.label("這次多了：" + "、".join(news), 17, 1.0, true)
			l.add_theme_color_override("font_color", Color(COLOR["tell"]))
			report_box.add_child(l)

	# 這場用了哪些招，用得多的排前面
	var used: Dictionary = now["used"]
	var ids := used.keys()
	ids.sort_custom(func(a, b): return used[a] > used[b])
	var parts := []
	for id in ids:
		var s := "%s ×%d" % [MoveData.MOVES[id]["name"], used[id]]
		if not before.is_empty() and not before["learned"].has(id) and not MoveData.is_basic(id):
			s = "★" + s
		parts.append(s)
	report_box.add_child(UiKit.label("這場用了：" + "、".join(parts), 16, 0.8, true))


func _outcome(r: Dictionary) -> String:
	if r.is_empty():
		return ""
	var text: String = OUTCOME_NAMES[r["outcome"]]
	if r["outcome"] == "flee":
		text += "（第 %d 回合）" % r["rounds"]
	return text


## 比較用的分數，越大越好
func _score(key: String, r: Dictionary) -> float:
	match key:
		"outcome":
			return {"lose": 0, "flee": 1, "win": 2}.get(r["outcome"], 0)
		"rounds":
			return -r["rounds"]
		"hp_lost":
			return -float(r["hp_lost"]) / r["max_hp"]
		"foe_left":
			return -r["foe_left"]
		"stats":
			return r["str"] + r["agi"]
	return 0.0


## 用文字描述狀態，不只看血條
func _condition(c: Combatant, is_hero: bool) -> String:
	var r := float(c.hp) / c.max_hp
	if is_hero:
		if not c.is_alive():
			return "你倒在地上。" if c.yield_hp == 0 else "你撐不住了。"
		if r >= 0.8:
			return "你呼吸平穩，握劍的手很穩。"
		if r >= 0.5:
			return "你身上掛了幾道傷，還撐得住。"
		if r >= 0.25:
			return "你喘著粗氣，血一直流。"
		return "你搖搖欲墜，眼前發黑。"
	if not c.is_alive():
		return c.fill("{name}倒下了。")
	if c.enemy_def.get("hide_hp", false):
		return c.fill("{name}氣定神閒。")
	if r >= 0.8:
		return c.fill("{name}毫髮無傷。")
	if r >= 0.5:
		return c.fill("{name}身上帶了傷。")
	if r >= 0.25:
		return c.fill("{name}傷得不輕，動作慢了下來。")
	return c.fill("{name}快撐不住了。")


func _hp_column(name_text: String, fill_color: Color) -> Dictionary:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	var name_label := UiKit.label(name_text, 24)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var hp := UiKit.label("", 20)
	head.add_child(hp)
	box.add_child(head)
	var bar := UiKit.bar(fill_color)
	box.add_child(bar)
	var status := UiKit.label("", 16, 1.0, true)
	status.add_theme_color_override("font_color", Color(COLOR["status"]))
	box.add_child(status)
	return {"box": box, "bar": bar, "hp": hp, "name": name_label, "status": status}
