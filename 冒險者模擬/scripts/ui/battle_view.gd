class_name BattleView
extends VBoxContainer

## 戰鬥畫面。只負責顯示和按鈕，規則都在 Battle。
## 戰鬥紀錄參考 CK3 單挑：開場交代場景，每回合把雙方的動作寫成一整段，數字另外放一行小字，
## 雙方的狀態用文字描述。
##
## 打完發出 ended（外面結算後呼叫 show_settlement），按「回到城裡」發出 closed。

signal ended
signal closed

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

var battle: Battle
var hero_c: Combatant
var foe_c: Combatant

var hero_name_label: Label
var hero_bar: ProgressBar
var hero_hp_label: Label
var hero_status: Label
var foe_bar: ProgressBar
var foe_hp_label: Label
var foe_name_label: Label
var foe_status: Label
var log_label: RichTextLabel
var tell_label: Label
var hint_label: Label
var move_row: HBoxContainer
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

	# 對手現在的動作
	tell_label = UiKit.label("", 22, 1.0, true)
	tell_label.add_theme_color_override("font_color", Color(COLOR["tell"]))
	add_child(tell_label)

	# 下：選項
	move_row = UiKit.hbox(10)
	add_child(move_row)

	hint_label = UiKit.label("", 16, 0.6)
	add_child(hint_label)

	# 結束後的按鈕
	end_box = UiKit.hbox(10)
	var back := UiKit.button("回到城裡", 170, 52)
	back.pressed.connect(func(): closed.emit())
	end_box.add_child(back)
	add_child(end_box)


func begin(p_battle: Battle, note := "") -> void:
	battle = p_battle
	hero_c = battle.allies[0]
	foe_c = battle.enemies[0]
	log_label.clear()
	# 人標境界，怪物標危險度，都用境界的顏色
	var a := hero_c.adventurer
	hero_name_label.text = "你　%s" % a.realm_text()
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


## 打完的結算（拿到多少錢、數值成長…）接在戰鬥紀錄後面
func show_settlement(msgs: Array) -> void:
	log_label.append_text("\n" + UiKit.messages_bbcode(msgs) + "\n")


func _on_move(id: String) -> void:
	if battle == null or battle.is_over():
		return
	_append(battle.play_round({hero_c: {"move": id, "target": foe_c}}))
	_refresh()
	if battle.is_over():
		ended.emit()


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
	if not over and hero_c.hand_note != "":
		hero_status.text += hero_c.hand_note
	move_row.visible = not over
	hint_label.visible = not over
	end_box.visible = over
	if over:
		tell_label.text = ""
		return
	tell_label.text = "▶ " + foe_c.intent["text"]

	# 選項每回合都不同，重新排按鈕
	UiKit.clear(move_row)
	for opt in battle.hand_options(hero_c):
		var b := UiKit.button(opt["name"], 150, 52)
		b.tooltip_text = opt["desc"]
		b.pressed.connect(_on_move.bind(opt["id"]))
		b.mouse_entered.connect(_show_hint.bind(opt["id"]))
		move_row.add_child(b)
	# 撤退不是招式，跟選項分開放在最右邊
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_row.add_child(spacer)
	var flee := UiKit.button("撤退", 120, 52)
	flee.disabled = not battle.can_flee(hero_c)
	flee.pressed.connect(_on_move.bind(MoveData.FLEE))
	flee.mouse_entered.connect(_show_hint.bind(MoveData.FLEE))
	move_row.add_child(flee)
	hint_label.text = ""


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


func _show_hint(id: String) -> void:
	var m: Dictionary = MoveData.MOVES[id]
	if m.has("stat"):
		var s: String = m["stat"]
		hint_label.text = "%s（靠%s：你 %d，對手 %d）：%s" % [m["name"], GrowthData.NAMES[s], hero_c.stats[s], foe_c.stats[s], m["desc"]]
	else:
		hint_label.text = "%s：%s" % [m["name"], m["desc"]]


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
