extends SceneTree

## 人開口、有人來找你（開發用）：把每一種對話叫出來，印出文字和選了之後的結果，看寫法順不順、舊事有沒有提到、口氣分不分得出來。
## 找上門算帳（四種口氣）、傳話警告、求你幫忙 → 答應 → 辦完來謝你、答應了沒去辦、報恩、邀你去打懸賞、比劍、
## 傳話（在打聽你、搶過你東西的人死了、你的東西被賣到武器店、你被懸賞、你殺的人的家人知道了）、打起來之前那一句、人物面板上「跟你」。
## 執行：Godot --headless --path . --script res://tests/talk.gd

var town: Town
var w: World


func _init() -> void:
	town = Town.new(3)
	w = town.world
	var h := town.hero
	h.stats = {"str": 22, "agi": 22}
	h.realm = 3
	h.give_item("knight_sword")
	h.weapon = "knight_sword"
	h.hp = h.max_hp()
	h.fame = 12.0
	h.money = 300
	town.visits.reset()

	print("======== 找上門算帳：每種口氣 ========")
	for id in ["magnus", "yvette", "black_knight", "hakon"]:
		var p := w.person(id)
		w.add_grudge(p, h.id, "beaten")
		w.remember(p, "robbed_by_you", {"item": "steel_sword", "place": "bridge"})
		print("\n【%s（%s）】" % [p.display_name, p.voice])
		print(town.comer_text(p))
		p.grudges.erase(h.id)
	var erik := w.person("erik")
	w.hero_won(erik, true)
	print("\n【烏爾夫：你殺了他弟弟（自己寫的話）】")
	print(town.comer_text(w.person("ulf")))
	var bran := w.person("bran")
	bran.grudges.clear()
	var lina := w.person("lina")
	lina.relations["allen"] = "sibling"
	w.person("allen").relations["lina"] = "sibling"
	w.hero_won(w.person("allen"), true)
	print("\n【莉娜：你殺了她兄弟】")
	print(town.comer_text(lina))

	_visit("傳話警告：葛雷森（自己寫的話）", {"kind": "warn", "who": "grayson", "target": "bran"}, "defy")
	_visit("傳話警告：沒寫自己的話、人不在這裡（叫人帶話）", {"kind": "warn", "who": "magnus", "target": "roderick", "messenger": true}, "heed")

	var ora := w.person("ora")
	if ora == null:
		ora = w._spawn("ora")
	ora.location = MapData.HOME
	_visit("求你幫忙：歐拉和烏爾夫", {"kind": "ask_help", "who": "ora", "target": "ulf"}, "yes")
	w.hero_won(w.person("ulf"), true)
	_visit("答應的事辦完了：來謝你", {"kind": "thanks", "who": "ora", "target": "ulf"}, "refuse")
	_who("ora")

	var sira := w.person("sira")
	sira.location = MapData.HOME
	w.add_grudge(sira, "black_knight", "beaten")
	_visit("求你幫忙：席拉和黑騎士", {"kind": "ask_help", "who": "sira", "target": "black_knight"}, "yes")
	h.promises[-1]["month"] -= 40
	_visit("答應了沒去辦", {"kind": "broke", "who": "sira", "target": "black_knight"}, "drop")
	_who("sira")

	var hakon := w.person("hakon")
	hakon.location = MapData.HOME
	hakon.grateful.append(h.id)
	w.remember(hakon, "spared", {"place": "relay"})
	_visit("報恩", {"kind": "repay", "who": "hakon"}, "gift")
	_visit("邀你去打懸賞", {"kind": "invite", "who": "hakon", "target": "roderick"}, "yes")
	town.take_wait()
	_who("hakon")
	_visit("比劍", {"kind": "challenge", "who": "matthias"}, "no")
	_visit("比劍（上次你不比）", {"kind": "challenge", "who": "matthias"}, "no")

	print("\n======== 傳話 ========")
	var magnus := w.person("magnus")
	w.add_grudge(magnus, h.id, "beaten")
	magnus.target = h.id
	h.owned_weapons.append("steel_sword")
	w.settle(magnus, h, false)
	w.remember(magnus, "beat_you", {"item": "steel_sword", "place": "wheat"})
	w.tiding("hunted", {"about": magnus.id})
	_tidings()
	magnus.location = "wheat"
	w.person("hakon").location = "wheat"
	w.fight(w.person("hakon"), magnus)
	if not magnus.dead:
		w.settle(w.person("hakon"), magnus, true)
	_tidings()
	w.tiding("item_sold", {"about": "hakon", "item": "steel_sword"})
	w.shop_stock.append("steel_sword")
	_tidings()
	w.hero_murdered(w.person("tim") if w.person("tim") != null else w.person("lina"), "石橋")
	_tidings()

	print("\n======== 打起來之前那一句 ========")
	for id in ["yvette", "black_knight", "matthias", "hakon"]:
		var p := w.person(id)
		if p != null and not p.dead:
			w.remember(p, "duel_lost", {"place": "bridge"})
			print("【%s】%s" % [p.display_name, town.talk.say(p, "again")])

	print("\n======== 人物面板：跟你 ========")
	for id in ["hakon", "ora", "sira", "matthias"]:
		_who(id)
	quit()


## 叫出一件主動找你的事，印出來，選 pick
func _visit(title: String, c: Dictionary, pick: String) -> void:
	print("\n======== %s ========" % title)
	town.visits.current = c
	var v := town.visits.view()
	print("【%s】" % v["title"])
	print(v["text"])
	print("　選項：", "／".join(v["options"].map(func(o): return o[1])))
	var label := ""
	for o in v["options"]:
		if o[0] == pick:
			label = o[1]
	print("　→ ", label)
	var r := town.visits.answer(pick)
	for m in r["msgs"]:
		print("　　", m["text"])


## 把現在要傳的話都叫出來
func _tidings() -> void:
	town.visits.reset()
	town.visits.approach_budget = 0
	while town.visits.next():
		var v := town.visits.view()
		print("\n【%s】" % v["title"])
		print(v["text"])
		print("　選項：", "／".join(v["options"].map(func(o): return o[1])))
		var r := town.visits.answer(v["options"][0][0])
		for m in r["msgs"]:
			print("　　", m["text"])
		town.visits.reset()
		town.visits.approach_budget = 0


func _who(id: String) -> void:
	var p := w.person(id)
	if p == null:
		return
	print("　＊%s（%s）跟你：" % [p.display_name, "死了" if p.dead else "活著"])
	for e in town.talk.memo_lines(p):
		print("　　　", e["text"])
