class_name TownData
extends RefCounted

## 城鎮的數字：錢、天數、委託、休養、打輸。只有資料。

const START_MONEY := 60
## 每天的生活費
const LIVING_COST := 5
## 休養一天回復最大血量的幾成
const REST_HEAL := 0.2

## 打輸：重傷被救回，醒在城裡
const INJURED_HP := 0.1
const INJURED_DAYS := 5

## 偷學：被敵人的招牌招打中幾次就學會
const STEAL_NEED := 3

## 打倒這個就算原型通關
const GOAL := "ogre"

## 委託板（只有討伐）。danger 危險度 1～5；days 來回要幾天；reward 打贏的報酬
const COMMISSIONS := {
	"wolf": {"danger": 1, "days": 2, "reward": 40,
		"text": "村外的野狼咬死了好幾頭羊。牧場主人請人去把牠解決掉。"},
	"bandit_leader": {"danger": 2, "days": 3, "reward": 100,
		"text": "往南的山道上有盜匪攔路搶劫。商會懸賞他們的頭目。"},
	"deserter": {"danger": 3, "days": 3, "reward": 120,
		"text": "一個逃兵騎士佔了石橋，向過路的人收過路費。領主的管家請人去把他趕走。"},
	"bear": {"danger": 4, "days": 4, "reward": 200,
		"text": "山腳的獵人小屋被大熊拆了。獵人公會請人去討伐。"},
	"ogre": {"danger": 5, "days": 5, "reward": 500,
		"text": "食人魔在舊城牆一帶出沒，已經有人被抓走了。城主親自發的懸賞。"},
}
