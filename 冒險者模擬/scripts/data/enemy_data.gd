class_name EnemyData
extends RefCounted

## 敵人資料。每個敵人有自己的一套招。
##
## 同一類型的招，描述要有同一個「看得出來的特徵」，玩家才看得懂：
##   sweep 橫掃：往一側拉得很開、身體扭過去
##   thrust 直刺/撲：壓低身子、直直對準你
##   smash 重砸：高高舉起
##   grab 擒抱：張開手臂、要抓住你
##   trick 詭招：腳尖勾地、嘴角奸笑…（每招不同）
##   roar 威嚇：張大嘴、胸口一鼓
##   guard 防守：縮到盾牌後面
##
## traits：beast 野獸（怒喝有效）、big 體型大（掃不倒、打不斷）、disarmable 武器繳得掉
## actions：
##   type 類型；w 隨機權重（0 = 只靠習慣或特殊情況觸發）；power 威力
##   windup  true = 分兩拍：這回合蓄勢（tell），下回合才打下來（strike_tell）
##   on_hit  打中你之後的效果：blind 眼睛進沙（下回合只想得到一招）、shaken 嚇到（下回合一招都想不到）、
##           off_balance 站不穩（下回合少想到一招）、held 被抱住（下回合只能掙扎）
##   hold    被抱住時每回合的勒緊（power、tell、hit）
##   armed   true = 要有武器才能用；unarmed true = 只有被繳械時才用；pickup true = 撿回武器
##   tell / strike_tell / hit：描述，每次隨機挑一句
## habits：習慣和連招。從上往下找第一條符合的。
##   last 上一招；last_seq 最近兩招；player 你上回合用了這些招之一；chance 機率；rage 只在發狂/沒發狂時
## rage：血量低於 hp_below 時發狂，之後改用 weights。
## pain：被你打中時的反應。light 輕傷、heavy 重傷、dying 快死了。

const FORCED_OPENING := {
	"trip": ["{name}摔倒在地上，正掙扎著要爬起來。", "{name}重重摔了一跤，一時爬不起來。"],
	"break": ["{name}的防守被震開，整個胸口空了出來。"],
	"interrupt": ["{name}的動作被你打斷，踉蹌了一下，還沒站穩。"],
	"stagger": ["{name}收勢不住，往前踉蹌了好幾步，背後全空了。"],
	"scare": ["{name}被你嚇得一縮，猶豫著不敢上前。"],
}

const BLIND_MISS := ["{name}瞇著眼亂揮，完全打偏了。", "{name}揉著眼睛胡亂出手，連你的衣角都沒碰到。"]

const ORDER := ["wolf", "bandit_leader", "deserter", "bear", "ogre"]

const ARMOR_MULT := {"none": 1.0, "light": 0.8, "heavy": 0.5}

const ENEMIES := {
	"wolf": {
		"name": "野狼",
		"blurb": "森林裡常見的野獸。會撲、會咬住不放。",
		"hp": 45, "atk": 12, "armor": "none", "traits": ["beast"],
		"weapon": "利牙", "guard": "架勢",
		"start": ["一頭野狼從樹叢裡鑽出來，壓低身子盯著你。"],
		"actions": {
			"bite": {"type": "thrust", "w": 40, "power": 0.8,
				"tell": ["野狼壓低身子，猛地竄上來，張嘴就往你腿上咬。", "野狼壓低身子，直直朝你衝了過來。"],
				"hit": ["野狼一口咬在你的小腿上。", "利牙撕開了你的褲管，咬進肉裡。"]},
			"pounce": {"type": "thrust", "w": 35, "power": 1.4, "windup": true,
				"tell": ["野狼往後一縮，後腿繃緊，眼睛直直對準你的喉嚨。"],
				"strike_tell": ["野狼就要撲上來了！"],
				"hit": ["野狼整個撲在你身上，利牙擦過你的脖子。"]},
			"drag": {"type": "grab", "w": 25, "power": 0.6, "on_hit": "held",
				"tell": ["野狼繞到你側邊，張大嘴，要咬住你的手臂不放。"],
				"hit": ["野狼一口咬住你的手臂，死不鬆口！"],
				"hold": {"power": 0.5, "tell": ["野狼死死咬住你的手臂，拼命往後拖。"], "hit": ["利牙越咬越深。"]}},
		},
		"habits": [],
		"pain": {
			"light": ["野狼哀叫一聲。", "野狼縮了一下，又齜牙咧嘴地瞪著你。"],
			"heavy": ["野狼慘叫著滾了出去，又掙扎著爬起來。"],
			"dying": ["野狼的腿在發抖，夾著尾巴低吼。", "野狼喘得很急，身上的毛被血黏成一片。"],
		},
	},
	"bandit_leader": {
		"name": "盜匪頭子",
		"blurb": "在路上攔人搶劫的盜匪頭目，大刀使得很兇，手段也很髒。",
		"hp": 90, "atk": 30, "armor": "light", "traits": ["disarmable"],
		"weapon": "大刀", "guard": "架勢",
		"start": ["盜匪頭子扛著大刀擋在路中間，咧嘴笑著：「把錢留下。」"],
		"actions": {
			"sweep": {"type": "sweep", "w": 35, "power": 1.0, "armed": true,
				"tell": ["盜匪頭子把大刀往身體右側拉得很開，腰跟著扭了過去。", "盜匪頭子雙手握刀，刀身往旁邊一拉，腰扭了過去。"],
				"hit": ["大刀從側面掃中了你。", "刀鋒劃過你的腰側，血一下子湧了出來。"]},
			"thrust": {"type": "thrust", "w": 25, "power": 1.0, "armed": true,
				"tell": ["盜匪頭子壓低身子，刀尖直直對準你的胸口。"],
				"hit": ["刀尖刺進了你的肩膀。", "大刀捅進你的腰側，你痛得眼前一白。"]},
			"smash": {"type": "smash", "w": 25, "power": 1.5, "windup": true, "armed": true,
				"tell": ["盜匪頭子雙手把大刀高高舉過頭頂。", "盜匪頭子大吼一聲，把大刀高高舉起。"],
				"strike_tell": ["盜匪頭子的大刀就要劈下來了！"],
				"hit": ["大刀重重劈在你身上。", "大刀從頭頂劈下，你的肩膀一陣劇痛。"]},
			"sand_kick": {"type": "trick", "w": 15, "power": 0.0, "on_hit": "blind",
				"tell": ["盜匪頭子腳尖往地上一勾，嘴角帶著奸笑。"],
				"hit": ["一把沙土踢進你的眼睛，你什麼都看不清了！"]},
			"punch": {"type": "thrust", "w": 50, "power": 0.5, "unarmed": true,
				"tell": ["盜匪頭子罵了一聲，壓低身子，揮拳直直朝你臉上打來。"],
				"hit": ["一拳打在你臉上，你嘴裡一陣血腥味。"]},
			"pickup": {"type": "opening", "w": 50, "unarmed": true, "pickup": true,
				"tell": ["盜匪頭子彎腰去撿地上的大刀，背後全空了。"]},
			"rest": {"type": "opening", "w": 0,
				"tell": ["盜匪頭子大口喘氣，刀尖垂到了地上。", "盜匪頭子抹了一把臉上的血，腳步有點亂。"]},
		},
		"habits": [
			{"last": "sweep", "chance": 0.6, "then": "smash", "tell": "盜匪頭子順著掃刀的勢頭，把大刀高高舉過頭頂。"},
		],
		"rage": {
			"hp_below": 0.35,
			"text": "盜匪頭子滿臉是血，紅著眼睛大吼，刀法亂了起來。",
			"weights": {"sweep": 30, "thrust": 20, "smash": 30, "sand_kick": 20, "rest": 20},
		},
		"pain": {
			"light": ["盜匪頭子罵了一聲髒話。", "盜匪頭子往後退了半步，又握緊了刀。"],
			"heavy": ["盜匪頭子痛得大叫，差點把刀甩掉。", "盜匪頭子踉蹌了一下，臉上的笑容不見了。"],
			"dying": ["盜匪頭子的腳在發抖，刀尖一直在晃。", "盜匪頭子喘著粗氣，眼神開始飄向路邊。"],
		},
	},
	"deserter": {
		"name": "逃兵騎士",
		"blurb": "從戰場逃出來的騎士，一身鐵甲，盾牌很難打穿。",
		"hp": 70, "atk": 20, "armor": "heavy", "traits": ["disarmable"],
		"weapon": "長劍", "guard": "盾牌",
		"start": ["一個穿著破舊鐵甲的騎士舉起盾牌，一言不發地朝你走來。"],
		"actions": {
			"shield_wall": {"type": "guard", "w": 35,
				"tell": ["逃兵騎士縮到盾牌後面，一步一步逼過來。", "逃兵騎士把盾牌抬到眼前，穩穩地往前推進。"]},
			"thrust": {"type": "thrust", "w": 30, "power": 1.0, "armed": true,
				"tell": ["逃兵騎士壓低身子，劍尖直直對準你的胸口。"],
				"hit": ["長劍刺進了你的身體。", "劍尖從你的肋骨間刺了進去。"]},
			"shield_bash": {"type": "smash", "w": 20, "power": 0.8, "on_hit": "off_balance",
				"tell": ["逃兵騎士把盾牌高高舉起，要往你身上砸。"],
				"hit": ["盾牌重重砸在你身上，你往後踉蹌了好幾步，腦袋嗡嗡作響。"]},
			"charge": {"type": "thrust", "w": 15, "power": 1.6, "windup": true, "armed": true,
				"tell": ["逃兵騎士往後退了兩步，壓低身子，劍尖對準你，準備衝鋒。"],
				"strike_tell": ["逃兵騎士就要衝過來了！"],
				"hit": ["逃兵騎士連人帶劍撞在你身上，長劍刺得很深。"]},
			"pickup": {"type": "opening", "w": 40, "unarmed": true, "pickup": true,
				"tell": ["逃兵騎士彎腰去撿地上的長劍，盾牌垂了下來。"]},
		},
		"habits": [
			# 你砍在盾上，他從盾後反刺
			{"last": "shield_wall", "player": ["attack", "vital", "combo", "sweep_kick"], "then": "thrust", "tell": "逃兵騎士從盾牌後面猛地壓低身子，劍尖直直對準你的胸口。"},
		],
		"pain": {
			"light": ["劍刃在鐵甲上刮出一道白痕。", "逃兵騎士悶哼一聲，腳步沒停。"],
			"heavy": ["鐵甲被打凹了一塊，逃兵騎士往後晃了兩步。", "逃兵騎士的頭盔被打歪，他一把扶正。"],
			"dying": ["逃兵騎士的盾牌越舉越低，呼吸在頭盔裡嘶嘶作響。"],
		},
	},
	"bear": {
		"name": "熊",
		"blurb": "比人還高的大熊，皮又厚又硬。被牠抱住就麻煩了。",
		"hp": 120, "atk": 24, "armor": "light", "traits": ["beast", "big"],
		"weapon": "熊掌", "guard": "架勢",
		"start": ["一頭大熊從洞裡鑽了出來，嗅了嗅空氣，轉頭看向你。"],
		"actions": {
			"swipe": {"type": "sweep", "w": 40, "power": 1.0,
				"tell": ["熊把右掌往旁邊拉得很開，肩膀跟著扭了過去。", "熊揚起前掌往一側拉開，整個身子扭了過去。"],
				"hit": ["熊掌從側面拍中了你。", "熊掌拍在你身上，把你打得轉了半圈。"]},
			"rear_smash": {"type": "smash", "w": 25, "power": 1.5, "windup": true,
				"tell": ["熊人立而起，兩隻前掌高高舉過頭頂。"],
				"strike_tell": ["熊的雙掌就要砸下來了！"],
				"hit": ["熊掌從上面把你壓倒在地。", "兩隻熊掌砸在你肩上，你整個人跪了下去。"]},
			"hug": {"type": "grab", "w": 20, "power": 0.6, "on_hit": "held",
				"tell": ["熊張開兩隻前臂，朝你撲過來，要把你整個抱住。"],
				"hit": ["熊一把將你抱住，你的雙腳離開了地面！"],
				"hold": {"power": 0.8, "tell": ["熊死死抱住你，越勒越緊。"], "hit": ["你聽見自己的骨頭在響。", "你被勒得眼前發黑。"]}},
			"roar": {"type": "roar", "w": 15, "power": 0.0, "on_hit": "shaken",
				"tell": ["熊張開大嘴，胸口一鼓一鼓的。"],
				"hit": ["一聲震耳的咆哮，你腿一軟，腦中一片空白。"]},
			"rest": {"type": "opening", "w": 0,
				"tell": ["熊甩著頭，喘著粗氣，動作慢了下來。", "熊重重落地，大口喘氣。"]},
		},
		"habits": [
			# 節奏：拍、拍、站起來砸、喘氣
			{"last_seq": ["swipe", "swipe"], "then": "rear_smash"},
			{"last": "rear_smash", "rage": false, "then": "rest"},
			# 發狂後砸完不喘，直接撲上來抱
			{"last": "rear_smash", "rage": true, "then": "hug", "tell": "熊一落地毫不停頓，張開兩隻前臂朝你撲過來，要把你整個抱住。"},
		],
		"rage": {
			"hp_below": 0.4,
			"text": "熊被打痛了，眼睛發紅，吼聲震得你耳朵發疼。",
			"weights": {"swipe": 40, "rear_smash": 30, "hug": 30},
		},
		"pain": {
			"light": ["熊低吼一聲，毛皮擋掉了大半。", "熊甩了甩被砍到的地方，好像只是被蚊子叮了一下。"],
			"heavy": ["熊痛得咆哮，口水噴了你一臉。", "熊往後退了一步，傷口的血染紅了毛皮。"],
			"dying": ["熊的腳步開始踉蹌，鮮血滴在地上。", "熊喘得像風箱，眼神卻更兇了。"],
		},
	},
	"ogre": {
		"name": "食人魔",
		"blurb": "兩個人高的怪物，拖著一根大木棍。力氣大得能把人抓起來摔。",
		"hp": 160, "atk": 28, "armor": "none", "traits": ["big"],
		"weapon": "木棍", "guard": "架勢",
		"start": ["地面一陣震動。食人魔拖著一根大木棍，從遠處朝你走來。"],
		"actions": {
			"club_sweep": {"type": "sweep", "w": 35, "power": 1.0,
				"tell": ["食人魔把木棍往身體一側拉得很開，整個上身跟著扭了過去。", "食人魔單手拖著木棍往旁邊一拉，腰扭了過去。"],
				"hit": ["木棍從側面把你掃飛出去。", "木棍掃在你身上，你在地上滾了好幾圈。"]},
			"club_smash": {"type": "smash", "w": 30, "power": 1.5, "windup": true,
				"tell": ["食人魔雙手把木棍高高舉過頭頂。"],
				"strike_tell": ["食人魔的木棍就要砸下來了！"],
				"hit": ["木棍從頭頂砸中了你。", "木棍砸在你身上，你聽見自己骨頭在響。"]},
			"grab_throw": {"type": "grab", "w": 20, "power": 1.2, "on_hit": "off_balance",
				"tell": ["食人魔張開一隻大手朝你抓過來，要把你整個抓起來。"],
				"hit": ["食人魔一把抓起你，往地上狠狠一摔！"]},
			"stomp": {"type": "smash", "w": 15, "power": 0.9,
				"tell": ["食人魔高高抬起一隻大腳，要往你身上踩。"],
				"hit": ["大腳把你踩進了泥裡。"]},
			"stuck": {"type": "opening", "w": 0,
				"tell": ["食人魔的木棍砸進土裡，正用力往外拔。"]},
		},
		"habits": [
			# 砸下去木棍常卡在土裡
			{"last": "club_smash", "chance": 0.6, "then": "stuck"},
		],
		"pain": {
			"light": ["食人魔好像沒什麼感覺，低頭看了看傷口。", "食人魔哼了一聲。"],
			"heavy": ["食人魔痛得大吼，震得樹葉都在抖。", "食人魔往後晃了一下，伸手摸了摸傷口，一手的血。"],
			"dying": ["食人魔的腳步越來越沉，喘氣聲像打雷。"],
		},
	},
}
