extends SceneTree

## 整輪模擬（開發用）：電腦玩家從第 1 天玩到打倒食人魔，看要幾天、幾場、什麼時候學到什麼。
## 策略很簡單：傷了就休養、能學就學、能考就考、卡瓶頸有錢就特訓；
## 委託挑「最難、但在目前實力下還沒連輸兩次」的。
## 執行：Godot.exe --headless --path . --script res://tests/career.gd

const Bot := preload("res://tests/bot.gd")
const RUNS := 30
## 估算真人花的時間：每回合幾秒、每次城裡的動作幾秒
const SEC_PER_ROUND := 10
const SEC_PER_TOWN := 15


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
	for k in milestones:
		var v: Array = milestones[k]
		v.sort()
		print("　%s：第 %d 場左右（%d/%d 輪有）" % [k, v[v.size() / 2], v.size(), cleared.size()])
	quit()


func _career(run: int, verbose: bool) -> Dictionary:
	var town := Town.new()
	var h := town.hero
	var bot := Bot.new()
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
		# 考驗
		if town.spar_state()["ok"] and h.learned.size() >= 2 and mini(h.stats["str"], h.stats["agi"]) >= 13 and spar_tries < 3:
			spar_tries += 1
			var b := town.start_spar()
			b.rng.seed = rng.randi()
			rounds += bot.play(b)["rounds"]
			town.finish_spar(b)
			town_actions += 1
			if h.approved_tier >= 2:
				when["通過師傅考驗"] = fights
			continue
		# 卡瓶頸就特訓
		var tr := town.train_state()
		if tr["available"] and tr["ok"]:
			town.train()
			when["特訓升到" + GrowthData.REALM_NAMES[h.realm]] = fights
			town_actions += 1
			continue
		# 挑委託
		# 挑戰「打贏過的最強對手」的下一個；在目前實力下連輸兩次，就回去打打得贏的
		var best := -1
		for i in EnemyData.ORDER.size():
			if h.beaten.has(EnemyData.ORDER[i]):
				best = i
		var target: String = EnemyData.ORDER[mini(best + 1, EnemyData.ORDER.size() - 1)]
		if lost_at.get(target, 0) >= 2:
			target = EnemyData.ORDER[maxi(best, 0)]
		var realm_before := h.realm
		var b := town.start_commission(target)
		b.rng.seed = rng.randi()
		var r := bot.play(b)
		rounds += r["rounds"]
		var msgs := town.finish_commission(b)
		fights += 1
		if r["outcome"] != "win":
			losses += 1
			lost_at[target] = lost_at.get(target, 0) + 1
		elif not when.has("打贏" + EnemyData.ENEMIES[target]["name"]):
			when["打贏" + EnemyData.ENEMIES[target]["name"]] = fights
		if h.realm > realm_before:
			when["打贏強敵升到" + GrowthData.REALM_NAMES[h.realm]] = fights
		for k in h.steal_hits:
			if h.knows(k) and not when.has("偷學" + MoveData.MOVES[k]["name"]):
				when["偷學" + MoveData.MOVES[k]["name"]] = fights
		if verbose:
			print("第%3d天 %-4s %-4s 血%3d/%3d 錢%4d 力%d 敏%d %s 招%d" % [
				h.day, EnemyData.ENEMIES[target]["name"], r["outcome"], h.hp, h.max_hp(), h.money,
				h.stats["str"], h.stats["agi"], h.realm_text(), h.learned.size()])
	var minutes := (rounds * SEC_PER_ROUND + (fights + town_actions) * SEC_PER_TOWN) / 60
	return {"cleared": h.cleared, "days": h.day, "fights": fights, "losses": losses, "minutes": minutes, "when": when}


func _power_sig(h: Adventurer) -> String:
	var total: int = h.stats["str"] + h.stats["agi"]
	return "%d %d %d %d" % [total / 2, h.learned.size(), h.realm, h.approved_tier]
