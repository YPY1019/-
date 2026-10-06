extends SceneTree

## 路上的事（開發用）：把每一種事叫出來走一遍，印出文字、選了什麼、結果，看寫法順不順、後果有沒有留在世界上
## （殺無辜被懸賞、放走的人記恩、搜身的人記仇、小賊變成世界上的人、埋了死人家人記恩……）。
## 選項用資料裡的編號（RoadData 的順序）；打完之後 kill / spare 決定殺不殺，rob 拿走他身上的東西。
## 執行：Godot --headless --path . --script res://tests/road.gd

var town: Town
var pilot := AutoPilot.new()
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 5
	town = Town.new(3)
	town.road_boost = 0.0
	var h := town.hero
	# 夠強，打得贏大部分的人（看的是打完之後的事）
	h.stats = {"str": 24, "agi": 24}
	h.realm = 4
	h.give_item("knight_sword")
	h.weapon = "knight_sword"
	for m in ["knee", "fallstone", "deflect", "triple", "needle"]:
		h.learn(m)
	h.hp = h.max_hp()
	h.fame = 12.0
	h.money = 400
	var w := town.world

	_case("小賊：打倒了放他走 → 變成世界上的人，欠你一條命", "thug", "", "", "pasture", ["0", "1"])
	_show_drifter()
	_case("小賊：丟錢袋 → 他搶了你，變成世界上的人", "thug", "", "", "bridge", ["1"])
	_show_drifter()

	_case("有懸賞的人攔路（你強很多，他躲起來）", "robbers_shy", "bran", "", "south_road", ["1"])
	_case("有懸賞的人攔路：打倒了放他走（沒拿東西）→ 欠你一條命", "robbers", "bran", "", "south_road", ["1", "spare"])
	_who("bran")
	_case("欠你情的人在茶棚叫住你", "repay", "bran", "", "bridge", ["1"])

	_case("路上的酒館：對沒懸賞的人動手、殺了 → 公會懸賞你", "traveler", "sira", "", "frost", ["2", "kill"])
	print("懸賞你：", w.bounties.get(w.hero_id, {}))
	var hakon := w.person("hakon")
	hakon.target = w.hero_id
	hakon.rest_left = 0
	_case("來收你懸賞的人在路上堵你：付錢讓他走", "ambush", "hakon", "", "bridge", ["0", "3"])
	_who("hakon")

	var erik := w.person("erik")
	w.hero_won(erik, true)
	var ulf := w.person("ulf")
	ulf.rest_left = 0
	_case("你殺了他弟弟：在路上堵你，你叫他回去", "ambush", "ulf", "", "coast", ["2", "4"])
	_who("ulf")

	var magnus := w.person("magnus")
	w.add_grudge(magnus, w.hero_id, "beaten")
	_case("你打傷搶過他：付錢了結", "ambush", "magnus", "", "wheat", ["0", "2"])
	_who("magnus")

	var allen := w.person("allen")
	allen.location = "bridge"
	w.settle(w.person("roderick"), allen, true)
	_case("有人剛死在路邊：看腳印、埋了（他的師傅欠你情）", "corpse", "allen", "roderick", "bridge", ["0", "0", "0"])
	_who("master")

	var h2 := town.hero
	h2.school = SchoolData.ID
	h2.rank = 1
	_case("同門被有懸賞的人圍住：走開", "kin_help", "matthias", "roderick", "wheat", ["2"])
	_who("matthias")
	_case("同門被有懸賞的人圍住：上去幫他", "kin_help", "lina", "yvette", "frost", ["0", "kill", "0"])
	_who("lina")

	_case("強者榜上的人等你比劍", "challenge", "oskar", "", "bridge", ["0", "0"])
	_who("oskar")
	_case("有懸賞的人剛搶過的村子", "raided", "roderick", "", "wheat", ["0", "0"])
	_case("被搶的商人：去追", "merchant", "magnus", "", "wheat", ["0", "0", "1"])
	_case("商隊：夜裡摸過來的是真的攔路的人", "caravan", "black_knight", "", "relay", ["0", "1", "spare", "0"])
	_case("跟在後面的東西", "stalked", "", "", "lodge", ["2", "1"])
	_case("路上的酒館：問你在找的人", "traveler", "leonard_or_any", "", "bridge", ["1", "0"])
	quit()


## 叫出一件事、照 picks 走完
func _case(title: String, id: String, who: String, other: String, at: String, picks: Array) -> void:
	var w := town.world
	if who == "leonard_or_any":
		who = w.others().filter(func(p): return p.role == "hunter")[0].id
	var p := w.person(who)
	if p != null and p.dead and id != "corpse":
		print("\n（%s 已經死了，跳過：%s）" % [who, title])
		return
	print("\n======== %s ========" % title)
	var h := town.hero
	h.hp = h.max_hp()
	h.location = MapData.HOME
	h.travel_left = 1
	town.road = town._road._begin({"id": id, "who": who, "other": other, "at": at}, "frost" if at != "frost" else "bridge")
	var guard := 0
	while not town.road.is_empty() and town.road["step"] != "" and guard < 10:
		guard += 1
		var v := town.road_event()
		print("【%s】%s" % [v["title"], v["text"]])
		print("　選項：", "／".join(v["options"].map(func(o): return "%s %s" % [o[0], o[1]])))
		var pick: String = picks.pop_front() if not picks.is_empty() else v["options"][0][0]
		var label := ""
		for o in v["options"]:
			if o[0] == pick:
				label = o[1]
		if label == "":
			print("　！選項 %s 看不到" % pick)
			pick = v["options"][0][0]
		print("　→ ", label)
		var r := town.answer_road(pick)
		_print(r["msgs"])
		var fight: String = r["fight"]
		if fight != "":
			_fight(fight, picks)
	town.road = {}
	h.travel_left = 0


func _fight(fight: String, picks: Array) -> void:
	var kind := fight.get_slice(":", 0)
	var id := fight.get_slice(":", 1)
	var b: Battle
	match kind:
		"enemy":
			b = town.start_monster(id)
		"person":
			b = town.start_person(id)
		"duel":
			b = town.start_duel(id)
	b.rng.seed = rng.randi()
	var r := pilot.play(b)
	print("　（打%s：%s）" % [b.enemies[0].display_name, r["outcome"]])
	var msgs: Array
	match kind:
		"enemy":
			msgs = town.finish_monster(b)
		"person":
			msgs = town.finish_person(b)
		"duel":
			msgs = town.finish_duel(b)
	_print(msgs)
	if town.fate_pending != null:
		var f: String = picks.pop_front() if not picks.is_empty() else "spare"
		_print(town.decide_fate(f == "kill"))
		if not picks.is_empty() and picks[0] == "rob":
			picks.pop_front()
			for it in town.loot.duplicate():
				_print(town.take_loot(it))
	town.clear_loot()


func _print(msgs: Array) -> void:
	for m in msgs:
		print("　　", m["text"])


## 這個人現在怎樣：仇人、欠誰情、經歷
func _who(id: String) -> void:
	var w := town.world
	var p := w.person(id)
	var h := town.hero
	print("　＊%s：%s　記你的仇：%s　欠你情：%s　在%s" % [p.display_name, "死了" if p.dead else "活著", p.grudges.has(h.id), p.grateful.has(h.id), MapData.place_name(p.location)])
	for e in p.history.slice(-3):
		print("　　　", w.fmt(e["text"]))


func _show_drifter() -> void:
	var w := town.world
	var list := w.others().filter(func(p): return p.title == "攔路的")
	if list.is_empty():
		print("　＊沒有變成世界上的人")
		return
	_who(list[-1].id)
