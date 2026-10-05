class_name Town
extends RefCounted

## 城鎮的規則：委託、休養、時間（月）和生活費、壽命、師傅（考驗、交代的事）、秘笈、武器店、戰利品、
## 戰鬥打完的結算（數值成長、瓶頸、偷學）。
## 不碰畫面：每個動作回傳訊息清單 [{"kind", "text"}]，畫面照著顯示。
##   kind：info 一般、good 好事、bad 壞事、big 大事、epic 一輩子記得的大事（升境、拿到秘笈、讀完秘笈、死去）
## 花時間的事（出發、學招、讀秘笈、休養、養傷）會在 wait 留下要演的那一段，畫面演完等的畫面才給結果。
## 壽命用完了 hero.dead 就是 true，正在做的事做不完。

var hero := Adventurer.new()
## 剛打贏的對手身上的東西（武器 id、秘笈 id）。玩家自己決定拿不拿，離開戰鬥畫面就沒了
var loot: Array[String] = []
## 剛花掉的時間，給等的畫面演：{"kind", "title", "from", "months"}。沒有就是空的。畫面用 take_wait() 拿走
var wait := {}

## 正在打的委託（結算用）
var _fight_enemy := ""


func take_wait() -> Dictionary:
	var w := wait
	wait = {}
	return w


# ---------- 委託 ----------

## 出發：路上和找人的時間先花掉。壽命在路上用完的話就打不成了
func depart(enemy_id: String) -> Array:
	_fight_enemy = enemy_id
	loot.clear()
	var c: Dictionary = TownData.COMMISSIONS[enemy_id]
	return _pass_months(c["months"], "travel", "出發：%s" % _enemy_name(enemy_id))


func start_commission() -> Battle:
	return Battle.new([hero.to_combatant()], [Combatant.from_enemy(_fight_enemy)])


func finish_commission(battle: Battle) -> Array:
	var r := battle.result()
	var id := _fight_enemy
	var c: Dictionary = TownData.COMMISSIONS[id]
	var msgs := []
	match r["outcome"]:
		"win":
			hero.hp = r["hp"]
			hero.money += c["reward"]
			msgs.append(_m("good", "報酬 %d 銀。" % c["reward"]))
		"flee":
			hero.hp = r["hp"]
		"lose":
			hero.hp = maxi(1, roundi(hero.max_hp() * TownData.INJURED_HP))
			hero.note("被%s打成重傷" % _enemy_name(id))
			msgs.append(_m("bad", "路過的商隊把你撿了回來。醒來時你躺在城裡的旅店，身上纏滿了繃帶。"))
	if r["outcome"] == "win":
		msgs.append_array(_after_win(id))
	msgs.append_array(_grow(EnemyData.ENEMIES[id], r))
	msgs.append_array(_steal(r["sig_hits"]))
	if r["outcome"] == "lose":
		msgs.append_array(_pass_months(TownData.INJURED_MONTHS, "injured", "養傷"))
	return msgs


## 委託板上有哪些對手：一般的都在；有名字的強者打倒了就不會再出現
func board() -> Array:
	var list: Array = EnemyData.ORDER.duplicate()
	for id in EnemyData.NAMED:
		if not hero.beaten.has(id):
			list.append(id)
	return list


## 打贏之後：對手身上的東西、卡在瓶頸時打贏強敵就衝破瓶頸、通關
func _after_win(id: String) -> Array:
	var msgs := []
	if not hero.beaten.has(id):
		hero.beaten.append(id)
		hero.note("打倒了%s" % _enemy_name(id))
	var e: Dictionary = EnemyData.ENEMIES[id]
	var drop: String = e.get("loot", "")
	if drop != "" and not hero.owned_weapons.has(drop):
		loot.append(drop)
	for b in e.get("books", []):
		if not hero.books.has(b):
			loot.append(b)
	# 卡在瓶頸時打贏比瓶頸強的對手就衝破。以前打贏過也算，不然先打贏、後卡瓶頸的人會卡死
	var stronger: bool = maxi(e["str"], e["agi"]) > hero.cap()
	if stronger and hero.stuck() and hero.can_break_through():
		msgs.append_array(_break_through())
	if id == TownData.GOAL and not hero.cleared:
		hero.cleared = true
		msgs.append(_m("big", "★ 原型通關（%s）" % hero.date_text()))
	return msgs


func _enemy_name(id: String) -> String:
	var e: Dictionary = EnemyData.ENEMIES[id]
	return ("%s%s" % [e.get("title", ""), e["name"]])


# ---------- 戰利品 ----------

## 拿走一樣東西。拿到秘笈是大事
func take_loot(id: String) -> Array:
	if not loot.has(id):
		return []
	loot.erase(id)
	if BookData.is_book(id):
		hero.books.append(id)
		hero.note("拿到劍譜《%s》" % BookData.get_def(id)["name"])
		return [_m("epic", BookData.get_def(id)["got"])]
	hero.owned_weapons.append(id)
	var w := WeaponData.get_def(id)
	if w.get("rare", false):
		hero.note("拿到%s" % w["name"])
	return [_m("info", "你拿走了%s。" % w["name"])]


func clear_loot() -> void:
	loot.clear()


## 回到城裡：劍譜在身上，師傅又交代過，就拿去給他看
func return_to_town() -> Array:
	return _report_errand()


# ---------- 秘笈 ----------

## 這本現在能不能讀：{"read", "ok", "months", "why"}
func book_state(id: String) -> Dictionary:
	var b := BookData.get_def(id)
	var st := {"read": hero.knows(b["move"]), "ok": false, "months": b["months"], "why": ""}
	if not st["read"]:
		st["ok"] = hero.books.has(id)
	return st


## 花時間讀完，就學會裡面的招。壽命在讀完之前用完就學不成
func read_book(id: String) -> Array:
	var st := book_state(id)
	if not st["ok"]:
		return []
	var b := BookData.get_def(id)
	var msgs := _pass_months(st["months"], "read", "讀《%s》" % b["name"])
	if hero.dead:
		return msgs
	hero.learn(b["move"])
	var move_name: String = MoveData.MOVES[b["move"]]["name"]
	hero.note("讀完《%s》" % b["name"] if b["name"] == move_name else "讀完《%s》，學會「%s」" % [b["name"], move_name])
	msgs.append(_m("epic", "%s\n你學會了「%s」。" % [b["read"], move_name]))
	return msgs


## 師傅交代的事：劍譜拿回來給他看。first：他還沒交代，就看見你拿著了
func _report_errand(first := false) -> Array:
	var book: String = SchoolData.ERRAND["book"]
	if hero.errand_reported or hero.approved_tier < 2 or not hero.books.has(book):
		return []
	hero.errand_reported = true
	var read := hero.knows(BookData.get_def(book)["move"])
	var text: String = SchoolData.ERRAND["seen" if first else "returned"]
	return [_m("epic", text + "\n" + SchoolData.ERRAND["keep_read" if read else "keep"])]


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
	hero.note("升到%s" % GrowthData.REALM_NAMES[hero.realm])
	return [_m("epic", "%s\n%s" % [BREAKTHROUGH_TEXT[hero.realm], GrowthData.REALM_NAMES[hero.realm]])]


## 用了哪個數值的招就練到哪個數值。練多少看對手「那一項」比你現在的身體高多少。
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
		var grow := GrowthData.grow_mult(enemy[s], hero.body(s))
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
			hero.note("偷學到「%s」" % MoveData.MOVES[id]["name"])
			msgs.append(_m("big", "你學會了「%s」。" % MoveData.MOVES[id]["name"]))
	return msgs


# ---------- 休養、時間 ----------

func months_to_full() -> int:
	var missing := hero.max_hp() - hero.hp
	if missing <= 0:
		return 0
	return ceili(missing / (hero.max_hp() * TownData.REST_HEAL))


func rest(months: int) -> Array:
	if hero.hp >= hero.max_hp():
		return [_m("info", "你身體好好的，不用休養。")]
	var before := hero.month
	var msgs := _pass_months(months, "rest", "休養")
	var heal := roundi(hero.max_hp() * TownData.REST_HEAL)
	hero.hp = mini(hero.max_hp(), hero.hp + heal * (hero.month - before))
	if not hero.dead:
		msgs.append(_m("good", "血量回到 %d / %d。" % [hero.hp, hero.max_hp()]))
	return msgs


## 花掉 n 個月：扣生活費、變老。壽命用完就停在那一刻。
## kind 不是空的就留給等的畫面演（title：畫面上寫在做什麼）
func _pass_months(n: int, kind := "", title := "") -> Array:
	var from := hero.month
	var passed := mini(n, hero.months_left())
	hero.month += passed
	var cost := TownData.LIVING_COST * passed
	hero.money -= cost
	if kind != "":
		wait = {"kind": kind, "title": title, "from": from, "months": passed}
	var msgs := [_m("info", "過了 %s，生活費 %d 銀。" % [LifeData.span_text(passed), cost])]
	if hero.money < 0:
		msgs.append(_m("bad", "你已經欠了 %d 銀。" % -hero.money))
	if hero.months_left() == 0:
		hero.dead = true
		msgs.append(_m("epic", LifeData.DEATH_TEXT))
	return msgs


# ---------- 師傅 ----------

## 有沒有入門（學過第 1 階的招）
func enrolled() -> bool:
	for id in SchoolData.tier_def(1)["moves"]:
		if hero.knows(id):
			return true
	return false


## 這招現在能不能在道場學：{"learned", "ok", "why": [原因], "cost", "months"}。絕學不在道場學（讀秘笈）
## 數值門檻看現在的身體
func move_state(id: String) -> Dictionary:
	var t := SchoolData.tier_def(SchoolData.tier_of(id))
	var st := {"learned": hero.knows(id), "ok": false, "why": [], "cost": t.get("cost", 0), "months": t.get("months", 0)}
	if st["learned"] or t["exam"] == "errand":
		return st
	if t["tier"] > hero.approved_tier:
		st["why"].append("要通過「%s」" % t["exam_name"])
	var req: Dictionary = SchoolData.REQ.get(id, {})
	for s in req:
		if hero.body(s) < req[s]:
			st["why"].append("%s要 %d" % [GrowthData.NAMES[s], req[s]])
	if st["cost"] > hero.money:
		st["why"].append("錢不夠")
	st["ok"] = st["why"].is_empty()
	return st


## 學費先付。壽命在學完之前用完就學不成
func learn_move(id: String) -> Array:
	var st := move_state(id)
	if not st["ok"]:
		return []
	hero.money -= st["cost"]
	var move_name: String = MoveData.MOVES[id]["name"]
	var msgs := _pass_months(st["months"], "learn", "學「%s」" % move_name)
	if hero.dead:
		return msgs
	hero.learn(id)
	hero.note("學會「%s」" % move_name)
	msgs.append(_m("good", "你學會了「%s」。" % move_name))
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


## 通過考驗：師傅交代他的事（劍譜已經在你身上的話，他直接看見）
func finish_spar(battle: Battle) -> Array:
	var msgs := []
	if battle.result()["outcome"] == "survive":
		hero.approved_tier = 2
		hero.note("接住了師傅三招")
		if hero.books.has(SchoolData.ERRAND["book"]):
			msgs.append_array(_report_errand(true))
		else:
			msgs.append(_m("big", SchoolData.ERRAND["ask"]))
	msgs.append_array(_pass_months(SchoolData.SPAR_MONTHS))
	return msgs


# ---------- 武器店 ----------

## 這把劍現在能不能買：{"owned", "ok", "why": [原因]}
func weapon_state(id: String) -> Dictionary:
	var w := WeaponData.get_def(id)
	var st := {"owned": hero.owned_weapons.has(id), "ok": false, "why": []}
	if st["owned"]:
		return st
	if not hero.can_wield(id):
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
