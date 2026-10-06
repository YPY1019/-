class_name TownData
extends RefCounted

## 城鎮的數字：錢、時間（月）、委託、休養、打輸。只有資料。

const START_MONEY := 60
## 每個月的生活費
const LIVING_COST := 5
## 休養一個月回復最大血量的幾成
const REST_HEAL := 0.2

## 打輸：重傷被救回，醒在城裡，躺了幾個月
const INJURED_HP := 0.1
const INJURED_MONTHS := 6


## 一般委託（只有討伐）：委託板上的怪物在哪裡、報酬多少。危險度從敵人的數值算（EnemyData.danger）。
## 打完一次就撤下來，越打越久才再出現（World.MONSTER_BACK）。有名字的人的懸賞在 World（PeopleData）。
const COMMISSIONS := {
	"wolf": {"place": "pasture", "reward": 60,
		"text": "村外的野狼咬死了好幾頭羊。牧場主人請人去把牠解決掉。"},
	"bandit_leader": {"place": "wheat", "reward": 100,
		"text": "往麥田鎮的林道上有盜匪攔路搶劫。鎮長懸賞他們的頭目。"},
	"deserter": {"place": "bridge", "reward": 150,
		"text": "一個逃兵騎士佔了石橋，向過路的人收過路費。領主的管家請人去把他趕走。"},
	"bear": {"place": "lodge", "reward": 250,
		"text": "山腳的獵人小屋被大熊拆了。獵人公會請人去討伐。"},
	"ogre": {"place": "old_wall", "reward": 500,
		"text": "食人魔在舊城牆一帶出沒，已經有人被抓走了。城主親自發的懸賞。"},
}

## 練武場：退休的老兵收錢教通用招（綠）。招 id -> 學費、學多久。數值門檻在 SchoolData.REQ
const TRAINING := {
	"knee": {"cost": 40, "months": 3},
	"fallstone": {"cost": 40, "months": 3},
	"shed": {"cost": 50, "months": 4},
	"dust": {"cost": 30, "months": 2},
}
const TRAINER := "老兵哈洛德"
const TRAINER_TEXT := "練武場在城牆根下，地上的沙被踩得很實。老兵哈洛德少了一隻耳朵，教的都是戰場上活下來的招。"

## 開局的名字（玩家角色）
const HERO_NAMES := [["凱爾", "他"], ["羅蘭", "他"], ["艾德", "他"], ["莫琳", "她"], ["蕾娜", "她"], ["班恩", "他"]]
