class_name Town
extends RefCounted

## 城鎮的規則：委託、休養、天數和生活費、師傅、武器店、戰鬥打完的結算（數值成長、瓶頸、偷學、跟上次比）。
## 不碰畫面：每個動作回傳訊息清單 [{"kind", "text"}]，畫面照著顯示。
##   kind：info 一般、good 好事、bad 壞事、big 大事

var hero := Adventurer.new()

## 正在打的委託（結算用）
var _fight_enemy := ""
## 開打時的你（跟上次比用）
var _fight_start := {}
## 剛打完的這場跟上次比：{"before": 上次的紀錄（第一次打是空的）, "now": 這次的紀錄}
var last_report := {}


# ---------- 委託 ----------

func start_commission(enemy_id: String) -> Battle:
	_fight_enemy = enemy_id
	_fight_start = {"day": hero.day, "hp": hero.hp, "max_hp": hero.max_hp(), "realm": hero.realm_text(),
		"str": hero.stats["str"], "agi": hero.stats["agi"],
		"weapon": WeaponData.get_def(hero.weapon)["name"], "learned": hero.learned.duplicate()}
	return Battle.new([hero.to_combatant()], [Combatant.from_enemy(enemy_id)])


func finish_commission(battle: Battle) -> Array:
	var r := battle.result()
	var id := _fight_enemy
	var record := _fight_record(battle)
	last_report = {"before": hero.last_fights.get(id, {}), "now": record}
	hero.last_fights[id] = record
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
	msgs.append_array(_grow(EnemyData.ENEMIES[id], r))
	msgs.append_array(_steal(r["sig_hits"]))
	return msgs


## 這場的紀錄：開打時的你 ＋ 打得怎樣
func _fight_record(battle: Battle) -> Dictionary:
	var r := battle.result()
	var foe: Combatant = battle.enemies[0]
	var used := {}
	for m in r["used"]:
		used[m] = used.get(m, 0) + 1
	var rec := _fight_start.duplicate()
	rec.merge({"outcome": r["outcome"], "rounds": r["rounds"], "hp_lost": _fight_start["hp"] - r["hp"],
		"foe_left": float(foe.hp) / foe.max_hp, "used": used})
	return rec


## 打贏之後：卡在瓶頸時打贏強敵就衝破瓶頸、師傅的考驗、通關
func _after_win(id: String) -> Array:
	var msgs := []
	if not hero.beaten.has(id):
		hero.beaten.append(id)
	# 卡在瓶頸時打贏比瓶頸強的對手就衝破。以前打贏過也算，不然先打贏、後卡瓶頸的人會卡死
	var e: Dictionary = EnemyData.ENEMIES[id]
	var stronger: bool = maxi(e["str"], e["agi"]) > hero.cap()
	if stronger and hero.stuck() and hero.can_break_through():
		msgs.append(_break_through("卡在瓶頸時打贏了比自己強的對手。你覺得身體裡有什麼被打通了。"))
	msgs.append_array(_check_bear_exam())
	if id == TownData.GOAL and not hero.cleared:
		hero.cleared = true
		msgs.append(_m("big", "★ 你打倒了食人魔！原型通關。（第 %d 天）" % hero.day))
	return msgs


func _check_bear_exam() -> Array:
	if hero.approved_tier == 2 and hero.beaten.has("bear"):
		hero.approved_tier = 3
		return [_m("big", "師傅的考驗「去打倒熊」完成了。回道場就能學絕學。")]
	return []


# ---------- 基礎數值成長 ----------

## 升一境。回傳訊息
func _break_through(why: String) -> Dictionary:
	var old_realm: String = GrowthData.REALM_NAMES[hero.realm]
	var old_cap := hero.cap()
	var old_hp := hero.max_hp()
	hero.break_through()
	return _m("big", "%s\n　%s → %s：瓶頸 %d → %d，血量上限 %d → %d。" % [
		why, old_realm, GrowthData.REALM_NAMES[hero.realm], old_cap, hero.cap(), old_hp, hero.max_hp()])


## 用了哪個數值的招就練到哪個數值。練多少看對手「那一項」比你高多少。
func _grow(enemy: Dictionary, r: Dictionary) -> Array:
	var uses := {"str": 0.0, "agi": 0.0}
	for id in r["used"]:
		var s: String = MoveData.MOVES[id].get("stat", "")
		if s != "":
			uses[s] += 1.0
	var mult: float = GrowthData.OUTCOME_MULT[r["outcome"]]

	var msgs := []
	for s in GrowthData.STATS:
		if uses[s] <= 0.0:
			continue
		var stat_name: String = GrowthData.NAMES[s]
		if hero.at_cap(s):
			msgs.append(_m("info", "%s卡在瓶頸（%d），練不上去了。" % [stat_name, hero.cap()]))
			continue
		var grow := GrowthData.grow_mult(enemy[s], hero.stats[s])
		if grow <= 0.0:
			msgs.append(_m("info", "%s的%s只有 %d，已經練不到你的%s了。" % [enemy["name"], stat_name, enemy[s], stat_name]))
			continue
		var gained := hero.add_exp(s, GrowthData.EXP_PER_USE * uses[s] * grow * mult)
		if gained > 0:
			msgs.append(_m("good", "%s +%d（現在 %d）" % [stat_name, gained, hero.stats[s]]))
			if hero.at_cap(s):
				msgs.append(_m("info", "%s到了瓶頸（%d）。要再往上，得打贏更強的對手。" % [stat_name, hero.cap()]))
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
			st["why"] = "先入門：學一招基礎招"
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
		msgs.append(_m("big", "通過考驗「接住我三招」！進階招可以學了（數值也要夠）。"))
		if hero.beaten.has("bear"):
			msgs.append(_m("info", "師傅：「聽說你打倒過熊？那絕學的考驗也算你過了。」"))
			msgs.append_array(_check_bear_exam())
	else:
		msgs.append(_m("bad", "考驗沒過。"))
	msgs.append_array(_pass_days(SchoolData.SPAR_DAYS))
	return msgs


# ---------- 武器店 ----------

## 這把劍現在能不能買：{"owned", "ok", "why": [原因]}
func weapon_state(id: String) -> Dictionary:
	var w := WeaponData.get_def(id)
	var st := {"owned": hero.owned_weapons.has(id), "ok": false, "why": []}
	if st["owned"]:
		return st
	if hero.stats["str"] < w["str"]:
		st["why"].append("力量要 %d" % w["str"])
	if hero.money < w["cost"]:
		st["why"].append("錢不夠")
	st["ok"] = st["why"].is_empty()
	return st


## 買了就直接換上
func buy_weapon(id: String) -> Array:
	if not weapon_state(id)["ok"]:
		return []
	var w := WeaponData.get_def(id)
	hero.money -= w["cost"]
	hero.owned_weapons.append(id)
	hero.weapon = id
	return [_m("good", "你花了 %d 銀買下%s，換上了。" % [w["cost"], w["name"]])]


func _m(kind: String, text: String) -> Dictionary:
	return {"kind": kind, "text": text}
