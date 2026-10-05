class_name BattleView
extends VBoxContainer

## 戰鬥畫面。只負責顯示，規則都在 Battle，挑招在 AutoPilot。
## 戰鬥自己打：每隔一下打一回合，戰報一段一段出來。
## 玩家能調的：播放速度（像影音播放器）、跳過、撤退。
## 戰報像小說一樣一段接一段：每回合寫成一段，不列回合數，對手一般出手的架勢不單獨寫
## （蓄勢、破綻、被抱住才寫）。傷害數字另外放一行小字。不寫雙方的數值（show don't tell）。
##
## 打完發出 ended（外面結算後呼叫 show_settlement），按「回到城裡」發出 closed。

signal ended
signal closed
## 戰利品：拿走對方身上的東西、換上自己的武器
signal loot_taken(id: String)
signal equip_requested(id: String)

## 播放速度：圖示、每回合幾秒
const SPEEDS := [["▶", 1.4], ["▶▶", 0.8], ["▶▶▶", 0.3]]

const COLOR := {
	"scene": "#9aa3ad",
	"damage_out": "#9be39b",
	"damage_in": "#ff8a8a",
	"info": "#a0c4ff",
	"pain": "#c9b8a6",
	"status": "#c9b8a6",
	"ult": "#ffe9a8",
	"big": "#ffd479",
}

var battle: Battle
var hero_c: Combatant
var foe_c: Combatant
var pilot := AutoPilot.new()
var timer: Timer
## 速度選第幾個（換場戰鬥也記得）
var speed_index := 1
## 玩家按了撤退，下一回合就撤
var flee_requested := false
## 還沒寫出去的段落（對手的架勢寫在下一回合那段的開頭）
var _para: Array = []

var hero_name_label: Label
var hero_bar: ProgressBar
var hero_hp_label: Label
var hero_status: Label
var foe_bar: ProgressBar
var foe_hp_label: Label
var foe_name_label: Label
var foe_status: Label
var log_label: RichTextLabel
var play_box: HBoxContainer
var speed_buttons: Array[Button] = []
var flee_button: Button
var end_box: HBoxContainer
## 打贏後的戰利品：左邊你的武器、右邊對方身上的
var loot_box: HBoxContainer
var mine_list: VBoxContainer
var drop_list: VBoxContainer
var drop_title: Label


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

	# 中：戰鬥紀錄
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_constant_override("line_separation", 6)
	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_child(log_label)
	add_child(log_panel)

	# 下：打的時候 速度／跳過／撤退，打完 回到城裡
	play_box = UiKit.hbox(8)
	for i in SPEEDS.size():
		var b := UiKit.button(SPEEDS[i][0], 80, 52)
		b.toggle_mode = true
		b.pressed.connect(_set_speed.bind(i))
		speed_buttons.append(b)
		play_box.add_child(b)
	var skip := UiKit.button("⏭", 80, 52)
	skip.tooltip_text = "跳過"
	skip.pressed.connect(_skip)
	play_box.add_child(skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_box.add_child(spacer)
	flee_button = UiKit.button("撤退", 120, 52)
	flee_button.pressed.connect(_request_flee)
	play_box.add_child(flee_button)
	add_child(play_box)

	# 打贏後的戰利品（有東西才出現）
	loot_box = UiKit.hbox(16)
	loot_box.visible = false
	var mine := _loot_column("你的武器")
	mine_list = mine["list"]
	loot_box.add_child(mine["box"])
	var drop := _loot_column("")
	drop_list = drop["list"]
	drop_title = drop["title"]
	loot_box.add_child(drop["box"])
	add_child(loot_box)

	end_box = UiKit.hbox(10)
	var back := UiKit.button("回到城裡", 170, 52)
	back.pressed.connect(func(): closed.emit())
	end_box.add_child(back)
	add_child(end_box)

	timer = Timer.new()
	timer.timeout.connect(_play_one)
	add_child(timer)


func begin(p_battle: Battle, note := "") -> void:
	battle = p_battle
	hero_c = battle.allies[0]
	foe_c = battle.enemies[0]
	flee_requested = false
	log_label.clear()
	_para.clear()
	loot_box.visible = false
	# 人標境界，怪物標危險度，都用境界的顏色
	var a := hero_c.adventurer
	hero_name_label.text = "你　%s　%s" % [a.realm_text(), WeaponData.get_def(a.weapon)["name"]]
	hero_name_label.add_theme_color_override("font_color", Color(a.realm_color()))
	var dg := EnemyData.danger(foe_c.enemy_id)
	if foe_c.enemy_def.has("title"):
		foe_name_label.text = ("%s %s" % [foe_c.enemy_def["title"], foe_c.display_name]).strip_edges() + "　" + dg["text"]
	elif foe_c.enemy_def.has("realm"):
		foe_name_label.text = "%s　%s" % [foe_c.display_name, dg["text"]]
	else:
		foe_name_label.text = "%s　%s %s" % [foe_c.display_name, dg["stars"], dg["stage"]]
	foe_name_label.add_theme_color_override("font_color", Color(dg["color"]))
	var hide: bool = foe_c.enemy_def.get("hide_hp", false)
	foe_bar.visible = not hide
	foe_hp_label.visible = not hide
	# 師傅的考驗：撐過幾回合就好，不能撤退（認輸由血量決定）
	var spar := hero_c.yield_hp > 0
	flee_button.visible = not spar
	_append(battle.start())
	if note != "":
		log_label.append_text("[color=%s]%s[/color]\n" % [COLOR["info"], note])
	_refresh()
	_set_speed(speed_index)
	timer.start()


## 打完的結算（拿到多少錢、數值成長…）接在戰鬥紀錄後面
func show_settlement(msgs: Array) -> void:
	log_label.append_text("\n" + UiKit.messages_bbcode(msgs) + "\n")


func _play_one() -> void:
	if battle == null or battle.is_over():
		timer.stop()
		return
	var choice := pilot.choose(battle, hero_c, foe_c)
	if flee_requested and battle.can_flee(hero_c):
		choice = MoveData.FLEE
	_append(battle.play_round({hero_c: {"move": choice, "target": foe_c}}))
	_refresh()
	if battle.is_over():
		timer.stop()
		ended.emit()


func _skip() -> void:
	while battle != null and not battle.is_over():
		_play_one()


func _set_speed(i: int) -> void:
	speed_index = i
	timer.wait_time = SPEEDS[i][1]
	for j in speed_buttons.size():
		speed_buttons[j].button_pressed = j == i


## 撤退：下一回合轉身就跑（被抱住時要等掙脫）
func _request_flee() -> void:
	flee_requested = true
	flee_button.disabled = true
	flee_button.text = "準備撤退…"


## 把事件排成段落：同一回合的敘述接成一段，傷害數字另外一行小字。
## 對手擺出的架勢（tell）是下一回合那段的開頭，所以留著等下一批事件。
func _append(events: Array) -> void:
	var damage := []
	var last := ""
	for e in events:
		var text: String = e["text"]
		last = e["kind"]
		match e["kind"]:
			"round", "intent", "stat":
				pass  # 回合數、對手一般的架勢、雙方數值只寫進試玩紀錄
			"scene":
				log_label.append_text("[i][color=%s]%s[/color][/i]\n" % [COLOR["scene"], text])
			"tell":
				_flush(damage)
				_para.append(text)
			"end":
				_flush(damage)
				log_label.append_text("\n[b][font_size=26]%s[/font_size][/b]\n" % text)
			"ult":
				# 絕學喊出招名：自己一行、字很大
				_flush(damage)
				log_label.append_text("[center][b][font_size=34][color=%s]%s[/color][/font_size][/b][/center]\n" % [COLOR["ult"], text])
			"big":
				_flush(damage)
				log_label.append_text("[color=%s]%s[/color]\n" % [COLOR["big"], text])
			"damage_in", "damage_out":
				# 劍的特效多砍的那一下，標出是哪把劍（不然看起來像莫名多打了一次）
				var src: String = "（%s）" % e["src"] if e.has("src") else ""
				damage.append("[color=%s]%s −%d%s[/color]" % [COLOR[e["kind"]], text, e["amount"], src])
			"action", "fx":
				_para.append(text)
			_:
				_para.append("[color=%s]%s[/color]" % [COLOR.get(e["kind"], "#ffffff"), text])
	if last != "tell" or battle.is_over():
		_flush(damage)


func _flush(damage: Array) -> void:
	if not _para.is_empty():
		log_label.append_text("\n" + "".join(_para) + "\n")
		_para.clear()
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
	if not flee_requested:
		flee_button.disabled = false
		flee_button.text = "撤退"


## 用文字描述狀態，不只看血條
func _condition(c: Combatant, is_hero: bool) -> String:
	var r := float(c.hp) / c.max_hp
	if is_hero:
		if not c.is_alive():
			return "你倒在地上。" if c.yield_hp == 0 else "你撐不住了。"
		if c.held:
			return "你被抱住了，掙脫之前跑不掉。"
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


# ---------- 戰利品 ----------

## 打贏後，對方身上有東西才打開。drops：還沒拿的武器 id
func show_loot(hero: Adventurer, drops: Array) -> void:
	loot_box.visible = true
	drop_title.text = "%s身上" % foe_c.display_name
	refresh_loot(hero, drops)


func refresh_loot(hero: Adventurer, drops: Array) -> void:
	UiKit.clear(mine_list)
	for id in hero.owned_weapons:
		var right: Control
		if hero.weapon == id:
			right = UiKit.label("用著", 16, 0.6)
		elif not hero.can_wield(id):
			right = UiKit.label("拿不動", 16, 0.6)
		else:
			var b := UiKit.button("換上", 90, 36)
			b.pressed.connect(func(): equip_requested.emit(id))
			right = b
		mine_list.add_child(_loot_row(id, right))
	UiKit.clear(drop_list)
	for id in drops:
		var b := UiKit.button("拿", 90, 36)
		b.pressed.connect(func(): loot_taken.emit(id))
		drop_list.add_child(_loot_row(id, b))
	if drops.is_empty():
		drop_list.add_child(UiKit.label("（空了）", 16, 0.5))


## 一樣東西一行：名字（滑鼠移上去看說明）＋右邊的按鈕。秘笈用品級的顏色
func _loot_row(id: String, right: Control) -> HBoxContainer:
	var row := UiKit.hbox(8)
	var n: Label
	if BookData.is_book(id):
		n = UiKit.book_label(id, 18)
	else:
		var w := WeaponData.get_def(id)
		n = UiKit.label(w["name"], 18)
		n.tooltip_text = UiKit.weapon_tooltip(w)
		if w.get("rare", false):
			n.add_theme_color_override("font_color", Color(COLOR["big"]))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(n)
	row.add_child(right)
	return row


func _loot_column(title: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiKit.vbox(6)
	var t := UiKit.label(title, 18, 0.8)
	box.add_child(t)
	var list := UiKit.vbox(4)
	box.add_child(list)
	panel.add_child(box)
	return {"box": panel, "list": list, "title": t}


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
