class_name TownData
extends RefCounted

## 城鎮的數字：錢、時間（月）、委託、休養、打輸。只有資料。

const START_MONEY := 60
## 在公會打聽一個人的下落：多少錢（越強的人越貴：基本價 + 每一境加多少）、之後幾個月有他的消息（地圖上標出他在哪）
const INQUIRE_COST := 40
const INQUIRE_PER_REALM := 40
const INQUIRE_MONTHS := 6
## 休養一個月回復最大血量的幾成
const REST_HEAL := 0.2

## 打輸：重傷被救回，醒在城裡，躺了幾個月
const INJURED_HP := 0.1
const INJURED_MONTHS := 6


## 一般委託（只有討伐）：委託板上的怪物在哪裡出沒（固定一個地方）、報酬多少。
## 危險度從敵人的數值算（EnemyData.danger）。報酬打完回公會交差才拿得到。
## 打完一次就撤下來，越打越久才再出現（World.MONSTER_BACK）。有名字的人的懸賞在 World（PeopleData）。
## text 的 {place}：這次出沒的地方
const COMMISSIONS := {
	"wolf": {"place": "pasture", "reward": 60,
		"text": "{place}附近的野狼咬死了好幾頭羊。牧場主人請人去把牠解決掉。"},
	"bandit_leader": {"place": "wheat", "reward": 100,
		"text": "往{place}的路上有盜匪攔路搶劫。鎮長懸賞他們的頭目。"},
	"deserter": {"place": "bridge", "reward": 150,
		"text": "一個逃兵騎士佔了{place}，向過路的人收過路費。領主的管家請人去把他趕走。"},
	"bear": {"place": "lodge", "reward": 250,
		"text": "{place}附近出了一頭大熊，拆了兩間屋子。獵人公會請人去討伐。"},
	"ogre": {"place": "old_wall", "reward": 500,
		"text": "食人魔在{place}一帶出沒，已經有人被抓走了。城主親自發的懸賞。"},
	"boar": {"place": "south_road", "reward": 70,
		"text": "{place}一帶有野豬拱壞了好幾片田，還撞傷了一個趕車的。"},
	"poacher": {"place": "lodge", "reward": 140,
		"text": "{place}附近有人下套子盜獵。獵人公會派人去看過一次，那個人沒回來。"},
	"smuggler": {"place": "coast", "reward": 160,
		"text": "{place}的碼頭有一夥走私的，打傷了收稅的人。稅務官出錢請人去收拾。"},
	"pikeman": {"place": "relay", "reward": 240,
		"text": "一個逃營的長槍兵占了{place}，攔下過路的馬車收錢。驛站的主人請人去把他趕走。"},
	"alpha_wolf": {"place": "pasture", "reward": 260,
		"text": "{place}外面的狼群換了一頭頭狼，這個冬天已經咬死了兩個牧人。"},
	"elk": {"place": "south_road", "reward": 380,
		"text": "{place}的山路上有一頭巨角鹿，頂翻了好幾輛馬車。"},
	"butcher": {"place": "old_wall", "reward": 420,
		"text": "{place}的缺口裡住著一個屠夫。附近一直有人失蹤。"},
	"croc": {"place": "coast", "reward": 600,
		"text": "{place}的泥灘上有一條老鱷，拖走了一個撿蛤蜊的孩子。"},
	"troll": {"place": "fortress", "reward": 900,
		"text": "{place}有巨魔出沒，要塞的補給隊過不去。領主出了重賞。"},
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
const HERO_NAMES := [["凱爾", "他"], ["羅蘭", "他"], ["艾德", "他"], ["莫琳", "她"], ["伊芙", "她"], ["班恩", "他"]]
