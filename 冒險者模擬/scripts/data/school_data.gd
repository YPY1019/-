class_name SchoolData
extends RefCounted

## 流派：北境劍術。只有資料。
##
## 招式分三階，畫面上叫基礎招、進階招、絕學（暫定，跟「第二境」分開）。
## 基礎招：交學費就教。
## 進階招：錢沒用，要師傅認可（通過考驗「接住我三招」），而且數值要到門檻。
## 絕學：高級秘笈（BookData）。不在道場學：
##   1. 通過「接住我三招」後，師傅交代一件事（ERRAND：把劍譜從他的仇人身上拿回來）。
##   2. 打倒仇人，劍譜在戰利品裡。拿回城，師傅看過之後讓你留著讀。
##   3. 在城裡花時間讀完就學會（讀秘笈不用等師傅）。
## 北境劍術給秘笈的方式是替師傅辦事。每個流派給秘笈的方式不一樣。
## 高階的招比低階的強：學了高階，角色就改用高階的。
## 師傅不能帶你過瓶頸（實力和認可是兩回事）。

const NAME := "北境劍術"
const MASTER_ENEMY := "master"

const TIERS := [
	{"tier": 1, "name": "基礎招", "moves": ["parry", "sweep_kick", "heavy"], "cost": 60, "months": 6, "exam": ""},
	{"tier": 2, "name": "進階招", "moves": ["redirect", "disarm", "break_free", "vital", "combo"], "cost": 0, "months": 12,
		"exam": "spar", "exam_name": "接住我三招", "exam_quote": "「三招。接住了，進階招就教你。」"},
	{"tier": 3, "name": "絕學", "moves": ["sunder"], "exam": "errand"},
]

## 招式的數值門檻（沒寫的 = 沒有門檻）
const REQ := {
	"redirect": {"str": 13},
	"disarm": {"agi": 13},
	"break_free": {"str": 13},
	"vital": {"agi": 14},
	"combo": {"str": 15},
}

## 絕學
const ULT := "sunder"
## 師傅交代的事：打倒誰、拿回哪本書、他怎麼交代、提醒。
## 你拿回來時：returned 交代過之後拿回來；seen 還沒交代你就拿到了（考驗過了他才看見）；
## 最後一句 keep 還沒讀、keep_read 已經讀過
const ERRAND := {
	"target": "merc_captain",
	"book": "sunder_book",
	"ask": "師傅把你留了下來。「十年前，紅鬃的人燒了山下的村子。我師弟在那裡，沒能出來。他身上那本劍譜，後來到了紅鬃那個獨眼隊長手上。」\n他停了一下。「把它拿回來。」",
	"reminder": "師傅說過：「把它拿回來。」",
	"returned": "師傅接過劍譜，翻了幾頁，手停在一頁的邊上。那裡有幾行小字，是他師弟的筆跡。",
	"seen": "師傅看見你身上那本燒焦的書，伸手要了過去。他翻了幾頁，手停在一頁的邊上。\n「這是我師弟的字。十年前紅鬃燒了山下的村子，他沒能出來。」",
	"keep": "他把書合上，推回你面前：「拿去讀。」",
	"keep_read": "他把書合上，還給你：「讀過了就好。」",
}

## 過招考驗
const SPAR_MONTHS := 2
const SPAR_ROUNDS := 3
## 血掉到這個比例以下就算輸（掉超過四成）
const SPAR_YIELD := 0.6


static func tier_of(move_id: String) -> int:
	for t in TIERS:
		if t["moves"].has(move_id):
			return t["tier"]
	return 0


static func tier_def(tier: int) -> Dictionary:
	return TIERS[tier - 1]
