class_name World
extends RefCounted

## 活的世界：時間、世界上的人、懸賞、委託板上的怪物、傳聞。每過一個月推一次（tick）。
## 世界上的人自己過日子：移動、變強、變老、老死、互相打、拿走輸的人身上的東西、替家人報仇。
## 玩家角色也是世界上的一個人（hero_id），但他的事由 Town 照玩家的決定去做，World 不替他決定。
## 跟玩家角色有關的打鬥（有人找上門）World 只負責走過去，打由 Town 開戰鬥。
## 不碰畫面：傳到你耳裡的事放在 news（[{"month", "text", "kind"}]），由 Town 交給畫面。

## 一般委託越打越少：第 n 次打完，要再過幾個月才會再出現
const MONSTER_BACK := [2, 3, 4, 6, 9, 12, 18]
## 世界上的人一個月回幾成血
const HEAL := 0.25
## 被打傷沒死的人剩幾成血
const ROBBED_HP := 0.3
## 30 歲以後就不長了
const GROW_UNTIL := 30
## 有懸賞的人在外面做壞事（每個月的機率），懸賞跟著漲
const CRIME_CHANCE := 0.05
const CRIME_RAISE := 25
## 有懸賞的人搶路過的人（每個月的機率，只搶比自己弱的）
const ROB_CHANCE := 0.08
## 說得出是誰下的手的機率（其他時候只知道人死了）
const NAMED_CHANCE := 0.5
## 變強了的傳聞多常傳到你耳裡
const GREW_NEWS := 0.6
## 跟你有仇的人：強不過你這麼多也會來
const GRUDGE_DARE := 1.0
## 決鬥家多久找一次對手、找差不多強的（自己減多少到加多少）
const DUEL_EVERY := [14, 24]
const DUEL_RANGE := [-3.0, 0.5]
## 打完、被打跑之後歇幾個月；冒險者撕下一張懸賞之後歇比較久（領賞、花錢、養傷）
const REST_AFTER := [3, 6]
const HUNT_REST := [8, 16]

var clock := Clock.new()
## id -> Person（死了的也留著，世界記得）
var people := {}
var hero_id := ""
## 有懸賞的人 id -> {"reward", "text", "takers": [接下的人]}
var bounties := {}
## 委託板上的怪物 id -> {"count": 打過幾次, "back": 世界的第幾個月再出現}
var monsters := {}
## 這次推的時候傳到你耳裡的事
var news: Array = []
## 已經傳過話給你的人（target id）
var warned: Array = []
## 下個月要傳到你耳裡的話
var _mail: Array = []
## 以前的玩家角色（照順序）
var lives: Array = []
var rng := RandomNumberGenerator.new()


## seed：-1 = 隨機（測試用固定的）
func _init(seed := -1) -> void:
	if seed < 0:
		rng.randomize()
	else:
		rng.seed = seed
	for id in PeopleData.PEOPLE:
		if PeopleData.PEOPLE[id].get("arrive", 0) == 0:
			_spawn(id)


# ---------- 查 ----------

func month() -> int:
	return clock.month


func hero() -> Person:
	return people[hero_id]


func person(id: String) -> Person:
	return people.get(id)


## 活著的人（不含玩家角色）
func others() -> Array:
	return people.values().filter(func(p): return not p.dead and p.id != hero_id)


## 在這個地方的人（不在路上、活著、不是你）
func at(place: String) -> Array:
	return others().filter(func(p): return p.location == place and p.travel_left == 0)


## 是你就寫「你」，其他人寫名字
func who(id: String) -> String:
	if id == hero_id:
		return "你"
	var p: Person = people.get(id)
	return p.display_name if p != null else "某人"


## 把 {p:id} 換成名字
func fmt(text: String) -> String:
	var out := text
	while true:
		var i := out.find("{p:")
		if i < 0:
			break
		var j := out.find("}", i)
		out = out.substr(0, i) + who(out.substr(i + 3, j - i - 3)) + out.substr(j + 1)
	return out


## 這個人身上的東西都是誰的（看得到的那面）：關係的說法
const RELATION_NAMES := {"parent": "父親", "child": "孩子", "master": "師傅", "disciple": "徒弟",
	"sibling": "兄弟", "boss": "老大", "follower": "手下"}
const RELATION_BACK := {"parent": "child", "child": "parent", "master": "disciple", "disciple": "master",
	"sibling": "sibling", "boss": "follower", "follower": "boss"}
## 死了會有人替他報仇、動他之前會先傳話的關係
const AVENGER_RELATIONS := ["parent", "child", "master", "disciple", "sibling", "boss", "follower"]
const PROTECTOR_RELATIONS := ["parent", "sibling", "boss", "master"]


## 有懸賞
func wanted(id: String) -> bool:
	return bounties.has(id)


## 委託板上的怪物現在有沒有委託
func monster_open(enemy_id: String) -> bool:
	return monsters.get(enemy_id, {}).get("back", 0) <= month()


## 打完一次怪物的委託：越打越久才再出現
func monster_done(enemy_id: String) -> void:
	var m: Dictionary = monsters.get(enemy_id, {"count": 0, "back": 0})
	m["back"] = month() + MONSTER_BACK[mini(m["count"], MONSTER_BACK.size() - 1)]
	m["count"] += 1
	monsters[enemy_id] = m


## 現在找上門來要跟你打的人（在你待的地方，正在找你）
func comer() -> Person:
	var h := hero()
	if h.travel_left > 0:
		return null
	for p in at(h.location):
		if p.target == hero_id and p.rest_left <= 0:
			return p
	return null


## 動手前會先傳話的人：這個人的家人、老大、師傅（活著、跟你沒仇）
func protector_of(id: String) -> Person:
	var t: Person = people[id]
	for r in t.relations:
		var p: Person = people.get(r)
		if p != null and not p.dead and p.id != hero_id and t.relations[r] in PROTECTOR_RELATIONS:
			return p
	return null


# ---------- 開局、新的人 ----------

func make_hero(name: String, pron: String) -> Person:
	var h := Person.new()
	h.id = "hero"
	h.display_name = name
	h.pron = pron
	h.clock = clock
	h.born_year = -LifeData.START_AGE
	h.dies_at = LifeData.roll_dies_at(rng, h.born_year, LifeData.LIFESPAN_MIN, LifeData.LIFESPAN_MAX, month())
	h.hp = h.max_hp()
	people[h.id] = h
	hero_id = h.id
	return h


func _spawn(id: String) -> Person:
	var d: Dictionary = PeopleData.PEOPLE[id]
	var p := Person.new()
	p.id = id
	p.clock = clock
	p.display_name = d["name"]
	p.title = d.get("title", "")
	p.pron = d.get("pron", "他")
	p.style = d["style"]
	p.start_lines = d.get("start", [])
	p.born_year = LifeData.year_of(month()) - d["age"]
	var life: Array = d.get("life", [LifeData.LIFESPAN_MIN, LifeData.LIFESPAN_MAX])
	p.dies_at = LifeData.roll_dies_at(rng, p.born_year, life[0], life[1], month())
	p.stats = d["stats"].duplicate()
	p.potential = d.get("potential", d["stats"]).duplicate()
	p.growth = d.get("growth", 0.0)
	p.realm = GrowthData.realm_of_stats(p.stats)
	p.base_hp = d.get("hp", 0)
	p.base_sum = p.stats["str"] + p.stats["agi"]
	p.owned_weapons.clear()
	p.owned_weapons.append(d["weapon"])
	p.weapon = d["weapon"]
	for it in d.get("items", []):
		p.give_item(it)
	for m in d.get("learned", []):
		p.learn(m)
	p.school = d.get("school", "")
	p.rank = d.get("rank", 0)
	p.location = d["place"]
	p.role = d["role"]
	p.haunts = d.get("haunts", [])
	p.follows = d.get("follows", "")
	p.boldness = d.get("boldness", 0.5)
	p.vow = d.get("vow", {}).duplicate()
	p.grudges = d.get("grudges", []).duplicate()
	p.stay_left = rng.randi_range(2, 8)
	p.rest_left = rng.randi_range(4, 14)
	p.hp = p.max_hp()
	people[id] = p
	# 關係寫一邊就好，另一邊補上
	for other in d.get("relations", {}):
		var kind: String = d["relations"][other]
		p.relations[other] = kind
		if people.has(other):
			people[other].relations[id] = RELATION_BACK[kind]
	for other in people:
		var od: Dictionary = PeopleData.PEOPLE.get(other, {})
		if od.get("relations", {}).has(id):
			p.relations[other] = RELATION_BACK[od["relations"][id]]
	if d.has("bounty"):
		bounties[id] = {"reward": d["bounty"]["reward"], "text": d["bounty"]["text"], "takers": []}
	return p


## 換人接著玩時，沒有夠年輕的人可以選：找一個剛到城裡的年輕人
func newcomer() -> Person:
	var pick: Array = PeopleData.NEWCOMER_NAMES[rng.randi_range(0, PeopleData.NEWCOMER_NAMES.size() - 1)]
	var p := Person.new()
	p.id = "new_%d_%d" % [month(), rng.randi_range(0, 99999)]
	p.clock = clock
	p.display_name = pick[0]
	p.pron = pick[1]
	p.style = "master"
	p.born_year = LifeData.year_of(month()) - LifeData.START_AGE
	p.dies_at = LifeData.roll_dies_at(rng, p.born_year, LifeData.LIFESPAN_MIN, LifeData.LIFESPAN_MAX, month())
	p.role = "youth"
	p.potential = {"str": 20, "agi": 20}
	p.growth = 1.2
	p.location = MapData.HOME
	p.hp = p.max_hp()
	people[p.id] = p
	return p


# ---------- 時間 ----------

## 過 n 個月。回傳這段時間傳到你耳裡的事
func advance(n: int) -> Array:
	news.clear()
	for i in n:
		tick()
	return news.duplicate()


func tick() -> void:
	clock.month += 1
	for m in _mail:
		_tell(m, "big")
	_mail.clear()
	for id in PeopleData.PEOPLE:
		if PeopleData.PEOPLE[id].get("arrive", 0) == month() and not people.has(id):
			var p := _spawn(id)
			if PeopleData.PEOPLE[id].has("arrive_text"):
				_tell(PeopleData.PEOPLE[id]["arrive_text"])
	var list := others()
	_shuffle(list)
	for p in list:
		if p.dead:
			continue
		if month() >= p.dies_at:
			_die(p)
			continue
		p.hp = mini(p.max_hp(), p.hp + roundi(p.max_hp() * HEAL))
		_grow(p)
		if p.travel_left > 0:
			p.travel_left -= 1
			if p.travel_left == 0:
				p.location = p.travel_to
				p.travel_to = ""
	for p in list:
		if not p.dead and p.travel_left == 0:
			_act(p)


func _grow(p: Person) -> void:
	if p.growth <= 0.0 or p.age() >= GROW_UNTIL:
		return
	var old := p.realm
	for s in GrowthData.STATS:
		if p.stats[s] < p.potential.get(s, 0) and rng.randf() < p.growth / 12.0:
			p.stats[s] += 1
			p.weapon = p.best_weapon()
	p.realm = maxi(p.realm, GrowthData.realm_of_stats(p.stats))
	if p.realm > old and rng.randf() < GREW_NEWS:
		_tell(_pick(NewsData.GREW).replace("{p:who}", "{p:%s}" % p.id).replace("{place}", MapData.place_name(p.location)))


# ---------- 世界上的人做什麼 ----------

func _act(p: Person) -> void:
	if p.rest_left > 0:
		p.rest_left -= 1
	# 誓言：到了那個月就去找那個人
	if not p.vow.is_empty() and month() >= p.vow["month"]:
		var v: Person = people.get(p.vow["target"])
		if v != null and not v.dead and p.target == "":
			p.target = v.id
			_tell(NewsData.VOW.replace("{p:who}", "{p:%s}" % p.id).replace("{p:target}", "{p:%s}" % v.id))
		p.vow = {}
	# 有仇：打得過（或差不多）就去找他
	if p.target == "":
		for g in p.grudges.duplicate():
			var t: Person = people.get(g)
			if t == null or t.dead:
				p.grudges.erase(g)
				continue
			var dare := GRUDGE_DARE if g == hero_id else 0.5
			if p.power() >= t.power() - dare:
				_set_target(p, g)
				break
	if p.target != "":
		_chase(p)
		return
	match p.role:
		"villain":
			_wander(p)
			_crime(p)
			_rob(p)
		"follower":
			var boss := _boss(p)
			if boss != null and boss.travel_left == 0 and boss.location != p.location:
				_go(p, boss.location)
			_rob(p)
		"hunter":
			_hunt(p)
		"duelist":
			_wander(p)
			_crime(p)
			_duel(p)
		_:
			if p.location != MapData.HOME and p.role in ["youth", "master", "settled"]:
				_go(p, MapData.HOME)


func _set_target(p: Person, id: String) -> void:
	p.target = id
	if id == hero_id:
		_tell(NewsData.HUNT_YOU.replace("{p:who}", "{p:%s}" % p.id), "bad")


## 去找要找的人。到了同一個地方就打（找的是你的話，等 Town 開戰鬥）
func _chase(p: Person) -> void:
	var t: Person = people.get(p.target)
	if t == null or t.dead:
		p.target = ""
		p.rest_left = rng.randi_range(REST_AFTER[0], REST_AFTER[1])
		return
	if t.travel_left > 0:
		return
	if t.location != p.location:
		if t.id == hero_id and p.rest_left <= 0:
			var text := NewsData.HUNT.replace("{p:who}", "{p:%s}" % p.id).replace("{item}", _look_short(p.weapon))
			_tell(text.replace("{place}", MapData.place_name(t.location)), "bad")
		_go(p, t.location)
		return
	if t.id == hero_id:
		return
	if p.rest_left > 0:
		return
	fight(p, t)


## 有懸賞的人、決鬥家：在幾個地方之間走
func _wander(p: Person) -> void:
	p.stay_left -= 1
	if p.stay_left > 0 or p.haunts.size() < 2:
		return
	var choices := p.haunts.filter(func(h): return h != p.location)
	_go(p, choices[rng.randi_range(0, choices.size() - 1)])
	p.stay_left = rng.randi_range(4, 10)


func _crime(p: Person) -> void:
	if not bounties.has(p.id) or rng.randf() >= CRIME_CHANCE:
		return
	var lines: Array = PeopleData.PEOPLE.get(p.id, {}).get("crimes", [])
	if lines.is_empty():
		return
	bounties[p.id]["reward"] += CRIME_RAISE
	_tell(_pick(lines).replace("{place}", MapData.place_name(p.location)))


## 搶路過、比自己弱的人（不搶自己人、師傅）
func _rob(p: Person) -> void:
	if rng.randf() >= ROB_CHANCE:
		return
	var prey := []
	for o in at(p.location):
		if o != p and not p.relations.has(o.id) and not o.role in ["master", "follower", "villain"] and not bounties.has(o.id) \
				and o.power() < p.power() - 1.0:
			prey.append(o)
	if prey.is_empty():
		return
	fight(p, prey[rng.randi_range(0, prey.size() - 1)])


func _boss(p: Person) -> Person:
	var b: Person = people.get(p.follows)
	return b if b != null and not b.dead else null


## 冒險者：歇夠了就挑一張打得過的懸賞去接。有很強的家人護著的不接
func _hunt(p: Person) -> void:
	if p.rest_left > 0:
		if p.location != MapData.HOME:
			_go(p, MapData.HOME)
		return
	var best := ""
	var best_reward := 0
	for id in bounties:
		var t: Person = people.get(id)
		if t == null or t.dead or t == p or p.relations.has(id):
			continue
		if t.power() > p.power() + p.boldness:
			continue
		var guard := protector_of(id)
		if guard != null and guard != p and guard.power() > p.power() + 1.0:
			continue
		if bounties[id]["reward"] > best_reward:
			best = id
			best_reward = bounties[id]["reward"]
	if best == "":
		p.rest_left = rng.randi_range(3, 8)
		return
	p.target = best
	if not bounties[best]["takers"].has(p.id):
		bounties[best]["takers"].append(p.id)
		_tell(NewsData.BOUNTY_TAKEN.replace("{p:hunter}", "{p:%s}" % p.id).replace("{p:target}", "{p:%s}" % best))


## 決鬥家：隔一陣子找一個差不多強的人決鬥（可能是你）
func _duel(p: Person) -> void:
	if p.rest_left > 0:
		return
	var list := []
	for o in people.values():
		var gap: float = o.power() - p.power()
		if not o.dead and o != p and not p.relations.has(o.id) and not o.role in ["master", "youth"] and gap >= DUEL_RANGE[0] and gap <= DUEL_RANGE[1]:
			list.append(o)
	if list.is_empty():
		p.rest_left = rng.randi_range(3, 6)
		return
	var o: Person = list[rng.randi_range(0, list.size() - 1)]
	p.target = o.id
	if o.id != hero_id:
		_tell(NewsData.DUEL[0].replace("{p:a}", "{p:%s}" % p.id).replace("{p:b}", "{p:%s}" % o.id).replace("{place}", MapData.place_name(o.location)))


func _go(p: Person, place: String) -> void:
	if place == p.location:
		return
	p.travel_to = place
	p.travel_left = MapData.distance(p.location, place)


# ---------- 打 ----------

## 這一架輸的人會不會死：有懸賞的、有仇的、決鬥。其他（搶東西）只是被打傷
func lethal(a: Person, b: Person) -> bool:
	return bounties.has(b.id) or bounties.has(a.id) and b.target == a.id or a.grudges.has(b.id) or b.grudges.has(a.id) \
		or a.role == "duelist" and a.target == b.id or b.role == "duelist" and b.target == a.id


## 世界上的兩個人打一架（a 找上 b）。不含玩家角色（玩家角色的架由 Town 開戰鬥，打完呼叫 settle）
func fight(a: Person, b: Person) -> void:
	var a_wins := rng.randf() < GrowthData.win_chance(a.power(), b.power())
	var w := a if a_wins else b
	var l := b if a_wins else a
	settle(w, l, lethal(a, b), rng.randf() < NAMED_CHANCE)


## 打完：輸的人死掉或被打傷，贏的人拿走他身上的東西。told = 傳聞說得出是誰
func settle(w: Person, l: Person, kill: bool, told := true) -> Array:
	if w.id == hero_id or l.id == hero_id:
		told = true
	var place := MapData.place_name(l.location)
	var taken: Array = []
	if l.id != hero_id:
		taken = _take(w, l, kill) if w.id != hero_id else []
	elif w.id != hero_id:
		taken = _take_from_hero(w, l)
	w.grudges.erase(l.id)
	if w.target == l.id:
		w.target = ""
	w.rest_left = rng.randi_range(REST_AFTER[0], REST_AFTER[1])
	if w.role == "hunter" and kill:
		w.rest_left = rng.randi_range(HUNT_REST[0], HUNT_REST[1])
	if w.role == "duelist":
		w.rest_left = rng.randi_range(DUEL_EVERY[0], DUEL_EVERY[1])
	# 打贏比自己強的人，長一點（世界上的人）
	if w.id != hero_id and l.power() > w.power():
		var s: String = GrowthData.STATS[rng.randi_range(0, 1)]
		w.stats[s] += 1
		w.realm = maxi(w.realm, GrowthData.realm_of_stats(w.stats))
	if w.id != hero_id:
		w.hp = maxi(1, w.hp - roundi(w.max_hp() * rng.randf_range(0.2, 0.6)))
	if kill and l.id != hero_id:
		var text: String = _pick(NewsData.KILL if told else NewsData.KILL_ANON)
		_tell(text.replace("{p:killer}", "{p:%s}" % w.id).replace("{p:victim}", "{p:%s}" % l.id).replace("{place}", place),
			"big" if w.id == hero_id or l.relations.has(hero_id) else "info")
		w.note("在%s殺了{p:%s}" % [place, l.id], told)
		if told:
			l.note("在%s被{p:%s}殺了" % [place, w.id])
		_kill(l, w)
	else:
		if l.id != hero_id:
			l.hp = maxi(1, roundi(l.max_hp() * ROBBED_HP))
			if not l.grudges.has(w.id):
				l.grudges.append(w.id)
			l.target = ""
			l.rest_left = rng.randi_range(REST_AFTER[0], REST_AFTER[1])
		if w.id != hero_id and l.id != hero_id:
			var t: String = _pick(NewsData.ROB if told else NewsData.ROB_ANON)
			_tell(t.replace("{p:winner}", "{p:%s}" % w.id).replace("{p:loser}", "{p:%s}" % l.id).replace("{place}", place))
		w.note("在%s打傷了{p:%s}" % [place, l.id], told)
		l.note("在%s被{p:%s}打傷" % [place, w.id], told)
	return taken


## 世界上的人贏了：拿走稀有的武器、秘笈，和比自己的好的同類武器。死了的人剩下的東西就沒了
func _take(w: Person, l: Person, kill: bool) -> Array:
	var taken: Array = []
	for it in l.items():
		var take := BookData.is_book(it) or WeaponData.is_rare(it)
		if not take and it != l.weapon:
			continue
		if not take:
			take = WeaponData.get_def(it)["power"] > WeaponData.get_def(w.weapon)["power"] and w.can_wield(it) \
				and EnemyData.ENEMIES[w.style].get("kinds", []).has(WeaponData.get_def(it)["kind"])
		if take:
			taken.append(it)
	for it in taken:
		l.remove_item(it)
		w.give_item(it)
		if BookData.is_book(it):
			w.learn(BookData.get_def(it)["move"])
	w.weapon = w.best_weapon()
	return taken


## 世界上的人打贏你：拿走你身上最值錢的一樣（稀有的武器 > 還沒讀的秘笈 > 比他好的武器）。最後一把武器不拿
func _take_from_hero(w: Person, h: Person) -> Array:
	var pick := ""
	for it in h.owned_weapons:
		if WeaponData.is_rare(it) and h.owned_weapons.size() > 1:
			if pick == "" or WeaponData.get_def(it)["power"] > WeaponData.get_def(pick)["power"]:
				pick = it
	if pick == "":
		for b in h.books:
			if not h.knows(BookData.get_def(b)["move"]):
				pick = b
				break
	if pick == "" and h.owned_weapons.size() > 1:
		var best := h.weapon
		if WeaponData.get_def(best)["power"] > WeaponData.get_def(w.weapon)["power"]:
			pick = best
	if pick == "":
		return []
	h.remove_item(pick)
	w.give_item(pick)
	if BookData.is_book(pick):
		w.learn(BookData.get_def(pick)["move"])
	w.weapon = w.best_weapon()
	return [pick]


## 死了：懸賞撕掉；家人、師徒、手下記仇；手下接手老大的人
func _kill(l: Person, killer: Person) -> void:
	l.dead = true
	l.died_at = month()
	l.travel_left = 0
	if bounties.has(l.id):
		bounties.erase(l.id)
		_tell(NewsData.BOUNTY_GONE.replace("{p:who}", "{p:%s}" % l.id))
	for r in l.relations:
		var p: Person = people.get(r)
		if p == null or p.dead or p == killer or not l.relations[r] in AVENGER_RELATIONS:
			continue
		if killer != null and not p.grudges.has(killer.id) and p.id != hero_id:
			p.grudges.append(killer.id)
			p.note("{p:%s}死了" % l.id)
			_tell(NewsData.GRIEF.replace("{p:who}", "{p:%s}" % p.id).replace("{p:victim}", "{p:%s}" % l.id), "info")
	_takeover(l)


## 老大死了，手下接手（有懸賞的老大，手下也被懸賞）
func _takeover(l: Person) -> void:
	for p in others():
		if p.follows != l.id or p.role != "follower":
			continue
		p.role = "villain"
		p.haunts = l.haunts.duplicate()
		if l.title != "" and p.title.ends_with("副隊長"):
			p.title = l.title
		if PeopleData.PEOPLE.get(l.id, {}).has("bounty") and not bounties.has(p.id):
			var reward: int = PeopleData.PEOPLE[l.id]["bounty"]["reward"] / 2
			var text := fmt(NewsData.TAKEOVER_BOUNTY.replace("{p:boss}", "{p:%s}" % l.id).replace("{p:who}", "{p:%s}" % p.id))
			bounties[p.id] = {"reward": reward, "text": text, "takers": []}
		_tell(NewsData.TAKEOVER.replace("{p:boss}", "{p:%s}" % l.id).replace("{p:who}", "{p:%s}" % p.id))
		break


## 老死、病死：東西給孩子或徒弟，沒有就跟著下葬
func _die(p: Person) -> void:
	_tell(_pick(NewsData.DIED).replace("{p:who}", "{p:%s}" % p.id), "big" if p.relations.has(hero_id) else "info")
	var heir: Person = null
	for r in p.relations:
		var o: Person = people.get(r)
		if o != null and not o.dead and o.id != hero_id and p.relations[r] in ["child", "disciple", "follower"]:
			heir = o
			break
	var valuable := p.items().filter(func(it): return BookData.is_book(it) or WeaponData.is_rare(it))
	if not valuable.is_empty():
		if heir != null:
			for it in valuable:
				p.remove_item(it)
				heir.give_item(it)
			heir.weapon = heir.best_weapon()
			_tell(NewsData.INHERIT.replace("{p:who}", "{p:%s}" % p.id).replace("{p:heir}", "{p:%s}" % heir.id))
		else:
			_tell(NewsData.BURIED.replace("{p:who}", "{p:%s}" % p.id))
			for it in valuable:
				p.remove_item(it)
	p.dead = true
	p.died_at = month()
	if bounties.has(p.id):
		bounties.erase(p.id)
		_tell(NewsData.BOUNTY_GONE.replace("{p:who}", "{p:%s}" % p.id))
	_takeover(p)


# ---------- 跟你有關的 ----------

## 你接下懸賞。他有家人、老大護著的話，過一陣子會傳話給你
func accept_bounty(id: String) -> void:
	if not bounties.has(id) or bounties[id]["takers"].has(hero_id):
		return
	bounties[id]["takers"].append(hero_id)
	var guard := protector_of(id)
	if guard != null and not warned.has(id):
		warned.append(id)
		var text: String = PeopleData.PEOPLE.get(guard.id, {}).get("warn", NewsData.WARN)
		_mail.append(text.replace("{p:who}", "{p:%s}" % guard.id).replace("{p:target}", "{p:%s}" % id))


## 你打贏一個人：settle 之後，輸的人死了就記仇；沒死的人身上剩下的東西還是他的
func hero_won(l: Person, kill: bool) -> void:
	settle(hero(), l, kill, true)


## 你打輸了（被救回來）：他拿走你身上的一樣東西，這筆帳算清了
func hero_lost(w: Person) -> Array:
	var taken := settle(w, hero(), false, true)
	w.grudges.erase(hero_id)
	w.target = ""
	return taken


## 你逃了：他歇一陣子再來
func hero_fled(p: Person) -> void:
	p.rest_left = rng.randi_range(REST_AFTER[0], REST_AFTER[1])


## 換人接著玩：上一個人死了，東西交給接手的人，仇人也記到他頭上
func pass_on(heir_id: String) -> void:
	var old := hero()
	var heir: Person = people[heir_id]
	old.dead = true
	old.died_at = month()
	lives.append(old.id)
	for it in old.items():
		heir.give_item(it)
	heir.money += maxi(0, old.money)
	heir.role = ""
	heir.jobs.clear()
	heir.school_jobs.clear()
	heir.target = ""
	heir.grudges.clear()
	heir.vow = {}
	heir.weapon = heir.best_weapon()
	heir.relations[old.id] = "master"
	old.relations[heir.id] = "disciple"
	heir.location = MapData.HOME
	heir.travel_left = 0
	heir.hp = heir.max_hp()
	for p in others():
		if p == heir:
			continue
		if p.grudges.has(old.id):
			p.grudges.erase(old.id)
			if not p.grudges.has(heir.id):
				p.grudges.append(heir.id)
			_mail.append(NewsData.GRUDGE_PASSED.replace("{p:who}", "{p:%s}" % p.id).replace("{p:old}", "{p:%s}" % old.id).replace("{p:heir}", "{p:%s}" % heir.id))
		if p.target == old.id:
			p.target = ""
	for b in bounties:
		bounties[b]["takers"].erase(old.id)
	hero_id = heir_id
	_mail.append(_pick(NewsData.REMEMBER).replace("{p:who}", "{p:%s}" % old.id))


## 可以接手的人：活著、跟你沒仇、沒有懸賞、不是師傅、不太老。不夠就找剛到城裡的年輕人
const HEIR_MAX_AGE := 30
const HEIR_MIN := 3


func heir_candidates() -> Array:
	var list := []
	for p in others():
		if p.age() <= HEIR_MAX_AGE and not bounties.has(p.id) and not p.grudges.has(hero_id) and p.role in ["youth", "hunter", "settled"]:
			list.append(p)
	while list.size() < HEIR_MIN:
		list.append(newcomer())
	return list


# ---------- 小工具 ----------

func _tell(text: String, kind := "news") -> void:
	news.append({"month": month(), "text": fmt(text), "kind": kind})


func _pick(list: Array) -> String:
	return list[rng.randi_range(0, list.size() - 1)]


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = list[i]
		list[i] = list[j]
		list[j] = t


## 武器、秘笈的樣子（短的，去掉句號）
func _look_short(item: String) -> String:
	var look: String = WeaponData.get_def(item).get("look", WeaponData.get_def(item)["name"])
	return look.trim_suffix("。").split("，")[0]
