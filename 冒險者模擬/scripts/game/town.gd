class_name Town
extends RefCounted

## 城鎮的規則：委託、休養、天數和生活費、師傅（考驗、交代的事、口訣）、武器店、戰利品、
## 戰鬥打完的結算（數值成長、瓶頸、偷學、悟出絕學）。
## 不碰畫面：每個動作回傳訊息清單 [{"kind", "text"}]，畫面照著顯示。
##   kind：info 一般、good 好事、bad 壞事、big 大事、epic 一輩子記得的大事（升境、師傅傳口訣、悟出絕學）

var hero := Adventurer.new()
## 剛打贏的對手身上的東西（武器 id）。玩家自己決定拿不拿，離開戰鬥畫面就沒了
var loot: Array[String] = []

## 正在打的委託（結算用）
var _fight_enemy := ""


# ---------- 委託 ----------

func start_commission(enemy_id: String) -> Battle:
	_fight_enemy = enemy_id
	loot.clear()
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
			msgs.append(_m("good", "報酬 %d 銀。" % c["reward"]))
		"flee":
			hero.hp = r["hp"]
		"lose":
			hero.hp = maxi(1, roundi(hero.max_hp() * TownData.INJURED_HP))
			days += TownData.INJURED_DAYS
			msgs.append(_m("bad", "路過的商隊把你撿了回來。你昏迷了好幾天，醒來時躺在城裡的旅店。"))
	msgs.append_array(_pass_days(days))
	hero.lore_misses += r["lore_misses"]
	msgs.append_array(_realize(r))
	if r["outcome"] == "win":
		msgs.append_array(_after_win(id))
	msgs.append_array(_grow(EnemyData.ENEMIES[id], r))
	msgs.append_array(_steal(r["sig_hits"]))
	return msgs


## 委託板上有哪些對手：一般的都在；有名字的強者打倒了就不會再出現
func board() -> Array:
	var list: Array = EnemyData.ORDER.duplicate()
	for id in EnemyData.NAMED:
		if not hero.beaten.has(id):
			list.append(id)
	return list


## 打贏之後：對手身上的東西、卡在瓶頸時打贏強敵就衝破瓶頸、師傅交代的事、通關
func _after_win(id: String) -> Array:
	var msgs := []
	if not hero.beaten.has(id):
		hero.beaten.append(id)
	var e: Dictionary = EnemyData.ENEMIES[id]
	var drop: String = e.get("loot", "")
	if drop != "" and not hero.owned_weapons.has(drop):
		loot.append(drop)
	# 卡在瓶頸時打贏比瓶頸強的對手就衝破。以前打贏過也算，不然先打贏、後卡瓶頸的人會卡死
	var stronger: bool = maxi(e["str"], e["agi"]) > hero.cap()
	if stronger and hero.stuck() and hero.can_break_through():
		msgs.append_array(_break_through())
	if id == SchoolData.ERRAND["target"] and hero.approved_tier >= 2:
		msgs.append_array(_give_lore())
	if id == TownData.GOAL and not hero.cleared:
		hero.cleared = true
		msgs.append(_m("big", "★ 原型通關（第 %d 天）" % hero.day))
	return msgs


# ---------- 戰利品 ----------

func take_loot(id: String) -> void:
	if loot.has(id):
		loot.erase(id)
		hero.owned_weapons.append(id)


func clear_loot() -> void:
	loot.clear()


# ---------- 絕學：口訣、悟出 ----------

## 師傅傳口訣（辦到他交代的事之後）
func _give_lore() -> Array:
	if hero.lore.has(SchoolData.ULT) or hero.knows(SchoolData.ULT):
		return []
	hero.lore.append(SchoolData.ULT)
	return [_m("epic", SchoolData.ERRAND["done"])]


## 這場第一次用出了只有口訣的招：從此學會，師傅說出招名
func _realize(r: Dictionary) -> Array:
	var msgs := []
	for id in hero.lore.duplicate():
		if r["used"].has(id):
			hero.lore.erase(id)
			hero.learn(id)
			msgs.append(_m("epic", SchoolData.ERRAND["named"]))
	return msgs


# ---------- 基礎數值成長 ----------

## 升境的那一刻（每一境寫法不同）
const BREAKTHROUGH_TEXT := [
	"",
	"回城的路上，你走了一整天也不覺得累。呼吸又深又穩，劍拿在手上也輕了。",
	"這一仗打完，你在原地站了很久。耳朵裡很安靜，只聽得到自己的心跳，又沉又慢。",
]


## 升一境
func _break_through() -> Array:
	hero.break_through()
	return [_m("epic", "%s\n%s" % [BREAKTHROUGH_TEXT[hero.realm], GrowthData.REALM_NAMES[hero.realm]])]


## 用了哪個數值的招就練到哪個數值。練多少看對手「那一項」比你高多少。
## 只寫長了幾點、到了瓶頸；練不到、卡住都不寫（看經驗條就知道）
func _grow(enemy: Dictionary, r: Dictionary) -> Array:
	var uses := {"str": 0.0, "agi": 0.0}
	for id in r["used"]:
		var s: String = MoveData.MOVES[id].get("stat", "")
		if s != "":
			uses[s] += 1.0
	var mult: float = GrowthData.OUTCOME_MULT[r["outcome"]]

	var msgs := []
	for s in GrowthData.STATS:
		if uses[s] <= 0.0 or hero.at_cap(s):
			continue
		var grow := GrowthData.grow_mult(enemy[s], hero.stats[s])
		if grow <= 0.0:
			continue
		var gained := hero.add_exp(s, GrowthData.EXP_PER_USE * uses[s] * grow * mult)
		if gained > 0:
			msgs.append(_m("good", "%s +%d" % [GrowthData.NAMES[s], gained]))
			if hero.at_cap(s):
				msgs.append(_m("info", "%s到了瓶頸。" % GrowthData.NAMES[s]))
	return msgs


# ---------- 偷學 ----------

func _steal(sig_hits: Dictionary) -> Array:
	var msgs := []
	for id in sig_hits:
		if hero.knows(id):
			continue
		var n: int = hero.steal_hits.get(id, 0) + sig_hits[id]
		hero.steal_hits[id] = n
		if n >= TownData.STEAL_NEED:
			hero.learn(id)
			msgs.append(_m("big", "你學會了「%s」。" % MoveData.MOVES[id]["name"]))
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


## 這招現在能不能在道場學：{"learned", "ok", "why": [原因], "cost", "days"}。絕學不在道場學（口訣 ＋ 實戰悟出）
func move_state(id: String) -> Dictionary:
	var t := SchoolData.tier_def(SchoolData.tier_of(id))
	var st := {"learned": hero.knows(id), "ok": false, "why": [], "cost": t.get("cost", 0), "days": t.get("days", 0)}
	if st["learned"] or t["exam"] == "errand":
		return st
	if t["tier"] > hero.approved_tier:
		st["why"].append("要通過「%s」" % t["exam_name"])
	var req: Dictionary = SchoolData.REQ.get(id, {})
	for s in req:
		if hero.stats[s] < req[s]:
			st["why"].append("%s要 %d" % [GrowthData.NAMES[s], req[s]])
	if st["cost"] > hero.money:
		st["why"].append("錢不夠")
	st["ok"] = st["why"].is_empty()
	return st


func learn_move(id: String) -> Array:
	var st := move_state(id)
	if not st["ok"]:
		return []
	hero.money -= st["cost"]
	hero.learn(id)
	var msgs := [_m("good", "你學會了「%s」。" % MoveData.MOVES[id]["name"])]
	msgs.append_array(_pass_days(st["days"]))
	return msgs


## 第 2 階的考驗：{"passed", "ok", "why"}
func spar_state() -> Dictionary:
	var st := {"passed": hero.approved_tier >= 2, "ok": false, "why": ""}
	if not st["passed"]:
		if not enrolled():
			st["why"] = "先學一招基礎招"
		else:
			st["ok"] = true
	return st


func start_spar() -> Battle:
	var me := hero.to_combatant(true)
	me.yield_hp = roundi(me.max_hp * SchoolData.SPAR_YIELD)
	var b := Battle.new([me], [Combatant.from_enemy(SchoolData.MASTER_ENEMY)])
	b.round_limit = SchoolData.SPAR_ROUNDS
	return b


## 通過考驗：師傅交代他的事（已經辦到的話，直接傳口訣）
func finish_spar(battle: Battle) -> Array:
	var msgs := []
	if battle.result()["outcome"] == "survive":
		hero.approved_tier = 2
		if hero.beaten.has(SchoolData.ERRAND["target"]):
			msgs.append(_m("info", SchoolData.ERRAND["heard"]))
			msgs.append_array(_give_lore())
		else:
			msgs.append(_m("big", SchoolData.ERRAND["ask"]))
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


func equip(id: String) -> Array:
	if not hero.owned_weapons.has(id) or not hero.can_wield(id) or hero.weapon == id:
		return []
	hero.weapon = id
	return [_m("info", "你換上了%s。" % WeaponData.get_def(id)["name"])]


func _m(kind: String, text: String) -> Dictionary:
	return {"kind": kind, "text": text}
