extends SceneTree

## 整輪模擬（開發用）：電腦玩家在活的世界裡過一輩子，看好東西（稀有武器、秘笈）幾歲拿到、
## 有多少被世界上的人先拿走、最後落在誰手上。
## 策略很簡單：傷了就回城休養、能學就學、能讀就讀、能考就考、買得起更好的劍就買、換上最好的武器；
## 挑「打得過的」懸賞（看 Person.power，比自己強不超過一點）去接、走過去找人打；沒有就打委託的怪物練身體。
## 有人找上門就打。戰鬥是自動的（AutoPilot）。
## 真人大約比電腦玩家快一倍（2026-10-06 試玩），電腦拿到的只當下限參考。
## 執行：Godot --headless --path . --script res://tests/career.gd -- [幾輪] [印第一輪的過程 1/0]

const PRIZES := ["red_fang", "knell", "gatebreaker", "nightwatch", "sunder_book", "falcon_book", "bastion_book"]
## 怪物由弱到強
const LADDER := ["wolf", "bandit_leader", "deserter", "bear", "ogre"]

var verbose := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 20
	verbose = args.size() > 1 and args[1] == "1"
	var got_ages := {}
	var counts := []
	var lost := {}
	var deaths := []
	for run in runs:
		var r := _career(run)
		counts.append(r["got"].size())
		deaths.append(r["age"])
		for k in r["got"]:
			got_ages[k] = got_ages.get(k, []) + [r["got"][k]]
		for k in r["lost"]:
			lost[k] = lost.get(k, 0) + 1
	print("\n%d 輪。好東西幾歲拿到（中位數，幾輪拿到）、幾輪是別人先拿走或跟著下葬的：" % runs)
	for k in PRIZES:
		var v: Array = got_ages.get(k, [])
		v.sort()
		var name := _name(k)
		if v.is_empty():
			print("　%s：沒有一輪拿到，%d 輪被別人拿走／下葬" % [name, lost.get(k, 0)])
		else:
			print("　%s：%d 歲（%d/%d 輪），%d 輪被別人拿走／下葬" % [name, v[v.size() / 2], v.size(), runs, lost.get(k, 0)])
	counts.sort()
	deaths.sort()
	print("一輩子拿到幾樣：最少 %d、中位數 %d、最多 %d（死在 %d～%d 歲）" % [counts[0], counts[counts.size() / 2], counts[-1], deaths[0], deaths[-1]])
	quit()


func _career(run: int) -> Dictionary:
	var town := Town.new(run + 1)
	var w := town.world
	var h := town.hero
	var pilot := AutoPilot.new()
	pilot.retreat_at = 0.2  # 代替玩家按撤退
	var rng := RandomNumberGenerator.new()
	rng.seed = run * 7919
	var got := {}
	var lost := {}
	var fails := {}  # 對手 id -> 在目前實力下輸了幾次
	var spar_tries := 0
	var guard := 0
	while not h.dying() and guard < 2000:
		guard += 1
		# 有人找上門
		var comer := town.comer()
		if comer != null:
			_fight(town, pilot, rng, func(): return town.start_person(comer.id), "person", got, h)
			continue
		# 傷了就回城休養
		if h.hp < h.max_hp() * 0.6:
			if not town.in_city():
				town.travel(MapData.HOME)
			else:
				town.rest(town.months_to_full())
			continue
		# 城裡有事可做（學得起的招、能讀的秘笈、能考的考驗）就回城
		if not town.in_city() and _city_wanted(town):
			town.travel(MapData.HOME)
			continue
		if town.in_city() and _city_chores(town, pilot, rng, spar_tries):
			spar_tries += 1 if h.approved_tier < 2 and town.spar_state()["ok"] else 0
			continue
		# 挑懸賞：打得過的（看粗略的強弱），在目前實力下輸了兩次的先不去
		# 會的招多，比粗略的強弱估得強一點
		var me := h.power() + 0.25 * h.learned.size()
		var target := ""
		for id in w.bounties:
			var p := w.person(id)
			if p.power() <= me + 0.5 and fails.get(id, 0) < 2 and (target == "" or p.power() > w.person(target).power()):
				target = id
		if target != "":
			if not town.took_bounty(target):
				if not town.in_city():
					town.travel(MapData.HOME)
					continue
				town.accept_bounty(target)
			var p := w.person(target)
			if p.travel_left > 0:
				town.rest(1) if town.in_city() and h.hp < h.max_hp() else town._pass_months(1)
				continue
			if p.location != h.location:
				town.travel(p.location)
				continue
			var r := _fight(town, pilot, rng, func(): return town.start_person(target), "person", got, h)
			if r != "win":
				fails[target] = fails.get(target, 0) + 1
			continue
		# 沒有打得過的懸賞：打委託的怪物練身體（還沒打贏過的最弱的；都打贏過就打打得贏的最強的）
		# 缺錢學招的時候先打打贏過的賺錢；不然打還沒打贏過的最弱的；都不行就打打贏過的最強的
		var poor := h.money < 80 and h.learned.size() < 3
		var beaten := LADDER.filter(func(id): return w.monster_open(id) and h.beaten.has(id))
		var fresh := LADDER.filter(func(id): return w.monster_open(id) and not h.beaten.has(id) and fails.get(id, 0) < 2)
		var mon := ""
		if poor and not beaten.is_empty():
			mon = beaten[-1]
		elif not fresh.is_empty():
			mon = fresh[0]
		elif not beaten.is_empty():
			mon = beaten[-1]
		if mon == "":
			fails.clear()
			town._pass_months(1)
			continue
		var place: String = TownData.COMMISSIONS[mon]["place"]
		if h.location != place:
			town.travel(place)
			continue
		var r2 := _fight(town, pilot, rng, func(): return town.start_monster(mon), "monster", got, h)
		if r2 != "win":
			fails[mon] = fails.get(mon, 0) + 1
		else:
			fails.clear()
	# 好東西最後在誰手上
	var where := {}
	for p in w.people.values():
		for it in p.items():
			where[it] = p
	for k in PRIZES:
		if not got.has(k):
			var holder: Person = where.get(k)
			if holder == null or holder.dead or holder.id != w.hero_id:
				lost[k] = true
	if verbose:
		print("—— 第 %d 輪：%s 死在 %d 歲。拿到：%s" % [run, h.display_name, h.age_at(h.dies_at), "、".join(got.keys().map(func(k): return "%s(%d)" % [_name(k), got[k]]))])
		for k in PRIZES:
			var holder: Person = where.get(k)
			print("　　%s：%s" % [_name(k), "沒了（下葬）" if holder == null else ("你" if holder.id == w.hero_id else holder.display_name + ("（死了）" if holder.dead else ""))])
	return {"got": got, "lost": lost, "age": h.age_at(h.dies_at)}


## 不在城裡時，城裡有沒有事可做（只看「要在城裡」以外的條件）
func _city_wanted(town: Town) -> bool:
	for t in SchoolData.TIERS:
		for id in t["moves"]:
			var st := town.move_state(id)
			if not st["learned"] and st["why"] == ["要在城裡"]:
				return true
	for id in town.hero.books:
		if town.book_state(id)["why"] == "要在城裡":
			return true
	return false


## 城裡的事：學招、讀秘笈、考驗、買劍、換劍。做了一件就回傳 true
func _city_chores(town: Town, pilot: AutoPilot, rng: RandomNumberGenerator, spar_tries: int) -> bool:
	var h := town.hero
	for t in SchoolData.TIERS:
		for id in t["moves"]:
			if town.move_state(id)["ok"]:
				town.learn_move(id)
				return true
	for id in h.books:
		if town.book_state(id)["ok"]:
			town.read_book(id)
			return true
	var best_w := h.weapon
	for wid in h.owned_weapons:
		if h.can_wield(wid) and WeaponData.get_def(wid)["power"] > WeaponData.get_def(best_w)["power"]:
			best_w = wid
	if best_w != h.weapon:
		town.equip(best_w)
	for wid in WeaponData.SHOP:
		if WeaponData.get_def(wid)["power"] > WeaponData.get_def(h.weapon)["power"] and town.weapon_state(wid)["ok"]:
			town.buy_weapon(wid)
			return true
	if town.spar_state()["ok"] and h.learned.size() >= 2 and spar_tries < 3:
		var sb := town.start_spar()
		sb.rng.seed = rng.randi()
		pilot.play(sb)
		town.finish_spar(sb)
		return true
	return false


## 打一場、拿光戰利品、結算。回傳勝負
func _fight(town: Town, pilot: AutoPilot, rng: RandomNumberGenerator, start: Callable, kind: String, got: Dictionary, h: Person) -> String:
	var b: Battle = start.call()
	b.rng.seed = rng.randi()
	var r := pilot.play(b)
	if kind == "person":
		town.finish_person(b)
	else:
		town.finish_monster(b)
	for id in town.loot.duplicate():
		town.take_loot(id)
		if PRIZES.has(id) and not got.has(id):
			got[id] = h.age()
	town.clear_loot()
	town.after_fight()
	if verbose:
		print("%s %-6s %-4s 血%3d/%3d 錢%5d 力%d 敏%d %s %s" % [h.date_text(), town.world.who(b.enemies[0].person.id) if b.enemies[0].person != null else b.enemies[0].display_name,
			r["outcome"], h.hp, h.max_hp(), h.money, h.body("str"), h.body("agi"), h.realm_text(), WeaponData.get_def(h.weapon)["name"]])
	return r["outcome"]


func _name(id: String) -> String:
	return BookData.get_def(id)["name"] if BookData.is_book(id) else WeaponData.get_def(id)["name"]
