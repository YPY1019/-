class_name EnemyData
extends RefCounted

## 敵人資料。
## 同一種動作的描述要有同一個「看得出來的特徵」，玩家才看得懂：
##   sweep  橫掃：往一側拉得很開、身體扭過去
##   thrust 直衝：壓低身子、直直對準你
##   smash  重砸：高高舉過頭頂 / 高高躍起
##   guard  防守：縮到盾牌後面
##   opening 破綻：喘氣、動作慢下來、卡住
##
## intents：平常隨機出招的權重（w）、描述（tell）、打中你的描述（hit）。
## habits：習慣和連招。每回合從上往下找，第一條符合的就照做；都不符合才隨機。
##   last      上一個動作是這個
##   last_seq  最近兩個動作是這樣
##   player    你上回合用了這些招之一
##   chance    符合時有多少機率照做（沒寫 = 一定）
##   rage      true = 只在發狂時；false = 只在沒發狂時
##   then      下一個動作類型；tell 可以換掉描述（要保留同一個特徵）
##   charge    true = 蓄力，下一次攻擊特別重
## rage：血量低於 hp_below 時發狂，印出 text，之後改用 weights 隨機。
## armor：none / light / heavy。big = 體型大，掃不倒。

## 被逼出來的破綻（不是自己選的動作）
const FORCED_OPENING := {
	"smash_missed": "{name}一擊落空，身體還收不回來。",
	"tripped": "{name}摔倒在地上，正掙扎著要爬起來。",
	"guard_broken": "{name}的防守被震開，整個胸口空了出來。",
}

## 蓄力後的攻擊傷害倍率
const CHARGE_MULT := 1.8

const ORDER := ["wolf", "bandit_leader", "deserter", "bear", "ogre"]

const ENEMIES := {
	"wolf": {
		"name": "野狼",
		"blurb": "森林裡常見的野獸，動作很快。",
		"hp": 40, "atk": 12, "armor": "none", "big": false,
		"weapon": "利牙", "guard": "架勢",
		"intents": {
			"thrust": {"w": 55, "tell": "野狼壓低身子，眼睛直直對準你的喉嚨。", "hit": "野狼一口咬在你身上。"},
			"smash": {"w": 25, "tell": "野狼後腿一蹬，高高躍起，要從上面撲下來。", "hit": "野狼從上面把你撲倒在地。"},
			"opening": {"w": 20, "tell": "野狼繞著你慢慢踱步，吐著舌頭喘氣。"},
		},
		"habits": [
			# 撲空了馬上轉身再撲
			{"last": "thrust", "player": ["dodge"], "then": "thrust", "tell": "野狼落地馬上轉身，又壓低身子對準你的喉嚨。"},
		],
	},
	"bandit_leader": {
		"name": "盜匪頭子",
		"blurb": "在路上攔人搶劫的盜匪頭目，拿著一把大刀。",
		"hp": 75, "atk": 16, "armor": "light", "big": false,
		"weapon": "大刀", "guard": "架勢",
		"intents": {
			"sweep": {"w": 40, "tell": "盜匪頭子把大刀往身體右側拉得很開，腰跟著扭了過去。", "hit": "大刀從側面掃中了你。"},
			"thrust": {"w": 30, "tell": "盜匪頭子壓低身子，刀尖直直對準你的胸口。", "hit": "刀尖刺進了你的身體。"},
			"smash": {"w": 30, "tell": "盜匪頭子雙手把大刀高高舉過頭頂。", "hit": "大刀從頭頂劈中了你。"},
			"opening": {"w": 0, "tell": "盜匪頭子大口喘氣，刀尖垂到了地上。"},
		},
		"habits": [
			# 橫掃之後常常順勢舉刀重劈
			{"last": "sweep", "chance": 0.7, "then": "smash", "tell": "盜匪頭子順著掃刀的勢頭，把大刀高高舉過頭頂。"},
		],
		"rage": {
			"hp_below": 0.35,
			"text": "盜匪頭子滿臉是血，紅著眼睛大吼，刀法亂了起來。",
			"weights": {"sweep": 35, "thrust": 15, "smash": 30, "opening": 20},
		},
	},
	"deserter": {
		"name": "逃兵騎士",
		"blurb": "從戰場逃出來的騎士，一身鐵甲，拿著盾和長劍。",
		"hp": 60, "atk": 18, "armor": "heavy", "big": false,
		"weapon": "長劍", "guard": "盾牌",
		"intents": {
			"guard": {"w": 45, "tell": "逃兵騎士縮到盾牌後面，一步一步逼過來。"},
			"thrust": {"w": 35, "tell": "逃兵騎士壓低身子，劍尖直直對準你的胸口。", "hit": "長劍刺進了你的身體。"},
			"sweep": {"w": 20, "tell": "逃兵騎士把長劍往身體右側拉得很開，腰跟著扭了過去。", "hit": "長劍從側面掃中了你。"},
		},
		"habits": [
			# 你砍在盾上，他從盾後反刺
			{"last": "guard", "player": ["attack", "vital", "sweep_kick"], "then": "thrust", "tell": "逃兵騎士從盾牌後面猛地壓低身子，劍尖直直對準你的胸口。"},
			# 你不出手，他逼到面前就掃
			{"last_seq": ["guard", "guard"], "then": "sweep", "tell": "逃兵騎士逼到你面前，把長劍往身體右側拉得很開，腰跟著扭了過去。"},
		],
	},
	"bear": {
		"name": "熊",
		"blurb": "比人還高的大熊，皮又厚又硬。",
		"hp": 90, "atk": 16, "armor": "light", "big": true,
		"weapon": "熊掌", "guard": "架勢",
		"intents": {
			"sweep": {"w": 70, "tell": "熊把右掌往旁邊拉得很開，肩膀跟著扭了過去。", "hit": "熊掌從側面拍中了你。"},
			"smash": {"w": 30, "tell": "熊人立而起，兩隻前掌高高舉過頭頂。", "hit": "熊掌從上面把你壓倒在地。"},
			"opening": {"w": 0, "tell": "熊甩著頭，喘著粗氣，動作慢了下來。"},
		},
		"habits": [
			# 節奏：拍、拍、站起來砸、喘氣
			{"last_seq": ["sweep", "sweep"], "then": "smash"},
			{"last": "smash", "rage": false, "then": "opening"},
			# 發狂後砸完不喘，馬上再拍
			{"last": "smash", "rage": true, "then": "sweep", "tell": "熊一落地毫不停頓，又把右掌往旁邊拉得很開。"},
		],
		"rage": {
			"hp_below": 0.4,
			"text": "熊被打痛了，眼睛發紅，吼聲震得你耳朵發疼。",
			"weights": {"sweep": 50, "smash": 50},
		},
	},
	"ogre": {
		"name": "食人魔",
		"blurb": "兩個人高的怪物，拖著一根大木棍。",
		"hp": 150, "atk": 22, "armor": "none", "big": true,
		"weapon": "木棍", "guard": "架勢",
		"charged_tell": "牠全身的肌肉還鼓著。",
		"intents": {
			"sweep": {"w": 50, "tell": "食人魔把木棍往身體一側拉得很開，整個上身跟著扭了過去。", "hit": "木棍從側面把你掃飛出去。"},
			"smash": {"w": 50, "tell": "食人魔雙手把木棍高高舉過頭頂。", "hit": "木棍從頭頂砸中了你。"},
			"opening": {"w": 0, "tell": "食人魔喘著粗氣，木棍拖在地上。"},
		},
		"habits": [
			# 砸下去木棍會卡在土裡
			{"last": "smash", "chance": 0.6, "then": "opening", "tell": "食人魔的木棍砸進土裡，正用力往外拔。"},
			# 偶爾蓄力，下一擊特別重
			{"last": "sweep", "chance": 0.3, "then": "opening", "charge": true, "tell": "食人魔停下來深吸一口氣，全身的肌肉都鼓了起來。"},
		],
	},
}

const ARMOR_MULT := {"none": 1.0, "light": 0.8, "heavy": 0.5}
