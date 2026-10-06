class_name SchoolData
extends RefCounted

## 流派：原型只有獅心劍庭（正統騎士，用劍）。只有資料。
##
## 入門：通過考驗「接住庭主三招」，成為學徒。不收學費。
## 貢獻：替劍庭辦事（JOBS：清剿、討伐紅鬃、拿回庭主師弟的劍譜）。用貢獻換招（MOVES）。
##   不加入也能辦事、換第 1 階（藍）的招；更高的要加入、要階位。
## 階位：學徒 → 熟手 → 大師，靠公開比試（TRIALS）。累積的貢獻夠了才能比。
## 絕學「王權裁定」在庭主師弟的劍譜裡（BookData verdict_book）：拿回來交給庭主，他讓你留著讀。
## 架勢（STANCE）：會三招以上劍庭的招，「磐石劍位」自己生效。
## 庭主不能帶你過瓶頸（實力和認可是兩回事）。

const ID := "lionheart"
const NAME := "獅心劍庭"
## 階位：0 不是成員
const RANKS := ["", "學徒", "熟手", "大師"]
## 庭主（世界上的人）
const HEAD := "master"

## 換招：招 id -> 要什麼階位、多少貢獻、學多久。數值門檻在 REQ
const MOVES := {
	"lh_cross": {"rank": 1, "merit": 15, "months": 4},
	"lh_pommel": {"rank": 1, "merit": 15, "months": 4},
	"lh_half": {"rank": 2, "merit": 35, "months": 6},
	"lh_advance": {"rank": 2, "merit": 35, "months": 6},
	"lh_bind": {"rank": 3, "merit": 60, "months": 8},
}
## 絕學（讀劍譜）
const ULT := "lh_verdict"

## 招式的數值門檻（沒寫的 = 沒有門檻）。練武場的招也寫在這裡
const REQ := {
	"shed": {"str": 12},
	"deflect": {"agi": 13},
	"triple": {"str": 14},
	"needle": {"agi": 14},
	"lh_cross": {"str": 13},
	"lh_half": {"agi": 14},
	"lh_advance": {"str": 14},
	"lh_bind": {"agi": 15},
}

## 入門考驗：接住庭主三招。身體（比較高的那項）要到 JOIN_BODY 才收
const JOIN_BODY := 11
const SPAR_ENEMY := "master"
const SPAR_MONTHS := 2
const SPAR_ROUNDS := 3
## 血掉到這個比例以下就算輸（掉超過四成）
const SPAR_YIELD := 0.6

## 公開比試：升到這個階位要打贏誰（世界上的人；他不在了就換 EnemyData 的 fallback）、累積貢獻要多少
## 比試打到一方剩 MATCH_YIELD 的血就停，不會死、不會被搶
const TRIALS := {
	2: {"opponent": "matthias", "fallback": "lionheart_senior", "merit_total": 25, "months": 1,
		"text": "比試在劍庭的中庭，學徒們圍成一圈。"},
	3: {"opponent": "", "fallback": "lionheart_head", "merit_total": 90, "months": 1,
		"text": "庭主親自下場。中庭裡站滿了人，連街上的人都擠在門口看。"},
}
const MATCH_YIELD := 0.4

## 架勢：會 need 招以上劍庭的招就生效。擋下一招之後，下一劍重 bonus 倍
const STANCE := {
	"name": "磐石劍位", "need": 3, "bonus": 1.35,
	"desc": "獅心劍庭的架勢。腳下生根，擋下對手一招之後，下一劍借著那股勢子砍出去，特別重。",
	"lines": [
		"你腳下沒挪半步，劍從擋的位置直接遞了出去。",
		"你借著剛才擋開的勢子，一劍砍得又沉又重。",
		"擋下的那股力道還在你手臂裡，你順著它劈了回去。",
	],
}

## 世界上的七個流派（原型只有劍庭能加入；霜熊戰團的人在世界上走動）。
## ranks：階位的叫法。stance：架勢（會 need 招以上這派的招就生效）
##   lionheart 磐石劍位：擋下一招之後，下一劍重 bonus 倍（STANCE）
##   frostbear 狂戰士之血：血掉到 hp_below 以下，打出去重 bonus 倍
const SCHOOLS := {
	"lionheart": {"name": "獅心劍庭", "ranks": ["", "學徒", "熟手", "大師"], "head": "庭主", "stance": STANCE},
	"frostbear": {"name": "霜熊戰團", "ranks": ["", "新血", "戰士", "老熊"], "head": "團長", "stance": {
		"name": "狂戰士之血", "need": 3, "bonus": 1.3, "hp_below": 0.5,
		"desc": "霜熊戰團的架勢。血流得越多，斧頭越重。",
		"lines": [
			"你身上的傷口在燒，手上的力氣反而多了。",
			"血流進你的眼睛，你連眨都沒眨，一斧劈下去。",
		]}},
	"dawn": {"name": "破曉聖槌", "ranks": ["", "見習", "執槌", "聖槌"], "head": "主教"},
	"thorn": {"name": "鐵棘銳陣", "ranks": ["", "新兵", "陣士", "陣長"], "head": "陣主"},
	"hawk": {"name": "蒼鷹林衛", "ranks": ["", "學徒", "林衛", "鷹眼"], "head": "林主"},
	"blackwater": {"name": "黑水拳環", "ranks": ["", "新人", "拳手", "環主"], "head": "環主"},
	"raven": {"name": "夜鴉隱修會", "ranks": ["", "見習", "隱修", "長老"], "head": "院長"},
}


static func school_name(id: String) -> String:
	return SCHOOLS[id]["name"] if SCHOOLS.has(id) else ""


## 這個人在他流派裡的叫法（學徒、熟手…；掌門用 head）
static func rank_name(p: Person) -> String:
	if not SCHOOLS.has(p.school) or p.rank <= 0:
		return ""
	var s: Dictionary = SCHOOLS[p.school]
	if p.id == HEAD and p.school == ID:
		return s["head"]
	return s["ranks"][mini(p.rank, s["ranks"].size() - 1)]


## 劍庭的委託。kind：monster 打委託板上的怪物、kill 討伐某人、book 拿回劍譜（入門後庭主交代才有）
const JOBS := {
	"wolves": {"kind": "monster", "enemy": "wolf", "merit": 6,
		"text": "劍庭在牧羊村的農莊，羊又被狼咬死了。"},
	"bandits": {"kind": "monster", "enemy": "bandit_leader", "merit": 10,
		"text": "麥田鎮林道上的盜匪，劫了劍庭送去鐵匠鋪的劍。"},
	"deserter": {"kind": "monster", "enemy": "deserter", "merit": 14,
		"text": "石橋上那個逃兵騎士，盾牌上畫著一頭獅子。庭主說，獅心的紋章不能讓這種人用。"},
	"bear": {"kind": "monster", "enemy": "bear", "merit": 18,
		"text": "獵人小屋的熊咬傷了劍庭的一個學徒。"},
	"ogre": {"kind": "monster", "enemy": "ogre", "merit": 30,
		"text": "舊城牆的食人魔抓走了人。劍庭要派人去。"},
	"magnus": {"kind": "kill", "target": "magnus", "merit": 25,
		"text": "紅鬃的副隊長馬格努斯。十年前那一夜，他也在。"},
	"roderick": {"kind": "kill", "target": "roderick", "merit": 50,
		"text": "紅鬃的隊長羅德里克。十年前紅鬃燒了山下的村子，庭主的師弟死在那裡。"},
	"book": {"kind": "book", "book": "verdict_book", "merit": 60,
		"text": "把庭主師弟的劍譜拿回來。"},
}

## 庭主交代劍譜的事（入門的時候）。你拿回來時：returned 交代過之後拿回來；seen 還沒交代你就拿到了；
## 最後一句 keep 還沒讀、keep_read 已經讀過
const ERRAND := {
	"holder": "roderick",
	"book": "verdict_book",
	"ask": "庭主把你留了下來。「十年前，紅鬃的人燒了山下的村子。我師弟在那裡，沒能出來。他身上那本劍譜，後來到了紅鬃那個獨眼隊長手上。」\n他停了一下。「把它拿回來。」",
	"ask_lost": "庭主把你留了下來。「十年前，紅鬃的人燒了山下的村子。我師弟在那裡，沒能出來。他身上那本劍譜，後來到了紅鬃那個獨眼隊長手上。」\n他停了一下。「羅德里克死了，書不知道到了誰手上。找到它，拿回來。」",
	"returned": "庭主接過劍譜，翻了幾頁，手停在一頁的邊上。那裡有幾行小字，是他師弟的筆跡。",
	"seen": "庭主看見你身上那本燒焦的書，伸手要了過去。他翻了幾頁，手停在一頁的邊上。\n「這是我師弟的字。十年前紅鬃燒了山下的村子，他沒能出來。」",
	"keep": "他把書合上，推回你面前：「拿去讀。」",
	"keep_read": "他把書合上，還給你：「讀過了就好。」",
}


static func is_member(p: Person) -> bool:
	return p.school == ID and p.rank > 0


## 會幾招這派的招
static func moves_known(p: Person, school := ID) -> int:
	var n := 0
	for id in MoveData.MOVES:
		if MoveData.school(id) == school and p.knows(id):
			n += 1
	return n


## 這個人身上生效的架勢是哪一派的（空的是沒有）。會最多招的那派先算
static func stance_of(p: Person) -> String:
	for id in SCHOOLS:
		var st: Dictionary = SCHOOLS[id].get("stance", {})
		if not st.is_empty() and moves_known(p, id) >= st["need"]:
			return id
	return ""


static func stance_def(school: String) -> Dictionary:
	return SCHOOLS[school]["stance"]


static func stance_active(p: Person) -> bool:
	return stance_of(p) != ""


## 一派的招照等級排（給人物面板串成一條線）
static func chain(school := ID) -> Array:
	var list := []
	for id in MoveData.MOVES:
		if MoveData.school(id) == school:
			list.append(id)
	list.sort_custom(func(a, b): return MoveData.grade(a) < MoveData.grade(b))
	return list
