extends SceneTree

## 整輪模擬（開發用）：電腦玩家從第 1 天玩到打倒食人魔，看要幾天、幾場、什麼時候學到什麼。
## 策略很簡單：傷了就休養、能學就學、能考就考、買得起更好的劍就買；
## 委託挑「最難、但在目前實力下還沒連輸兩次」的。戰鬥是自動的（AutoPilot）。
## 執行：Godot.exe --headless --path . --script res://tests/career.gd

const RUNS := 30
## 挑戰的順序（大約由弱到強）
const LADDER := ["wolf", "bandit_leader", "deserter", "bear", "merc_captain", "black_knight", "ogre"]
## 估算真人花的時間：每回合幾秒（自動播放，有時按「看完」）、每次城裡的動作幾秒
const SEC_PER_ROUND := 2
const SEC_PER_FIGHT := 15
const SEC_PER_TOWN := 10


func _init() -> void:
	var all := []
	for run in RUNS:
		all.append(_career(run, run < 2))
	var cleared := all.filter(func(r): return r["cleared"])
	print("\n通關 %d/%d" % [cleared.size(), RUNS])
	for key in ["days", "fights", "losses", "minutes"]:
		var vals := cleared.map(func(r): return r[key])
		vals.sort()
		if not vals.is_empty():
			print("%s：中位數 %s（最少 %s、最多 %s）" % [key, vals[vals.size() / 2], vals[0], vals[-1]])
	var milestones := {}
	for r in cleared:
		for k in r["when"]:
			milestones[k] = milestones.get(k, []) + [r["when"][k]]
	var keys := milestones.keys()
	keys.sort_custom(func(a, b): return milestones[a][milestones[a].size() / 2] < milestones[b][milestones[b].size() / 2])
	for k in keys:
		var v: Array = milestones[k]
		v.sort()
		print("　%s：第 %d 場左右（%d/%d 輪有）" % [k, v[v.size() / 2], v.size(), cleared.size()])
	quit()


func _career(run: int, verbose: bool) -> Dictionary:
	var town := Town.new()
	var h := town.hero
	var pilot := AutoPilot.new()
	var fights := 0
	var losses := 0
	var rounds := 0
	var town_actions := 0
	var lost_at := {}  # enemy -> 在目前實力下輸了幾次
	var spar_tries := 0
	var when := {}
	var power := _power_sig(h)
	var rng := RandomNumberGenerator.new()
	rng.seed = run * 7919
	while not h.cleared and h.day < 500 and fights < 300:
		var sig := _power_sig(h)
		if sig != power:
			power = sig
			lost_at.clear()
			spar_tries = 0
		# 休養
		if h.hp < h.max_hp() * 0.6:
			town.rest(town.days_to_full())
			town_actions += 1
			continue
		# 學招
		var learned_any := false
		for t in SchoolData.TIERS:
			for id in t["moves"]:
				if town.move_state(id)["ok"]:
					town.learn_move(id)
					town_actions += 1
					when["學會" + MoveData.MOVES[id]["name"]] = fights
					learned_any = true
		if learned_any:
			continue
		# 買劍、換劍：換上拿得動的最好的劍；店裡的比較好就買
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
				when["買" + WeaponData.get_def(w)["name"]] = fights
				town_actions += 1
				bought = true
				break
		if bought:
			continue
		# 考驗
		if town.spar_state()["ok"] and h.learned.size() >= 2 and spar_tries < 3:
			spar_tries += 1
			var b := town.start_spar()
			b.rng.seed = rng.randi()
			rounds += pilot.play(b)["rounds"]
			town.finish_spar(b)
			fights += 1
			if h.approved_tier >= 2:
				when["通過師傅考驗"] = fights
			continue
		# 挑委託
		# 挑戰還沒打贏過的最弱對手；在目前實力下連輸兩次（或欠錢），就回去打打得贏的一般委託
		var target := ""
		for id in LADDER:
			if not h.beaten.has(id):
				target = id
				break
		if target == "":
			target = TownData.GOAL
		if lost_at.get(target, 0) >= 2 or h.money < 0:
			var safe := []
			for id in EnemyData.ORDER:
				if h.beaten.has(id):
					safe.append(id)
			if safe.is_empty():
				safe = [EnemyData.ORDER[0]]
			target = safe[-1]
			if lost_at.get(target, 0) >= 2 and safe.size() > 1:
				target = safe[-2]
		var realm_before := h.realm
		var b := town.start_commission(target)
		b.rng.seed = rng.randi()
		var r := pilot.play(b)
		rounds += r["rounds"]
		town.finish_commission(b)
		fights += 1
		if r["outcome"] != "win":
			losses += 1
			lost_at[target] = lost_at.get(target, 0) + 1
		else:
			# 去別處打贏一場、喘口氣，就再去試打不贏的
			for k in lost_at:
				if k != target:
					lost_at[k] = mini(lost_at[k], 1)
			if not when.has("打贏" + EnemyData.ENEMIES[target]["name"]):
				when["打贏" + EnemyData.ENEMIES[target]["name"]] = fights
		if h.realm > realm_before:
			when["升到" + GrowthData.REALM_NAMES[h.realm]] = fights
		for k in h.steal_hits:
			if h.knows(k) and not when.has("偷學" + MoveData.MOVES[k]["name"]):
				when["偷學" + MoveData.MOVES[k]["name"]] = fights
		if verbose:
			print("第%3d天 %-4s %-4s %2d回 血%3d/%3d 錢%4d 力%d 敏%d %s %s 招%d" % [
				h.day, EnemyData.ENEMIES[target]["name"], r["outcome"], r["rounds"], h.hp, h.max_hp(), h.money,
				h.stats["str"], h.stats["agi"], h.realm_text(), WeaponData.get_def(h.weapon)["name"], h.learned.size()])
	var minutes := (rounds * SEC_PER_ROUND + fights * SEC_PER_FIGHT + town_actions * SEC_PER_TOWN) / 60
	if not h.cleared:
		print("沒通關：第%d天 %d場 錢%d 力%d 敏%d %s %s 招%s 打贏過%s" % [h.day, fights, h.money, h.stats["str"], h.stats["agi"], h.realm_text(), h.weapon, h.learned, h.beaten])
	return {"cleared": h.cleared, "days": h.day, "fights": fights, "losses": losses, "minutes": minutes, "when": when}


func _power_sig(h: Adventurer) -> String:
	var total: int = h.stats["str"] + h.stats["agi"]
	return "%d %d %d %d %s" % [total / 2, h.learned.size(), h.realm, h.approved_tier, h.weapon]
