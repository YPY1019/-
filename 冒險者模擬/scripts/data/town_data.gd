class_name TownData
extends RefCounted

## 城鎮的數字：錢、時間（月）、委託、休養、打輸。只有資料。

const START_MONEY := 60
## 每個月的生活費
const LIVING_COST := 10
## 休養一個月回復最大血量的幾成
const REST_HEAL := 0.4

## 打輸：重傷被救回，醒在城裡，躺了幾個月
const INJURED_HP := 0.1
const INJURED_MONTHS := 3

## 偷學：被敵人的招牌招打中幾次就學會
const STEAL_NEED := 3

## 打倒這個就算原型通關
const GOAL := "ogre"

## 委託板（只有討伐）。危險度從敵人的數值算（EnemyData.danger）；months 來回加上找人要幾個月；reward 打贏的報酬
const COMMISSIONS := {
	"wolf": {"months": 1, "reward": 60,
		"text": "村外的野狼咬死了好幾頭羊。牧場主人請人去把牠解決掉。"},
	"bandit_leader": {"months": 1, "reward": 100,
		"text": "往南的山道上有盜匪攔路搶劫。商會懸賞他們的頭目。"},
	"deserter": {"months": 1, "reward": 150,
		"text": "一個逃兵騎士佔了石橋，向過路的人收過路費。領主的管家請人去把他趕走。"},
	"bear": {"months": 2, "reward": 250,
		"text": "山腳的獵人小屋被大熊拆了。獵人公會請人去討伐。"},
	"ogre": {"months": 2, "reward": 500,
		"text": "食人魔在舊城牆一帶出沒，已經有人被抓走了。城主親自發的懸賞。"},
	# 懸賞：有名字的強者，打倒了就不會再出現
	"merc_captain": {"months": 2, "reward": 300,
		"text": "傭兵團「紅鬃」洗劫了東邊的兩個村子。商會懸賞隊長羅德里克的人頭。"},
	"black_knight": {"months": 2, "reward": 400,
		"text": "被逐出騎士團的黑騎士佔了舊王家驛站，往來的信使一個都沒回來。騎士團私下發的懸賞。"},
}
