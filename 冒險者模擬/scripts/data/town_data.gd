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

## 偷學：被敵人的招牌招打中幾次就學會
const STEAL_NEED := 3


## 委託板（只有討伐）。危險度從敵人的數值算（EnemyData.danger）；months 來回加上找人要幾個月；reward 打贏的報酬
const COMMISSIONS := {
	"wolf": {"months": 2, "reward": 60,
		"text": "村外的野狼咬死了好幾頭羊。牧場主人請人去把牠解決掉。"},
	"bandit_leader": {"months": 2, "reward": 100,
		"text": "往南的山道上有盜匪攔路搶劫。商會懸賞他們的頭目。"},
	"deserter": {"months": 2, "reward": 150,
		"text": "一個逃兵騎士佔了石橋，向過路的人收過路費。領主的管家請人去把他趕走。"},
	"bear": {"months": 4, "reward": 250,
		"text": "山腳的獵人小屋被大熊拆了。獵人公會請人去討伐。"},
	"ogre": {"months": 9, "reward": 500,
		"text": "食人魔在舊城牆一帶出沒，已經有人被抓走了。城主親自發的懸賞。"},
	# 懸賞：有名字的強者，打倒了就不會再出現
	"merc_captain": {"months": 9, "reward": 300,
		"text": "傭兵團「紅鬃」洗劫了東邊的兩個村子。商會懸賞隊長羅德里克的人頭。"},
	"raider": {"months": 9, "reward": 300,
		"text": "北邊海岸的漁村被燒了兩個。劫掠者烏爾夫帶著手下往內陸來了，沿岸的領主懸賞他。"},
	"duelist": {"months": 9, "reward": 350,
		"text": "南方來的決鬥家伊薇特在城裡殺了三個貴族子弟，說是決鬥，沒人告得了她。死者的家族私下懸賞。"},
	"black_knight": {"months": 9, "reward": 400,
		"text": "被逐出騎士團的黑騎士佔了舊王家驛站，往來的信使一個都沒回來。騎士團私下發的懸賞。"},
	"old_captain": {"months": 9, "reward": 450,
		"text": "老衛隊長葛雷森替放高利貸的人收債，打斷了好幾個人的手。商會懸賞趕走他。"},
	"rebel_lord": {"months": 12, "reward": 600,
		"text": "叛將瓦倫佔了山口的舊要塞，往來的商隊都要給他抽成。領主派兵打了兩次都沒打下來，只好懸賞他的命。"},
}
