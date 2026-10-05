class_name SchoolData
extends RefCounted

## 流派：北境劍術。只有資料。
##
## 招式分三階，畫面上叫基礎招、進階招、絕學（暫定，跟「第二境」分開）。
## 基礎招：交學費就教。
## 進階招、絕學：錢沒用，要師傅認可（通過考驗），而且數值要到門檻。
## 高階的招比低階的強（自動戰鬥試驗）：學了高階，角色就改用高階的。
## 絕學只有一招（見 MoveData 的 ult）：通過「接住我三招」、又升到第二境，師傅就叫你過去教你。難的是升境本身。
## 師傅不能帶你過瓶頸（實力和認可是兩回事）。

const NAME := "北境劍術"
const MASTER_ENEMY := "master"

const TIERS := [
	{"tier": 1, "name": "基礎招", "moves": ["parry", "sweep_kick", "heavy"], "cost": 60, "days": 3,
		"exam": "", "exam_name": ""},
	{"tier": 2, "name": "進階招", "moves": ["redirect", "disarm", "break_free", "vital", "combo"], "cost": 0, "days": 5,
		"exam": "spar", "exam_name": "接住我三招",
		"exam_desc": "跟師傅木劍過招三回合，血掉不到四成就過。"},
	{"tier": 3, "name": "絕學", "moves": ["sunder"], "cost": 0, "days": 7,
		"exam": "realm", "exam_name": "第二境",
		"exam_desc": ""},
]

## 招式的數值門檻（沒寫的 = 沒有門檻）
const REQ := {
	"redirect": {"str": 13},
	"disarm": {"agi": 13},
	"break_free": {"str": 13},
	"vital": {"agi": 14},
	"combo": {"str": 15},
}

## 師傅教絕學的那一幕
const ULT_SCENE := "師傅帶你到道場後面的空地，叫你站到一邊看。\n他只劈了一劍。你沒看清楚，只看到空地邊上的木樁斷成了兩截。\n「北境裁決。」師傅把劍收起來，「練吧。」\n你在雪地裡練了七天。"
## 升到第幾境（0 起算）師傅才教絕學
const ULT_REALM := 1

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
