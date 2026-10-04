class_name Town
extends RefCounted

## 城鎮的規則：委託、休養、天數和生活費、師傅、戰鬥打完的結算（數值成長、瓶頸、偷學）。
## 不碰畫面：每個動作回傳訊息清單 [{"kind", "text"}]，畫面照著顯示。
##   kind：info 一般、good 好事、bad 壞事、big 大事

var hero := Adventurer.new()

## 正在打的委託和開打前的血量（結算用）
var _fight_enemy := ""
var _hp_before := 0


# ---------- 委託 ----------

func start_commission(enemy_id: String) -> Battle:
	_fight_enemy = enemy_id
	_hp_before = hero.hp
	return Battle.new([hero.to_combatant()], [Combatant.from_enemy(enemy_id)])


func finish_commission(battle: Battle) -> Array:
	var r := battle.result()
	var id := _fight_enemy
	var c: Dictionary = TownData.COMMISSIONS[id]
	var msgs := []
	var days: int = c["days"]
	match r["outcome"]:
		"win":
			hero.hp = r["hp"]
			hero.money += c["reward"]
			msgs.append(_m("good", "委託完成，拿到報酬 %d 銀。" % c["reward"]))
		"flee":
			hero.hp = r["hp"]
			msgs.append(_m("bad", "你逃回城裡。委託失敗，沒有報酬。"))
		"lose":
			hero.hp = maxi(1, roundi(hero.max_hp() * TownData.INJURED_HP))
			days += TownData.INJURED_DAYS
			msgs.append(_m("bad", "你重傷倒地，被路過的商隊撿了回來。昏迷了好幾天，醒來時躺在城裡的旅店。"))
	msgs.append_array(_pass_days(days))
	if r["outcome"] == "win":
		msgs.append_array(_after_win(id))
	msgs.append_array(_grow(EnemyData.ENEMIES[id]["level"], r))
	msgs.append_array(_steal(r["sig_hits"]))
	return msgs


## 打贏之後：第一次打贏強敵衝破瓶頸、師傅的考驗、通關
func _after_win(id: String) -> Array:
	var msgs := []
	if not hero.beaten.has(id):
		hero.beaten.append(id)
		var level: int = EnemyData.ENEMIES[id]["level"]
		if level > hero.cap() and hero.cap_tier < GrowthData.CAPS.size() - 1:
			var old := hero.cap()
			hero.cap_tier += 1
			msgs.append(_m("big", "第一次打贏比自己強的對手。你覺得身體裡有什麼被打通了。（瓶頸 %d → %d）" % [old, hero.cap()]))
	msgs.append_array(_check_bear_exam())
	if id == TownData.GOAL and not hero.cleared:
		hero.cleared = true
		msgs.append(_m("big", "★ 你打倒了食人魔！原型通關。（第 %d 天）" % hero.day))
	return msgs


func _check_bear_exam() -> Array:
	if hero.approved_tier == 2 and hero.beaten.has("bear"):
		hero.approved_tier = 3
		return [_m("big", "師傅的考驗「去打倒熊」完成了。回道場就能學第 3 階的招。")]
	return []


# ---------- 基礎數值成長 ----------

## 用了哪個數值的招就練到哪個數值；挨打練體魄。練多少看對手比你強多少。
func _grow(enemy_level: int, r: Dictionary) -> Array:
	var uses := {"str": 0.0, "agi": 0.0, "con": 0.0}
	for id in r["used"]:
		var s: String = MoveData.MOVES[id].get("stat", "")
		if s != "":
			uses[s] += 1.0
	var lost := maxf(0.0, _hp_before - r["hp"]) / hero.max_hp()
	uses["con"] += lost / GrowthData.HURT_PER_USE
	var mult: float = GrowthData.OUTCOME_MULT[r["outcome"]]

	var msgs := []
	for s in GrowthData.STATS:
		if uses[s] <= 0.0:
			continue
		var stat_name: String = GrowthData.NAMES[s]
		if hero.at_cap(s):
			msgs.append(_m("info", "%s卡在瓶頸（%d），練不上去了。" % [stat_name, hero.cap()]))
			continue
		var gap := GrowthData.gap_mult(enemy_level, hero.stats[s])
		if gap <= 0.0:
			msgs.append(_m("info", "這種對手已經練不到你的%s了。" % stat_name))
			continue
		var gained := hero.add_exp(s, GrowthData.EXP_PER_USE * uses[s] * gap * mult)
		if gained > 0:
			msgs.append(_m("good", "%s +%d（現在 %d）" % [stat_name, gained, hero.stats[s]]))
			if hero.at_cap(s):
				msgs.append(_m("info", "%s到了瓶頸（%d）。要再往上，得打贏更強的對手，或找師傅特訓。" % [stat_name, hero.cap()]))
		else:
			msgs.append(_m("info", "%s有一點長進。" % stat_name))
	return msgs


# ---------- 偷學 ----------

func _steal(sig_hits: Dictionary) -> Array:
	var msgs := []
	for id in sig_hits:
		if hero.knows(id):
			continue
		var n: int = hero.steal_hits.get(id, 0) + sig_hits[id]
		hero.steal_hits[id] = n
		var move_name: String = MoveData.MOVES[id]["name"]
		if n >= TownData.STEAL_NEED:
			hero.learn(id)
			msgs.append(_m("big", "你偷學會了「%s」！（野路子的招，不屬於任何流派）" % move_name))
		else:
			msgs.append(_m("info", "你對「%s」越來越有感覺了。（%d/%d）" % [move_name, n, TownData.STEAL_NEED]))
	return msgs


# ---------- 休養、天數 ----------

func days_to_full() -> int:
	var missing := hero.max_hp() - hero.hp
	if missing <= 0:
		return 0
	return ceili(missing / (hero.max_hp() * TownData.REST_HEAL))


func rest(days: int) -> Array:
	if hero.hp >= hero.max_hp():
		return [_m("info", "你身體好好的，不用休養。")]
	var heal := roundi(hero.max_hp() * TownData.REST_HEAL)
	hero.hp = mini(hero.max_hp(), hero.hp + heal * days)
	var msgs := [_m("good", "休養了 %d 天，血量回到 %d / %d。" % [days, hero.hp, hero.max_hp()])]
	msgs.append_array(_pass_days(days))
	return msgs


func _pass_days(n: int) -> Array:
	hero.day += n
	var cost := TownData.LIVING_COST * n
	hero.money -= cost
	var msgs := [_m("info", "過了 %d 天，生活費 %d 銀。" % [n, cost])]
	if hero.money < 0:
		msgs.append(_m("bad", "你已經欠了 %d 銀。" % -hero.money))
	return msgs


# ---------- 師傅 ----------

## 有沒有入門（學過第 1 階的招）
func enrolled() -> bool:
	for id in SchoolData.tier_def(1)["moves"]:
		if hero.knows(id):
			return true
	return false


## 這招現在能不能學：{"learned", "ok", "why": [原因], "cost", "days"}
func move_state(id: String) -> Dictionary:
	var t := SchoolData.tier_def(SchoolData.tier_of(id))
	var st := {"learned": hero.knows(id), "ok": false, "why": [], "cost": t["cost"], "days": t["days"]}
	if st["learned"]:
		return st
	if t["tier"] > hero.approved_tier:
		st["why"].append("要通過考驗「%s」" % t["exam_name"])
	var req: Dictionary = SchoolData.REQ.get(id, {})
	for s in req:
		if hero.stats[s] < req[s]:
			st["why"].append("%s要 %d" % [GrowthData.NAMES[s], req[s]])
	if t["cost"] > hero.money:
		st["why"].append("錢不夠")
	st["ok"] = st["why"].is_empty()
	return st


func learn_move(id: String) -> Array:
	var st := move_state(id)
	if not st["ok"]:
		return []
	hero.money -= st["cost"]
	hero.learn(id)
	var msgs := []
	if st["cost"] > 0:
		msgs.append(_m("good", "你交了 %d 銀學費，師傅教你「%s」。" % [st["cost"], MoveData.MOVES[id]["name"]]))
	else:
		msgs.append(_m("good", "師傅教你「%s」。" % MoveData.MOVES[id]["name"]))
	msgs.append_array(_pass_days(st["days"]))
	return msgs


## 第 2 階的考驗：{"passed", "ok", "why"}
func spar_state() -> Dictionary:
	var st := {"passed": hero.approved_tier >= 2, "ok": false, "why": ""}
	if not st["passed"]:
		if not enrolled():
			st["why"] = "先入門：學一招第 1 階的招"
		else:
			st["ok"] = true
	return st


func start_spar() -> Battle:
	var me := hero.to_combatant(true)
	me.yield_hp = roundi(me.max_hp * SchoolData.SPAR_YIELD)
	var b := Battle.new([me], [Combatant.from_enemy(SchoolData.MASTER_ENEMY)])
	b.round_limit = SchoolData.SPAR_ROUNDS
	return b


func finish_spar(battle: Battle) -> Array:
	var msgs := []
	if battle.result()["outcome"] == "survive":
		hero.approved_tier = 2
		msgs.append(_m("big", "通過考驗「接住我三招」！第 2 階的招可以學了（數值也要夠）。"))
		if hero.beaten.has("bear"):
			msgs.append(_m("info", "師傅：「聽說你打倒過熊？那第 3 階的考驗也算你過了。」"))
			msgs.append_array(_check_bear_exam())
	else:
		msgs.append(_m("bad", "考驗沒過。"))
	msgs.append_array(_pass_days(SchoolData.SPAR_DAYS))
	return msgs


## 特訓過瓶頸：{"available", "ok", "why", "cost", "days", "next"}
func train_state() -> Dictionary:
	if hero.cap_tier >= SchoolData.TRAIN.size():
		return {"available": false}
	var t: Dictionary = SchoolData.TRAIN[hero.cap_tier]
	var st := {"available": true, "ok": false, "why": "", "cost": t["cost"], "days": t["days"],
		"next": GrowthData.CAPS[hero.cap_tier + 1]}
	if not enrolled():
		st["why"] = "先入門：學一招第 1 階的招"
	elif hero.money < t["cost"]:
		st["why"] = "錢不夠"
	else:
		st["ok"] = true
	return st


func train() -> Array:
	var st := train_state()
	if not st.get("ok", false):
		return []
	var old := hero.cap()
	hero.money -= st["cost"]
	hero.cap_tier += 1
	var msgs := [_m("big", "師傅帶著你苦練了 %d 天。你的瓶頸從 %d 提高到 %d。" % [st["days"], old, hero.cap()])]
	msgs.append_array(_pass_days(st["days"]))
	return msgs


func _m(kind: String, text: String) -> Dictionary:
	return {"kind": kind, "text": text}
