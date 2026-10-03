class_name EnemyData
extends RefCounted

## 敵人資料。
## 同一種動作的描述要有同一個「看得出來的特徵」，玩家才學得會：
##   sweep  橫掃：往一側拉得很開、身體扭過去
##   thrust 直衝：壓低身子、直直對準你
##   smash  重砸：高高舉過頭頂 / 高高躍起
##   guard  防守：縮到盾牌後面
##   opening 破綻：喘氣、動作慢下來
## w = 出現機率的權重。hit = 這招打中你時的描述。
## armor：none / light / heavy。big = 體型大，掃不倒。

## 被逼出來的破綻（不是自己選的動作）
const FORCED_OPENING := {
	"smash_missed": "{name}一擊落空，身體還收不回來。",
	"tripped": "{name}摔倒在地上，正掙扎著要爬起來。",
	"guard_broken": "{name}的防守被震開，整個胸口空了出來。",
}

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
	},
	"bandit_leader": {
		"name": "盜匪頭子",
		"blurb": "在路上攔人搶劫的盜匪頭目，拿著一把大刀。",
		"hp": 75, "atk": 18, "armor": "light", "big": false,
		"weapon": "大刀", "guard": "架勢",
		"intents": {
			"sweep": {"w": 40, "tell": "盜匪頭子把大刀往身體右側拉得很開，腰跟著扭了過去。", "hit": "大刀從側面掃中了你。"},
			"thrust": {"w": 30, "tell": "盜匪頭子壓低身子，刀尖直直對準你的胸口。", "hit": "刀尖刺進了你的身體。"},
			"smash": {"w": 30, "tell": "盜匪頭子雙手把大刀高高舉過頭頂。", "hit": "大刀從頭頂劈中了你。"},
		},
	},
	"deserter": {
		"name": "逃兵騎士",
		"blurb": "從戰場逃出來的騎士，一身鐵甲，拿著盾和長劍。",
		"hp": 60, "atk": 20, "armor": "heavy", "big": false,
		"weapon": "長劍", "guard": "盾牌",
		"intents": {
			"guard": {"w": 35, "tell": "逃兵騎士縮到盾牌後面，一步一步逼過來。"},
			"thrust": {"w": 40, "tell": "逃兵騎士壓低身子，劍尖直直對準你的胸口。", "hit": "長劍刺進了你的身體。"},
			"sweep": {"w": 25, "tell": "逃兵騎士把長劍往身體右側拉得很開，腰跟著扭了過去。", "hit": "長劍從側面掃中了你。"},
		},
	},
	"bear": {
		"name": "熊",
		"blurb": "比人還高的大熊，皮又厚又硬。",
		"hp": 120, "atk": 22, "armor": "light", "big": true,
		"weapon": "熊掌", "guard": "架勢",
		"intents": {
			"sweep": {"w": 50, "tell": "熊把右掌往旁邊拉得很開，肩膀跟著扭了過去。", "hit": "熊掌從側面拍中了你。"},
			"smash": {"w": 35, "tell": "熊人立而起，兩隻前掌高高舉過頭頂。", "hit": "熊掌從上面把你壓倒在地。"},
			"opening": {"w": 15, "tell": "熊甩著頭，喘著粗氣，動作慢了下來。"},
		},
	},
	"ogre": {
		"name": "食人魔",
		"blurb": "兩個人高的怪物，拖著一根大木棍。",
		"hp": 160, "atk": 28, "armor": "none", "big": true,
		"weapon": "木棍", "guard": "架勢",
		"intents": {
			"sweep": {"w": 45, "tell": "食人魔把木棍往身體一側拉得很開，整個上身跟著扭了過去。", "hit": "木棍從側面把你掃飛出去。"},
			"smash": {"w": 40, "tell": "食人魔雙手把木棍高高舉過頭頂。", "hit": "木棍從頭頂砸中了你。"},
			"opening": {"w": 15, "tell": "食人魔喘著粗氣，木棍拖在地上。"},
		},
	},
}

const ARMOR_MULT := {"none": 1.0, "light": 0.8, "heavy": 0.5}
