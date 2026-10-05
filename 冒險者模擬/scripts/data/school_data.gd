class_name SchoolData
extends RefCounted

## 流派：北境劍術。只有資料。
##
## 招式分三階，畫面上叫基礎招、進階招、絕學（暫定，跟「第二境」分開）。
## 基礎招：交學費就教。
## 進階招：錢沒用，要師傅認可（通過考驗「接住我三招」），而且數值要到門檻。
## 絕學：口訣 ＋ 實戰悟出。師傅不直接教：
##   1. 通過「接住我三招」後，師傅交代一件事（ERRAND：打倒他的仇人）。
##   2. 辦到了，師傅傳口訣（MoveData 的 lore）。
##   3. 之後在一場硬仗裡，對手露出大破綻，角色第一次用出來，從此學會。回城師傅才說出招名。
## 北境劍術看你做了什麼：傳口訣靠替師傅辦事。每個流派傳口訣的方式不一樣。
## 高階的招比低階的強：學了高階，角色就改用高階的。
## 師傅不能帶你過瓶頸（實力和認可是兩回事）。

const NAME := "北境劍術"
const MASTER_ENEMY := "master"

const TIERS := [
	{"tier": 1, "name": "基礎招", "moves": ["parry", "sweep_kick", "heavy"], "cost": 60, "days": 3, "exam": ""},
	{"tier": 2, "name": "進階招", "moves": ["redirect", "disarm", "break_free", "vital", "combo"], "cost": 0, "days": 5,
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
## 師傅交代的事：打倒誰、他怎麼說、辦到之後怎麼說、你悟出來之後他怎麼說
const ERRAND := {
	"target": "merc_captain",
	"ask": "師傅把你留了下來。「十年前，紅鬃的人燒了山下的村子。我師弟在那裡，沒能出來。帶頭的那個獨眼，現在還活著。」\n他沒有再說下去。",
	"heard": "師傅看了你一眼：「羅德里克的事，我聽說了。」",
	"done": "師傅聽你說完，很久沒有開口。最後他說：「我只說一遍。」\n「敵人站不穩的時候，別砍他的劍，砍他的人。」",
	"lore": "「敵人站不穩的時候，別砍他的劍，砍他的人。」",
	"reminder": "師傅說過：「帶頭的那個獨眼，現在還活著。」",
	"named": "師傅看了你身上的傷，又看了看你的劍。「那一劍，北境的人叫它北境裁決。」",
}

## 過招考驗
const SPAR_DAYS := 1
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
