class_name LifeData
extends RefCounted

## 一生的數字：出道年紀、壽命、老化，和等的畫面、老了的戰報用的句子。只有資料和換算。
##
## 時間用「月」算。冒險者身上記的是出道以來過了幾個月（Adventurer.month）。
## 每年 1 月長一歲。壽命到了（滿 LIFESPAN 歲的那個 1 月）就是一生結束。
## 原型的一生壓短（內容只夠玩一小時左右），之後內容變多再拉長。
##
## 老化：過了某個年紀，身體每兩年掉一點。敏捷先掉，再晚一點力量也掉。
##   掉的是「現在的身體」，練出來的底子還在：招式、秘笈、武器都不掉，境界也不掉。

const START_AGE := 16
## 出道那年的幾月
const START_MONTH := 3
const LIFESPAN := 36

## 過了這個年紀，這一項每 DECLINE_YEARS 年掉 1 點
const DECLINE_AGE := {"agi": 28, "str": 30}
const DECLINE_YEARS := 2

const SEASONS := {12: "winter", 1: "winter", 2: "winter", 3: "spring", 4: "spring", 5: "spring",
	6: "summer", 7: "summer", 8: "summer", 9: "autumn", 10: "autumn", 11: "autumn"}


## 出道後過了 month 個月，是幾歲
static func age_at(month: int) -> int:
	return START_AGE + (START_MONTH - 1 + month) / 12


## 出道後過了 month 個月，是幾月
static func month_of_year(month: int) -> int:
	return (START_MONTH - 1 + month) % 12 + 1


## 「23 歲 4 月」
static func date_text(month: int) -> String:
	return "%d 歲 %d 月" % [age_at(month), month_of_year(month)]


## 從出道到壽命用完，一共幾個月
static func life_months() -> int:
	return (LIFESPAN - START_AGE) * 12 - (START_MONTH - 1)


## 「1 年 6 個月」「3 個月」「1 年」
static func span_text(months: int) -> String:
	var y := months / 12
	var m := months % 12
	if y == 0:
		return "%d 個月" % m
	if m == 0:
		return "%d 年" % y
	return "%d 年 %d 個月" % [y, m]


## 這個年紀，這一項掉了幾點
static func decline(stat: String, age: int) -> int:
	return maxi(0, age - DECLINE_AGE[stat]) / DECLINE_YEARS


# ---- 等的畫面 ----
## 花時間的事：剛開始的一句、快結束的一句（要花三個月以上才寫）。中間換季時寫季節。
const WAIT_LINES := {
	"travel": {
		"start": [
			"你收拾好東西，天還沒亮就出了城門。",
			"你跟著一隊往同個方向的商隊走了幾天。",
			"路上下了兩天雨，你在一間穀倉裡等雨停。",
			"你在路邊的酒館問了幾次路。",
		],
		"end": [],
	},
	"learn": {
		"start": [
			"師傅把同一個動作拆成三段，要你一段一段做。",
			"道場的木樁上全是刀痕，你在上面又添了幾道。",
			"天還沒亮，你已經在道場裡揮了兩百下。",
			"師傅看你做了一遍，什麼都沒說，叫你再做一遍。",
		],
		"end": [
			"師傅這次看完，點了一下頭。",
			"有一天你不用想，手自己就動了。",
		],
	},
	"read": {
		"start": [
			"你把劍譜攤在旅店的桌上，一頁一頁看劍圖。",
			"有幾頁的字被燒掉了，你只能看圖猜。",
			"白天照著劍圖比劃，晚上點著蠟燭再翻一遍。",
		],
		"end": [
			"你翻到最後一頁，又從第一頁翻起。",
			"書頁的邊角被你翻得起了毛。",
		],
	},
	"rest": {
		"start": [
			"你在旅店的床上躺了好幾天，每天換一次藥。",
			"傷口結了痂，癢得睡不著。",
			"你每天早上沿著城牆慢慢走一圈。",
			"老闆娘煮的湯很鹹，你還是每天喝完。",
		],
		"end": [
			"你試著揮了幾下劍，傷口沒有再裂開。",
		],
	},
	"injured": {
		"start": [
			"你醒來的時候，已經躺在旅店裡了。",
			"頭幾天你連翻身都會痛。",
		],
		"end": [
			"你扶著牆走到窗邊，外面的人來來去去。",
			"大夫說你命大。",
		],
	},
}

const SEASON_LINES := {
	"spring": ["城外的雪化了，路上全是泥。", "河邊的柳樹發了芽。", "田裡開始有人在翻土。"],
	"summer": ["天熱得連狗都躲在屋簷下。", "傍晚下了一場大雨，街上的灰塵都被沖掉了。", "市集上開始賣起了莓果。"],
	"autumn": ["山上的樹林黃了一片。", "農人在收麥子，城門口塞滿了運糧的車。", "早晚開始有點涼了。"],
	"winter": ["下雪了。城裡的屋頂一片白。", "井口結了冰，打水要先敲開。", "旅店的爐火從早燒到晚。"],
}

## 壽命用完的那一刻
const DEATH_TEXT := "那年冬天特別冷。你在旅店的房間裡睡著，就沒有再醒來。"


# ---- 老了的戰報 ----
## 身體掉了的那一項，打的時候偶爾寫一句
const AGED_LINES := {
	"agi": [
		"你踏出去的那一步，比你想的短了一點。",
		"幾個來回下來，你的呼吸已經亂了。",
		"你的眼睛跟得上，腳跟不太上。",
		"你退了一步，趁空檔換了一口氣。",
	],
	"str": [
		"這把劍握在手裡，比幾年前沉。",
		"你的手臂開始發酸。",
		"收劍的時候，你的肩膀抽了一下。",
	],
}
## 一場最多寫幾次；每回合寫的機率（掉越多越常寫）
const AGED_MAX_PER_FIGHT := 2
const AGED_CHANCE_PER_POINT := 0.1
const AGED_CHANCE_MAX := 0.45
