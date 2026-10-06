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
## 同一個人的壞事，傳聞至少隔幾個月才再傳一次
const CRIME_NEWS_GAP := 18
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
## 拼命的架，輸的人死的機率（見 _death_chance）
const DEATH_WANTED := 0.85
const DEATH_GRUDGE := 0.6
const DEATH_OTHER := 0.3
## 名聲：打贏一個人加多少（基本 + 對手名聲的幾成）、輸的人掉幾成、每個月淡掉多少
const FAME_WIN := 3.0
const FAME_TAKE := 0.25
const FAME_LOSS := 0.2
const FAME_FADE := 0.998
## 世界上的人自己的人生：每個月的機率
const RETIRE_AGE := 46
const RETIRE_CHANCE := 0.02
const MARRY_CHANCE := 0.006
const CHILD_CHANCE := 0.012
const CHILDREN_MAX := 3
const DISCIPLE_CHANCE := 0.03
const PROMOTE_CHANCE := 0.012
## 孩子幾歲進城（之前不出現在世界上）
const CHILD_ARRIVE_AGE := 14
## 世界上的人少於這個數，外地的人會慢慢來
const POP_MIN := 18
const NEWCOMER_CHANCE := 0.15
## 強者榜列幾個人
const RANKING_SIZE := 12

var clock := Clock.new()
## id -> Person（死了的也留著，世界記得）
var people := {}
var hero_id := ""
## 有懸賞的人 id -> {"reward", "text", "takers": [接下的人]}
var bounties := {}
## 委託板上的怪物 id -> {"count": 打過幾次, "back": 世界的第幾個月再出現}
var monsters := {}
## 武器店收來的東西（世界上的人用不到的稀有武器、秘笈）。你買得到
var shop_stock: Array = []
## 每個人的壞事上次傳到你耳裡是第幾個月
var _crime_told := {}
## 還沒長大的孩子：[{"due": 進城的月, "parents": [id, id], "name", "pron", "born": 生在哪一年}]
var _children: Array = []
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
const RELATION_NAMES := {"parent": "父母", "child": "孩子", "master": "師傅", "disciple": "徒弟",
	"sibling": "兄弟", "boss": "老大", "follower": "手下", "spouse": "伴侶"}
const RELATION_BACK := {"parent": "child", "child": "parent", "master": "disciple", "disciple": "master",
	"sibling": "sibling", "boss": "follower", "follower": "boss", "spouse": "spouse"}
## 死了會有人替他報仇、動他之前會先傳話的關係
const AVENGER_RELATIONS := ["parent", "child", "master", "disciple", "sibling", "boss", "follower", "spouse"]
const PROTECTOR_RELATIONS := ["parent", "sibling", "boss", "master", "spouse"]


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


## 委託的怪物在哪出沒
func monster_place(enemy_id: String) -> String:
	return TownData.COMMISSIONS[enemy_id]["place"]


## 你聽說誰在哪（傳聞提到他、或你親眼看到）
func hear(id: String, place := "") -> void:
	if id == hero_id or not people.has(id) or not people.has(hero_id):
		return
	var p: Person = people[id]
	hero().heard[id] = {"place": place if place != "" else (p.travel_to if p.travel_left > 0 else p.location), "month": month()}


## 你所在的地方的人，你都看得到
func look_around() -> void:
	if not people.has(hero_id) or hero().travel_left > 0:
		return
	for p in at(hero().location):
		hear(p.id)


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
	h.uses_slots = true
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
	p.fame = d.get("fame", p.power() * (0.5 if p.role == "youth" else 1.0))
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
			_sell_off(p)
			_life(p)
		# 名聲慢慢淡掉（很久沒消息的人，名字就沒人提了）
		p.fame *= FAME_FADE
	_births()
	_replenish()
	if LifeData.month_of_year(month()) == SchoolData.SELECTION_MONTHS[-1]:
		_spring()
	look_around()
	# 你花錢打聽的人：消息還沒斷，就知道他在哪
	if people.has(hero_id):
		for id in hero().inquired:
			if hero().inquired[id] >= month():
				hear(id)


## 春天：劍庭選拔新學徒（城裡夠結實的年輕人），劍庭的人各自往上學一招
func _spring() -> void:
	for p in others():
		if p.school == "" and not p.expelled and p.role == "youth" and p.location == MapData.HOME and p.travel_left == 0 \
				and maxi(p.body("str"), p.body("agi")) >= SchoolData.JOIN_BODY and p.selection_year != LifeData.year_of(month()) \
				and rng.randf() < SchoolData.NPC_PASS:
			join_school(p)
		elif p.school == SchoolData.ID and p.rank > 0 and rng.randf() < SchoolData.NPC_LEARN:
			for id in SchoolData.chain():
				if not p.knows(id) and SchoolData.MOVES.has(id) and SchoolData.MOVES[id]["rank"] <= p.rank:
					p.learn(id)
					break


## 通過選拔，成了劍庭的學徒
func join_school(p: Person) -> void:
	p.school = SchoolData.ID
	p.rank = 1
	p.note("通過獅心劍庭的選拔")
	_tell(NewsData.JOINED.replace("{p:who}", "{p:%s}" % p.id))

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
	# 同一個人的壞事，傳聞隔一陣子才再傳一次（不然同一句一直出現）
	if month() - _crime_told.get(p.id, -999) < CRIME_NEWS_GAP:
		return
	_crime_told[p.id] = month()
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


# ---------- 不是打架的人生 ----------

## 一個月裡，世界上的人自己的事：退隱、成親、收徒、在流派升階
func _life(p: Person) -> void:
	var age := p.age()
	if p.role in ["hunter", "duelist", "settled"] and age >= RETIRE_AGE and p.target == "" and rng.randf() < RETIRE_CHANCE:
		p.role = "retired"
		_go(p, MapData.HOME)
		p.note("退隱")
		_tell(NewsData.RETIRED.replace("{p:who}", "{p:%s}" % p.id))
		return
	if p.role != "villain" and p.role != "follower" and age >= 20 and age <= 40 and _spouse(p) == null and rng.randf() < MARRY_CHANCE:
		for o in at(p.location):
			if o != p and o.pron != p.pron and o.age() >= 20 and o.age() <= 42 and _spouse(o) == null \
					and not p.relations.has(o.id) and not o.role in ["villain", "follower"] and not p.grudges.has(o.id):
				p.relations[o.id] = "spouse"
				o.relations[p.id] = "spouse"
				p.note("跟{p:%s}成親" % o.id)
				o.note("跟{p:%s}成親" % p.id)
				_tell(NewsData.MARRIED.replace("{p:a}", "{p:%s}" % p.id).replace("{p:b}", "{p:%s}" % o.id))
				break
	var s := _spouse(p)
	if s != null and p.pron == "她" and age <= 40 and _kids(p) < CHILDREN_MAX and rng.randf() < CHILD_CHANCE:
		_have_child(p, s)
	if p.realm >= 2 and age >= 28 and not p.role in ["villain", "follower", "youth"] and _disciple(p) == null and rng.randf() < DISCIPLE_CHANCE:
		for o in at(p.location):
			if o.role == "youth" and not o.relations.values().has("master") and not p.relations.has(o.id):
				p.relations[o.id] = "disciple"
				o.relations[p.id] = "master"
				o.growth += 0.3
				var teach := p.learned.filter(func(m): return not o.knows(m))
				if not teach.is_empty():
					o.learn(teach[rng.randi_range(0, teach.size() - 1)])
				o.note("拜{p:%s}為師" % p.id)
				_tell(NewsData.DISCIPLE.replace("{p:master}", "{p:%s}" % p.id).replace("{p:disciple}", "{p:%s}" % o.id))
				break
	# 劍庭的人照實力慢慢升階
	if p.school == SchoolData.ID and p.rank > 0 and p.rank < 3 and p.realm >= p.rank + 1 and rng.randf() < PROMOTE_CHANCE:
		p.rank += 1
		p.note("升為%s" % SchoolData.RANKS[p.rank])
		_tell(NewsData.PROMOTED.replace("{p:who}", "{p:%s}" % p.id).replace("{rank}", SchoolData.RANKS[p.rank]))


func _spouse(p: Person) -> Person:
	for id in p.relations:
		if p.relations[id] == "spouse":
			var o: Person = people.get(id)
			if o != null and not o.dead:
				return o
	return null


func _disciple(p: Person) -> Person:
	for id in p.relations:
		if p.relations[id] == "disciple":
			var o: Person = people.get(id)
			if o != null and not o.dead:
				return o
	return null


func _kids(p: Person) -> int:
	var n := p.relations.values().count("child")
	for c in _children:
		if c["parents"].has(p.id):
			n += 1
	return n


## 生了孩子：孩子長到 CHILD_ARRIVE_AGE 歲才進城（世界上才有這個人）
func _have_child(mother: Person, father: Person) -> void:
	var pick := _fresh_name(PeopleData.CHILD_NAMES)
	_children.append({"due": month() + CHILD_ARRIVE_AGE * 12, "parents": [mother.id, father.id], "name": pick[0], "pron": pick[1],
		"born": LifeData.year_of(month())})
	mother.note("生了孩子")
	father.note("生了孩子")
	_tell(NewsData.BORN.replace("{p:who}", "{p:%s}" % father.id))


## 孩子長大了，進城
func _births() -> void:
	for c in _children.duplicate():
		if c["due"] > month():
			continue
		_children.erase(c)
		var p := _new_person(c["name"], c["pron"], "master", "youth", c["born"])
		p.stats = {"str": 9, "agi": 9}
		p.potential = {"str": rng.randi_range(16, 23), "agi": rng.randi_range(16, 23)}
		p.growth = 1.3
		var parent: Person = null
		for pid in c["parents"]:
			var par: Person = people.get(pid)
			if par == null:
				continue
			p.relations[pid] = "parent"
			par.relations[p.id] = "child"
			if parent == null or par.dead == false:
				parent = par
		p.hp = p.max_hp()
		if parent != null:
			_tell(NewsData.GROWN_UP.replace("{p:parent}", "{p:%s}" % parent.id).replace("{p:who}", "{p:%s}" % p.id))


## 人少了，外地的人慢慢來（接懸賞的冒險者、找地方落腳的劍士）
func _replenish() -> void:
	if others().size() >= POP_MIN or rng.randf() >= NEWCOMER_CHANCE:
		return
	var kinds := [["master", "steel_sword", "劍士"], ["raider", "hand_axe", "斧手"], ["duelist", "rapier", "劍客"]]
	var k: Array = kinds[rng.randi_range(0, kinds.size() - 1)]
	var pick := _fresh_name(PeopleData.NEWCOMER_NAMES)
	var age := rng.randi_range(19, 30)
	var p := _new_person(pick[0], pick[1], k[0], "hunter" if rng.randf() < 0.6 else "settled", LifeData.year_of(month()) - age)
	var base := rng.randi_range(12, 17)
	p.stats = {"str": base + rng.randi_range(-1, 1), "agi": base + rng.randi_range(-1, 1)}
	p.potential = {"str": p.stats["str"] + rng.randi_range(1, 4), "agi": p.stats["agi"] + rng.randi_range(1, 4)}
	p.growth = 0.5
	p.realm = GrowthData.realm_of_stats(p.stats)
	p.owned_weapons.clear()
	p.owned_weapons.append(k[1])
	p.weapon = k[1]
	var generic := ["knee", "fallstone", "shed", "dust", "deflect", "triple", "needle"].filter(func(m): return MoveData.usable(m, k[1]))
	generic.shuffle()
	for m in generic.slice(0, rng.randi_range(1, 3)):
		p.learn(m)
	p.boldness = rng.randf_range(0.0, 0.8)
	p.hp = p.max_hp()
	p.fame = p.power() * 0.6
	_tell(NewsData.NEWCOMER[rng.randi_range(0, NewsData.NEWCOMER.size() - 1)].replace("%s", k[2]).replace("{p:who}", "{p:%s}" % p.id))


## 挑一個還沒有人用過的名字（用完了就加上「小」）
func _fresh_name(names: Array) -> Array:
	var used := {}
	for p in people.values():
		used[p.display_name] = true
	for c in _children:
		used[c["name"]] = true
	var free := names.filter(func(n): return not used.has(n[0]))
	if free.is_empty():
		var n: Array = names[rng.randi_range(0, names.size() - 1)]
		return ["小" + n[0], n[1]]
	return free[rng.randi_range(0, free.size() - 1)]


## 一個不在 PeopleData 裡的新人（孩子、外地來的）
func _new_person(name: String, pron: String, style: String, role: String, born_year: int) -> Person:
	var p := Person.new()
	p.id = "p_%d_%d" % [month(), rng.randi_range(0, 999999)]
	p.clock = clock
	p.display_name = name
	p.pron = pron
	p.style = style
	p.role = role
	p.born_year = born_year
	p.dies_at = LifeData.roll_dies_at(rng, born_year, LifeData.LIFESPAN_MIN + 6, LifeData.LIFESPAN_MAX + 14, month())
	p.location = MapData.HOME
	people[p.id] = p
	return p


## 強者榜：最有名的幾個人（活著的，含你）
func ranking() -> Array:
	var list: Array = people.values().filter(func(p): return not p.dead and p.fame > 0.0)
	list.sort_custom(func(a, b): return a.fame > b.fame)
	return list.slice(0, RANKING_SIZE)


# ---------- 打 ----------

## 這一架輸的人會不會死：有懸賞的、有仇的才拼命。其他（搶東西、比劍）只是被打傷、認輸
func lethal(a: Person, b: Person) -> bool:
	return bounties.has(b.id) or bounties.has(a.id) and b.target == a.id or a.grudges.has(b.id) or b.grudges.has(a.id)


## 這一架是比劍（決鬥家找上門、沒有仇）：打到一方認輸，不拿東西
func is_duel(a: Person, b: Person) -> bool:
	return not lethal(a, b) and (a.role == "duelist" and a.target == b.id or b.role == "duelist" and b.target == a.id)


## 世界上的兩個人打一架（a 找上 b）。不含玩家角色（玩家角色的架由 Town 開戰鬥，打完呼叫 settle）
func fight(a: Person, b: Person) -> void:
	var a_wins := rng.randf() < GrowthData.win_chance(a.power(), b.power())
	var w := a if a_wins else b
	var l := b if a_wins else a
	if is_duel(a, b):
		_duel_done(w, l)
		return
	settle(w, l, lethal(a, b) and rng.randf() < _death_chance(w, l), rng.randf() < NAMED_CHANCE)


## 拼命的架，輸的人死的機率：懸賞的人被抓到多半沒命；去抓人反被打倒的，常常只是被打傷、搶光
func _death_chance(w: Person, l: Person) -> float:
	if bounties.has(l.id):
		return DEATH_WANTED
	if w.grudges.has(l.id):
		return DEATH_GRUDGE
	return DEATH_OTHER


## 比劍分出勝負：輸的人認輸，名聲換一點過去
func _duel_done(w: Person, l: Person) -> void:
	_gain_fame(w, l, 0.6)
	if w.target == l.id:
		w.target = ""
	if l.target == w.id:
		l.target = ""
	w.rest_left = rng.randi_range(DUEL_EVERY[0], DUEL_EVERY[1]) if w.role == "duelist" else rng.randi_range(REST_AFTER[0], REST_AFTER[1])
	l.rest_left = rng.randi_range(REST_AFTER[0], REST_AFTER[1])
	l.hp = maxi(1, roundi(l.max_hp() * 0.5))
	w.note("在%s跟{p:%s}比劍，贏了" % [MapData.place_name(w.location), l.id])
	l.note("在%s跟{p:%s}比劍，認輸了" % [MapData.place_name(w.location), w.id])
	_tell(NewsData.DUEL_WON.replace("{p:winner}", "{p:%s}" % w.id).replace("{p:loser}", "{p:%s}" % l.id).replace("{place}", MapData.place_name(w.location)))


## 打贏一個人：名聲照對手有多有名加（殺了他加多一點），輸的人掉一點
func _gain_fame(w: Person, l: Person, scale := 1.0) -> void:
	w.fame += (FAME_WIN + l.fame * FAME_TAKE) * scale
	l.fame *= 1.0 - FAME_LOSS * scale


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
	_gain_fame(w, l, 1.2 if kill else 1.0)
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


## 世界上的人贏了：拿走值錢的東西（稀有的武器、秘笈、比自己好的同類武器）。死了的人剩下的東西就沒了。
## 用得上的留著（秘笈裡的招拿著自己的武器用得出來就學），用不上的拿去霜溪城的武器店賣掉（你買得到）
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
	w.weapon = w.best_weapon()
	for it in w.items():
		if BookData.is_book(it):
			# 秘笈不賣（錢買不到秘笈）：湊得成、拿著的武器用得出來就學，不然帶在身上
			var move: String = BookData.get_def(it)["move"]
			if MoveData.usable(move, w.weapon) and BookData.complete(w.books, it):
				w.learn(move)
		elif it != w.weapon and WeaponData.is_rare(it) and not w.to_sell.has(it):
			w.to_sell.append(it)
	return taken


## 用不上的稀有武器：回到霜溪城才賣給武器店
func _sell_off(p: Person) -> void:
	if p.location != MapData.HOME or p.travel_left > 0:
		return
	for it in p.to_sell:
		if not p.has_item(it) or it == p.weapon:
			continue
		p.remove_item(it)
		if not shop_stock.has(it):
			shop_stock.append(it)
		_tell(NewsData.SOLD.replace("{p:who}", "{p:%s}" % p.id).replace("{item}", WeaponData.get_def(it)["name"]))
	p.to_sell.clear()


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
				# 殘頁不會憑空消失：落到同一個地方的別人手上（沒有人就隨便一個人）
				if BookData.is_book(it) and BookData.get_def(it).has("page_of"):
					_pass_page(p, it)
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


## 死人身上的殘頁落到別人手上
func _pass_page(dead: Person, it: String) -> void:
	var near := at(dead.location).filter(func(o): return o != dead)
	var pool: Array = near if not near.is_empty() else others().filter(func(o): return o != dead)
	if pool.is_empty():
		return
	var o: Person = pool[rng.randi_range(0, pool.size() - 1)]
	o.give_item(it)
	_tell(NewsData.PAGE_PASSED.replace("{p:who}", "{p:%s}" % dead.id).replace("{p:to}", "{p:%s}" % o.id))


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
	heir.claims.clear()
	# 接手的人也只能帶幾招：先帶他會的、照等級高的帶
	heir.uses_slots = true
	var moves := heir.learned.duplicate()
	moves.sort_custom(func(a, b): return MoveData.grade(a) > MoveData.grade(b))
	heir.equipped.assign(moves.slice(0, heir.slots()))
	heir.shield = heir.shield or old.shield
	heir.heard = old.heard.duplicate()
	heir.seen = old.seen.duplicate()
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
	# 傳聞提到的人、也說了在哪：你知道他大概在哪了
	var said := fmt(text)
	var i := text.find("{p:")
	while i >= 0:
		var j := text.find("}", i)
		var p: Person = people.get(text.substr(i + 3, j - i - 3))
		if p != null and said.contains(MapData.place_name(p.travel_to if p.travel_left > 0 else p.location)):
			hear(p.id)
		i = text.find("{p:", j)


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
