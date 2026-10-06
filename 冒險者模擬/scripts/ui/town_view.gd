class_name TownView
extends VBoxContainer

## 主畫面：你的狀態、地圖、人物、休養；在城裡才有委託板（冒險者公會）、練武場、獅心劍庭、武器店的分頁。
## 點人的名字發出 person_requested，由 main 打開人物面板。
## 只負責顯示和按鈕，規則都在 Town。城外只能走路、找人打；接委託、休養、學招、讀秘笈、買武器要在城裡。
## 要開打、要走路時發出 monster_requested / fight_requested / travel_requested / spar_requested，由 main 處理。
## 花時間的事（學招、讀秘笈、休養）發出 wait_requested，由 main 擋住按鈕、呼叫 play_wait 演那段時間。
## 臨終時中間換成安排後事（選誰接手），選好發出 heir_chosen。

signal monster_requested(enemy_id: String)
signal fight_requested(person_id: String)
signal travel_requested(place: String)
signal heir_chosen(person_id: String)
signal spar_requested
signal trial_requested
signal person_requested(person_id: String)
## 花了時間：w 是 Town.take_wait() 那一段，msgs 是這件事的結果
signal wait_requested(w: Dictionary, msgs: Array)
## 城裡發生了事（寫試玩紀錄用）
signal messages_added(msgs: Array)

const BAD := "#ff8a8a"
const GOLD := "#ffd479"
const AGED := "#c9a46a"

var town: Town

var date_label: Label
var place_label: Label
var home_button: Button
var money_label: Label
var hp_bar: ProgressBar
var hp_label: Label
var rest_row: HBoxContainer
var me_box: VBoxContainer
var board_box: VBoxContainer
var training_view: SchoolView
var school_view: SchoolView
var shop_box: VBoxContainer
var log_label: RichTextLabel
var tabs: TabContainer
var map_view: MapView
var people_view: PeopleView
## 跳出來的選擇（main 給的）
var dialog: EncounterDialog
## 臨終時換掉中間的分頁
var deathbed_box: VBoxContainer
var deathbed_panel: Control


func _init(p_town: Town) -> void:
	town = p_town
	_rng.randomize()
	add_theme_constant_override("separation", 12)

	# 上：年紀、錢、血量、休養（壽命看不到）
	var top := UiKit.hbox(28)
	add_child(top)
	var date_box := UiKit.vbox(0)
	date_label = UiKit.label("", 24)
	date_box.add_child(date_label)
	top.add_child(date_box)
	var place_box := UiKit.hbox(8)
	place_label = UiKit.label("", 24)
	place_box.add_child(place_label)
	home_button = UiKit.button("", 150)
	home_button.pressed.connect(func(): travel_requested.emit(MapData.HOME))
	place_box.add_child(home_button)
	top.add_child(place_box)
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

	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(tabs)
	board_box = UiKit.vbox(10)
	var board := _scroll(board_box)
	board.name = "委託板"
	tabs.add_child(board)
	map_view = MapView.new(town)
	map_view.name = "地圖"
	map_view.travel_requested.connect(func(p): travel_requested.emit(p))
	map_view.fight_requested.connect(func(id): fight_requested.emit(id))
	map_view.monster_requested.connect(func(id): monster_requested.emit(id))
	map_view.person_selected.connect(show_person)
	training_view = SchoolView.new(town, "training", _act)
	training_view.name = "練武場"
	tabs.add_child(training_view)
	school_view = SchoolView.new(town, "school", _act)
	school_view.name = SchoolData.NAME
	school_view.spar_requested.connect(func(): spar_requested.emit())
	school_view.trial_requested.connect(func(): trial_requested.emit())
	school_view.person_requested.connect(show_person)
	tabs.add_child(school_view)
	tabs.add_child(map_view)
	people_view = PeopleView.new(town)
	people_view.name = "人物"
	people_view.person_requested.connect(show_person)
	tabs.add_child(people_view)
	shop_box = UiKit.vbox(10)
	var shop := _scroll(shop_box)
	shop.name = "武器"
	tabs.add_child(shop)
	deathbed_box = UiKit.vbox(10)
	deathbed_panel = _scroll(deathbed_box)
	deathbed_panel.visible = false
	mid.add_child(deathbed_panel)

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


# ---------- 等（花時間的事） ----------
# 不另開畫面：左上的年月一格一格往上跳，手寫片段寫進下面的紀錄。跳完 after 才給結果。
# 整段幾秒鐘，不能跳過；跳的時候按鈕按不了（由 main 擋住）。

## 每個月跳多快：整段的秒數 = 月數 × WAIT_SEC_PER_MONTH，限制在最短和最長之間
const WAIT_SEC_PER_MONTH := 0.3
const WAIT_MIN_SEC := 1.0
const WAIT_MAX_SEC := 3.5
## 最多寫幾句季節
const WAIT_SEASON_MAX := 2
const LINE_COLOR := "#9aa3ad"

var _rng := RandomNumberGenerator.new()


## w：Town.take_wait() 那一段。跳完呼叫 after。世界上發生的事跳到那個月才寫
func play_wait(w: Dictionary, after: Callable) -> void:
	var from: int = w["from"]
	var months: int = w["months"]
	var schedule := _wait_schedule(w["kind"], from, months)
	var news: Array = w.get("news", [])
	log_label.append_text("[color=%s]%s……[/color]\n" % [LINE_COLOR, w["title"]])
	_show_month(from)
	if months > 0:
		var step := clampf(months * WAIT_SEC_PER_MONTH, WAIT_MIN_SEC, WAIT_MAX_SEC) / months
		for tick in range(1, months + 1):
			await get_tree().create_timer(step).timeout
			_show_month(from + tick)
			if schedule.has(tick):
				log_label.append_text("[color=%s]%s[/color]\n" % [LINE_COLOR, schedule[tick]])
			var told := news.filter(func(e): return e["month"] == from + tick)
			if not told.is_empty():
				log_label.append_text(UiKit.messages_bbcode(told) + "\n")
				messages_added.emit(told)
	await get_tree().create_timer(0.3).timeout
	after.call()


## 跳的時候只動年月，其他的（血量、錢）跳完才更新
func _show_month(month: int) -> void:
	date_label.text = LifeData.date_text(town.hero.age_at(month), month)


## 第幾格寫哪一句：第一格寫剛開始的，中間換季寫季節，最後一格寫快結束的
func _wait_schedule(kind: String, from: int, months: int) -> Dictionary:
	var lines: Dictionary = LifeData.WAIT_LINES[kind]
	var s := {1: _pick_line(lines["start"])}
	var seasons := 0
	for i in range(2, months):
		var m := LifeData.month_of_year(from + i)
		if m % 3 == 0 and seasons < WAIT_SEASON_MAX:
			s[i] = _pick_line(LifeData.SEASON_LINES[LifeData.SEASONS[m]])
			seasons += 1
	if months >= 3 and not lines["end"].is_empty():
		s[months] = _pick_line(lines["end"])
	return s


func _pick_line(list: Array) -> String:
	return list[_rng.randi_range(0, list.size() - 1)]


## 上面那排：年月、錢、血量（等的時候先更新血量，不然打輸了還顯示滿血）
func refresh_status() -> void:
	var h := town.hero
	date_label.text = h.date_text()
	money_label.text = "%d 銀" % h.money
	hp_label.text = "血量 %d / %d" % [h.hp, h.max_hp()]
	hp_bar.max_value = h.max_hp()
	hp_bar.value = h.hp


func refresh() -> void:
	var h := town.hero
	refresh_status()
	place_label.text = "往%s的路上" % MapData.place_name(h.location) if h.travel_left > 0 else MapData.place_name(h.location)
	var home := MapData.distance(h.location, MapData.HOME)
	home_button.visible = home > 0 and not h.dying()
	home_button.text = "回城"
	tabs.visible = not h.dying()
	# 旅店在城裡：城外不能休養
	rest_row.visible = town.in_city() and not h.dying()
	# 城裡才有的地方：公會的委託板、道場、武器店
	var city := town.in_city()
	for tab in [board_box.get_parent(), training_view, school_view, shop_box.get_parent()]:
		var idx: int = tab.get_index()
		tabs.set_tab_hidden(idx, not city)
		if not city and tabs.current_tab == idx:
			tabs.current_tab = map_view.get_index()
	deathbed_panel.visible = h.dying()
	money_label.text = "%d 銀" % h.money
	money_label.add_theme_color_override("font_color", Color(BAD) if h.money < 0 else Color(GOLD))
	hp_label.text = "血量 %d / %d" % [h.hp, h.max_hp()]
	hp_bar.max_value = h.max_hp()
	hp_bar.value = h.hp
	_build_rest()
	_build_me()
	_build_board()
	training_view.refresh()
	school_view.refresh()
	_build_shop()
	map_view.refresh()
	people_view.refresh()
	if h.dying():
		_build_deathbed()


## 打開這個人的人物面板
func show_person(id: String) -> void:
	person_requested.emit(id)


## 走到一個地方之後：打開地圖，看這裡有誰
func show_map() -> void:
	tabs.current_tab = map_view.get_index()
	map_view.select(town.hero.location)


## 花了時間的就先演等的畫面，演完才寫進紀錄
func _act(msgs: Array) -> void:
	var w := town.take_wait()
	if w.is_empty():
		add_messages(msgs)
	else:
		wait_requested.emit(w, msgs)


# ---------- 休養 ----------

## 一個「休養」鍵：按了再選要休多久
func _build_rest() -> void:
	UiKit.clear(rest_row)
	var full := town.months_to_full()
	var away := not town.in_city() or town.hero.dying()
	var b := UiKit.button("休養", 150)
	b.disabled = full == 0 or away
	if away and not town.hero.dying():
		b.tooltip_text = "要在城裡"
	b.pressed.connect(_ask_rest)
	rest_row.add_child(b)


func _ask_rest() -> void:
	dialog.show_choice("", Color.WHITE, "在旅店住多久？",
		[["1", "一個月"], ["3", "三個月"], ["6", "半年"], ["full", "住到傷好"], ["no", "算了"]], _on_rest_choice)


func _on_rest_choice(c: String) -> void:
	if c == "no":
		return
	var full := town.months_to_full()
	_act(town.rest(full if c == "full" else mini(int(c), full)))


# ---------- 你 ----------
# 只放狀態，不放說明。規則和數字放在滑鼠提示（想查才看）

func _build_me() -> void:
	UiKit.clear(me_box)
	var h := town.hero
	var name_button := LinkButton.new()
	name_button.text = h.display_name
	name_button.tooltip_text = "人物面板"
	name_button.add_theme_font_size_override("font_size", 22)
	name_button.pressed.connect(func(): show_person(town.world.hero_id))
	me_box.add_child(name_button)
	var realm := _tip(UiKit.label(h.realm_text(), 22), "境界。衝破瓶頸就升一境，血量也跟著變多。")
	realm.add_theme_color_override("font_color", Color(h.realm_color()))
	me_box.add_child(realm)
	for s in GrowthData.STATS:
		var row := UiKit.hbox(10)
		var n := _tip(UiKit.label(GrowthData.NAMES[s], 18),
			"跟對手的%s比。比對手低越多，靠%s的招越容易失敗、打得越不痛。" % [GrowthData.NAMES[s], GrowthData.NAMES[s]])
		n.custom_minimum_size.x = 48
		row.add_child(n)
		# 寫現在的身體。老了掉下來的，字變暗黃，滑鼠移上去看最好的時候
		var v := UiKit.label(str(h.body(s)), 20)
		v.custom_minimum_size.x = 30
		if h.decline(s) > 0:
			v.add_theme_color_override("font_color", Color(AGED))
			_tip(v, "最好的時候 %d" % h.stats[s])
		row.add_child(v)
		var bar := UiKit.bar(Color("#7fa7d9"), 10)
		bar.custom_minimum_size.x = 140
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = h.exp_need()
		bar.value = h.exp[s]
		row.add_child(bar)
		if h.at_cap(s):
			var cap := _tip(UiKit.label("瓶頸", 16), "卡住了。打贏比你強的對手才衝得破。")
			cap.add_theme_color_override("font_color", Color(GOLD))
			row.add_child(cap)
		me_box.add_child(row)
	var w := WeaponData.get_def(h.weapon)
	me_box.add_child(_tip(UiKit.label(w["name"], 18), UiKit.weapon_tooltip(w)))

	# 流派、架勢（招和更多的東西看人物面板）
	if h.school == SchoolData.ID and h.rank > 0:
		me_box.add_child(UiKit.label("%s %s・貢獻 %d" % [SchoolData.NAME, SchoolData.RANKS[h.rank], h.merit], 17, 0.85))
	elif h.merit > 0:
		me_box.add_child(UiKit.label("劍庭的貢獻 %d" % h.merit, 17, 0.85))
	if SchoolData.stance_active(h):
		var sd := SchoolData.stance_def(SchoolData.stance_of(h))
		var st := _tip(UiKit.label("架勢：%s" % sd["name"], 17), sd["desc"])
		st.add_theme_color_override("font_color", Color(GrowthData.GRADE_COLORS[2]))
		me_box.add_child(st)

	if not h.books.is_empty():
		me_box.add_child(UiKit.heading("秘笈"))
		var shown := []
		for id in h.books:
			var st := town.book_state(id)
			var row := UiKit.hbox(10)
			# 殘頁湊齊了就是一本書（寫書名）；還沒湊齊只寫殘頁，不能讀
			var set_id := BookData.set_of(id)
			var whole := BookData.complete(h.books, id)
			if shown.has(set_id) and whole:
				continue
			var n := UiKit.book_label(set_id if whole else id, 18)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(n)
			if not whole:
				me_box.add_child(row)
				continue
			shown.append(set_id)
			if st["read"]:
				row.add_child(UiKit.label("讀過", 16, 0.5))
			else:
				var b := UiKit.button("讀", 100)
				b.disabled = not st["ok"]
				b.tooltip_text = st["why"]
				b.pressed.connect(func(): _act(town.read_book(id)))
				row.add_child(b)
			me_box.add_child(row)


# ---------- 委託板 ----------
# 一般委託：怪物在哪、報酬多少。懸賞只寫懸賞本身（誰、做了什麼、賞多少、有誰接了）。
# 人在哪、多強、帶著什麼，看人物面板（點名字）。

func _build_board() -> void:
	UiKit.clear(board_box)
	var h := town.hero
	# 辦完的事：回來交差才拿得到報酬
	var done := town.claims("guild")
	if not done.is_empty():
		var row := UiKit.hbox(16)
		var l := UiKit.label("辦完了：" + "、".join(done.map(func(c): return c["what"])), 18, 1.0, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := UiKit.button("交差", 110, 48)
		b.pressed.connect(func(): add_messages(town.turn_in("guild")))
		row.add_child(b)
		board_box.add_child(row)
		board_box.add_child(HSeparator.new())
	board_box.add_child(UiKit.heading("一般委託"))
	var list := town.board()
	if list.is_empty():
		board_box.add_child(UiKit.label("板子上空空的。", 17, 0.6))
	for id in list:
		var c: Dictionary = TownData.COMMISSIONS[id]
		var e: Dictionary = EnemyData.ENEMIES[id]
		var row := UiKit.hbox(16)
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dg := EnemyData.danger(id)
		var title_row := UiKit.hbox(12)
		title_row.add_child(UiKit.label(e["name"], 20))
		# 怪物標危險度
		var stars := _tip(UiKit.label("%s %s" % [dg["stars"], dg["stage"]], 20), "危險度：大約是%s的人打得贏的" % dg["text"])
		stars.add_theme_color_override("font_color", Color(dg["color"]))
		title_row.add_child(stars)
		if h.beaten.has(id):
			title_row.add_child(UiKit.label("打贏過", 16, 0.5))
		info.add_child(title_row)
		info.add_child(UiKit.label(town.commission_text(id), 16, 0.75, true))
		info.add_child(UiKit.label("%s・%d 銀" % [MapData.place_name(town.world.monster_place(id)), c["reward"]], 15, 0.6))
		row.add_child(info)
		row.add_child(_take_button(town.took_job(id), func(): add_messages(town.accept_job(id))))
		board_box.add_child(row)
		board_box.add_child(HSeparator.new())

	var head := UiKit.heading("懸賞")
	head.add_theme_color_override("font_color", Color(GOLD))
	board_box.add_child(head)
	for id in town.world.bounties:
		var bounty: Dictionary = town.world.bounties[id]
		var p := town.world.person(id)
		var row := UiKit.hbox(16)
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_button := LinkButton.new()
		name_button.text = ("%s %s" % [p.title, p.display_name]).strip_edges()
		name_button.add_theme_font_size_override("font_size", 20)
		name_button.add_theme_color_override("font_color", Color(p.realm_color()))
		name_button.tooltip_text = "看人物面板"
		name_button.pressed.connect(show_person.bind(id))
		var name_row := UiKit.hbox(0)
		name_row.add_child(name_button)
		info.add_child(name_row)
		info.add_child(UiKit.label(bounty["text"], 16, 0.75, true))
		# 公會知道的：最近有人在哪裡看到他
		var line := "最近有人在%s看到%s・%d 銀" % [MapData.place_name(p.travel_to if p.travel_left > 0 else p.location), p.pron, bounty["reward"]]
		var takers: Array = bounty["takers"].filter(func(t): return t != town.world.hero_id and not town.world.person(t).dead)
		if not takers.is_empty():
			line += "・接下的人：" + "、".join(takers.map(func(t): return town.world.who(t)))
		info.add_child(UiKit.label(line, 15, 0.6))
		row.add_child(info)
		row.add_child(_take_button(town.took_bounty(id), func(): add_messages(town.accept_bounty(id))))
		board_box.add_child(row)
		board_box.add_child(HSeparator.new())


## 「接下」按鈕；接過了就寫「你接下了」
func _take_button(took: bool, on_take: Callable) -> Control:
	if took:
		var l := UiKit.label("你接下了", 17)
		l.add_theme_color_override("font_color", Color("#9be39b"))
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return l
	var b := UiKit.button("接下", 110, 52)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(on_take)
	return b


# ---------- 臨終 ----------
# 病倒了，不能出遠門。選一個人把東西交給他，換他接著玩。

func _build_deathbed() -> void:
	UiKit.clear(deathbed_box)
	var h := town.hero
	deathbed_box.add_child(UiKit.heading("後事"))
	deathbed_box.add_child(UiKit.label("你知道自己起不來了。身上的東西、還沒做完的事，要交給誰？", 18, 0.85, true))
	var things := h.items().map(func(it): return town._item_name(it))
	deathbed_box.add_child(UiKit.label("身上的東西：%s。還有 %d 銀。" % ["、".join(things), maxi(0, h.money)], 16, 0.7, true))
	deathbed_box.add_child(HSeparator.new())
	for p in town.heir_candidates():
		var row := UiKit.hbox(16)
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title_row := UiKit.hbox(12)
		title_row.add_child(UiKit.label(("%s %s" % [p.title, p.display_name]).strip_edges(), 20))
		var realm := UiKit.label(p.realm_text(), 18)
		realm.add_theme_color_override("font_color", Color(p.realm_color()))
		title_row.add_child(realm)
		title_row.add_child(UiKit.label("%d 歲" % p.age(), 18, 0.7))
		info.add_child(title_row)
		var school := "%s %s" % [SchoolData.school_name(p.school), SchoolData.rank_name(p)] if p.rank > 0 else "沒有流派"
		info.add_child(UiKit.label("%s・在%s" % [school, MapData.place_name(p.location)], 16, 0.7))
		row.add_child(info)
		var b := UiKit.button("交給%s" % p.pron, 130, 52)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): heir_chosen.emit(p.id))
		row.add_child(b)
		deathbed_box.add_child(row)
		deathbed_box.add_child(HSeparator.new())


# ---------- 武器（你的武器、武器店） ----------

func _build_shop() -> void:
	UiKit.clear(shop_box)
	var h := town.hero
	shop_box.add_child(UiKit.heading("你的武器"))
	for id in h.owned_weapons:
		var w := WeaponData.get_def(id)
		var row := UiKit.hbox(12)
		row.add_child(_weapon_name(w, h.can_wield(id)))
		if h.weapon == id:
			var using := UiKit.label("用著", 17)
			using.add_theme_color_override("font_color", Color("#9be39b"))
			row.add_child(using)
		elif h.can_wield(id):
			var b := UiKit.button("換上", 120)
			b.pressed.connect(func(): _act(town.equip(id)))
			row.add_child(b)
		shop_box.add_child(row)

	shop_box.add_child(HSeparator.new())
	shop_box.add_child(UiKit.heading("武器店"))
	for id in town.shop_items():
		var st := town.weapon_state(id)
		if st["owned"]:
			continue
		var row := UiKit.hbox(12)
		if BookData.is_book(id):
			var bk := BookData.get_def(id)
			var l := _tip(UiKit.label("《%s》" % bk["name"], 19), bk["desc"])
			l.add_theme_color_override("font_color", Color(BookData.color(id)))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
		else:
			row.add_child(_weapon_name(WeaponData.get_def(id), st["ok"]))
		var b := UiKit.button("花 %d 銀買" % town.price(id), 170)
		b.disabled = not st["ok"]
		b.tooltip_text = "、".join(st["why"])
		b.pressed.connect(func(): _act(town.buy_weapon(id)))
		row.add_child(b)
		shop_box.add_child(row)


## 武器的名字（稀有的金色），拿不動的寫門檻。說明和數字在滑鼠提示
func _weapon_name(w: Dictionary, usable: bool) -> Label:
	var title: String = w["name"]
	if w["str"] > 0 and not usable:
		title += "　（力量 %d）" % w["str"]
	var l := _tip(UiKit.label(title, 19, 1.0 if usable else 0.5), UiKit.weapon_tooltip(w))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if w.get("rare", false):
		l.add_theme_color_override("font_color", Color(GOLD))
	return l


## 加上滑鼠提示
func _tip(l: Label, text: String) -> Label:
	l.tooltip_text = text
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	return l


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
