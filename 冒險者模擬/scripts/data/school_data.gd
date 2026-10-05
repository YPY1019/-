class_name SchoolData
extends RefCounted

## 流派：北境劍術。只有資料。
##
## 第 1 階：交學費就教。
## 第 2、3 階：錢沒用，要師傅認可（通過考驗），而且數值要到門檻。
## 特訓：付錢請師傅帶你過瓶頸（加快，不是買）。

const NAME := "北境劍術"
const MASTER_ENEMY := "master"

const TIERS := [
	{"tier": 1, "moves": ["parry", "sweep_kick", "heavy"], "cost": 60, "days": 3,
		"exam": "", "exam_name": ""},
	{"tier": 2, "moves": ["redirect", "disarm", "break_free"], "cost": 0, "days": 5,
		"exam": "spar", "exam_name": "接住我三招",
		"exam_desc": "跟師傅用木劍過招三回合。撐過三回合、血掉不到三成就算通過。師傅的力量、敏捷都是 15，差太多的話擋不住也閃不掉。花 1 天，不會真的受傷。"},
	{"tier": 3, "moves": ["vital", "combo"], "cost": 0, "days": 7,
		"exam": "bear", "exam_name": "去打倒熊",
		"exam_desc": "接熊的委託，打贏一次。"},
]

## 招式的數值門檻（沒寫的 = 沒有門檻）
const REQ := {
	"redirect": {"str": 13},
	"disarm": {"agi": 13},
	"break_free": {"str": 13},
	"vital": {"agi": 17},
	"combo": {"str": 17},
}

## 過招考驗
const SPAR_DAYS := 1
const SPAR_ROUNDS := 3
## 血掉到這個比例以下就算輸（掉超過三成）
const SPAR_YIELD := 0.7

## 特訓過瓶頸：第 i 個是從 CAPS[i] 練到 CAPS[i+1]
const TRAIN := [
	{"cost": 300, "days": 10},
	{"cost": 600, "days": 15},
]


static func tier_of(move_id: String) -> int:
	for t in TIERS:
		if t["moves"].has(move_id):
			return t["tier"]
	return 0


static func tier_def(tier: int) -> Dictionary:
	return TIERS[tier - 1]
