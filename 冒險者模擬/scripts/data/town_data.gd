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


## 一般委託（只有討伐）：委託板上的怪物會在哪幾個地方出沒（每次出現換一個，見 World.monster_place）、報酬多少。
## 危險度從敵人的數值算（EnemyData.danger）。報酬打完回公會交差才拿得到。
## 打完一次就撤下來，越打越久才再出現（World.MONSTER_BACK）。有名字的人的懸賞在 World（PeopleData）。
## text 的 {place}：這次出沒的地方
const COMMISSIONS := {
	"wolf": {"places": ["pasture", "lodge", "south_road"], "reward": 60,
		"text": "{place}附近的野狼咬死了好幾頭羊。牧場主人請人去把牠解決掉。"},
	"bandit_leader": {"places": ["wheat", "south_road", "bridge"], "reward": 100,
		"text": "往{place}的路上有盜匪攔路搶劫。鎮長懸賞他們的頭目。"},
	"deserter": {"places": ["bridge", "relay", "wheat"], "reward": 150,
		"text": "一個逃兵騎士佔了{place}的路口，向過路的人收過路費。領主的管家請人去把他趕走。"},
	"bear": {"places": ["lodge", "pasture", "south_road"], "reward": 250,
		"text": "{place}附近出了一頭大熊，拆了兩間屋子。獵人公會請人去討伐。"},
	"ogre": {"places": ["old_wall", "coast", "fortress"], "reward": 500,
		"text": "食人魔在{place}一帶出沒，已經有人被抓走了。城主親自發的懸賞。"},
}

## 武器店收來的好東西的價錢：等級 × 這個數
const RARE_PRICE := 300
const BOOK_PRICE := 250

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
