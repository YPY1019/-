class_name Road
extends RefCounted

## 路上的事（規則）：走路時看世界上現在有誰、跟你有什麼關係，挑一件事；選了之後發生什麼。文字和機率在 RoadData。
## 正在處理的事放在 Town.road：{"id", "place": 要去的地方, "at": 在哪一帶出的事, "step", "who", "other",
##   "win": 打贏了接哪一步, "delay": 多走幾個月, "justified": 是對方先動手（殺了他不算殺無辜）}
## 不碰畫面：view() 給對話框要顯示的，answer() 回傳 {"fight", "msgs"}。

## Town 也拿著 Road，所以這裡只留弱參照（不然兩個互相拿著，永遠不會釋放）
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

## 對方先動手的事（打起來殺了他不算殺無辜）
const AGGRESSORS := ["ambush", "robbers", "kin_help", "merchant", "caravan", "thug"]
## 會把人叫到路上來的事（他就在那一帶）
const MEET := ["ambush", "robbers", "robbers_shy", "challenge", "kin_help"]
## 檢定：差距 0 時一半一半，每差 1 點加減 CHECK_PER_POINT
const CHECK_PER_POINT := 0.1


func _init(t: Town) -> void:
	_town = weakref(t)


# ---------- 碰不碰得上 ----------

## 從 from 走到 to（走 months 個月）：擲這趟路上碰不碰得上事
func happens(from: String, to: String, months: int) -> bool:
	var stay := 1.0
	for c in _list(from, to):
		stay *= pow(1.0 - c["chance"], months)
	return world.rng.randf() < 1.0 - stay


## 走到半路，碰上哪一件（這時候世界上的人可能已經走了、死了）：回傳這件事的狀態，都不成立就是空的
func pick(from: String, to: String) -> Dictionary:
	var list := _list(from, to)
	var total := 0.0
	for c in list:
		total += c["chance"]
	if list.is_empty():
		return {}
	var r := world.rng.randf() * total
	for c in list:
		r -= c["chance"]
		if r <= 0.0:
			return _begin(c, to)
	return _begin(list[-1], to)


func _list(from: String, to: String) -> Array:
	var list := _one_each(_candidates(MapData.path(from, to)))
	for c in list:
		c["chance"] = minf(0.95, c["chance"] * town.road_boost)
	return list.filter(func(c): return c["chance"] > 0.0)


## 同一種事有好幾個人可以碰：隨便挑一個（機率不疊加，不然人一多就一直碰到同一種事）。
## 仇人堵你例外：找你的人越多，越容易被堵
func _one_each(list: Array) -> Array:
	var by_id := {}
	for c in list:
		var key: String = c["id"] if c["id"] != "ambush" else "ambush:" + c["who"]
		by_id[key] = by_id.get(key, []) + [c]
	var out := []
	for key in by_id:
		var group: Array = by_id[key]
		out.append(group[world.rng.randi_range(0, group.size() - 1)])
	return out


func _begin(c: Dictionary, to: String) -> Dictionary:
	var id: String = c["id"]
	hero.road_seen[id] = world.month()
	var who: String = c.get("who", "")
	if who != "":
		hero.road_seen["p:" + who] = world.month()
		hero.road_seen[id + ":" + who] = world.month()
	if MEET.has(id):
		for key in ["who", "other"]:
			var p := world.person(c.get(key, ""))
			if p != null and not p.dead:
				p.location = c["at"]
				p.travel_left = 0
				p.travel_to = ""
	return {"id": id, "place": to, "at": c["at"], "step": "start", "who": who, "other": c.get("other", ""),
		"justified": AGGRESSORS.has(id), "delay": 0, "win": ""}


## 這趟路上可能碰上的事：[{"id", "chance", "who", "other", "at"}]
func _candidates(path: Array) -> Array:
	var out := []
	var wild := path.filter(func(x): return not MapData.is_city(x))
	if wild.is_empty():
		wild = [path[-1]]
	var mid: String = wild[wild.size() / 2]
	var h := hero
	var me := h.power()
	var others := world.others()
	for p in others:
		var on_road: bool = wild.has(p.location) and p.travel_left == 0
		var at: String = p.location if on_road else mid
		var hunting: bool = p.target == h.id and (p.grudges.has(h.id) or world.wanted(h.id))
		# 仇人、來收你懸賞的人：在路上堵你
		if (hunting or p.grudges.has(h.id) and p.power() >= me - World.GRUDGE_DARE) and p.rest_left <= 0:
			out.append({"id": "ambush", "chance": RoadData.CHANCE["ambush"] if hunting else RoadData.AMBUSH_IDLE, "who": p.id, "at": at})
			continue
		if p.grudges.has(h.id):
			continue
		# 欠你情的人
		if p.grateful.has(h.id) and (on_road or p.travel_left > 0) and _free("repay", p):
			out.append({"id": "repay", "chance": RoadData.CHANCE["repay"], "who": p.id, "at": at})
			continue
		# 有懸賞的人、他的手下、攔路的：在自己出沒的路上搶人。你強太多，他們不敢出來
		if p.role in ["villain", "follower"] and on_road and p.rest_left <= 0 and not p.relations.has(h.id) and not p.grateful.has(h.id):
			var shy: bool = me >= p.power() + RoadData.STRONGER_GAP
			var id := "robbers_shy" if shy else "robbers"
			if _free(id, p):
				out.append({"id": id, "chance": RoadData.CHANCE[id], "who": p.id, "at": at})
		# 強者榜上跟你差不多的人，等你比劍（你帶著重傷就不找你）
		if h.fame >= RoadData.CHALLENGE_FAME and h.hp >= h.max_hp() * SchoolData.FIT_HP and p.role in ["hunter", "settled", "duelist", "youth"] and p.age() >= 17 \
				and not world.wanted(p.id) and not p.relations.has(h.id) and p.target == "" and (path.has(p.location) or p.travel_left > 0):
			var gap: float = p.power() - me
			if gap >= RoadData.CHALLENGE_RANGE[0] and gap <= RoadData.CHALLENGE_RANGE[1] and _free("challenge", p):
				out.append({"id": "challenge", "chance": RoadData.CHANCE["challenge"], "who": p.id, "at": at})
		# 路上碰到的人
		if p.travel_left > 0 and _free("traveler", p):
			out.append({"id": "traveler", "chance": RoadData.CHANCE["traveler"], "who": p.id, "at": mid})
	# 同門被有懸賞的人圍住
	if town.member() and _free("kin_help", null):
		var foes := others.filter(func(o): return world.wanted(o.id) and wild.has(o.location) and o.travel_left == 0 and o.rest_left <= 0)
		if not foes.is_empty():
			var foe: Person = foes[world.rng.randi_range(0, foes.size() - 1)]
			var kin := others.filter(func(o): return o.school == h.school and o.rank > 0 and not o.grudges.has(h.id) and o.power() < foe.power() and _free("kin_help", o))
			if not kin.is_empty():
				out.append({"id": "kin_help", "chance": RoadData.CHANCE["kin_help"], "who": kin[world.rng.randi_range(0, kin.size() - 1)].id,
					"other": foe.id, "at": foe.location})
	# 有人剛死在路邊
	for e in world.recent_deaths:
		if wild.has(e["place"]) and world.month() - e["month"] <= 4 and not h.road_seen.has("corpse:" + e["id"]) and e["id"] != h.id and e["killer"] != h.id:
			out.append({"id": "corpse", "chance": RoadData.CHANCE["corpse"], "who": e["id"], "other": e["killer"], "at": e["place"]})
			break
	# 有懸賞的人剛搶過的地方
	for e in world.recent_crimes:
		var v := world.person(e["who"])
		if v != null and not v.dead and world.wanted(v.id) and wild.has(e["place"]) and world.month() - e["month"] <= 3 and _free("raided", v):
			out.append({"id": "raided", "chance": RoadData.CHANCE["raided"], "who": v.id, "at": e["place"]})
			break
	# 被搶的商人：搶他的人就在附近
	var near := []
	for x in wild:
		near.append(x)
		near.append_array(MapData.neighbors(x))
	var robbers := others.filter(func(o): return o.role in ["villain", "follower"] and near.has(o.location) and not MapData.is_city(o.location) and o.travel_left == 0 \
		and not o.grudges.has(h.id) and not o.grateful.has(h.id))
	if not robbers.is_empty() and _free("merchant", null):
		out.append({"id": "merchant", "chance": RoadData.CHANCE["merchant"], "who": robbers[world.rng.randi_range(0, robbers.size() - 1)].id, "at": mid})
	# 商隊（夜裡摸過來的，附近有攔路的就是他們）
	if _free("caravan", null):
		var raider := robbers.filter(func(o): return wild.has(o.location))
		out.append({"id": "caravan", "chance": RoadData.CHANCE["caravan"], "who": raider[0].id if not raider.is_empty() else "", "at": mid})
	if h.realm <= 1 and _free("thug", null):
		out.append({"id": "thug", "chance": RoadData.CHANCE["thug"], "at": mid})
	return out


## 這件事（跟這個人）最近沒碰過
func _free(id: String, p: Person) -> bool:
	var seen := hero.road_seen
	var now := world.month()
	if seen.has(id) and now - seen[id] < RoadData.AGAIN[id]:
		return false
	if p != null and seen.has("p:" + p.id) and now - seen["p:" + p.id] < RoadData.PERSON_AGAIN:
		return false
	return true


# ---------- 這一步 ----------

## 現在這一步：{"title", "color", "text", "options": [[選項的編號, 按鈕的字]]}
func view() -> Dictionary:
	var st := town.road
	var d: Dictionary = RoadData.EVENTS[st["id"]]
	var step: Dictionary = d["steps"][st["step"]]
	var t: String = step.get("title", d["title"])
	var title := t
	var color := Color.WHITE
	if t == "who" or t == "other":
		var p := world.person(st[t])
		title = ""
		if p != null and (not p.dead or _knows(p)):
			title = ("%s %s" % [p.title, p.display_name]).strip_edges()
			color = Color(p.realm_color())
			if not p.dead:
				world.hear(p.id)
		elif p != null:
			title = "路邊的人"
	var options := []
	var list: Array = step["options"]
	for i in list.size():
		if _need(list[i].get("need", {})):
			options.append([str(i), _fmt(list[i]["label"])])
	return {"title": title, "color": color, "text": _fmt(step["text"]), "options": options}


func _need(need: Dictionary) -> bool:
	var h := hero
	var who := _p("who")
	if need.has("money") and h.money < need["money"]:
		return false
	if need.get("pay", false) and (who == null or h.money < _pay()):
		return false
	if need.get("bribe", false) and (who == null or h.money < _bribe() or _bribe() <= 0):
		return false
	if need.get("member", false) and not town.member():
		return false
	if need.get("took_bounty", false) and (who == null or not town.took_bounty(who.id)):
		return false
	if need.has("kind") and (who == null or _kind(who) != need["kind"]):
		return false
	if need.get("lead", false) and _lead() == null:
		return false
	return true


## 選了一個選項：{"fight": 空的 = 不打；enemy:怪物 id / person:人 id / duel:人 id, "msgs"}
## 之後 road["step"] 是下一步（空的 = 這件事結束，接著走路）
func answer(choice: String) -> Dictionary:
	var st := town.road
	var h := hero
	var step: Dictionary = RoadData.EVENTS[st["id"]]["steps"][st["step"]]
	var opt: Dictionary = step["options"][int(choice)]
	var out: Dictionary = opt
	if opt.has("check"):
		out = opt["ok"] if _check(opt["check"]) else opt["fail"]
	var who := _p("who")
	var other := _p("other")
	var msgs := []
	var vals := {}
	if out.has("money"):
		var n := 0
		match str(out["money"]):
			"purse":
				n = world.rng.randi_range(RoadData.PURSE[0], RoadData.PURSE[1])
			"gift":
				n = world.rng.randi_range(RoadData.GIFT[0], RoadData.GIFT[1])
			_:
				n = int(out["money"])
		h.money = maxi(0, h.money + n)
		vals["{n}"] = str(absi(n))
	if out.get("rob", false):
		var n := mini(h.money, maxi(RoadData.ROB_MIN, roundi(h.money * RoadData.ROB_SHARE)))
		h.money -= n
		vals["{n}"] = str(n)
		if who != null:
			who.money += n
	if out.get("pay", false) and who != null:
		h.money -= _pay()
		who.grudges.erase(h.id)
		who.grudge_why.erase(h.id)
		if who.target == h.id:
			who.target = ""
		who.note("收了{p:%s}的錢，了結了舊帳" % h.id)
	if out.get("bribe", false) and who != null:
		h.money -= _bribe()
		who.target = ""
		who.rest_left = world.rng.randi_range(24, 36)
		if world.bounties.has(h.id):
			world.bounties[h.id]["takers"].erase(who.id)
	if out.has("hear"):
		var p: Person = null
		match out["hear"]:
			"lead":
				p = _lead()
			"notable":
				p = _notable()
				if p != null:
					vals["{who}"] = ("%s%s" % [p.title, p.display_name])
					vals["{where}"] = MapData.place_name(p.location)
				else:
					out = {"text": "沒有什麼有用的消息。"}
			_:
				p = _p(out["hear"])
		if p != null:
			world.hear(p.id)
	if out.has("fame"):
		h.fame = maxf(0.0, h.fame + out["fame"])
	if out.has("merit"):
		h.merit += out["merit"]
		h.merit_total += out["merit"]
	if out.has("hurt"):
		h.hp = maxi(1, h.hp - roundi(h.max_hp() * out["hurt"]))
	if out.has("item") and not h.has_item(out["item"]):
		h.give_item(out["item"])
	st["delay"] = st.get("delay", 0) + out.get("delay", 0)
	if out.has("escape"):
		var p := _p(out["escape"])
		if p != null:
			p.rest_left = world.rng.randi_range(3, 6)
	if out.get("backoff", false) and who != null:
		who.rest_left = world.rng.randi_range(12, 24)
		who.target = ""
	if out.get("grateful", "") != "":
		var p := _p(out["grateful"])
		if p != null and not p.grateful.has(h.id):
			p.grateful.append(h.id)
	if out.get("repaid", false) and who != null:
		who.grateful.erase(h.id)
	# 他記下跟你之間的這件事
	if out.has("memo") and who != null and not who.dead:
		world.remember(who, out["memo"], {"place": st["at"]})
	for key in out.get("note", {}):
		var p := _p(key)
		if p != null and not p.dead:
			p.note(_fmt(out["note"][key]).replace("{p:hero}", "{p:%s}" % h.id))
	if out.get("bury", false) and who != null:
		_bury(who)
	if out.has("text"):
		var text := _fmt(out["text"])
		for k in vals:
			text = text.replace(k, vals[k])
		msgs.append(_m("info", text))
	if out.get("leave_fight", false) and who != null and other != null:
		msgs.append_array(_leave(who, other))
	if out.has("drifter"):
		_drifter(out["drifter"], int(vals.get("{n}", "0")))
	var fight := ""
	if out.get("duel", false) and who != null:
		fight = "duel:" + who.id
	elif out.has("fight"):
		match out["fight"]:
			"who", "other":
				fight = "person:" + st[out["fight"]]
			"thug":
				fight = "enemy:highwayman"
			"raider":
				fight = "person:" + st["who"] if who != null and not who.dead else "enemy:highwayman"
			_:
				fight = "enemy:" + out["fight"]
	if fight != "":
		st["win"] = out.get("win", "")
		st["step"] = ""
	else:
		st["step"] = out.get("next", "")
	return {"fight": fight, "msgs": msgs}


## 路上打完：打贏了、這件事還有下一步就接下去；不然這件事結束
func after_fight(won: bool) -> void:
	var st := town.road
	if st.is_empty():
		return
	st["step"] = st.get("win", "") if won else ""
	st["win"] = ""


# ---------- 結果 ----------

## 你走開了：other 跟 who 自己打。結果你不知道（之後聽說、或有人來告訴你）
func _leave(who: Person, other: Person) -> Array:
	world.remember(who, "left", {"place": town.road["at"]})
	world.fight(other, who)
	if not who.dead:
		who.note("在%s被{p:%s}的人圍住，{p:%s}路過，沒有停下來" % [MapData.place_name(town.road["at"]), other.id, hero.id])
	return []


## 把死人埋了：他的家人、師徒欠你一份情
func _bury(dead: Person) -> void:
	hero.fame += 0.5
	for r in dead.relations:
		var p := world.person(r)
		if p == null or p.dead or p.id == hero.id or not dead.relations[r] in World.AVENGER_RELATIONS or p.grudges.has(hero.id):
			continue
		if not p.grateful.has(hero.id):
			p.grateful.append(hero.id)
		p.note("聽說{p:%s}在%s把{p:%s}埋了" % [hero.id, MapData.place_name(town.road["at"]), dead.id])
		world.remember(p, "buried", {"place": town.road["at"], "victim": dead.id})


## 沒名字的小賊活下來：變成世界上的人
func _drifter(kind: String, n: int) -> void:
	var h := hero
	var at: String = town.road["at"]
	var place := MapData.place_name(at)
	var p := world.make_drifter(at)
	match kind:
		"robbed":
			p.money += n
			p.note("在%s攔路，搶了{p:%s}" % [place, h.id])
			world.remember(p, "robbed_you", {"place": at})
		"pitied":
			p.grateful.append(h.id)
			p.note("在%s攔路，{p:%s}丟了錢給%s" % [place, h.id, p.pron])
			world.remember(p, "pitied", {"place": at})
		"fled":
			p.note("在%s攔路，被{p:%s}嚇跑了" % [place, h.id])
			world.remember(p, "scared", {"place": at})
		"spared":
			p.hp = maxi(1, roundi(p.max_hp() * World.ROBBED_HP))
			p.grateful.append(h.id)
			p.note("在%s攔路，被{p:%s}打倒，放了一條生路" % [place, h.id])
			world.remember(p, "spared", {"place": at})
		"stripped":
			p.hp = maxi(1, roundi(p.max_hp() * World.ROBBED_HP))
			world.add_grudge(p, h.id, "beaten")
			p.note("在%s攔路，被{p:%s}打倒，搜光了身上" % [place, h.id])
			world.remember(p, "stripped", {"place": at})


# ---------- 小工具 ----------

func _p(key: String) -> Person:
	return world.person(town.road.get(key, ""))


## 檢定：有機率，不是一刀切
func _check(c: Dictionary) -> bool:
	var chance := 0.5
	if c.has("power"):
		var p := _p(c["power"])
		chance = GrowthData.win_chance(hero.power(), p.power()) if p != null else 0.5
	else:
		var mine: int = hero.body(c["stat"]) + c.get("bonus", 0)
		var theirs: int = c["vs"] if c["vs"] is int else (_p(c["vs"]).body(c["stat"]) if _p(c["vs"]) != null else mine)
		chance = clampf(0.5 + (mine - theirs) * CHECK_PER_POINT, 0.05, 0.95)
	return world.rng.randf() < chance


## 他為什麼找你：kin 你殺了他的人、beaten 你打傷搶過他、heir 上一個人欠的、bounty 來收你的懸賞
func _kind(p: Person) -> String:
	if p.grudges.has(hero.id):
		return p.grudge_why.get(hero.id, {}).get("kind", "beaten")
	if world.wanted(hero.id) and p.target == hero.id:
		return "bounty"
	return "beaten"


## 付錢了結他的仇、讓來收懸賞的人走：要多少
func _pay() -> int:
	var p := _p("who")
	return RoadData.PAY_BASE + RoadData.PAY_PER_REALM * (p.realm if p != null else 0)


func _bribe() -> int:
	return roundi(world.bounties.get(hero.id, {}).get("reward", 0) * RoadData.BRIBE_SHARE)


## 你在找的人（說得出他在哪的）：在找你的人、跟你有仇的人、你接了懸賞的人
func _lead() -> Person:
	var who := _p("who")
	var best: Person = null
	var best_rank := 0
	for p in world.others():
		if p == who:
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


## 聽得到消息的有名的人（不在路上的）
func _notable() -> Person:
	var list := world.others().filter(func(o): return o.travel_left == 0 and (o.role in ["villain", "follower", "duelist", "hunter"] or world.ranking().has(o)))
	if list.is_empty():
		return null
	return list[world.rng.randi_range(0, list.size() - 1)]


## 你認得這個人（聽說過、交過手、有關係）
func _knows(p: Person) -> bool:
	return hero.heard.has(p.id) or hero.fought.has(p.id) or hero.relations.has(p.id) or p.relations.has(hero.id)


## 文字：換上你、碰到的人、在哪。{say:情況} 他用自己的口氣說（先提舊事）、{voice:情況} 不提舊事、{past} 只提舊事、{gesture} 怕你或看不起你
func _fmt(text: String) -> String:
	var h := hero
	var st := town.road
	var who := _p("who")
	var other := _p("other")
	if who != null:
		text = _talk_tokens(text, who)
		if text.contains("{line}"):
			text = text.replace("{line}", town.talk.revenge(who))
	text = text.replace("{my}", WeaponData.get_def(h.weapon).get("noun", "兵器")).replace("{me}", h.display_name)
	text = text.replace("{road}", "往%s的路上" % MapData.place_name(st["place"])).replace("{dest}", MapData.place_name(st["place"]))
	text = text.replace("{place}", MapData.place_name(st["at"]))
	if text.contains("{who_line}") and who != null:
		text = text.replace("{who_line}", "是{name}。" if _knows(who) else "你不認得{pron}。")
	if text.contains("{wound}") and who != null:
		text = text.replace("{wound}", _wound(who))
	if text.contains("{lead"):
		var l := _lead()
		if l != null:
			var hunting := l.target == h.id or l.grudges.has(h.id)
			var line := "「{lead}在打聽你。最後有人在{leadplace}看見%s。」" % l.pron if hunting else "「你在找的{lead}，前幾天在{leadplace}。」"
			text = text.replace("{lead_line}", line).replace("{lead}", l.display_name).replace("{leadplace}", MapData.place_name(_where(l)))
	if who != null:
		text = text.replace("{name}", who.display_name).replace("{pron}", who.pron).replace("{look}", _look(who.weapon))
		text = text.replace("{noun}", WeaponData.get_def(who.weapon).get("noun", "兵器"))
		text = text.replace("{wplace}", MapData.place_name(_where(who))).replace("{pay}", str(_pay())).replace("{bribe}", str(_bribe()))
	if other != null:
		text = text.replace("{other}", other.display_name).replace("{opron}", other.pron).replace("{olook}", _look(other.weapon))
		text = text.replace("{kplace}", MapData.place_name(_where(other)) if not other.dead else "林子")
	return text


## 他說話：{say:情況}、{voice:情況}、{past}、{gesture}
func _talk_tokens(text: String, who: Person) -> String:
	var t := town.talk
	for tag in ["{say:", "{voice:"]:
		var i := text.find(tag)
		while i >= 0:
			var j := text.find("}", i)
			var key := text.substr(i + tag.length(), j - i - tag.length())
			var vals := {"{rank}": t.rank_line(who)}
			var line := t.say(who, key, vals) if tag == "{say:" else t.say(who, key, vals, ["*"])
			text = text.substr(0, i) + line + text.substr(j + 1)
			i = text.find(tag)
	if text.contains("{past}"):
		var past := t.past_line(who)
		text = text.replace("{past}", "\n" + past if past != "" else "")
	if text.contains("{gesture}"):
		text = text.replace("{gesture}", t.gesture(who))
	return text


## 死人身上的傷口：看兇手拿的兵器
func _wound(dead: Person) -> String:
	var weapon := ""
	for e in world.recent_deaths:
		if e["id"] == dead.id:
			weapon = e["weapon"]
	var kind: String = WeaponData.get_def(weapon)["kind"] if weapon != "" else "sword"
	return RoadData.WOUNDS.get(kind, RoadData.WOUNDS["sword"]).replace("{pron}", dead.pron)


## 他在哪（在路上就寫要去的地方）
func _where(p: Person) -> String:
	return p.travel_to if p.travel_left > 0 else p.location


## 武器的樣子（短的，去掉句號）
func _look(item: String) -> String:
	var look: String = WeaponData.get_def(item).get("look", WeaponData.get_def(item)["name"])
	return look.trim_suffix("。").split("，")[0]


func _m(kind: String, text: String) -> Dictionary:
	return {"kind": kind, "text": text}
