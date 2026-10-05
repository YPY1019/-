extends SceneTree

## 整輪模擬（開發用）：電腦玩家不會死（壽命拉到很長），一直玩到好東西全拿完（或打不動了），
## 看每樣好東西大約幾歲拿到，再估算「死在幾歲時，拿得到幾樣」。
## 策略很簡單：傷了就休養、能學就學、能讀就讀、能考就考、買得起更好的劍就買、換上最好的武器；
## 委託挑「還沒打贏過的最弱對手」，在目前實力下連輸兩次就回去打打得贏的。戰鬥是自動的（AutoPilot）。
## 真人大約比電腦玩家快一倍（2026-10-06 試玩：真人 22 歲 10 月打倒食人魔，電腦玩家約 30 歲），
## 所以也印出「照真人速度」的估算（月數減半）。
## 執行：Godot.exe --headless --path . --script res://tests/career.gd

const RUNS := 30
## 挑戰的順序（大約由弱到強）
const LADDER := ["wolf", "bandit_leader", "deserter", "bear", "merc_captain", "raider", "duelist",
	"black_knight", "ogre", "old_captain", "rebel_lord"]
## 好東西：打倒有名字的強者（拿到他身上的武器或秘笈）、讀完秘笈、打倒食人魔
const PRIZES := ["打贏羅德里克", "打贏烏爾夫", "打贏伊薇特", "打贏黑騎士", "打贏葛雷森", "打贏瓦倫",
	"打贏食人魔", "讀完北境裁決", "讀完隼之一刺", "讀完不落要塞"]
## 真人比電腦玩家快幾倍
const HUMAN_SPEED := 2.0
## 估算「死在幾歲」
const DEATH_AGES := [26, 28, 30, 32, 34, 36, 38, 40]


func _init() -> void:
	var all := []
	for run in RUNS:
		all.append(_career(run, run < 1))
	var when := {}
	for r in all:
		for k in r["when"]:
			when[k] = when.get(k, []) + [r["when"][k]]
	print("\n好東西大約幾歲拿到（中位數，幾輪拿到）：")
	for k in PRIZES:
		var v: Array = when.get(k, [])
		if v.is_empty():
			print("　%s：沒有一輪拿到" % k)
			continue
		v.sort()
		var med: int = v[v.size() / 2]
		print("　%s：電腦 %s，真人約 %s（%d/%d 輪）" % [k, LifeData.date_text(med), LifeData.date_text(int(med / HUMAN_SPEED)), v.size(), RUNS])
	print("\n死在幾歲時，拿得到幾樣（共 %d 樣，中位數）：" % PRIZES.size())
	for age in DEATH_AGES:
		var end: int = (age - LifeData.START_AGE) * 12 - (LifeData.START_MONTH - 1)
		var bot := []
		var human := []
		for r in all:
			bot.append(_count(r["when"], end))
			human.append(_count(r["when"], end * HUMAN_SPEED))
		bot.sort()
		human.sort()
		print("　%d 歲：電腦 %d 樣，真人約 %d 樣" % [age, bot[bot.size() / 2], human[human.size() / 2]])
	quit()


func _count(when: Dictionary, end: float) -> int:
	var n := 0
	for k in PRIZES:
		if when.has(k) and when[k] <= end:
			n += 1
	return n


func _career(run: int, verbose: bool) -> Dictionary:
	var town := Town.new()
	var h := town.hero
	h.life_months = 99999
	var pilot := AutoPilot.new()
	pilot.retreat_at = 0.2  # 代替玩家按撤退
	var fights := 0
	var lost_at := {}  # enemy -> 在目前實力下輸了幾次
	var spar_tries := 0
	var when := {}
	var power := _power_sig(h)
	var rng := RandomNumberGenerator.new()
	rng.seed = run * 7919
	while fights < 250 and h.month < 600 and not PRIZES.all(func(k): return when.has(k)):
		var sig := _power_sig(h)
		if sig != power:
			power = sig
			lost_at.clear()
			spar_tries = 0
		# 休養
		if h.hp < h.max_hp() * 0.6:
			town.rest(town.months_to_full())
			continue
		# 學招、讀秘笈
		var learned_any := false
		for t in SchoolData.TIERS:
			for id in t["moves"]:
				if town.move_state(id)["ok"]:
					town.learn_move(id)
					learned_any = true
		for id in h.books:
			if town.book_state(id)["ok"]:
				town.read_book(id)
				when["讀完" + BookData.get_def(id)["name"]] = h.month
				learned_any = true
		if learned_any:
			continue
		# 換上拿得動的最好的武器；店裡的比較好就買
		var best_w := h.weapon
		for w in h.owned_weapons:
			if h.can_wield(w) and WeaponData.get_def(w)["power"] > WeaponData.get_def(best_w)["power"]:
				best_w = w
		if best_w != h.weapon:
			town.equip(best_w)
		var bought := false
		for w in WeaponData.SHOP:
			if WeaponData.get_def(w)["power"] > WeaponData.get_def(h.weapon)["power"] and town.weapon_state(w)["ok"]:
				town.buy_weapon(w)
				bought = true
				break
		if bought:
			continue
		# 考驗
		if town.spar_state()["ok"] and h.learned.size() >= 2 and spar_tries < 3:
			spar_tries += 1
			var sb := town.start_spar()
			sb.rng.seed = rng.randi()
			pilot.play(sb)
			town.finish_spar(sb)
			fights += 1
			continue
		# 挑委託：還沒打贏過的最弱對手；在目前實力下連輸兩次（或欠錢），就回去打打得贏的
		var target := ""
		for id in LADDER:
			if not h.beaten.has(id) and lost_at.get(id, 0) < 2:
				target = id
				break
		if target == "" or h.money < 0:
			var safe := EnemyData.ORDER.filter(func(id): return h.beaten.has(id))
			target = safe[-1] if not safe.is_empty() else EnemyData.ORDER[0]
		town.depart(target)
		var b := town.start_commission()
		b.rng.seed = rng.randi()
		var r := pilot.play(b)
		town.finish_commission(b)
		for id in town.loot.duplicate():
			town.take_loot(id)
		town.return_to_town()
		fights += 1
		if r["outcome"] != "win":
			lost_at[target] = lost_at.get(target, 0) + 1
		else:
			# 去別處打贏一場、喘口氣，就再去試打不贏的
			for k in lost_at:
				if k != target:
					lost_at[k] = mini(lost_at[k], 1)
			var key: String = "打贏" + EnemyData.ENEMIES[target]["name"]
			if not when.has(key):
				when[key] = h.month
		if verbose:
			print("%s %-5s %-4s 血%3d/%3d 錢%5d 力%d(%d) 敏%d(%d) %s %s 招%d" % [
				h.date_text(), EnemyData.ENEMIES[target]["name"], r["outcome"], h.hp, h.max_hp(), h.money,
				h.body("str"), h.stats["str"], h.body("agi"), h.stats["agi"], h.realm_text(),
				WeaponData.get_def(h.weapon)["name"], h.learned.size()])
	return {"months": h.month, "fights": fights, "when": when}


func _power_sig(h: Adventurer) -> String:
	var total: int = h.body("str") + h.body("agi")
	return "%d %d %d %d %s" % [total / 2, h.learned.size(), h.realm, h.approved_tier, h.weapon]
