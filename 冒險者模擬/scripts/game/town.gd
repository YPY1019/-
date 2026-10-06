class_name Town
extends RefCounted

## 你能做的事（規則）：走到哪裡、打委託的怪物、找人打、接懸賞、休養、時間（月）和生活費、
## 練武場、獅心劍庭（入門、委託和貢獻、換招、公開比試）、秘笈、武器店、戰利品、戰鬥打完的結算（數值成長、瓶頸）、臨終和換人接著玩。
## 世界上的人自己的事在 World；你也是 World 裡的一個人（hero）。
## 不碰畫面：每個動作回傳訊息清單 [{"kind", "text"}]，畫面照著顯示。
##   kind：info 一般、good 好事、bad 壞事、big 大事、epic 一輩子記得的大事（升境、拿到秘笈、讀完秘笈、病倒、死去）、
##   news 傳聞（世界上發生的事）
## 花時間的事（走路、學招、讀秘笈、休養、養傷）會在 wait 留下要演的那一段，畫面演完等的畫面才給結果。
## 快死時病倒（臨終）：正在做的事做不完，之後只能安排後事。壽命用完了 hero.dead 就是 true。

var world: World
var hero: Person:
	get:
		return world.hero()
## 剛打贏的對手身上的東西（武器 id、秘笈 id）。玩家自己決定拿不拿，離開戰鬥畫面就沒了
var loot: Array[String] = []
## 剛花掉的時間，給等的畫面演：{"kind", "title", "from", "months", "age_from", "news"}。畫面用 take_wait() 拿走
var wait := {}
## 臨終時選好要交給誰
var heir_id := ""

## 正在打的：委託的怪物 id，或世界上的人 id
var _fight_enemy := ""
var _fight_person: Person
var _fight_lethal := true
## 打的是同門
var _fight_kin := false
## 打的怪物有沒有接委託
var _fight_has_job := false
## 剛打贏、還沒決定殺不殺的人
var fate_pending: Person = null
## 選拔的對手（世界上的人；沒有就是 null）
var _selection_foe: Person = null


## seed：-1 = 隨機（測試用固定的）
func _init(seed := -1) -> void:
	world = World.new(seed)
	var pick: Array = TownData.HERO_NAMES[world.rng.randi_range(0, TownData.HERO_NAMES.size() - 1)]
	world.make_hero(pick[0], pick[1])


func take_wait() -> Dictionary:
	var w := wait
	wait = {}
	return w


func in_city() -> bool:
	return MapData.is_city(hero.location) and hero.travel_left == 0


# ---------- 走路 ----------

## 走到別的地方。路上的時間先花掉；路上病倒了就被送回城裡
func travel(place: String) -> Array:
	var h := hero
	var months := MapData.distance(h.location, place)
	if months <= 0 or h.dying():
		return []
	var title := "回%s" % MapData.place_name(place) if MapData.is_city(place) else "往%s去" % MapData.place_name(place)
	h.location = place
	h.travel_left = months
	var msgs := _pass_months(months, "travel_back" if MapData.is_city(place) else "travel", title)
	h.travel_left = 0
	if h.dying():
		return msgs
	world.look_around()
	msgs.append(_m("info", "你到了%s。" % MapData.place_name(place)))
	# 委託的怪物在這裡：看得到牠留下的痕跡
	for id in monsters_at(place):
		msgs.append(_m("info", TownData.COMMISSIONS[id]["sign"]))
	msgs.append_array(_deliver(place))
	if MapData.is_city(place):
		if not claims("guild").is_empty():
			msgs.append(_m("info", "公會的櫃台後面，有人朝你招手。"))
		if not claims("school").is_empty():
			msgs.append(_m("info", "劍庭門口的學徒看見你，進去通報了。"))
	return msgs


## 送貨：走到那裡就交了，回劍庭交差
func _deliver(place: String) -> Array:
	var msgs := []
	for id in hero.school_jobs.duplicate():
		var j: Dictionary = SchoolData.JOBS[id]
		if j["kind"] == "deliver" and j["place"] == place:
			msgs.append(_m("info", j["done"]))
			msgs.append_array(_school_done(id))
	return msgs


# ---------- 委託的怪物 ----------

## 委託板上現在有哪些怪物（打過的越來越久才再出現）
func board() -> Array:
	return EnemyData.ORDER.filter(func(id): return world.monster_open(id))


## 這個地方現在有委託的怪物
func monsters_at(place: String) -> Array:
	return board().filter(func(id): return world.monster_place(id) == place)


## 委託的說明（寫著這次在哪出沒）
func commission_text(id: String) -> String:
	return TownData.COMMISSIONS[id]["text"].replace("{place}", MapData.place_name(world.monster_place(id)))


## 這個地方你接下的劍庭的事要打的人（duel）
func duels_at(place: String) -> Array:
	var list := []
	for id in hero.school_jobs:
		var j: Dictionary = SchoolData.JOBS[id]
		if j["kind"] == "duel" and j["place"] == place:
			list.append(j["enemy"])
	return list


## 在公會接下委託（不花時間）。接了才拿得到報酬，地方自己走過去
func accept_job(enemy_id: String) -> Array:
	if hero.jobs.has(enemy_id) or not world.monster_open(enemy_id):
		return []
	hero.jobs.append(enemy_id)
	return [_m("info", "你接下了委託：%s。" % EnemyData.ENEMIES[enemy_id]["name"])]


func took_job(enemy_id: String) -> bool:
	return hero.jobs.has(enemy_id)


## 開打：場景照所在的地方寫
func start_monster(enemy_id: String) -> Battle:
	_fight_enemy = enemy_id
	_fight_has_job = hero.jobs.has(enemy_id) or duels_at(hero.location).has(enemy_id)
	_fight_person = null
	loot.clear()
	var foe := Combatant.from_enemy(enemy_id)
	foe.enemy_def = foe.enemy_def.duplicate()
	foe.enemy_def["scene"] = MapData.PLACES[hero.location]["scene"]
	return Battle.new([hero.to_combatant()], [foe])


func finish_monster(battle: Battle) -> Array:
	var r := battle.result()
	var id := _fight_enemy
	var msgs := []
	match r["outcome"]:
		"win":
			hero.hp = r["hp"]
			if TownData.COMMISSIONS.has(id):
				world.monster_done(id)
				if hero.jobs.has(id):
					hero.jobs.erase(id)
					var e: Dictionary = EnemyData.ENEMIES[id]
					_claim("guild", e["name"], TownData.COMMISSIONS[id]["reward"], 0)
					msgs.append(_m("info", "你帶上能證明的東西，回公會交差。"))
				elif not _fight_has_job:
					msgs.append(_m("info", "這一趟沒有人付錢。"))
			msgs.append_array(_jobs_done("duel", id))
			msgs.append_array(_after_monster(id))
		"flee":
			hero.hp = r["hp"]
		"lose":
			hero.note("被%s打成重傷" % EnemyData.ENEMIES[id]["name"])
			msgs.append_array(_knocked_out())
	msgs.append_array(_grow(EnemyData.ENEMIES[id], r))
	if r["outcome"] == "lose":
		msgs.append_array(_pass_months(TownData.INJURED_MONTHS, "injured", "養傷"))
	return msgs


## 打贏怪物：牠身上的東西、卡在瓶頸時打贏強敵就衝破瓶頸
func _after_monster(id: String) -> Array:
	var msgs := []
	if not hero.beaten.has(id):
		hero.beaten.append(id)
		hero.note("打倒了%s" % EnemyData.ENEMIES[id]["name"])
	var e: Dictionary = EnemyData.ENEMIES[id]
	var drop: String = e.get("loot", "")
	if drop != "" and not hero.owned_weapons.has(drop):
		loot.append(drop)
	msgs.append_array(_maybe_break_through(maxi(e["str"], e["agi"])))
	return msgs


## 卡在瓶頸時打贏比瓶頸強的對手就衝破。以前打贏過也算，不然先打贏、後卡瓶頸的人會卡死
func _maybe_break_through(foe_best: int) -> Array:
	if foe_best > hero.cap() and hero.stuck() and hero.can_break_through():
		return _break_through()
	return []


## 打輸了：重傷，被人撿回城裡
func _knocked_out() -> Array:
	hero.hp = maxi(1, roundi(hero.max_hp() * TownData.INJURED_HP))
	var away := hero.location != MapData.HOME
	hero.location = MapData.HOME
	if away:
		return [_m("bad", "路過的商隊把你撿了回來。醒來時你躺在霜溪城的旅店，身上纏滿了繃帶。")]
	return [_m("bad", "有人把你抬回了旅店。醒來時你身上纏滿了繃帶。")]


# ---------- 世界上的人 ----------

## 在你這裡的人（不含你）
func people_here() -> Array:
	return world.at(hero.location)


## 這個人是你的同門（你是劍庭的人，他也是）
func same_school(id: String) -> bool:
	var p := world.person(id)
	return p != null and member() and p.school == hero.school and p.rank > 0


## 能不能找這個人打：在同一個地方。庭主不打
func can_fight(id: String) -> bool:
	var p := world.person(id)
	return p != null and not p.dead and p.role != "master" and p.location == hero.location and p.travel_left == 0 \
		and not hero.dying()


## 有人找上門來（在你這裡、正在找你）。沒有就是 null
func comer() -> Person:
	if hero.dying() or hero.dead:
		return null
	return world.comer()


## 找上門的人開口說的話
func comer_text(p: Person) -> String:
	var d: Dictionary = PeopleData.PEOPLE.get(p.id, {})
	if p.role == "duelist" and d.has("challenge"):
		return d["challenge"]
	if d.has("avenge"):
		return "%s找上了你。\n%s" % [p.display_name, d["avenge"]]
	if world.bounties.has(hero.id) or p.role == "hunter":
		return "%s找上了你，手按在%s上。" % [p.display_name, WeaponData.get_def(p.weapon).get("noun", "兵器")]
	return "%s找上了你，擋在你面前不走。" % p.display_name


## 找上門的人：你可以怎麼回應 [[id, 按鈕的字]]。fight 應戰；decline 不跟他打（決鬥的人會走）；slip 想辦法走掉
func comer_options(p: Person) -> Array:
	var list := [["fight", "應戰"]]
	if p.role == "duelist" and p.grudges.is_empty() or not p.grudges.has(hero.id) and p.target == hero.id and not world.lethal(p, hero):
		list.append(["decline", "不跟%s打" % p.pron])
	else:
		list.append(["slip", "想辦法走掉"])
	return list


## 不應戰：決鬥的人走了（過一陣子再說）；來尋仇的人看你身手，走不走得掉（敏捷比他高越多越容易）
## 回傳 {"fight": 還是要打, "msgs"}
func answer_comer(p: Person, choice: String) -> Dictionary:
	match choice:
		"decline":
			p.target = ""
			p.rest_left = world.rng.randi_range(World.DUEL_EVERY[0], World.DUEL_EVERY[1])
			return {"fight": false, "msgs": [_m("info", "%s看了你一會兒，把%s收了回去，轉身走了。" % [p.display_name, WeaponData.get_def(p.weapon).get("noun", "兵器")])]}
		"slip":
			var chance := GrowthData.success_chance(hero.body("agi") - p.body("agi"))
			if world.rng.randf() < chance:
				p.rest_left = world.rng.randi_range(2, 4)
				return {"fight": false, "msgs": [_m("info", "你閃進人群，從後巷繞了出去。%s沒追上來。" % p.display_name)]}
			return {"fight": true, "msgs": [_m("bad", "你才轉身，%s已經擋在你前面。" % p.display_name)]}
	return {"fight": true, "msgs": []}


func start_person(id: String) -> Battle:
	var p := world.person(id)
	_fight_enemy = ""
	_fight_person = p
	_fight_lethal = world.lethal(hero, p)
	_fight_kin = same_school(id)
	if not hero.fought.has(p.id):
		hero.fought.append(p.id)
	loot.clear()
	fate_pending = null
	# 打贏之後殺不殺由你決定（decide_fate），戰鬥本身只寫到他倒下
	return Battle.new([hero.to_combatant()], [Combatant.from_person(p, hero.location, false)])


func finish_person(battle: Battle) -> Array:
	var r := battle.result()
	var p := _fight_person
	var msgs := []
	p.hp = maxi(1, battle.enemies[0].hp)
	var outcome: String = r["outcome"]
	# 打到一半他逃了：人和東西都還是他的
	if outcome == "win" and battle.enemies[0].fled:
		outcome = "fled_foe"
		hero.hp = r["hp"]
		p.rest_left = maxi(p.rest_left, 3)
	match outcome:
		"win":
			hero.hp = r["hp"]
			if not hero.beaten.has(p.id):
				hero.beaten.append(p.id)
			fate_pending = p
			for it in p.items():
				if it != WeaponData.FIST:
					loot.append(it)
			msgs.append_array(_maybe_break_through(maxi(p.body("str"), p.body("agi"))))
		"flee":
			hero.hp = r["hp"]
			world.hero_fled(p)
		"lose":
			var taken := world.hero_lost(p)
			msgs.append_array(_knocked_out())
			for it in taken:
				msgs.append(_m("bad", "你身上的%s不見了。" % _item_name(it)))
	msgs.append_array(_grow(p.body_stats(), r))
	if _fight_kin:
		msgs.append_array(_expel())
	if r["outcome"] == "lose":
		msgs.append_array(_pass_months(TownData.INJURED_MONTHS, "injured", "養傷"))
	return msgs


## 打贏了一個人：殺了他，還是放他走。懸賞要的是他的命
func decide_fate(kill: bool) -> Array:
	var p := fate_pending
	if p == null:
		return []
	fate_pending = null
	var msgs := []
	var b: Dictionary = world.bounties.get(p.id, {})
	var paid: bool = kill and not b.is_empty() and b["takers"].has(world.hero_id)
	world.hero_won(p, kill)
	if kill:
		msgs.append(_m("big", "你走上前，結果了%s。" % p.display_name))
		msgs.append_array(_jobs_done("kill", p.id))
		if paid:
			_claim("guild", "%s的懸賞" % p.display_name, b["reward"], 0)
			msgs.append(_m("info", "你帶上能證明的東西，回公會交差。"))
	else:
		msgs.append(_m("info", "你收起%s，讓%s走了。" % [WeaponData.get_def(hero.weapon).get("noun", "兵器"), p.display_name]))
	return msgs


## 對同門動手：被逐出劍庭
func _expel() -> Array:
	if not member():
		return []
	hero.rank = 0
	hero.school = ""
	hero.expelled = true
	hero.merit = 0
	hero.school_jobs.clear()
	hero.claims = hero.claims.filter(func(c): return c["from"] != "school")
	hero.note("對同門動手，被逐出獅心劍庭")
	return [_m("bad", "消息傳回劍庭。第二天，你的名字從劍庭的名冊上劃掉了。")]


## 在公會打聽一個人的下落：付錢，之後幾個月都知道他在哪（地圖上標出來）。要在城裡
func inquire_state(id: String) -> Dictionary:
	var p := world.person(id)
	var cost := TownData.INQUIRE_COST + (TownData.INQUIRE_PER_REALM * p.realm if p != null else 0)
	var st := {"ok": false, "why": "", "cost": cost, "tracking": hero.inquired.get(id, -1) >= world.month()}
	if p == null or p.dead or id == world.hero_id:
		st["why"] = "-"
	elif not in_city():
		st["why"] = "要在城裡"
	elif hero.money < st["cost"]:
		st["why"] = "錢不夠"
	else:
		st["ok"] = true
	return st


func inquire(id: String) -> Array:
	var st := inquire_state(id)
	if not st["ok"]:
		return []
	hero.money -= st["cost"]
	hero.inquired[id] = world.month() + TownData.INQUIRE_MONTHS
	world.hear(id)
	var p := world.person(id)
	var where := MapData.place_name(p.travel_to if p.travel_left > 0 else p.location)
	var line := "往%s的路上" % where if p.travel_left > 0 else "在%s" % where
	return [_m("info", "公會的人收下 %d 銀，翻了翻簿子：「%s%s。之後有消息，會再告訴你。」" % [st["cost"], p.display_name, line])]


## 接下懸賞（不花時間）
func accept_bounty(id: String) -> Array:
	if not world.bounties.has(id):
		return []
	world.accept_bounty(id)
	world.hear(id)
	return [_m("info", "你在公會登記，接下了%s的懸賞。" % world.who(id))]


func took_bounty(id: String) -> bool:
	return world.bounties.has(id) and world.bounties[id]["takers"].has(world.hero_id)


# ---------- 戰利品 ----------

## 拿走一樣東西。拿到秘笈是大事
func take_loot(id: String) -> Array:
	if not loot.has(id):
		return []
	loot.erase(id)
	if _fight_person != null:
		_fight_person.remove_item(id)
	hero.give_item(id)
	if BookData.is_book(id):
		var b := BookData.get_def(id)
		hero.note("拿到%s" % _item_name(id))
		var got: String = b["got"].replace("{p:from}", _fight_person.display_name if _fight_person != null else "")
		var msgs := [_m("epic", got)]
		# 殘頁湊齊了
		if b.has("page_of") and BookData.complete(hero.books, id):
			msgs.append(_m("epic", BookData.get_def(b["page_of"])["complete"]))
		return msgs
	var w := WeaponData.get_def(id)
	if w.get("rare", false):
		hero.note("拿到%s" % w["name"])
	return [_m("info", "你拿走了%s。" % w["name"])]


func clear_loot() -> void:
	loot.clear()
	_fight_person = null


## 打完回來：劍譜在身上，庭主又交代過，就拿去給他看
func after_fight() -> Array:
	return _report_errand() if in_city() else []


# ---------- 秘笈 ----------

## 這本現在能不能讀：{"read", "ok", "months", "why"}。殘頁要湊齊才能讀（讀的是整本）
func book_state(id: String) -> Dictionary:
	var b := BookData.get_def(BookData.set_of(id))
	var st := {"read": hero.knows(b["move"]), "ok": false, "months": b["months"], "why": ""}
	if st["read"]:
		return st
	if not BookData.complete(hero.books, id):
		st["why"] = "只有幾張，看不出整套"
	elif hero.realm < b.get("realm", 0):
		st["why"] = "還看不懂"
	elif not in_city():
		st["why"] = "要在城裡"
	st["ok"] = hero.books.has(id) and st["why"] == ""
	return st


## 花時間讀完，就學會裡面的招。讀完之前病倒就學不成
func read_book(id: String) -> Array:
	var st := book_state(id)
	if not st["ok"]:
		return []
	var b := BookData.get_def(BookData.set_of(id))
	var msgs := _pass_months(st["months"], "read", "讀《%s》" % b["name"])
	if hero.dying():
		return msgs
	hero.learn(b["move"])
	var move_name: String = MoveData.MOVES[b["move"]]["name"]
	hero.note("讀完《%s》" % b["name"] if b["name"] == move_name else "讀完《%s》，學會「%s」" % [b["name"], move_name])
	msgs.append(_m("epic", "%s\n你學會了「%s」。" % [b["read"], move_name]))
	return msgs


## 庭主交代的事：找到的殘頁拿回來給他看，一疊算一份功勞，他讓你留著。first：他還沒交代，就看見你拿著了。
## 庭主不在了，劍庭的人收下。全部看過了，這件事就辦完了
func _report_errand(first := false) -> Array:
	var book: String = SchoolData.ERRAND["book"]
	if hero.errand_reported or not hero.errand_given or not member():
		return []
	var pages: Array = BookData.get_def(book)["pages"]
	var msgs := []
	var head := world.person(SchoolData.HEAD)
	for page in pages:
		if not hero.books.has(page) or hero.errand_pages.has(page):
			continue
		hero.errand_pages.append(page)
		var text: String = SchoolData.ERRAND["gone" if head == null or head.dead else ("seen" if first else "returned")]
		var done := BookData.complete(hero.books, page)
		msgs.append(_m("epic", text + "\n" + SchoolData.ERRAND["keep_done" if done else "keep"]))
		msgs.append_array(_merit_now("book"))
		first = false
	if hero.errand_pages.size() >= pages.size():
		hero.errand_reported = true
	return msgs


## 庭主交代的話
func errand_ask() -> String:
	return SchoolData.ERRAND["ask"]


# ---------- 基礎數值成長 ----------

## 升境的那一刻（每一境寫法不同）
const BREAKTHROUGH_TEXT := [
	"",
	"回城的路上，你走了一整天也不覺得累。呼吸又深又穩，劍拿在手上也輕了。",
	"這一仗打完，你在原地站了很久。耳朵裡很安靜，只聽得到自己的心跳，又沉又慢。",
	"你發現自己看得見對手肩膀先動，還是腳先動。以前你只看得見劍。",
	"那天之後，你出劍不再想。想的時候，劍已經到了。",
	"你站在那裡，對手還沒動，你已經知道這一仗怎麼結束。",
]


## 升一境
func _break_through() -> Array:
	hero.break_through()
	hero.note("升到%s" % GrowthData.REALM_NAMES[hero.realm])
	return [_m("epic", "%s\n%s" % [BREAKTHROUGH_TEXT[hero.realm], GrowthData.REALM_NAMES[hero.realm]])]


## 用了哪個數值的招就練到哪個數值。練多少看對手「那一項」比你現在的身體高多少。
## 只寫長了幾點、到了瓶頸；練不到、卡住都不寫（看經驗條就知道）
func _grow(enemy: Dictionary, r: Dictionary) -> Array:
	var uses := {"str": 0.0, "agi": 0.0}
	for id in r["used"]:
		var s: String = MoveData.MOVES[id].get("stat", "")
		if s != "":
			uses[s] += 1.0
	var mult: float = GrowthData.OUTCOME_MULT[r["outcome"]]

	var msgs := []
	for s in GrowthData.STATS:
		if uses[s] <= 0.0 or hero.at_cap(s):
			continue
		var grow := GrowthData.grow_mult(enemy[s], hero.body(s))
		if grow <= 0.0:
			continue
		var gained := hero.add_exp(s, GrowthData.EXP_PER_USE * uses[s] * grow * mult)
		if gained > 0:
			msgs.append(_m("good", "%s +%d" % [GrowthData.NAMES[s], gained]))
			if hero.at_cap(s):
				msgs.append(_m("info", "%s到了瓶頸。" % GrowthData.NAMES[s]))
	return msgs


# ---------- 休養、時間 ----------

## 一個月回多少血：快死的時候變慢
func _heal_per_month() -> int:
	var slow := 1.0 - hero.omen() * (1.0 - LifeData.OMEN_REST_MIN)
	return maxi(1, roundi(hero.max_hp() * TownData.REST_HEAL * slow))


func months_to_full() -> int:
	var missing := hero.max_hp() - hero.hp
	if missing <= 0:
		return 0
	return ceili(float(missing) / _heal_per_month())


func rest(months: int) -> Array:
	if hero.hp >= hero.max_hp():
		return [_m("info", "你身體好好的，不用休養。")]
	if not in_city():
		return []
	var heal := _heal_per_month()
	var before := world.month()
	var msgs := _pass_months(months, "rest", "休養")
	hero.hp = mini(hero.max_hp(), hero.hp + heal * (world.month() - before))
	if not hero.dying():
		if hero.omen() > 0.3:
			msgs.append(_m("info", LifeData.OMEN_REST_LINES[world.rng.randi_range(0, LifeData.OMEN_REST_LINES.size() - 1)]))
		msgs.append(_m("good", "血量回到 %d / %d。" % [hero.hp, hero.max_hp()]))
	return msgs


## 花掉 n 個月：世界跟著走、變老（沒有生活費：錢只花在你自己決定的事上）。病倒（臨終）就停在那一刻；臨終時壽命用完就死了。
## kind 不是空的就留給等的畫面演（title：畫面上寫在做什麼）。世界上發生的事放在 wait["news"]，跳到那個月才寫
func _pass_months(n: int, kind := "", title := "") -> Array:
	var h := hero
	var from := world.month()
	var age_from := h.age()
	var was_dying := h.dying()
	var limit := h.months_left() if was_dying else h.months_left() - LifeData.DYING_MONTHS
	var passed := clampi(n, 0, limit)
	var news := world.advance(passed)
	# 快死的徵兆：旁人說你氣色不好（等的時候偶爾寫一句）
	if h.omen() > 0.2 and passed > 0 and world.rng.randf() < h.omen():
		news.append({"month": world.month(), "kind": "omen",
			"text": LifeData.OMEN_TOWN_LINES[world.rng.randi_range(0, LifeData.OMEN_TOWN_LINES.size() - 1)]})
	if kind != "":
		wait = {"kind": kind, "title": title, "from": from, "months": passed, "age_from": age_from, "news": news}
	var msgs := []
	if kind == "":
		for e in news:
			msgs.append(_m(e["kind"], e["text"]))
	if not was_dying and h.dying():
		var away := h.location != MapData.HOME or h.travel_left > 0
		h.location = MapData.HOME
		h.travel_left = 0
		h.note("病倒了")
		msgs.append(_m("epic", LifeData.FALL_ILL_AWAY_TEXT if away else LifeData.FALL_ILL_TEXT))
	if h.months_left() == 0:
		h.dead = true
		h.died_at = world.month()
		msgs.append(_m("epic", LifeData.DEATH_TEXT[LifeData.SEASONS[LifeData.month_of_year(world.month())]]))
	return msgs


# ---------- 臨終、換人接著玩 ----------

## 可以接手的人
func heir_candidates() -> Array:
	return world.heir_candidates()


func choose_heir(id: String) -> void:
	heir_id = id


## 交代完了，躺到最後
func wait_out() -> Array:
	return _pass_months(hero.months_left(), "dying", "最後的日子")


## 死後：換成接手的人接著玩
func succeed() -> Array:
	var old := hero
	world.pass_on(heir_id)
	var h := hero
	h.note("接下了{p:%s}的東西" % old.id)
	heir_id = ""
	var msgs := [_m("big", "你是%s，%d 歲。%s把東西交給了你。" % [h.display_name, h.age(), old.display_name])]
	var things := old.items().map(func(it): return _item_name(it))
	if not things.is_empty():
		msgs.append(_m("info", "你身上多了：%s。" % "、".join(things)))
	return msgs


# ---------- 練武場 ----------

## 練武場的招現在能不能學：{"learned", "ok", "why": [原因], "cost", "months"}。數值門檻看現在的身體
func training_state(id: String) -> Dictionary:
	var t: Dictionary = TownData.TRAINING[id]
	var st := {"learned": hero.knows(id), "ok": false, "why": _req_why(id), "cost": t["cost"], "months": t["months"]}
	if st["learned"]:
		return st
	if t["cost"] > hero.money:
		st["why"].append("錢不夠")
	if not in_city():
		st["why"].append("要在城裡")
	st["ok"] = st["why"].is_empty()
	return st


## 學費先付。學完之前病倒就學不成
func learn_training(id: String) -> Array:
	var st := training_state(id)
	if not st["ok"]:
		return []
	hero.money -= st["cost"]
	return _learn(id, st["months"])


## 花時間學一招
func _learn(id: String, months: int) -> Array:
	var move_name: String = MoveData.MOVES[id]["name"]
	var msgs := _pass_months(months, "learn", "學「%s」" % move_name)
	if hero.dying():
		return msgs
	hero.learn(id)
	hero.note("學會「%s」" % move_name)
	msgs.append(_m("good", "你學會了「%s」。" % move_name))
	# 劍庭的招一手劍一手盾：第一次學，劍庭給你一面盾
	if MoveData.school(id) == SchoolData.ID and not hero.shield:
		hero.shield = true
		msgs.append(_m("info", "劍庭的人拿來一面圓盾，盾面上畫著一頭站起來的獅子。"))
	return msgs


## 數值門檻不夠的原因
func _req_why(id: String) -> Array:
	var why := []
	var req: Dictionary = SchoolData.REQ.get(id, {})
	for s in req:
		if hero.body(s) < req[s]:
			why.append("%s要 %d" % [GrowthData.NAMES[s], req[s]])
	return why


# ---------- 獅心劍庭 ----------

func member() -> bool:
	return SchoolData.is_member(hero)


## 選拔：{"passed", "ok", "why"}。每年春天一次
func spar_state() -> Dictionary:
	var st := {"passed": member(), "ok": false, "why": ""}
	if st["passed"]:
		return st
	if hero.expelled:
		st["why"] = "劍庭不收你了"
	elif maxi(hero.body("str"), hero.body("agi")) < SchoolData.JOIN_BODY:
		st["why"] = "身體還不夠結實"
	elif not in_city():
		st["why"] = "要在城裡"
	elif not SchoolData.SELECTION_MONTHS.has(LifeData.month_of_year(world.month())):
		st["why"] = "選拔在 %s" % SchoolData.selection_text()
	elif hero.selection_year == LifeData.year_of(world.month()):
		st["why"] = "今年考過了"
	else:
		st["ok"] = true
	return st


## 選拔的對手：城裡還沒入門、也來報名的年輕人（世界上的人），沒有就用一個沒名字的
func _applicant() -> Person:
	for p in world.at(MapData.HOME):
		if p.role == "youth" and p.school == "" and not p.expelled and p.selection_year != LifeData.year_of(world.month()) \
				and maxi(p.body("str"), p.body("agi")) >= SchoolData.JOIN_BODY - 1:
			return p
	return null


## 選拔：跟另一個報名的人用木劍比，打到一方剩 MATCH_YIELD 的血就停
func start_spar() -> Battle:
	_fight_person = null
	var year := LifeData.year_of(world.month())
	hero.selection_year = year
	var me := hero.to_combatant(true)
	me.yield_hp = roundi(me.max_hp * SchoolData.MATCH_YIELD)
	# 選拔用木劍：你的武器不算
	me.weapon_id = WeaponData.START
	me.weapon = "木劍"
	me.attack_mult = 1.0
	me.weapon_fx = ""
	var p := _applicant()
	var foe: Combatant
	if p != null:
		p.selection_year = year
		foe = Combatant.from_person(p, MapData.HOME, false)
		foe.hp = foe.max_hp
		_selection_foe = p
	else:
		foe = Combatant.from_enemy(SchoolData.SPAR_ENEMY)
		foe.enemy_def = foe.enemy_def.duplicate()
		# 沒名字的報名者也給個名字
		var pick: Array = PeopleData.NEWCOMER_NAMES[world.rng.randi_range(0, PeopleData.NEWCOMER_NAMES.size() - 1)]
		foe.display_name = pick[0]
		foe.pron = pick[1]
		_selection_foe = null
	foe.weapon = "木劍"
	foe.enemy_def["scene"] = [SchoolData.SELECTION_TEXT]
	foe.enemy_def["win_text"] = "{name}的木劍掉在地上。廊下的庭主點了點頭。"
	foe.enemy_def["lose_text"] = "{name}的木劍停在你的喉前。廊下的庭主搖了搖頭。"
	foe.yield_hp = roundi(foe.max_hp * SchoolData.MATCH_YIELD)
	return Battle.new([me], [foe])


## 選上了：成為學徒，庭主交代劍譜的事（劍譜已經在你身上的話，他直接看見）。
## 輸了：明年春天再來；贏你的那個人選上了
func finish_spar(battle: Battle) -> Array:
	var msgs := []
	if battle.result()["outcome"] == "win":
		hero.school = SchoolData.ID
		hero.rank = 1
		hero.note("通過獅心劍庭的選拔")
		msgs.append(_m("big", "庭主在名冊上寫下你的名字。你成了獅心劍庭的學徒。"))
		hero.errand_given = true
		var found := _report_errand(true)
		if found.is_empty():
			msgs.append(_m("big", errand_ask()))
		msgs.append_array(found)
	else:
		msgs.append(_m("info", "這次沒選上。"))
		if _selection_foe != null:
			world.join_school(_selection_foe)
	_selection_foe = null
	msgs.append_array(_grow(battle.enemies[0].stats, battle.result()))
	msgs.append_array(_pass_months(SchoolData.SPAR_MONTHS))
	return msgs


## 劍庭的招現在能不能換：{"learned", "ok", "why": [原因], "merit", "months", "rank"}
## 不是成員也能換第 1 階（藍）的招
func school_move_state(id: String) -> Dictionary:
	var t: Dictionary = SchoolData.MOVES[id]
	var st := {"learned": hero.knows(id), "ok": false, "why": _req_why(id), "merit": t["merit"], "months": t["months"], "rank": t["rank"]}
	if st["learned"]:
		return st
	if t["rank"] > 1 and not member():
		st["why"].push_front("要是劍庭的人")
	elif t["rank"] > hero.rank and member():
		st["why"].push_front("要%s" % SchoolData.RANKS[t["rank"]])
	if t["merit"] > hero.merit:
		st["why"].append("貢獻不夠")
	if not in_city():
		st["why"].append("要在城裡")
	st["ok"] = st["why"].is_empty()
	return st


func learn_school_move(id: String) -> Array:
	var st := school_move_state(id)
	if not st["ok"]:
		return []
	hero.merit -= st["merit"]
	return _learn(id, st["months"])


## 劍庭現在有的事。辦完過一陣子才會再有（again）；查冒牌貨只有一次；要討伐的人還活著才有；
## 劍譜要庭主交代過、還沒拿回來才有；守夜要是劍庭的人。被逐出的人什麼都接不到
func school_jobs() -> Array:
	var list := []
	if hero.expelled:
		return list
	for id in SchoolData.JOBS:
		var j: Dictionary = SchoolData.JOBS[id]
		if hero.job_back.get(id, 0) > world.month():
			continue
		match j["kind"]:
			"deliver":
				list.append(id)
			"watch":
				if member():
					list.append(id)
			"duel":
				if not hero.beaten.has(j["enemy"]):
					list.append(id)
			"kill":
				var t := world.person(j["target"])
				if t != null and not t.dead:
					list.append(id)
			"book":
				if hero.errand_given and not hero.errand_reported:
					list.append(id)
	return list


func accept_school_job(id: String) -> Array:
	if hero.school_jobs.has(id) or not school_jobs().has(id):
		return []
	hero.school_jobs.append(id)
	var j: Dictionary = SchoolData.JOBS[id]
	if j["kind"] == "kill":
		world.hear(j["target"])
	return [_m("info", "你接下了劍庭的事。")]


func took_school_job(id: String) -> bool:
	return hero.school_jobs.has(id) or SchoolData.JOBS[id]["kind"] == "book" and hero.errand_given


## 劍庭的事辦完了，還沒回去交差
func school_job_done(id: String) -> bool:
	return hero.claims.any(func(c): return c.get("job", "") == id)


## 守夜：在劍庭待幾個月，當場記上貢獻
func watch(id: String) -> Array:
	if not school_jobs().has(id) or not in_city():
		return []
	var j: Dictionary = SchoolData.JOBS[id]
	var msgs := _pass_months(j["months"], "watch", "守夜")
	if hero.dying():
		return msgs
	hero.job_back[id] = world.month() + j.get("again", 0)
	msgs.append_array(_merit_now(id))
	return msgs


## 劍庭的事辦完了：等你回去交差
func _school_done(id: String) -> Array:
	var j: Dictionary = SchoolData.JOBS[id]
	hero.school_jobs.erase(id)
	hero.job_back[id] = world.month() + j["again"] if j.has("again") else 999999
	_claim("school", j["text"], 0, j["merit"], id)
	return []


## 當面交的（劍譜、守夜）：直接記上貢獻
func _merit_now(id: String) -> Array:
	var j: Dictionary = SchoolData.JOBS[id]
	hero.school_jobs.erase(id)
	hero.merit += j["merit"]
	hero.merit_total += j["merit"]
	return [_m("good", "劍庭記下了你這份功勞（貢獻 +%d）。" % j["merit"])]


## 打贏了人、討伐了人：有接劍庭的事就算辦完了
func _jobs_done(kind: String, key: String) -> Array:
	var msgs := []
	for id in hero.school_jobs.duplicate():
		var j: Dictionary = SchoolData.JOBS[id]
		if j["kind"] == kind and j.get("enemy", j.get("target", "")) == key:
			msgs.append_array(_school_done(id))
	return msgs


# ---------- 交差 ----------

func _claim(from: String, what: String, money: int, merit: int, job := "") -> void:
	hero.claims.append({"from": from, "what": what, "money": money, "merit": merit, "job": job})


## 還沒交差的事（from：guild 公會、school 劍庭）
func claims(from: String) -> Array:
	return hero.claims.filter(func(c): return c["from"] == from)


## 回去交差：拿報酬、記貢獻。要在城裡
func turn_in(from: String) -> Array:
	if not in_city():
		return []
	var msgs := []
	var money := 0
	var merit := 0
	for c in claims(from):
		money += c["money"]
		merit += c["merit"]
	hero.claims = hero.claims.filter(func(c): return c["from"] != from)
	if money > 0:
		hero.money += money
		msgs.append(_m("good", "公會的人點過憑證，數了 %d 銀給你。" % money))
	if merit > 0:
		hero.merit += merit
		hero.merit_total += merit
		msgs.append(_m("good", "劍庭記下了你這份功勞（貢獻 +%d）。" % merit))
	return msgs


## 公開比試：{"rank": 要升到第幾階, "ok", "why", "opponent": 世界上的人 id（空的就用 fallback）}
func trial_state() -> Dictionary:
	var st := {"rank": hero.rank + 1, "ok": false, "why": "", "opponent": ""}
	if not member() or hero.rank >= SchoolData.RANKS.size() - 1:
		return st
	var t: Dictionary = SchoolData.TRIALS[st["rank"]]
	var p := world.person(t["opponent"]) if t["opponent"] != "" else null
	if p != null and not p.dead and p.location == MapData.HOME and p.travel_left == 0:
		st["opponent"] = p.id
	if hero.merit_total < t["merit_total"]:
		st["why"] = "替劍庭做的事還不夠多"
	elif not in_city():
		st["why"] = "要在城裡"
	else:
		st["ok"] = true
	return st


## 比試：打到一方剩 MATCH_YIELD 的血就停。不會死、不會被搶，打完不帶傷
func start_trial() -> Battle:
	var st := trial_state()
	_fight_person = null
	var me := hero.to_combatant(true)
	me.yield_hp = roundi(me.max_hp * SchoolData.MATCH_YIELD)
	var foe: Combatant
	if st["opponent"] != "":
		var p := world.person(st["opponent"])
		foe = Combatant.from_person(p, MapData.HOME, false)
		foe.hp = foe.max_hp
		foe.enemy_def["win_text"] = "{name}退了一步，把劍放低：「我輸了。」"
		foe.enemy_def["scene"] = [SchoolData.TRIALS[st["rank"]]["text"]]
	else:
		foe = Combatant.from_enemy(SchoolData.TRIALS[st["rank"]]["fallback"])
		# 升大師本來是庭主下場；庭主不在了，換劍庭最老的大師
		var head := world.person(SchoolData.HEAD)
		if st["rank"] == 3 and (head == null or head.dead):
			foe.display_name = "劍庭的老大師"
	foe.yield_hp = roundi(foe.max_hp * SchoolData.MATCH_YIELD)
	return Battle.new([me], [foe])


func finish_trial(battle: Battle) -> Array:
	var st := trial_state()
	var msgs := []
	if battle.result()["outcome"] == "win":
		hero.rank = st["rank"]
		hero.note("在公開比試升為%s" % SchoolData.RANKS[hero.rank])
		msgs.append(_m("epic", "你是獅心劍庭的%s了。" % SchoolData.RANKS[hero.rank]))
	else:
		msgs.append(_m("info", "這次沒能贏下來。"))
	msgs.append_array(_grow(battle.enemies[0].stats, battle.result()))
	msgs.append_array(_pass_months(SchoolData.TRIALS[st["rank"]]["months"]))
	return msgs


# ---------- 武器店 ----------

## 武器店賣的：普通貨，加上世界上的人賣進來的好東西（稀有武器、秘笈）
func shop_items() -> Array:
	return WeaponData.SHOP + world.shop_stock


## 店裡的價錢：普通貨照標價，收來的好東西照等級
func price(id: String) -> int:
	if BookData.is_book(id):
		return BookData.get_def(id)["grade"] * TownData.BOOK_PRICE
	var w := WeaponData.get_def(id)
	return w["cost"] if w["cost"] > 0 else w["grade"] * TownData.RARE_PRICE


## 這樣東西現在能不能買：{"owned", "ok", "why": [原因]}
func weapon_state(id: String) -> Dictionary:
	var st := {"owned": hero.has_item(id), "ok": false, "why": []}
	if st["owned"]:
		return st
	if not BookData.is_book(id) and not hero.can_wield(id):
		st["why"].append("力量要 %d" % WeaponData.get_def(id)["str"])
	if hero.money < price(id):
		st["why"].append("錢不夠")
	if not in_city():
		st["why"].append("要在城裡")
	st["ok"] = st["why"].is_empty()
	return st


## 買了武器就直接換上
func buy_weapon(id: String) -> Array:
	if not weapon_state(id)["ok"]:
		return []
	var cost := price(id)
	hero.money -= cost
	world.shop_stock.erase(id)
	hero.give_item(id)
	if BookData.is_book(id):
		return [_m("good", "你花了 %d 銀買下%s。" % [cost, _item_name(id)])]
	hero.weapon = id
	return [_m("good", "你花了 %d 銀買下%s，換上了。" % [cost, WeaponData.get_def(id)["name"]])]


func equip(id: String) -> Array:
	if not hero.owned_weapons.has(id) or not hero.can_wield(id) or hero.weapon == id:
		return []
	hero.weapon = id
	return [_m("info", "你換上了%s。" % WeaponData.get_def(id)["name"])]


func _item_name(id: String) -> String:
	if BookData.is_book(id):
		var b := BookData.get_def(id)
		return b["name"] if b.has("page_of") else "《%s》" % b["name"]
	return WeaponData.get_def(id)["name"]


func _m(kind: String, text: String) -> Dictionary:
	return {"kind": kind, "text": text}
