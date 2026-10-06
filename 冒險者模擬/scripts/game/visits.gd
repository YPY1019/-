class_name Visits
extends RefCounted

## 有人來找你（規則）：回到一個地方（花了時間之後），跳出對話。文字和數字在 TalkData。
## 2026-10-07 決定：跟你有關的事由一個人來跟你說，跳對話讓你當場決定，回來一次最多一兩件；平常也有人主動找你。
##   傳話（tiding）：世界上發生了跟你有關的事（World.tidings），在城裡由認識的人、旅店老闆娘、公會書記、武器店老闆告訴你。
##   主動找你（approach）：世界上真的人，人在你這裡才會來：傳話警告、來謝你、問你答應的事、報恩、求你幫忙、邀你去打懸賞、比劍。
##   來算帳的（仇人、收你懸賞的）不在這裡，見 Town.comer。
## 選了之後記在他身上（World.remember），之後說話會提、人物面板上看得到。
## 正在處理的放在 current：{"kind", "who": 人 id, "teller": inn/guild/shop（城裡的人）, "tiding", "target"}
## 不碰畫面：view() 給對話框要顯示的，answer() 回傳 {"fight": 空的 / "duel:人 id", "msgs"}

var _town: WeakRef
var town: Town:
	get:
		return _town.get_ref()
var world: World:
	get:
		return town.world
var hero: Person:
	get:
		return town.hero
var talk: Talk:
	get:
		return town.talk

## 這次回來還能來幾件、主動找你的還能來幾件（花了時間就重算，見 Town._pass_months）
var budget := 0
var approach_budget := 0
var current := {}

## 傳話的先後（越前面越先說）
const TIDING_ORDER := ["bounty_on_you", "hunted", "heir_grudge", "kin_knows", "bounty_taker", "death", "item_sold"]
## 主動找你的先後（每一種擲一次，碰上就是它）
const APPROACH_ORDER := ["warn", "thanks", "broke", "repay", "ask_help", "invite", "challenge"]
## 跟你有交情的事（這種人會來告訴你消息）
const FRIENDLY := ["spared", "saved", "buried", "kept", "hunted_with", "warn_heeded", "gift", "pitied", "paid", "duel_won", "duel_lost"]


func _init(t: Town) -> void:
	_town = weakref(t)


## 回來了：這次最多來幾件
func reset() -> void:
	budget = TalkData.PER_RETURN
	approach_budget = TalkData.APPROACH_PER_RETURN


# ---------- 誰來 ----------

## 下一個來找你的：有就放進 current，回傳 true
func next() -> bool:
	current = {}
	var h := hero
	if budget <= 0 or h.dead or h.dying() or h.travel_left > 0 or not town.road.is_empty():
		return false
	var t := _next_tiding()
	if t.is_empty() and approach_budget > 0:
		t = _next_approach()
		if not t.is_empty():
			approach_budget -= 1
	if t.is_empty():
		return false
	budget -= 1
	current = t
	if current.has("who"):
		var p := world.person(current["who"])
		if p != null:
			world.hear(p.id)
			h.talk_seen["p:" + p.id] = world.month()
	h.talk_seen[current["kind"]] = world.month()
	return true


## 傳話：只在城裡（旅店、公會、武器店的人來說）
func _next_tiding() -> Dictionary:
	if not town.in_city():
		return {}
	var list: Array = world.tidings.duplicate()
	list.sort_custom(func(a, b): return TIDING_ORDER.find(a["kind"]) < TIDING_ORDER.find(b["kind"]))
	for t in list:
		world.tidings.erase(t)
		if world.month() - t["month"] > TalkData.TIDING_STALE or not _still_true(t):
			continue
		var teller := _teller(t)
		var st := {"kind": "tiding", "tiding": t, "teller": teller}
		if world.person(teller) != null:
			st["who"] = teller
		return st
	return {}


## 這件事現在還是真的嗎（例如在打聽你的人還在找你）
func _still_true(t: Dictionary) -> bool:
	var about := world.person(t.get("about", ""))
	var h := hero
	match t["kind"]:
		"hunted", "heir_grudge", "kin_knows":
			return about != null and not about.dead and (about.target == h.id or about.grudges.has(h.id))
		"bounty_taker":
			return about != null and not about.dead and world.wanted(h.id) and about.target == h.id
		"bounty_on_you":
			return world.wanted(h.id)
		"item_sold":
			return world.shop_stock.has(t["item"]) and not h.has_item(t["item"])
	return about != null


## 誰來告訴你：認識的人（跟你有交情、在你這裡）優先，不然是城裡的人
func _teller(t: Dictionary) -> String:
	var friends := []
	for p in world.at(hero.location):
		if p.id == t.get("about", "") or _hostile(p) or p.role == "master":
			continue
		if p.grateful.has(hero.id) or p.memo_of(hero.id).any(func(e): return FRIENDLY.has(e["kind"])):
			friends.append(p.id)
	if not friends.is_empty() and t["kind"] != "item_sold":
		return friends[world.rng.randi_range(0, friends.size() - 1)]
	match t["kind"]:
		"bounty_taker", "bounty_on_you":
			return "guild"
		"item_sold":
			return "shop"
	return "inn"


## 主動找你：人在你這裡才會來
func _next_approach() -> Dictionary:
	for kind in APPROACH_ORDER:
		var list: Array = call("_cand_" + kind)
		list = list.filter(func(c): return _free(kind, c.get("who", "")))
		if list.is_empty() or world.rng.randf() >= TalkData.VISIT_CHANCE[kind]:
			continue
		var c: Dictionary = list[world.rng.randi_range(0, list.size() - 1)]
		c["kind"] = kind
		return c
	return {}


## 這件事、這個人最近沒來過
func _free(kind: String, who: String) -> bool:
	var seen := hero.talk_seen
	var now := world.month()
	if seen.has(kind) and now - seen[kind] < TalkData.VISIT_AGAIN[kind]:
		return false
	if kind in ["warn", "thanks", "broke"]:
		return true
	if who != "" and seen.has("p:" + who) and now - seen["p:" + who] < TalkData.PERSON_AGAIN:
		return false
	return true


## 對你有敵意的人（不會來好好說話）
func _hostile(p: Person) -> bool:
	return p.grudges.has(hero.id) or p.target == hero.id


## 在你這裡、不是來找你麻煩的人
func _here() -> Array:
	if hero.travel_left > 0:
		return []
	return world.at(hero.location).filter(func(p): return not _hostile(p))


# ---------- 每一種：條件成立的人 [{"who", "target"}] ----------

## 你接了懸賞的人，有家人、老大護著：他來（不在這裡就叫人帶話，要在城裡）
func _cand_warn() -> Array:
	var out := []
	for id in world.bounties:
		if not town.took_bounty(id) or world.warned.has(id):
			continue
		var guard := world.protector_of(id)
		if guard == null or _hostile(guard):
			continue
		var here := guard.location == hero.location and guard.travel_left == 0
		if here or town.in_city():
			out.append({"who": guard.id, "target": id, "messenger": not here})
	return out


## 答應的事辦完了：求你的人來謝你
func _cand_thanks() -> Array:
	var out := []
	for pr in hero.promises:
		var p := world.person(pr["asker"])
		if pr.get("done", false) and p != null and not p.dead and _here().has(p):
			out.append({"who": p.id, "target": pr["target"]})
	return out


## 答應了很久沒去辦：他來問
func _cand_broke() -> Array:
	var out := []
	for pr in hero.promises:
		var p := world.person(pr["asker"])
		var t := world.person(pr["target"])
		if not pr.get("done", false) and p != null and _here().has(p) and t != null and not t.dead \
				and world.month() - pr["month"] >= TalkData.PROMISE_DUE:
			out.append({"who": p.id, "target": t.id})
	return out


## 欠你情的人
func _cand_repay() -> Array:
	return _here().filter(func(p): return p.grateful.has(hero.id)).map(func(p): return {"who": p.id})


## 跟人有仇、自己打不過的人，求你去對付
func _cand_ask_help() -> Array:
	var out := []
	var h := hero
	for p in _here():
		if p.role in ["master", "villain", "follower"] or world.wanted(p.id):
			continue
		if h.fame < TalkData.ASK_FAME and not p.memo_of(h.id).any(func(e): return FRIENDLY.has(e["kind"])):
			continue
		for g in p.grudges:
			var t := world.person(g)
			if t == null or t.dead or t.id == h.id or t.power() <= p.power() + 0.5:
				continue
			if h.promises.any(func(pr): return pr["target"] == t.id and pr["asker"] == p.id):
				continue
			if p.memo_of(h.id).any(func(e): return e["kind"] in ["refused", "broke"] and e.get("target", "") == t.id):
				continue
			out.append({"who": p.id, "target": t.id})
			break
	return out


## 冒險者看上一張自己吃不下的懸賞，找你一起去
func _cand_invite() -> Array:
	var out := []
	var h := hero
	if world.wanted(h.id) or h.hp < h.max_hp() * SchoolData.FIT_HP:
		return out
	for p in _here():
		if p.role != "hunter" or p.target != "" or world.wanted(p.id):
			continue
		var best := ""
		var best_reward := 0
		for id in world.bounties:
			var t := world.person(id)
			if t == null or t.dead or t == p or t.id == h.id or p.relations.has(id) or h.relations.has(id) or _where(t) == h.location:
				continue
			if t.power() <= p.power() + p.boldness:
				continue
			var team := maxf(p.power(), h.power()) + TalkData.TEAM_BONUS
			if GrowthData.win_chance(team, t.power()) < 0.4:
				continue
			if world.bounties[id]["reward"] > best_reward:
				best = id
				best_reward = world.bounties[id]["reward"]
		if best != "":
			out.append({"who": p.id, "target": best})
	return out


## 強者榜上跟你差不多的人，來找你比劍
func _cand_challenge() -> Array:
	var h := hero
	if h.fame < RoadData.CHALLENGE_FAME or h.hp < h.max_hp() * SchoolData.FIT_HP:
		return []
	var out := []
	for p in _here():
		if not p.role in ["hunter", "settled", "duelist", "youth"] or p.age() < 17 or world.wanted(p.id) or p.relations.has(h.id):
			continue
		var gap: float = p.power() - h.power()
		if gap >= RoadData.CHALLENGE_RANGE[0] and gap <= RoadData.CHALLENGE_RANGE[1]:
			out.append({"who": p.id})
	return out


# ---------- 畫面 ----------

## {"title", "color", "text", "options": [[id, 按鈕的字]]}
func view() -> Dictionary:
	var c := current
	var p := world.person(c.get("who", ""))
	var t := world.person(c.get("target", ""))
	var title := ""
	var color := Color.WHITE
	if p != null:
		title = ("%s %s" % [p.title, p.display_name]).strip_edges()
		color = Color(p.realm_color())
	var vals := _vals(p, t)
	var text := ""
	var options := []
	match c["kind"]:
		"tiding":
			return _tiding_view()
		"warn":
			var custom: String = PeopleData.PEOPLE.get(p.id, {}).get("warn", "")
			if custom != "":
				text = world.fmt(custom.replace("{p:who}", "{p:%s}" % p.id).replace("{p:target}", "{p:%s}" % t.id))
			elif c.get("messenger", false):
				text = "一個沒見過的人在旅店門口攔住你，說是%s叫他來的。\n%s" % [p.display_name, talk.say(p, "warn", vals, ["*"])]
			else:
				text = talk.scene(p, TalkData.SCENE, true) + "\n" + talk.say(p, "warn", vals, ["*"])
			options = [["defy", "「懸賞我已經接了。」"], ["heed", "「我把懸賞退了。」"], ["think", "「我會想想。」"]]
		"thanks":
			text = talk.scene(p, TalkData.SCENE) + "\n" + talk.say(p, "thanks", vals, ["promised"])
			options = [["take", "收下"], ["refuse", "「不用了。」"]]
		"broke":
			text = talk.scene(p, TalkData.SCENE, true) + "\n" + talk.say(p, "broke", vals, ["*"])
			options = [["again", "「我會去。」"], ["drop", "「我辦不到。」"]]
		"repay":
			text = talk.scene(p, TalkData.SCENE) + "\n" + talk.say(p, "repay", vals)
			var lead := _lead(p)
			if lead != null:
				options.append(["lead", "聽%s說" % p.pron])
			options.append(["gift", "收下%s塞過來的布包" % p.pron])
			options.append(["no", "「不用了。」"])
		"ask_help":
			vals["{reason}"] = talk.reason(p, t)
			text = talk.scene(p, TalkData.SCENE) + "\n" + talk.say(p, "ask_help", vals)
			options = [["yes", "「我去。」"], ["no", "「這不關我的事。」"]]
		"invite":
			text = talk.scene(p, TalkData.SCENE) + "\n" + talk.say(p, "invite", vals)
			options = [["yes", "「一起去。」"], ["no", "「你自己去吧。」"]]
		"challenge":
			vals["{rank}"] = talk.rank_line(p)
			text = talk.scene(p, TalkData.SCENE, true) + "\n" + talk.say(p, "challenge", vals)
			options = [["yes", "比"], ["no", "「不比。」"]]
	return {"title": title, "color": color, "text": text, "options": options}


func _tiding_view() -> Dictionary:
	var c := current
	var td: Dictionary = c["tiding"]
	var teller := world.person(c.get("who", ""))
	var about := world.person(td.get("about", ""))
	var title := ""
	var color := Color.WHITE
	var intro := ""
	var pron := "她"
	if teller != null:
		title = ("%s %s" % [teller.title, teller.display_name]).strip_edges()
		color = Color(teller.realm_color())
		intro = talk.scene(teller, TalkData.SCENE) + "\n" + talk.say(teller, "tell", {}, ["*"])
		pron = teller.pron
	else:
		var d: Dictionary = TalkData.TELLERS[c["teller"]]
		title = d["title"]
		intro = d["scene"][world.rng.randi_range(0, d["scene"].size() - 1)]
		pron = d["pron"]
	var text: String = TalkData.DEATH[td["how"]] if td["kind"] == "death" else TalkData.TIDINGS[td["kind"]]
	text = text.replace("{ref}", talk.ref(about) if about != null else "")
	if td["kind"] == "death":
		text = _join(text, _items_now(about))
	var victim := world.person(td.get("victim", ""))
	if victim != null:
		# 「{victim}的{rel}{about}」：about 是死的人的誰
		text = text.replace("{victim}", victim.display_name).replace("{rel}", talk.rel(victim, about) if about != null else "")
	var old := world.person(td.get("old", ""))
	text = text.replace("{old}", old.display_name if old != null else "")
	text = text.replace("{killer}", world.who(td.get("killer", ""))).replace("{seller}", about.display_name if about != null else "有人")
	text = text.replace("{item}", talk.item_name(td.get("item", "")))
	text = text.replace("{place}", td["place_name"] if td.has("place_name") else MapData.place_name(td.get("place", hero.location)))
	if about != null:
		text = text.replace("{about}", about.display_name).replace("{apron}", about.pron)
	text = text.replace("{pron}", pron)
	var options := [["ok", "「知道了。」"]]
	if about != null and not about.dead and td["kind"] in ["hunted", "bounty_taker", "kin_knows", "heir_grudge"]:
		options.push_front(["where", "「%s在哪？」" % about.pron])
	return {"title": title, "color": color, "text": _join(intro, text, "\n"), "options": options}


## 接起兩段：同一個人連著說的兩句話，併成一句（「……。」「……。」→「……。……。」）
func _join(a: String, b: String, sep := "") -> String:
	if a.ends_with("」") and b.begins_with("「"):
		return a.trim_suffix("」") + b.substr(1)
	return a + sep + b if a != "" and b != "" else a + b


## 死了的人身上，以前從你這裡拿走的東西現在在哪
func _items_now(about: Person) -> String:
	if about == null:
		return ""
	var out := ""
	var h := hero
	for it in h.lost_items:
		# 只有獨一無二的東西（稀有武器、秘笈）說得出落到誰手上；店裡買得到的劍到處都是
		if h.lost_items[it] != about.id or h.has_item(it) or not (WeaponData.is_rare(it) or BookData.is_book(it)):
			continue
		var holder: Person = null
		for o in world.others():
			if o.has_item(it):
				holder = o
		var line: String
		if holder != null:
			line = TalkData.ITEM_NOW["held"].replace("{holder}", holder.display_name)
			world.hear(holder.id)
			h.lost_items[it] = holder.id
		elif world.shop_stock.has(it):
			line = TalkData.ITEM_NOW["shop"]
		else:
			line = TalkData.ITEM_NOW["buried"]
		out = _join(out, line.replace("{item}", talk.item_name(it)).replace("{apron}", about.pron))
	return out


func _vals(p: Person, t: Person) -> Dictionary:
	var v := {}
	if t != null:
		v["{target}"] = t.display_name
		v["{tpron}"] = t.pron
		v["{tplace}"] = MapData.place_name(_where(t))
		if p != null:
			v["{rel}"] = talk.rel(p, t)
	return v


# ---------- 選了 ----------

## 選了一個選項：{"fight": 空的 / "duel:人 id", "msgs"}。這件事結束（current 清空）
func answer(choice: String) -> Dictionary:
	var c := current
	current = {}
	if c.is_empty():
		return {"fight": "", "msgs": []}
	var h := hero
	var p := world.person(c.get("who", ""))
	var t := world.person(c.get("target", ""))
	var msgs := []
	var fight := ""
	match c["kind"]:
		"tiding":
			var td: Dictionary = c["tiding"]
			var about := world.person(td.get("about", ""))
			if choice == "where" and about != null:
				var name: String = p.display_name if p != null else TalkData.TELLERS[c["teller"]]["title"].split(" ")[-1]
				var line := TalkData.WHERE_REPLY if about.travel_left == 0 or world.rng.randf() < 0.7 else TalkData.WHERE_UNKNOWN
				if line == TalkData.WHERE_REPLY:
					world.hear(about.id)
				msgs.append(_m("info", line.replace("{teller}", name).replace("{where}", MapData.place_name(_where(about))).replace("{apron}", about.pron)))
		"warn":
			world.warned.append(t.id)
			match choice:
				"defy":
					world.remember(p, "warn_defied", {"target": t.id})
					msgs.append(_m("info", "你跟%s說，%s的懸賞你已經接了。" % [p.display_name, t.display_name]))
				"heed":
					world.remember(p, "warn_heeded", {"target": t.id})
					world.bounties[t.id]["takers"].erase(h.id)
					msgs.append(_m("info", "你回公會，把%s的懸賞退了。" % t.display_name))
				_:
					world.remember(p, "warned", {"target": t.id})
		"thanks":
			for pr in h.promises.duplicate():
				if pr["asker"] == p.id and pr["target"] == t.id:
					h.promises.erase(pr)
			world.remember(p, "kept", {"target": t.id})
			if choice == "take":
				var n := world.rng.randi_range(TalkData.THANKS_MONEY[0], TalkData.THANKS_MONEY[1])
				h.money += n
				msgs.append(_m("good", "錢袋裡是 %d 銀。" % n))
			else:
				if not p.grateful.has(h.id):
					p.grateful.append(h.id)
				msgs.append(_m("info", "你把錢袋推了回去。%s看了你一會兒，收了起來。" % p.display_name))
		"broke":
			for pr in h.promises.duplicate():
				if pr["asker"] == p.id and pr["target"] == t.id:
					if choice == "again":
						pr["month"] = world.month()
					else:
						h.promises.erase(pr)
			if choice == "again":
				world.remember(p, "promised", {"target": t.id})
				world.hear(t.id)
				msgs.append(_m("info", "你又答應了%s一次。" % p.display_name))
			else:
				world.remember(p, "broke", {"target": t.id})
				msgs.append(_m("info", "你跟%s說，%s的事你辦不到。" % [p.display_name, t.display_name]))
		"repay":
			match choice:
				"lead":
					var l := _lead(p)
					if l != null:
						world.hear(l.id)
						var hunting := l.target == h.id or l.grudges.has(h.id)
						var line := "%s說，%s在打聽你，最後有人在%s看見%s。" if hunting else "%s說，你在找的%s，前陣子在%s。"
						msgs.append(_m("info", line % ([p.display_name, l.display_name, MapData.place_name(_where(l)), l.pron] if hunting else [p.display_name, l.display_name, MapData.place_name(_where(l))])))
					p.grateful.erase(h.id)
					world.remember(p, "gift")
				"gift":
					var n := world.rng.randi_range(RoadData.GIFT[0], RoadData.GIFT[1])
					h.money += n
					p.grateful.erase(h.id)
					world.remember(p, "gift")
					msgs.append(_m("good", "布包裡是 %d 銀。" % n))
				_:
					msgs.append(_m("info", "你沒收。%s把布包收回懷裡，說這份情記著。" % p.display_name))
		"ask_help":
			if choice == "yes":
				h.promises.append({"asker": p.id, "target": t.id, "month": world.month(), "done": false})
				world.remember(p, "promised", {"target": t.id})
				world.hear(t.id)
				msgs.append(_m("info", "你答應%s，去對付%s。" % [p.display_name, t.display_name]))
			else:
				world.remember(p, "refused", {"target": t.id})
				msgs.append(_m("info", talk.say(p, "ask_no", {}, ["*"])))
		"invite":
			if choice == "yes":
				msgs.append_array(_hunt_with(p, t))
			else:
				world.remember(p, "invite_declined", {"target": t.id})
				msgs.append(_m("info", talk.say(p, "invite_no", {}, ["*"])))
		"challenge":
			if choice == "yes":
				fight = "duel:" + p.id
			else:
				h.fame = maxf(0.0, h.fame - 0.5)
				world.remember(p, "duel_declined")
				p.note("找{p:%s}比劍，{p:%s}不肯" % [h.id, h.id])
				msgs.append(_m("info", talk.say(p, "challenge_no", {}, ["*"])))
	return {"fight": fight, "msgs": msgs}


## 跟他一起去打懸賞（還沒有同伴：不開戰鬥，只寫結果）。來回的路上花時間
func _hunt_with(p: Person, t: Person) -> Array:
	var h := hero
	var home := h.location
	var where := _where(t)
	var months := MapData.distance(home, where) * 2 + 1
	var msgs := town._pass_months(months, "travel", "跟%s去找%s" % [p.display_name, t.display_name])
	if h.dying() or h.dead:
		return msgs
	p.location = home
	p.travel_left = 0
	p.travel_to = ""
	var vals := {"{target}": t.display_name, "{tpron}": t.pron, "{home}": MapData.place_name(home)}
	vals["{place}"] = MapData.place_name(where)
	if t.dead or not world.wanted(t.id):
		msgs.append(_m("info", talk.fill(TalkData.HUNT_GONE, p, vals)))
		world.remember(p, "hunted_with", {"target": t.id, "place": where})
		return msgs
	var team := maxf(p.power(), h.power()) + TalkData.TEAM_BONUS
	var reward: int = world.bounties[t.id]["reward"]
	t.location = where
	if world.rng.randf() < GrowthData.win_chance(team, t.power()):
		var taken := world._take(p, t, true)
		world.settle(h, t, true, true)
		p.fame += World.FAME_WIN
		p.note("跟{p:%s}一起在%s殺了{p:%s}" % [h.id, MapData.place_name(where), t.id])
		p.hp = maxi(1, p.hp - roundi(p.max_hp() * world.rng.randf_range(0.2, 0.5)))
		h.hp = maxi(1, h.hp - roundi(h.max_hp() * world.rng.randf_range(0.1, 0.4)))
		town._claim("guild", "%s的懸賞（一半）" % t.display_name, reward / 2, 0)
		msgs.append(_m("big", talk.fill(TalkData.HUNT_WIN, p, vals)))
		if not taken.is_empty():
			vals["{things}"] = "、".join(taken.map(func(it): return talk.look(it)))
			msgs.append(_m("info", talk.fill(TalkData.HUNT_WIN_TAKE, p, vals)))
		msgs.append(_m("info", "你們回公會交差，賞錢對半。"))
		world.remember(p, "hunted_with", {"target": t.id, "place": where})
		return msgs
	h.hp = maxi(1, roundi(h.max_hp() * 0.3))
	if world.rng.randf() < TalkData.TEAM_DEATH:
		world.settle(t, p, true, true)
		msgs.append(_m("bad", talk.fill(TalkData.HUNT_DEAD, p, vals)))
		return msgs
	p.hp = maxi(1, roundi(p.max_hp() * 0.3))
	p.rest_left = world.rng.randi_range(World.REST_AFTER[0], World.REST_AFTER[1])
	t.fame += World.FAME_WIN
	p.note("跟{p:%s}一起去找{p:%s}，被打退了" % [h.id, t.id])
	world.remember(p, "hunted_with", {"target": t.id, "place": where})
	msgs.append(_m("bad", talk.fill(TalkData.HUNT_LOSE, p, vals)))
	return msgs


# ---------- 小工具 ----------

## 你在找的人（說得出他在哪的）：在找你的人、跟你有仇的人、你接了懸賞的人
func _lead(teller: Person) -> Person:
	var best: Person = null
	var best_rank := 0
	for p in world.others():
		if p == teller:
			continue
		var rank := 0
		if p.target == hero.id:
			rank = 3
		elif p.grudges.has(hero.id):
			rank = 2
		elif town.took_bounty(p.id):
			rank = 1
		if rank > best_rank:
			best = p
			best_rank = rank
	return best


## 他在哪（在路上就寫要去的地方）
func _where(p: Person) -> String:
	return p.travel_to if p.travel_left > 0 else p.location


func _m(kind: String, text: String) -> Dictionary:
	return {"kind": kind, "text": text}
