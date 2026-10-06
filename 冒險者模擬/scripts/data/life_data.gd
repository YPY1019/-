class_name LifeData
extends RefCounted

## 一生的數字：出道年紀、壽命、老化、快死的徵兆，和等的畫面、老了的戰報用的句子。只有資料和換算。
##
## 時間用「月」算：世界開局以來過了幾個月（Clock.month）。開局那年是第 0 年，每年 1 月長一歲。
## 每個人記的是哪一年出生（born_year）和哪個月會死（dies_at，看不到）。
## 壽命看不到（參考俠客遊第三之書）：畫面上只寫年紀。冒險者的壽命在 LIFESPAN_MIN～LIFESPAN_MAX 歲之間隨機。
## 原型的一生壓短（內容只夠玩幾個小時），之後內容變多再拉長。
##
## 老化：過了某個年紀，身體每幾年掉一點。敏捷先掉，再晚一點力量也掉。幾歲開始掉不寫出來。
##   掉的是「現在的身體」，練出來的底子還在：招式、秘笈、武器都不掉，境界也不掉。
## 快死：死前 OMEN_MONTHS 個月開始有徵兆（戰報裡會喘、休養變慢、旁人說你氣色不好），越來越明顯；
##   死前 DYING_MONTHS 個月病倒（臨終），不能出遠門，只能安排後事。

const START_AGE := 16
## 開局那年的幾月
const START_MONTH := 3
## 冒險者的壽命（歲）的範圍，含頭含尾。死在那一歲的隨機一個月
const LIFESPAN_MIN := 36
const LIFESPAN_MAX := 42

## 過了這個年紀，這一項每 DECLINE_YEARS 年掉 1 點
const DECLINE_AGE := {"agi": 30, "str": 33}
const DECLINE_YEARS := 3

## 死前幾個月開始有徵兆、死前幾個月病倒
const OMEN_MONTHS := 36
const DYING_MONTHS := 3
## 有徵兆的時候休養變慢（最明顯時剩幾成）
const OMEN_REST_MIN := 0.5

const SEASONS := {12: "winter", 1: "winter", 2: "winter", 3: "spring", 4: "spring", 5: "spring",
	6: "summer", 7: "summer", 8: "summer", 9: "autumn", 10: "autumn", 11: "autumn"}


## 世界的第 month 個月是第幾年（開局那年是 0）
static func year_of(month: int) -> int:
	return (START_MONTH - 1 + month) / 12


## 世界的第 month 個月是幾月
static func month_of_year(month: int) -> int:
	return (START_MONTH - 1 + month) % 12 + 1


## 第 year 年的 1 月是世界的第幾個月
static func year_start(year: int) -> int:
	return year * 12 - (START_MONTH - 1)


## 「23 歲 4 月」
static func date_text(age: int, month: int) -> String:
	return "%d 歲 %d 月" % [age, month_of_year(month)]


## 擲一個人死在世界的第幾個月：age_min～age_max 歲那年的隨機一個月，至少在 after 之後
static func roll_dies_at(rng: RandomNumberGenerator, born_year: int, age_min: int, age_max: int, after := 0) -> int:
	var age := rng.randi_range(age_min, age_max)
	return maxi(after + 1, year_start(born_year + age) + rng.randi_range(0, 11))


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


## 徵兆有多明顯：0 = 還沒有，1 = 快死了。left：離死還有幾個月
static func omen(left: int) -> float:
	return clampf(1.0 - float(left - DYING_MONTHS) / (OMEN_MONTHS - DYING_MONTHS), 0.0, 1.0)


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
			"教你的人把同一個動作拆成三段，要你一段一段做。",
			"木樁上全是刀痕，你在上面又添了幾道。",
			"天還沒亮，你已經揮了兩百下。",
			"教你的人看你做了一遍，什麼都沒說，叫你再做一遍。",
		],
		"end": [
			"這次做完，教你的人點了一下頭。",
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
	"watch": {
		"start": [
			"你提著燈，沿著城牆走了一圈又一圈。",
			"半夜有人在巷子裡吵架，看見劍庭的灰衣就散了。",
			"天快亮的時候最冷，你把手縮在袖子裡。",
		],
		"end": [
			"輪到下一個人接班，你回劍庭睡了一整天。",
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
			"你試著揮了幾下，傷口沒有再裂開。",
		],
	},
	"travel_back": {
		"start": [
			"你在路邊的樹下歇了好幾次腳。",
			"一輛運貨的馬車讓你搭了一段。",
			"你遠遠就看見了城牆。",
		],
		"end": [],
	},
	"dying": {
		"start": [
			"你躺在旅店的床上，聽著樓下的人說話。",
			"老闆娘每天端一碗湯上來，你只喝得下幾口。",
			"有人來看你，坐了一會兒就走了。",
		],
		"end": [
			"窗外的天亮了又暗，你分不太清楚過了幾天。",
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

## 壽命用完的那一刻（看季節）
const DEATH_TEXT := {
	"spring": "那年春天，你在旅店的房間裡睡著，就沒有再醒來。窗外的柳樹剛發芽。",
	"summer": "那年夏天的一個晚上，你說有點累，早早就睡了，就沒有再醒來。",
	"autumn": "那年秋天，你坐在旅店門口曬太陽，坐著坐著就睡著了。老闆娘來叫你吃飯時，你已經走了。",
	"winter": "那年冬天特別冷。你在旅店的房間裡睡著，就沒有再醒來。",
}


## 病倒的那一刻（臨終開始）。away：在城外病倒，被人送回來
const FALL_ILL_TEXT := "那天早上你想起身，腿卻不聽使喚。大夫來看過，搖了搖頭，什麼都沒說。"
const FALL_ILL_AWAY_TEXT := "你在路上病倒了。一隊往霜溪城去的商隊把你抬上了車。"

## 快死的徵兆：旁人說的話（等的時候偶爾寫一句）、休養時的句子、戰報裡的句子
const OMEN_TOWN_LINES := [
	"旅店老闆娘端湯給你的時候，多看了你一眼：「你最近氣色不太好。」",
	"道場門口的學徒跟你打招呼，又小聲問旁邊的人：「他是不是瘦了？」",
	"你夜裡咳醒了好幾次。",
	"早上起來，枕頭上有幾根白頭髮。",
	"爬旅店的樓梯，你在中間停下來喘了一口氣。",
]
const OMEN_REST_LINES := [
	"傷口好得比以前慢。",
	"你睡了很久，醒來還是覺得累。",
]
## 戰報裡寫喘、咳的機率（徵兆最明顯時）
const OMEN_BATTLE_CHANCE := 0.4
const OMEN_BATTLE_LINES := [
	"你胸口一緊，咳了兩聲。",
	"才幾個來回，你已經喘得像跑了一整天。",
	"你眼前黑了一下，又亮起來。",
	"你的手抖了一下，{my}差點沒握住。",
]


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
		"這把{my}握在手裡，比幾年前沉。",
		"你的手臂開始發酸。",
		"收手的時候，你的肩膀抽了一下。",
	],
}
## 一場最多寫幾次；每回合寫的機率（掉越多越常寫）
const AGED_MAX_PER_FIGHT := 2
const AGED_CHANCE_PER_POINT := 0.1
const AGED_CHANCE_MAX := 0.45
