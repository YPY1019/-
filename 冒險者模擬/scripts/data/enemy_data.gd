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
## scene：開打時的場景（隨機一句）。start：對手登場。
## traits：beast 野獸（怒喝有效）、big 體型大（掃不倒、打不斷）、disarmable 武器繳得掉
## actions：
##   type 類型；w 隨機權重（0 = 只靠習慣或特殊情況觸發）；power 威力
##   windup  true = 分兩拍：這回合蓄勢（tell），下回合才打下來（strike_tell）
##   on_hit  打中你之後的效果：blind 眼睛進沙、shaken 嚇到、off_balance 站不穩、held 被抱住
##   hold    被抱住時每回合的勒緊（power、tell、hit）
##   armed   true = 要有武器才能用；unarmed true = 只有被繳械時才用；pickup true = 撿回武器
##   tell / strike_tell / hit：描述，每次隨機挑一句
## habits：習慣和連招。從上往下找第一條符合的。
##   last 上一招；last_seq 最近兩招；player 你上回合用了這些招之一；chance 機率；rage 只在發狂/沒發狂時
## rage：血量低於 hp_below 時發狂，之後改用 weights。
## pain：被你打中時的反應。light 輕傷、heavy 重傷、dying 快死了。
## str / agi：力量、敏捷。戰鬥時跟你同一項比（見 GrowthData），也決定打牠能把你練到多高。
##   招靠哪一項看類型（TYPE_STAT），招自己寫了 stat 就用招的。
## realm：只有人有境界。怪物用危險度，從數值算（danger()）。
## win_text / lose_text / flee_text / survive_text：戰鬥結束的句子（不寫就用預設的）。
## hide_hp：戰鬥畫面不顯示血量（庭主的考驗）。
## loot：打贏就拿到的武器（WeaponData）。稀有的劍拿在手上時，他打你也會發動那把劍的特效。
## books：身上帶的秘笈（BookData），打贏就在戰利品裡。
## parry：露出破綻時還拿兵器擋你的寫法（先吃虧，見 Battle.can_parry）。沒寫的不會擋。no_parry：這個破綻擋不了（兵器卡住）。
## moves：會的招（MoveData，跟你同一套）。move_pool / pool_n：每次碰上時從裡面隨機會幾招（同一種對手，每個人會的不一樣）。沒有名字的對手用；世界上的人用自己學會的。
## title：名號（有名的強者）。no_flee：再怎麼打不過也不會逃。fear / fear_flee：怕你時的句子。

const FORCED_OPENING := {
	"trip": ["{name}摔在地上，一手撐地正要爬起來。", "{name}倒在地上，一時起不了身。"],
	"break": ["{name}的{guard}被砸開，歪到一邊，胸口整個空了出來。"],
	"interrupt": ["{name}的動作被打斷，重心還沒找回來。"],
	"stagger": ["{name}收不住勢，往前踉蹌了好幾步，背後全空了。"],
	# 被喪鐘震開
	"jolt": ["{name}腳下還沒站穩，手上的{weapon}垂著。"],
	"scare": ["{name}縮著身子往後退，不敢上前。"],
}

const BLIND_MISS := ["{name}瞇著眼睛亂揮，完全打偏了。", "{name}一邊揉眼睛一邊出手，連你的衣角都沒碰到。"]

## 對手的招靠哪一項數值
const TYPE_STAT := {"sweep": "str", "smash": "str", "grab": "str", "hold": "str", "roar": "str",
	"thrust": "agi", "trick": "agi"}

## 對手的招打中了，附加效果卻沒用（看差距，你那一項越高越常這樣）
const RESIST := {
	"held": ["{name}想把你纏住，你肩膀一沉，甩開了。"],
	"blind": ["沙子撒過來，你偏頭躲開了。", "{name}腳尖一勾，你先一步閉眼側身，沙子全撒在肩上。"],
	"shaken": ["吼聲很大，你沒有退。"],
	"off_balance": ["你被撞得晃了一下，腳下沒亂。"],
}

## 差很多時的戰報（GrowthData.OUTCLASS）。敵人資料裡有寫 fear / fear_flee 就用敵人的
## overwhelmed：你那一項比對手高很多，砍中時；unfazed：對手那一項比你高很多，你砍中了也沒用
const OVERWHELMED := [
	"{name}連退了好幾步，第一次露出慌張的樣子。",
	"{name}兩腿一軟，差點跪下去。",
	"{name}咬著牙，臉色白了。",
]
const UNFAZED := [
	"{name}晃都沒晃。",
	"{name}低頭看了一眼傷口，沒當一回事。",
	"{name}像沒感覺一樣，腳下一步沒亂。",
]
## 對手比你弱太多：開打就怕，挨痛了會逃（算你贏）。no_flee 的不會逃
const FEAR := ["{name}看了你一眼，往後退了半步。", "{name}的氣勢一下子矮了一截。"]
const FEAR_FLEE := ["{name}轉身就逃，頭也不回。", "{name}突然掉頭跑了。"]
## 被嚇跑時結束的句子
const FLED_END := "對手跑了。"

## 委託板上的一般敵人（照危險度排）
const ORDER := ["wolf", "boar", "bandit_leader", "deserter", "poacher", "smuggler", "pikeman", "bear", "alpha_wolf",
	"elk", "butcher", "ogre", "croc", "troll"]
## 有名字、只有一個的強者（懸賞）：身上帶著稀有的武器或高級秘笈，打倒了就不會再出現。照難度排
const NAMED := ["merc_captain", "raider", "duelist", "black_knight", "old_captain", "rebel_lord"]

const ARMOR_MULT := {"none": 1.0, "light": 0.8, "heavy": 0.5}

const ENEMIES := {
	"wolf": {
		"name": "野狼",
		"blurb": "森林裡常見的野獸。會撲、會咬住不放。",
		"hp": 50, "str": 7, "agi": 11, "armor": "none", "traits": ["beast"], "pron": "牠",
		"weapon": "利牙", "guard": "架勢",
		"scene": ["黃昏的林間小路，落葉被風吹得沙沙響。", "清晨的霧還沒散，林子裡很安靜。"],
		"start": ["一頭灰毛野狼從樹叢裡鑽出來，壓低身子盯著你。", "樹叢一陣晃動，一頭瘦得見骨的野狼走了出來，嘴角滴著口水。"],
		"actions": {
			"bite": {"type": "thrust", "w": 40, "power": 0.8,
				"tell": ["野狼貼著地面竄上來，張嘴咬你的腿。"],
				"hit": ["野狼一口咬住你的小腿，甩著頭撕扯。", "野狼咬住你的褲管連肉一起扯，血浸濕了布料。", "小腿一陣刺痛，兩排齒痕正在冒血。"]},
			"pounce": {"type": "thrust", "w": 35, "power": 1.4, "windup": true,
				"tell": ["野狼往後一縮，後腿繃緊，眼睛對準你的喉嚨。", "野狼伏低身子，尾巴一動不動，喉嚨裡滾著低吼。"],
				"strike_tell": ["野狼後腿一蹬，朝你的喉嚨撲來！"],
				"hit": ["野狼整個撲在你身上，把你壓倒在地，牙齒擦過你的脖子。", "你被撲得仰面倒下，爪子在你胸口抓出幾道血痕。"]},
			"drag": {"type": "grab", "w": 25, "power": 0.6, "on_hit": "held",
				"tell": ["野狼繞到你側邊，張嘴撲向你的手臂。"],
				"hit": ["野狼一口咬住你的手臂，死不鬆口。", "你的前臂被咬住了，野狼四腳撐地，拼命往後拖。"],
				"hold": {"power": 0.5,
					"tell": ["野狼咬著你的手臂不放，四腳撐地往後拖。", "野狼咬著你的手臂左右甩頭。"],
					"hit": ["牙齒越咬越深，你的手快沒有知覺了。", "牠一甩頭，傷口又撕開了一些。"]}},
		},
		"habits": [],
		"fear": ["野狼夾起尾巴，耳朵往後貼，低吼變成了嗚咽。"],
		"fear_flee": ["野狼哀叫一聲，夾著尾巴竄進了樹林。"],
		"pain": {
			"light": ["野狼哀叫一聲，往旁邊跳開半步。", "野狼縮了一下，又齜牙瞪著你。"],
			"heavy": ["野狼慘叫著滾了出去，又掙扎著爬起來。"],
			"dying": ["野狼的腿在發抖，夾著尾巴低吼，不肯退。", "野狼喘得很急，身上的毛被血黏成一片。"],
		},
	},
	"bandit_leader": {
		"name": "盜匪頭子",
		"blurb": "在路上攔人搶劫的盜匪頭目，大刀使得很兇，手段也很髒。",
		"hp": 150, "str": 12, "agi": 12, "armor": "light", "traits": ["disarmable"], "kinds": ["blade", "sword"], "pron": "他",
		"weapon": "大刀", "guard": "架勢", "loot": "bandit_blade", "moves": ["knee"],
		"parry": ["{name}身子還歪著，大刀卻慌忙橫了過來。你的{my}砍在刀背上，震得手腕發麻。", "你搶上去出手，{name}把大刀往身前一擋，噹的一聲架住了。"],
		"fear": ["{name}的笑容僵在臉上，握刀的手緊了又鬆：「……喂，有話好說。」"],
		"fear_flee": ["{name}把大刀一扔，連滾帶爬地逃上了山。"],
		"scene": ["荒涼的山道，兩邊都是岩壁。", "官道旁的破廟前，地上還散著被搶過的行李。"],
		"start": ["{name}扛著大刀擋在路中間：「把錢留下，人可以走。」", "{name}從路邊跳出來，大刀在手裡轉了一圈：「錢袋扔過來。」"],
		"actions": {
			"sweep": {"type": "sweep", "w": 35, "power": 1.0, "armed": true,
				"tell": ["{name}把大刀往右一拉，腰身一擰，刀鋒橫掃過來。"],
				"hit": ["大刀掃中你的腰，你被帶得踉蹌兩步，血順著大腿流下來。", "刀鋒劃過你的肋下，衣服裂開一道大口子。", "你只來得及縮一下，大刀就砍進了你的手臂。"]},
			"thrust": {"type": "thrust", "w": 25, "power": 1.0, "armed": true,
				"tell": ["{name}壓低身子，刀尖對準你的胸口捅過來。"],
				"hit": ["刀尖刺進你的肩膀，他手腕一扭才拔出來。", "大刀捅進你的腰側。"]},
			"smash": {"type": "smash", "w": 25, "power": 1.5, "windup": true, "armed": true,
				"tell": ["{name}雙手把大刀舉過頭頂，整個人的重量都壓在後腳上。", "{name}大吼一聲，把大刀高高舉起。"],
				"strike_tell": ["大刀劈下來了！"],
				"hit": ["大刀劈在你的肩膀上，喀的一聲，整條手臂都麻了。", "你偏了偏頭，刀鋒還是在你肩上開了一道深口子。"]},
			"sand_kick": {"type": "trick", "w": 15, "power": 0.0, "on_hit": "blind",
				"tell": ["{name}腳尖往地上一勾。"],
				"hit": ["一把沙土踢進你的眼睛，你什麼都看不清了。", "沙子撒了你一臉，你閉上眼，耳邊是他的笑聲。"]},
			"punch": {"type": "thrust", "w": 50, "power": 0.5, "unarmed": true,
				"tell": ["{name}罵了一聲，揮拳朝你臉上打來。"],
				"hit": ["一拳正中你的鼻樑，嘴裡一陣血腥味。"]},
			"pickup": {"type": "opening", "w": 50, "unarmed": true, "pickup": true,
				"tell": ["{name}彎腰去撿地上的大刀，背後全空了。", "{name}盯著你，慢慢蹲下去摸地上的刀。"]},
			"rest": {"type": "opening", "w": 0,
				"tell": ["{name}大口喘氣，刀尖垂到了地上。", "{name}抹了一把臉上的血，腳步亂了。"]},
		},
		"habits": [
			{"last": "sweep", "chance": 0.6, "then": "smash", "tell": "{name}順著掃刀的勢子，把大刀舉過頭頂。"},
		],
		"rage": {
			"hp_below": 0.35,
			"text": "{name}滿臉是血，紅著眼大吼：「老子砍死你！」刀法亂了。",
			"weights": {"sweep": 30, "thrust": 20, "smash": 30, "sand_kick": 20, "rest": 20},
		},
		"pain": {
			"light": ["{name}罵了一聲。", "{name}退了半步，又握緊了刀。"],
			"heavy": ["{name}痛得大叫，差點把刀甩掉。", "{name}踉蹌了一下，臉上的笑容不見了。"],
			"dying": ["{name}的腳在發抖，刀尖一直在晃。", "{name}喘著粗氣，眼睛開始往路邊的樹林瞄。"],
		},
	},
	"deserter": {
		"name": "逃兵騎士",
		"blurb": "從戰場逃出來的騎士，一身鐵甲，盾牌很難打穿。",
		"hp": 120, "str": 14, "agi": 10, "armor": "heavy", "traits": ["disarmable"], "kinds": ["sword"], "pron": "他",
		"weapon": "長劍", "guard": "盾牌", "loot": "knight_sword", "moves": ["lh_cross", "lh_advance"],
		"parry": ["你搶上去出手，{name}把盾牌往上一甩，你的{my}砍在盾邊上滑開了。", "你的{my}砍過去，{name}的長劍橫過來一格，兩把劍撞在一起。"],
		"fear": ["{name}停下腳步，頭盔後面傳來一聲很輕的吸氣。"],
		"fear_flee": ["{name}丟下盾牌，鐵甲叮噹作響地逃過了石橋。"],
		"scene": ["戰場邊緣的焦土，烏鴉在遠處的屍堆上盤旋。", "下著細雨的石橋，雨水順著橋面往下流。"],
		"start": ["一個穿著破舊鐵甲的騎士舉起盾牌，一言不發地朝你走來。"],
		"actions": {
			"shield_wall": {"type": "guard", "w": 35,
				"tell": ["{name}縮到盾牌後面，一步一步逼過來。", "{name}把盾牌抬到眼前，只露出頭盔的眼縫。"]},
			"thrust": {"type": "thrust", "w": 30, "power": 1.0, "armed": true,
				"tell": ["{name}從盾牌邊緣探出劍尖，刺向你的胸口。"],
				"hit": ["長劍刺進你的身體，劍刃沒入了一截。", "劍尖從你的肋骨之間刺了進去。"]},
			"shield_bash": {"type": "smash", "w": 20, "power": 0.8, "on_hit": "off_balance",
				"tell": ["{name}舉起盾牌往你身上砸。"],
				"hit": ["盾牌砸在你身上，你往後踉蹌了好幾步。", "鐵盾撞在你臉上，你嘴裡一陣腥甜。"]},
			"charge": {"type": "thrust", "w": 15, "power": 1.6, "windup": true, "armed": true,
				"tell": ["{name}退了兩步，壓低身子，劍尖對準你，準備衝鋒。"],
				"strike_tell": ["鐵甲鏗鏘作響，{name}挺著長劍衝過來！"],
				"hit": ["{name}連人帶劍撞在你身上，長劍刺得很深，你被撞了出去。"]},
			"pickup": {"type": "opening", "w": 40, "unarmed": true, "pickup": true,
				"tell": ["{name}彎腰去撿地上的長劍，盾牌垂了下來。"]},
		},
		"habits": [
			# 你砍在盾上，他從盾後反刺
			{"last": "shield_wall", "player": ["attack", "needle", "lh_half", "triple", "knee", "fb_whirl", "lh_pommel"], "then": "thrust", "tell": "你的{my}還卡在盾牌上，{name}已經從盾後壓低身子，劍尖對準你的胸口。"},
		],
		"pain": {
			"light": ["劍刃在鐵甲上刮出一道白痕。", "{name}悶哼一聲，腳步沒停。"],
			"heavy": ["鐵甲被打凹了一塊，{name}往後晃了兩步。", "{name}的頭盔被打歪，他伸手扶正，呼吸聲變重了。"],
			"dying": ["{name}的盾牌越舉越低，呼吸在頭盔裡嘶嘶作響。"],
		},
	},
	"bear": {
		"name": "熊",
		"blurb": "比人還高的大熊，皮又厚又硬。被牠抱住就麻煩了。",
		"hp": 220, "str": 17, "agi": 9, "armor": "light", "traits": ["beast", "big"], "pron": "牠",
		"weapon": "熊掌", "guard": "架勢",
		"fear": ["熊嗅了嗅空氣，沒有站起來，壓低身子，呼嚕聲變得遲疑。"],
		"fear_flee": ["熊低吼一聲，轉身鑽進了樹林，樹枝被撞得劈啪響。"],
		"scene": ["山洞口的空地，地上散著動物的骨頭，一股腥臭味。", "溪邊的碎石灘，地上有被撕碎的魚。"],
		"start": ["一頭大熊從洞裡鑽出來，嗅了嗅，轉頭看向你。"],
		"actions": {
			"swipe": {"type": "sweep", "w": 40, "power": 1.0,
				"tell": ["熊把右掌往旁邊拉開，肩膀一扭，橫拍過來。"],
				"hit": ["熊掌從側面拍中你，四道爪痕從肩膀劃到胸口。", "熊掌拍在你身上，你整個人轉了半圈。", "爪子勾住你的衣服，連布帶肉撕下一塊。"]},
			"rear_smash": {"type": "smash", "w": 25, "power": 1.5, "windup": true,
				"tell": ["熊人立起來，兩隻前掌舉過頭頂，比你高出一大截。", "熊吼了一聲站起來，影子把你整個罩住。"],
				"strike_tell": ["熊帶著全身的重量，雙掌朝你頭頂砸下來！"],
				"hit": ["兩隻熊掌砸在你肩上，你跪了下去，膝蓋撞在地上。", "熊掌把你壓倒在地，胸口的骨頭快要斷了。"]},
			"hug": {"type": "grab", "w": 20, "power": 0.6, "on_hit": "held",
				"tell": ["熊張開兩隻前臂撲過來，要把你抱住。"],
				"hit": ["熊一把將你抱住，你的雙腳離了地。", "熊的前臂把你箍住，你掙不開。"],
				"hold": {"power": 0.8,
					"tell": ["熊死死抱住你，越勒越緊。", "你的臉被壓在熊的毛皮上，快喘不過氣。"],
					"hit": ["你聽見自己的骨頭在響。", "你被勒得眼前發黑，肺裡的空氣一點一點被擠出去。"]}},
			"roar": {"type": "roar", "w": 15, "power": 0.0, "on_hit": "shaken",
				"tell": ["熊張開大嘴，胸口一鼓，朝你吼了出來。"],
				"hit": ["咆哮聲直衝你的臉，你腿一軟，腦中一片空白。", "吼聲震得你耳朵嗡嗡響，{my}差點握不住。"]},
			"rest": {"type": "opening", "w": 0,
				"tell": ["熊落回四腳，甩著頭喘氣，動作慢了下來。", "熊重重落地，大口喘氣。"]},
		},
		"habits": [
			# 節奏：拍、拍、站起來砸、喘氣
			{"last_seq": ["swipe", "swipe"], "then": "rear_smash"},
			{"last": "rear_smash", "rage": false, "then": "rest"},
			# 發狂後砸完不喘，直接撲上來抱
			{"last": "rear_smash", "rage": true, "then": "hug", "tell": "熊一落地沒有停，張開前臂朝你撲過來。"},
		],
		"rage": {
			"hp_below": 0.4,
			"text": "熊被打痛了，仰頭長嚎，樹上的鳥全飛了起來。",
			"weights": {"swipe": 40, "rear_smash": 30, "hug": 30},
		},
		"pain": {
			"light": ["熊低吼一聲，毛皮擋掉了大半。", "熊甩了甩被砍到的地方。"],
			"heavy": ["熊痛得咆哮，口水噴了你一臉。", "熊往後退了一步，血染紅了毛皮。"],
			"dying": ["熊的腳步開始踉蹌，血滴在地上。", "熊喘得很重，眼神卻更兇了。"],
		},
	},
	"ogre": {
		"name": "食人魔",
		"blurb": "兩個人高的怪物，拖著一根大木棍。力氣大得能把人抓起來摔。",
		"hp": 520, "str": 23, "agi": 8, "armor": "none", "traits": ["big"], "pron": "牠",
		"weapon": "木棍", "guard": "架勢", "no_flee": true,
		"parry": ["食人魔胡亂把木棍往身前一擋，你的{my}砍進木頭裡，拔了一下才拔出來。", "你搶上去出手，砍在橫過來的木棍上，木屑亂飛。"],
		"scene": ["倒塌的城牆下，到處都是被砸爛的木箱和碎石。", "下著大雨的沼澤邊，泥水沒過了你的腳踝。"],
		"start": ["地面一陣震動。食人魔拖著一根大木棍走過來，咧開滿是爛牙的嘴。"],
		"actions": {
			"club_sweep": {"type": "sweep", "w": 35, "power": 1.0,
				"tell": ["食人魔單手拖著木棍往旁邊一拉，整個上身扭過去，橫掃過來。"],
				"hit": ["木棍從側面把你掃了出去，你在地上滾了好幾圈，嘴裡全是泥。", "木棍掃在你的腰上，你身體裡悶悶地響了一聲。"]},
			"club_smash": {"type": "smash", "w": 30, "power": 1.5, "windup": true,
				"tell": ["食人魔雙手把木棍舉過頭頂。", "食人魔雙手舉起木棍，嘴裡發出低沉的吼聲。"],
				"strike_tell": ["木棍朝你頭頂砸下來了！"],
				"hit": ["木棍從頭頂砸中了你，你眼前一白，整個人被砸倒在地。", "木棍砸在你身上，你聽見自己的骨頭在響。"]},
			"grab_throw": {"type": "grab", "w": 20, "power": 1.2, "on_hit": "off_balance",
				"tell": ["食人魔張開一隻大手抓過來。"],
				"hit": ["食人魔一把抓起你，往地上狠狠一摔。", "你被那隻大手抓住，雙腳離地，接著整個人被砸進泥地裡。"]},
			"stomp": {"type": "smash", "w": 15, "power": 0.9,
				"tell": ["食人魔抬起一隻大腳往你身上踩。"],
				"hit": ["大腳把你踩在地上，肋骨快被踩斷了。"]},
			"stuck": {"type": "opening", "w": 0, "no_parry": true,
				"tell": ["木棍砸進土裡卡住了，食人魔哼哼地用力往外拔。"]},
		},
		"habits": [
			# 砸下去木棍常卡在土裡
			{"last": "club_smash", "chance": 0.6, "then": "stuck"},
		],
		"pain": {
			"light": ["食人魔低頭看了看傷口。", "食人魔哼了一聲。"],
			"heavy": ["食人魔痛得大吼。", "食人魔往後晃了一下，伸手摸傷口，一手的血。"],
			"dying": ["食人魔的腳步越來越沉，喘氣聲很重。"],
		},
		"win_text": "食人魔往後倒了下去，地面跟著一跳。你拄著{my}站了好一會兒。",
	},
	# ---------- 2026-10-06 加的委託怪物（每一境 2～3 種） ----------
	"boar": {
		"name": "野豬",
		"blurb": "",
		"hp": 90, "str": 11, "agi": 9, "armor": "none", "traits": ["beast"], "pron": "牠",
		"weapon": "獠牙", "guard": "架勢",
		"fear": ["野豬哼了兩聲，往後退了幾步。"],
		"fear_flee": ["野豬掉頭鑽進了灌木叢。"],
		"scene": ["山路邊的灌木叢，地上被拱得坑坑洞洞。"],
		"start": ["灌木叢裡一陣亂響，一頭野豬鑽了出來，獠牙上還掛著泥。"],
		"actions": {
			"charge": {"type": "thrust", "w": 35, "power": 1.4, "windup": true,
				"tell": ["野豬低下頭，前蹄在地上刨了兩下，鼻子噴著白氣。"],
				"strike_tell": ["野豬低著頭直衝過來！"],
				"hit": ["獠牙撞在你的大腿上，你被頂得往後摔了出去。", "野豬撞在你的膝蓋上，你整個人翻倒在地。"]},
			"tusk": {"type": "sweep", "w": 35, "power": 0.9,
				"tell": ["野豬把頭往旁邊一甩，獠牙橫著挑過來。"],
				"hit": ["獠牙從你的小腿上劃過，劃開一道口子。", "獠牙勾住你的褲管，連肉一起撕開。"]},
			"trample": {"type": "thrust", "w": 30, "power": 0.7, "on_hit": "off_balance",
				"tell": ["野豬貼著地面竄過來，往你腳邊撞。"],
				"hit": ["野豬撞在你的腳踝上，你腳下一亂。"]},
			"turn": {"type": "opening", "w": 0,
				"tell": ["野豬衝過了頭，四蹄在地上打滑，正在掉轉身子。"]},
		},
		"habits": [
			# 衝過頭要掉頭
			{"last": "charge", "chance": 0.7, "then": "turn"},
		],
		"pain": {
			"light": ["野豬尖叫了一聲。", "野豬的厚皮擋掉了一半。"],
			"heavy": ["野豬滾了一圈，又爬起來。"],
			"dying": ["野豬喘得很急，鼻子裡冒著血沫。"],
		},
	},
	"poacher": {
		"name": "盜獵人",
		"blurb": "",
		"hp": 150, "str": 12, "agi": 15, "armor": "light", "traits": ["disarmable"], "kinds": ["blade"], "pron": "他",
		"weapon": "獵刀", "guard": "架勢", "move_pool": ["dust", "knee", "needle", "deflect"], "pool_n": 2,
		"parry": ["{name}把獵刀往身前一橫，你的{my}砍在刀背上。"],
		"fear": ["{name}往後退了兩步，眼睛往樹林裡瞄。"],
		"fear_flee": ["{name}一轉身鑽進了樹林，連獵刀都不要了。"],
		"scene": ["林子深處，樹上掛著幾張剝下來的鹿皮。"],
		"start": ["樹林裡傳來一聲口哨。一個穿著鹿皮的人從樹後走出來，手裡的獵刀還在滴血：「這片林子不歡迎外人。」"],
		"actions": {
			"slash": {"type": "sweep", "w": 35, "power": 0.9, "armed": true,
				"tell": ["{name}反手握著獵刀，往旁邊一拉，橫抹過來。"],
				"hit": ["獵刀從你的前臂上抹過去，血一下子流了滿手。", "刀鋒劃過你的肋下。"]},
			"stab": {"type": "thrust", "w": 30, "power": 1.0, "armed": true,
				"tell": ["{name}壓低身子，獵刀對準你的肚子捅過來。"],
				"hit": ["獵刀捅進你的腰側，{pron}手腕一擰才拔出來。"]},
			"snare": {"type": "trick", "w": 20, "power": 0.0, "on_hit": "off_balance",
				"tell": ["{name}往後一跳，腳尖勾起地上的一截繩子。"],
				"hit": ["繩套套住了你的腳踝，{pron}一扯，你摔倒在地。"]},
			"punch": {"type": "thrust", "w": 50, "power": 0.5, "unarmed": true,
				"tell": ["{name}罵了一聲，揮拳朝你臉上打來。"],
				"hit": ["一拳正中你的鼻樑。"]},
			"pickup": {"type": "opening", "w": 50, "unarmed": true, "pickup": true,
				"tell": ["{name}彎腰去撿地上的獵刀，背後全空了。"]},
		},
		"habits": [
			{"last": "snare", "then": "stab", "tell": "你還沒站穩，{name}已經撲上來，獵刀對準你的肚子。"},
		],
		"pain": {
			"light": ["{name}罵了一聲。"],
			"heavy": ["{name}捂著傷口退了一步。"],
			"dying": ["{name}靠在樹上喘氣，獵刀垂了下來。"],
		},
	},
	"smuggler": {
		"name": "走私頭子",
		"blurb": "",
		"hp": 180, "str": 15, "agi": 12, "armor": "light", "traits": ["disarmable"], "kinds": ["blade"], "pron": "他",
		"weapon": "彎刀", "guard": "架勢", "move_pool": ["fallstone", "triple", "shed", "dust"], "pool_n": 2,
		"parry": ["{name}把彎刀一豎，噹的一聲架住了你的{my}。"],
		"fear": ["{name}的眼睛往停在岸邊的小船瞄了一眼。"],
		"fear_flee": ["{name}跳上小船，拼命往外划。"],
		"scene": ["漁村的碼頭，木箱堆得比人還高，空氣裡全是魚腥味。"],
		"start": ["木箱後面站起來幾個人。帶頭的那個把彎刀從鞘裡抽出來：「看到不該看的了？」"],
		"actions": {
			"cut": {"type": "sweep", "w": 35, "power": 1.0, "armed": true,
				"tell": ["{name}把彎刀往身後一拉，腰一擰，刀鋒劈了過來。"],
				"hit": ["彎刀砍在你的肩膀上，刀刃卡進了肉裡。", "刀鋒從你胸前拖過去。"]},
			"chop": {"type": "smash", "w": 25, "power": 1.4, "windup": true, "armed": true,
				"tell": ["{name}雙手握刀舉過頭頂，腳下一沉。"],
				"strike_tell": ["彎刀劈下來了！"],
				"hit": ["彎刀劈在你肩頭，你半邊身子都麻了。"]},
			"bottle": {"type": "trick", "w": 15, "power": 0.3, "on_hit": "blind",
				"tell": ["{name}從腰間摸出一個酒瓶。"],
				"hit": ["酒瓶砸在你臉上，碎玻璃和烈酒一起濺進你眼睛。"]},
			"kick": {"type": "thrust", "w": 25, "power": 0.6, "on_hit": "off_balance",
				"tell": ["{name}抬腳往你肚子上踹。"],
				"hit": ["這一腳正中你的肚子，你彎著腰退了好幾步。"]},
			"punch": {"type": "thrust", "w": 50, "power": 0.5, "unarmed": true,
				"tell": ["{name}罵了一聲，揮拳朝你臉上打來。"],
				"hit": ["一拳正中你的下巴。"]},
			"pickup": {"type": "opening", "w": 50, "unarmed": true, "pickup": true,
				"tell": ["{name}彎腰去撿地上的彎刀，背後全空了。"]},
		},
		"habits": [
			{"last": "kick", "chance": 0.6, "then": "chop", "tell": "你還彎著腰，{name}已經雙手把彎刀舉過了頭頂。"},
		],
		"pain": {
			"light": ["{name}啐了一口。"],
			"heavy": ["{name}踉蹌了一下，撞翻了一個木箱。"],
			"dying": ["{name}靠在木箱上喘氣，刀尖垂到了地上。"],
		},
	},
	"pikeman": {
		"name": "長槍兵",
		"blurb": "",
		"hp": 230, "str": 16, "agi": 15, "armor": "light", "traits": ["disarmable"], "pron": "他",
		"weapon": "長槍", "guard": "槍桿", "move_pool": ["knee", "deflect", "dust", "shed"], "pool_n": 2,
		"parry": ["{name}把槍桿往身前一橫，架住了你的{my}。"],
		"fear": ["{name}握槍的手緊了緊，往後退了一步。"],
		"fear_flee": ["{name}丟下長槍，翻過驛站的矮牆跑了。"],
		"scene": ["驛站的馬廄前，地上的車轍裡積著泥水。"],
		"start": ["一個穿著舊軍服的人拄著長槍站在路中間：「這條路，現在歸我管。」"],
		"actions": {
			"thrust": {"type": "thrust", "w": 35, "power": 1.1, "armed": true,
				"tell": ["{name}兩手一前一後握著長槍，槍尖從遠處直刺過來。"],
				"hit": ["槍尖刺進你的肩膀，{pron}一抽，又收了回去。", "槍尖扎在你的大腿上。"]},
			"keep": {"type": "guard", "w": 20,
				"tell": ["{name}退了一步，槍尖在你面前畫著圈，不讓你靠近。"]},
			"butt": {"type": "sweep", "w": 25, "power": 0.8, "on_hit": "off_balance", "armed": true,
				"tell": ["{name}把槍桿一轉，用槍尾往你腳下掃過來。"],
				"hit": ["槍尾掃在你的腳踝上，你腳下一絆。"]},
			"lunge": {"type": "thrust", "w": 20, "power": 1.6, "windup": true, "armed": true,
				"tell": ["{name}往後撤了半步，槍尖壓低，重心往後坐。"],
				"strike_tell": ["{name}連人帶槍衝了過來！"],
				"hit": ["槍尖扎進你的腰側，你被頂得往後退了好幾步。"]},
			"punch": {"type": "thrust", "w": 50, "power": 0.5, "unarmed": true,
				"tell": ["{name}罵了一聲，揮拳朝你臉上打來。"],
				"hit": ["一拳正中你的臉。"]},
			"pickup": {"type": "opening", "w": 50, "unarmed": true, "pickup": true,
				"tell": ["{name}彎腰去撿地上的長槍，背後全空了。"]},
		},
		"habits": [
			# 你閃開了，槍尖追過來
			{"player": ["dodge"], "then": "thrust", "tell": "你剛躲開，槍尖已經追了過來。"},
		],
		"pain": {
			"light": ["{name}往後退了一步，又把槍尖對準你。"],
			"heavy": ["{name}的槍尖垂了一下。"],
			"dying": ["{name}拄著長槍喘氣。"],
		},
	},
	"alpha_wolf": {
		"name": "頭狼",
		"blurb": "",
		"hp": 270, "str": 14, "agi": 18, "armor": "none", "traits": ["beast"], "pron": "牠",
		"weapon": "利牙", "guard": "架勢",
		"fear": ["頭狼壓低了耳朵，往後退了一步。"],
		"fear_flee": ["頭狼轉身跑了，狼群跟著散進了草叢。"],
		"scene": ["村外的草地，風把草吹得一片一片倒下去。"],
		"start": ["草地上趴著三四頭狼，中間那頭站了起來。牠比別的狼大了一圈，脖子上的毛是灰白的。其他的狼沒有動，只看著。"],
		"actions": {
			"bite": {"type": "thrust", "w": 35, "power": 1.0,
				"tell": ["頭狼貼著地面竄上來，張嘴咬你的腿。"],
				"hit": ["頭狼一口咬在你的大腿上，甩頭一扯，撕下一塊肉。", "牙齒咬穿了你的小腿。"]},
			"leap": {"type": "thrust", "w": 25, "power": 1.5, "windup": true,
				"tell": ["頭狼往後一縮，後腿繃緊，眼睛盯著你的喉嚨。"],
				"strike_tell": ["頭狼撲向你的喉嚨！"],
				"hit": ["頭狼把你撲倒在地，牙齒擦過你的脖子，咬在肩膀上。"]},
			"feint": {"type": "trick", "w": 15, "power": 0.0, "on_hit": "off_balance",
				"tell": ["頭狼繞著你走，忽然往左一撲，又停住。"],
				"hit": ["你跟著往左擋，腳下一亂，頭狼已經繞到你身側。"]},
			"howl": {"type": "roar", "w": 10, "power": 0.0, "on_hit": "shaken",
				"tell": ["頭狼仰起頭，喉嚨一鼓。"],
				"hit": ["狼嚎在你耳邊炸開，四周的狼跟著嚎了起來。你腦中一空。"]},
			"drag": {"type": "grab", "w": 15, "power": 0.7, "on_hit": "held",
				"tell": ["頭狼從側面撲向你的手臂。"],
				"hit": ["頭狼咬住你的前臂，四腳撐地往後拖。"],
				"hold": {"power": 0.6,
					"tell": ["頭狼咬著你的手臂不放，左右甩頭。"],
					"hit": ["牙齒越咬越深，你的手指開始發麻。"]}},
		},
		"habits": [
			{"last": "feint", "then": "bite", "tell": "你腳下還沒站穩，頭狼已經咬向你的腿。"},
		],
		"rage": {
			"hp_below": 0.4,
			"text": "頭狼的毛全豎了起來，喉嚨裡滾著低吼，不再繞圈子。",
			"weights": {"leap": 40, "bite": 30, "drag": 30},
		},
		"pain": {
			"light": ["頭狼往旁邊一跳，又齜牙瞪著你。"],
			"heavy": ["頭狼哀叫一聲，滾了出去，又爬起來。"],
			"dying": ["頭狼的腿在發抖，還是擋在狼群前面。"],
		},
	},
	"elk": {
		"name": "巨角鹿",
		"blurb": "",
		"hp": 330, "str": 20, "agi": 13, "armor": "none", "traits": ["beast", "big"], "pron": "牠",
		"weapon": "鹿角", "guard": "鹿角",
		"fear": ["巨角鹿打了個響鼻，往後退了幾步。"],
		"fear_flee": ["巨角鹿轉身跑進了林子，樹枝被撞得劈啪響。"],
		"scene": ["山路兩邊是密密的杉樹，路上有被撞翻的車輪。"],
		"start": ["山路上站著一頭巨角鹿，肩膀比你的頭還高，鹿角張開來比一個人還寬。牠盯著你，前蹄在地上刨了一下。"],
		"actions": {
			"gore": {"type": "thrust", "w": 35, "power": 1.2,
				"tell": ["巨角鹿低下頭，鹿角對準你衝過來。"],
				"hit": ["鹿角頂在你的胸口，你被挑起來，摔在幾步外。"]},
			"sweep": {"type": "sweep", "w": 35, "power": 1.0,
				"tell": ["巨角鹿把頭往旁邊一甩，鹿角橫掃過來。"],
				"hit": ["鹿角掃中你的腰，你整個人轉了半圈。"]},
			"rear": {"type": "smash", "w": 25, "power": 1.5, "windup": true,
				"tell": ["巨角鹿人立起來，兩隻前蹄高高舉起。"],
				"strike_tell": ["前蹄踏下來了！"],
				"hit": ["前蹄踏在你肩上，你跪倒在地。"]},
			"tangle": {"type": "opening", "w": 0, "no_parry": true,
				"tell": ["鹿角卡進了路邊的樹枝裡，巨角鹿甩著頭想掙出來。"]},
		},
		"habits": [
			# 衝過頭，鹿角卡進樹枝
			{"last": "gore", "chance": 0.4, "then": "tangle"},
		],
		"rage": {
			"hp_below": 0.35,
			"text": "巨角鹿噴著鼻息，前蹄刨地，低下頭不再後退。",
			"weights": {"gore": 40, "rear": 40, "sweep": 20},
		},
		"pain": {
			"light": ["巨角鹿甩了甩頭。"],
			"heavy": ["巨角鹿嘶鳴一聲，往後退了好幾步。"],
			"dying": ["巨角鹿的腿在發抖，鹿角低低地對著你。"],
		},
	},
	"butcher": {
		"name": "屠夫",
		"blurb": "",
		"hp": 340, "str": 21, "agi": 14, "armor": "light", "traits": ["disarmable"], "kinds": ["blade"], "pron": "他", "no_flee": true,
		"weapon": "剁肉刀", "guard": "架勢", "move_pool": ["fallstone", "triple", "shed", "knee"], "pool_n": 2,
		"parry": ["{name}把剁肉刀一橫，刀背撞開了你的{my}。"],
		"scene": ["城牆的缺口裡又暗又潮，地上有拖過東西的痕跡。"],
		"start": ["缺口裡掛著幾塊肉，看不出是什麼的肉。一個圍著皮圍裙的大個子從陰影裡走出來，手裡的剁肉刀和鐵鉤都是黑的。"],
		"actions": {
			"chop": {"type": "smash", "w": 30, "power": 1.2, "armed": true,
				"tell": ["{name}把剁肉刀舉到耳邊，一刀剁下來。"],
				"hit": ["剁肉刀砍在你的肩膀上，骨頭響了一聲。"]},
			"hook": {"type": "grab", "w": 20, "power": 0.8, "on_hit": "held",
				"tell": ["{name}另一隻手抓著鐵鉤，往你的肩膀鉤過來。"],
				"hit": ["鐵鉤鉤住了你的肩頭，{pron}一扯，把你拉到身前。"],
				"hold": {"power": 0.9,
					"tell": ["{name}鉤著你不放，剁肉刀高高舉起。"],
					"hit": ["剁肉刀一下一下剁在你身上。"]}},
			"sweep": {"type": "sweep", "w": 30, "power": 1.0, "armed": true,
				"tell": ["{name}把剁肉刀往旁邊一拉，橫著揮過來。"],
				"hit": ["刀刃從你的肚子上拖過去。"]},
			"shove": {"type": "thrust", "w": 20, "power": 0.6, "on_hit": "off_balance",
				"tell": ["{name}挺著肚子往你身上撞。"],
				"hit": ["{pron}整個人撞在你身上，你往後踉蹌了好幾步。"]},
			"punch": {"type": "thrust", "w": 50, "power": 0.6, "unarmed": true,
				"tell": ["{name}掄起拳頭朝你臉上砸來。"],
				"hit": ["這一拳砸在你的顴骨上，你眼前一白。"]},
			"pickup": {"type": "opening", "w": 50, "unarmed": true, "pickup": true,
				"tell": ["{name}彎腰去撿地上的剁肉刀，背後全空了。"]},
		},
		"habits": [
			{"last": "shove", "then": "chop", "tell": "你還沒站穩，{name}的剁肉刀已經舉到了耳邊。"},
		],
		"pain": {
			"light": ["{name}低頭看了一眼，沒當一回事。"],
			"heavy": ["{name}悶哼一聲，圍裙上多了一道口子。"],
			"dying": ["{name}喘得很重，腳步還是往前。"],
		},
	},
	"croc": {
		"name": "老鱷",
		"blurb": "",
		"hp": 580, "str": 24, "agi": 11, "armor": "light", "traits": ["beast", "big"], "pron": "牠",
		"weapon": "大嘴", "guard": "鱗甲",
		"fear": ["老鱷往水邊退了一點，眼睛還盯著你。"],
		"fear_flee": ["老鱷滑進了水裡，不見了。"],
		"scene": ["退潮後的泥灘，腳一踩下去就陷到腳踝。"],
		"start": ["泥灘上有一截像爛木頭的東西。你走近了，那截木頭睜開了眼睛。"],
		"actions": {
			"snap": {"type": "thrust", "w": 35, "power": 1.2,
				"tell": ["老鱷貼著地面往前一竄，張開大嘴咬過來。"],
				"hit": ["老鱷一口咬在你的腿上，牙齒卡進了骨頭。"]},
			"roll": {"type": "grab", "w": 20, "power": 0.9, "on_hit": "held",
				"tell": ["老鱷從側面撲過來，要咬住你的腰。"],
				"hit": ["老鱷咬住你的腰，整個身子一翻，把你帶倒在泥裡。"],
				"hold": {"power": 1.0,
					"tell": ["老鱷咬著你翻滾，泥水灌進了你的嘴。"],
					"hit": ["你被甩得分不清上下，身上的肉被扯開。"]}},
			"tail": {"type": "sweep", "w": 30, "power": 1.1, "on_hit": "off_balance",
				"tell": ["老鱷的身子往一邊一扭，尾巴橫掃過來。"],
				"hit": ["尾巴掃在你的小腿上，你整個人被掃倒。"]},
			"sink": {"type": "guard", "w": 15,
				"tell": ["老鱷退回水邊，只露出眼睛和背上的鱗甲。"]},
			"rest": {"type": "opening", "w": 0,
				"tell": ["老鱷張著嘴趴在泥上喘氣，一動不動。"]},
		},
		"habits": [
			{"last": "roll", "chance": 0.5, "then": "rest"},
		],
		"pain": {
			"light": ["老鱷的鱗甲擋掉了大半。"],
			"heavy": ["老鱷翻了個身，喉嚨裡發出低沉的響聲。"],
			"dying": ["老鱷往水邊爬，泥上拖出一道血痕。"],
		},
	},
	"troll": {
		"name": "巨魔",
		"blurb": "",
		"hp": 800, "str": 28, "agi": 14, "armor": "light", "traits": ["big"], "pron": "牠", "no_flee": true,
		"weapon": "石頭", "guard": "手臂",
		"scene": ["山口的雪地，風颳得人睜不開眼睛。"],
		"start": ["雪地上一個比門還高的影子站了起來。巨魔的皮是灰白色的，跟雪差不多。"],
		"actions": {
			"swipe": {"type": "sweep", "w": 35, "power": 1.1,
				"tell": ["巨魔把一隻長手臂往後一拉，橫著掄過來。"],
				"hit": ["那隻手臂掃在你身上，你被拍飛出去，撞在岩壁上。"]},
			"boulder": {"type": "smash", "w": 25, "power": 1.8, "windup": true,
				"tell": ["巨魔彎腰抱起一塊石頭，舉過頭頂。"],
				"strike_tell": ["石頭砸下來了！"],
				"hit": ["石頭擦過你的肩膀，你被砸倒在地。"]},
			"grab": {"type": "grab", "w": 20, "power": 1.0, "on_hit": "held",
				"tell": ["巨魔張開大手抓過來。"],
				"hit": ["巨魔一把抓住你，把你舉了起來。"],
				"hold": {"power": 1.1,
					"tell": ["巨魔抓著你往岩壁上撞。"],
					"hit": ["你的背撞在岩壁上，眼前一黑。"]}},
			"roar": {"type": "roar", "w": 10, "power": 0.0, "on_hit": "shaken",
				"tell": ["巨魔張大了嘴，胸口一鼓。"],
				"hit": ["吼聲在山谷裡來回撞，你耳朵嗡嗡響，腦中一空。"]},
			"stuck": {"type": "opening", "w": 0, "no_parry": true,
				"tell": ["石頭砸進了雪裡，巨魔彎著腰，還沒直起身。"]},
		},
		"habits": [
			{"last": "boulder", "chance": 0.6, "then": "stuck"},
		],
		"rage": {
			"hp_below": 0.3,
			"text": "巨魔捶著胸口，一步一步往前逼，腳下的雪被踩得陷下去。",
			"weights": {"swipe": 40, "boulder": 30, "grab": 30},
		},
		"pain": {
			"light": ["巨魔低頭看了看，又抬起頭。"],
			"heavy": ["巨魔往後晃了一步，吼了一聲。"],
			"dying": ["巨魔的腳步越來越慢，每走一步都喘一口白氣。"],
		},
	},

	# ---------- 有名字的強者（懸賞） ----------
	"merc_captain": {
		"name": "羅德里克", "title": "傭兵隊長",
		"blurb": "傭兵團「紅鬃」的隊長。獨眼。",
		"hp": 260, "str": 18, "agi": 18, "armor": "light", "traits": [], "kinds": ["sword"], "pron": "他",
		"weapon": "鋸齒劍", "guard": "架勢", "loot": "red_fang", "no_flee": true,
		"parry": ["{name}腳下還沒站穩，劍卻已經橫在身前。你砍上去，{pron}的劍卡住了你的{my_blade}。", "你搶上一步出手，{name}的劍往上一挑，把你的{my}架開了。"],
		"scene": ["傭兵營地外的空地，篝火還在冒煙。十幾個傭兵圍成一圈等著看。"],
		"start": ["一個獨眼的高個子從人群裡走出來，拔出一把暗紅色的劍：「就是你要拿我的人頭？」"],
		"actions": {
			"slash": {"type": "sweep", "w": 35, "power": 1.1,
				"tell": ["{name}把劍往身側一拉，腰扭了過去。"],
				"hit": ["{weapon}從你腰側拖過去，衣服和皮肉一起被扯開。", "劍從側面砍進你的手臂。"]},
			"lunge": {"type": "thrust", "w": 30, "power": 1.0,
				"tell": ["{name}壓低身子，劍尖對準你的喉嚨。"],
				"hit": ["劍尖刺進你的肩膀。", "劍捅進你的腰側，刮過肋骨。"]},
			"execute": {"type": "smash", "w": 20, "power": 1.6, "windup": true,
				"tell": ["{name}雙手把劍舉過頭頂：「站好，很快就結束。」"],
				"strike_tell": ["{name}的劍劈了下來！"],
				"hit": ["劍劈在你肩上，劍刃卡進肉裡，{pron}一扯，你痛得叫出聲。"]},
			"feint": {"type": "trick", "w": 15, "power": 0.4, "on_hit": "off_balance",
				"tell": ["{name}的劍尖晃了兩下，腳卻往另一邊踏。"],
				"hit": ["你被騙得往左一撲，他一腳踹在你膝蓋上。旁邊的傭兵笑了起來。", "他劍尖一晃，你跟著去擋，膝蓋上結結實實挨了一腳。"]},
		},
		"habits": [
			{"last": "slash", "chance": 0.5, "then": "execute", "tell": "{name}順勢把劍舉過頭頂。"},
		],
		"rage": {
			"hp_below": 0.3,
			"text": "{name}抹掉臉上的血，笑了一聲。旁邊的傭兵不笑了。",
			"weights": {"slash": 40, "lunge": 30, "execute": 30},
		},
		"pain": {
			"light": ["{name}嘖了一聲。", "{name}退了半步。"],
			"heavy": ["{name}踉蹌了一下，旁邊有人叫出聲。", "{name}不笑了。", "{name}低頭看了一眼傷口，往地上啐了一口。"],
			"dying": ["{name}拄著劍喘氣，眼睛還盯著你。"],
		},
		"win_text": "{name}跪倒在地，劍掉在你腳邊。沒有一個傭兵上前。",
	},
	"black_knight": {
		"name": "黑騎士", "title": "",
		"blurb": "全身黑甲的騎士，被騎士團趕了出來。背著一把很寬的大劍。",
		"hp": 360, "str": 22, "agi": 20, "armor": "heavy", "traits": [], "kinds": ["greatsword", "sword"], "pron": "他",
		"weapon": "大劍", "guard": "劍身", "loot": "knell", "no_flee": true,
		"parry": ["你的{my}砍在{name}豎起來的大劍上，嗡的一聲，虎口都麻了。", "{name}還沒站穩，大劍卻已經擋在身前。你的{my}砍在寬寬的劍身上，滑了開去。"],
		"scene": ["廢棄的驛站。屋頂破了一個大洞，夕陽照在地上。"],
		"start": ["驛站中間坐著一個穿黑甲的騎士，膝上橫著一把黑色的大劍。他站起來的時候，劍身嗡嗡地響。"],
		"actions": {
			"cleave": {"type": "sweep", "w": 35, "power": 1.2,
				"tell": ["{name}把大劍往身側拉開，腰扭了過去。"],
				"hit": ["大劍從側面掃中你，你整個人被拍了出去。", "劍身砍進你的腰側，像被一扇鐵門甩中。"]},
			"wall": {"type": "guard", "w": 20,
				"tell": ["{name}把大劍豎在身前，寬寬的劍身把他整個人擋住。"]},
			"toll": {"type": "smash", "w": 25, "power": 1.7, "windup": true,
				"tell": ["{name}雙手把大劍舉起來，劍身越響越大聲。"],
				"strike_tell": ["大劍砸下來了！"],
				"hit": ["大劍砸在你身上，你耳朵裡只剩下嗡嗡聲。"]},
			"pierce": {"type": "thrust", "w": 20, "power": 1.0,
				"tell": ["{name}壓低身子，劍尖對準你的胸口，一步踏進來。"],
				"hit": ["劍尖撞進你的胸口，你往後滑了好幾步。"]},
		},
		"habits": [
			# 你砍在劍身上，他順勢刺回來
			{"last": "wall", "player": ["attack", "needle", "lh_half", "triple", "knee", "fb_whirl", "lh_pommel"], "then": "pierce", "tell": "{name}把擋住你的{my}身一翻，劍尖對準了你的胸口。"},
		],
		"pain": {
			"light": ["劍刃在黑甲上刮出一串火星。", "{name}沒有出聲。"],
			"heavy": ["黑甲裂開一道口子，{name}退了一步。", "頭盔裡傳出一聲悶哼。"],
			"dying": ["{name}拄著大劍，呼吸聲越來越重。"],
		},
		"win_text": "{name}單膝跪下，過了很久才開口：「拿去吧。」他把大劍推到你腳邊。",
	},

	"raider": {
		"name": "烏爾夫", "title": "劫掠者",
		"blurb": "從北邊海上來的劫掠者，扛著一把雙刃斧。打起來不要命。",
		"hp": 300, "str": 19, "agi": 13, "armor": "light", "traits": ["disarmable"], "kinds": ["axe"], "pron": "他",
		"weapon": "雙刃斧", "guard": "斧柄", "loot": "gatebreaker", "no_flee": true,
		"parry": ["{name}還沒站穩，就把斧柄往身前一橫。你的{my}砍在斧柄的鐵箍上，彈了回來。", "你搶上去出手，{name}用斧柄硬擋，木屑飛了起來。"],
		"scene": ["燒焦的漁村，海風把灰吹得到處都是。", "海邊的礁石灘，浪一直打上來。"],
		"start": ["一個滿臉紅鬍子的大漢把斧頭從木樁上拔出來，咧嘴一笑：「又一個。」"],
		"actions": {
			"hack": {"type": "sweep", "w": 35, "power": 1.2,
				"tell": ["{name}掄起斧頭往旁邊一甩，整個人跟著轉了過去。"],
				"hit": ["斧頭從側面砍進你的大腿，你差點跪下去。", "斧刃擦過你的肋下，帶走一片皮肉。"]},
			"cleave": {"type": "smash", "w": 25, "power": 1.8, "windup": true,
				"tell": ["{name}雙手握住斧柄，把斧頭舉過頭頂。"],
				"strike_tell": ["斧頭劈下來了！"],
				"hit": ["斧頭劈在你肩上，你整條手臂都沒了知覺。", "你偏了一下頭，斧刃砍在你的鎖骨上。"]},
			"charge": {"type": "grab", "w": 20, "power": 0.9, "on_hit": "off_balance",
				"tell": ["{name}低下頭，肩膀對著你衝過來。"],
				"hit": ["{name}一肩撞在你胸口，你往後倒，背砸在地上。"]},
			"howl": {"type": "roar", "w": 20, "power": 0.0, "on_hit": "shaken",
				"tell": ["{name}拿斧背敲著胸口，扯開嗓子大吼。"],
				"hit": ["吼聲震得你耳朵發疼，手上慢了下來。"]},
			"stuck": {"type": "opening", "w": 0, "no_parry": true,
				"tell": ["斧頭砍進地裡，{name}雙手握著斧柄往外拔。"]},
		},
		"habits": [
			# 劈下去斧頭常砍進地裡
			{"last": "cleave", "chance": 0.5, "then": "stuck"},
		],
		"rage": {
			"hp_below": 0.3,
			"text": "{name}把滿嘴的血吐在地上，大笑起來。",
			"weights": {"hack": 40, "cleave": 40, "charge": 20},
		},
		"pain": {
			"light": ["{name}哼了一聲。", "{name}往傷口看了一眼，笑了。"],
			"heavy": ["{name}往後退了一步，抹了一把臉上的血。", "{name}罵了一句你聽不懂的話。"],
			"dying": ["{name}喘著粗氣，斧頭越掄越慢。"],
		},
		"win_text": "{name}仰面倒在地上，手還握著斧柄。過了一會兒，手鬆開了。",
	},
	"duelist": {
		"name": "伊薇特", "title": "決鬥家",
		"blurb": "南方來的決鬥家，右手細劍，左手短劍。據說沒輸過。",
		"hp": 240, "str": 15, "agi": 21, "armor": "none", "traits": ["disarmable"], "kinds": ["rapier"], "pron": "她",
		"weapon": "細劍", "guard": "短劍", "no_flee": true,
		"parry": ["{name}還沒站穩，左手的短劍已經架了過來，把你的{my}撥開。", "你搶上去出手，{name}用短劍一擋，細劍跟著點向你的手腕，你只好收手。"],
		"scene": ["城外的墓園，墓碑之間的草剛割過。", "清晨的廣場，噴水池邊一個人都沒有。"],
		"start": ["一個穿深色外套的女人等在那裡，右手細劍，左手短劍。她把劍尖往地上點了點：「你是來決鬥的？」"],
		"actions": {
			"lunge": {"type": "thrust", "w": 30, "power": 1.1,
				"tell": ["{name}右腳往前一滑，細劍直直刺向你的胸口。"],
				"hit": ["細劍刺進你的上臂，又拔了出去。", "劍尖從你的肋骨之間刺進去一寸。"]},
			"flurry": {"type": "thrust", "w": 20, "power": 1.3,
				"tell": ["{name}的劍尖抖了幾下，連著刺過來。"],
				"hit": ["你擋開了兩劍，第三劍刺進了你的大腿。", "你身上一下子多了三個小洞。"]},
			"feint": {"type": "trick", "w": 20, "power": 0.4, "on_hit": "off_balance",
				"tell": ["{name}的劍尖往你左邊一點，人卻往右邊踏。"],
				"hit": ["你跟著去擋左邊，她的短劍在你手背上劃了一道。", "你撲了個空，腳下一亂。"]},
			"guard": {"type": "guard", "w": 25,
				"tell": ["{name}側過身子，短劍橫在胸前，細劍的劍尖對著你，一步也不肯上前。"]},
		},
		"habits": [
			{"last": "feint", "chance": 0.6, "then": "lunge", "tell": "你還沒站穩，{name}的劍尖已經對準了你。"},
			# 你用了收不回來的大招，她就刺過來
			{"player": ["fallstone", "fb_cleave", "triple", "fb_whirl"], "chance": 0.5, "then": "lunge", "tell": "你這一下用老了，{name}腳下一錯，劍尖跟著遞了過來。"},
		],
		"pain": {
			"light": ["{name}皺了一下眉。", "{name}往後跳開一步，看了看袖子上的血。"],
			"heavy": ["{name}悶哼一聲，臉色白了。", "{name}的腳步亂了一下。"],
			"dying": ["{name}的劍尖開始發抖，她咬著嘴唇不出聲。"],
		},
		"win_text": "{name}坐倒在地上，細劍掉在一邊。她看著你，笑了一下：「你贏了。」",
	},
	"old_captain": {
		"name": "葛雷森", "title": "老衛隊長",
		"blurb": "以前王都衛隊的隊長，現在替人收債。頭髮白了，劍還是很穩。",
		"hp": 620, "str": 27, "agi": 26, "armor": "light", "traits": ["disarmable"], "kinds": ["sword"], "pron": "他",
		"weapon": "長劍", "guard": "長劍", "loot": "nightwatch", "no_flee": true,
		"parry": ["{name}腳下一錯，長劍已經回到身前，把你的{my}擋了回來。", "你搶上去出手，{name}不慌不忙地一擋，像是早就知道你會砍哪裡。"],
		"scene": ["碼頭邊的倉庫，空氣裡都是魚腥味。", "下雨的巷子，水從屋簷一直滴下來。"],
		"start": ["一個頭髮花白的男人靠在牆邊，慢慢拔出一把長劍：「我年輕的時候，也是這樣一個人去找別人麻煩。」"],
		"actions": {
			"cut": {"type": "sweep", "w": 30, "power": 1.1,
				"tell": ["{name}的長劍從身側斜斜劈過來，不快，但很沉。"],
				"hit": ["長劍砍在你的手臂上，砍得很深。", "劍刃從你腰側拖過去，你的衣服一下子紅了一片。"]},
			"thrust": {"type": "thrust", "w": 25, "power": 1.1,
				"tell": ["{name}壓低身子，一步踏進來，劍尖對準你的喉嚨。"],
				"hit": ["劍尖刺進你的肩膀，他手腕一轉才拔出來。"]},
			"guard": {"type": "guard", "w": 25,
				"tell": ["{name}退了半步，長劍豎在身前，等你先動。"]},
			"cleave": {"type": "smash", "w": 20, "power": 1.6, "windup": true,
				"tell": ["{name}雙手握劍，慢慢舉到肩上。"],
				"strike_tell": ["長劍劈下來了！"],
				"hit": ["這一劍劈在你肩頭，你兩腿一軟，跪了一下才站起來。"]},
		},
		"habits": [
			# 你砍在他的劍上，他順著你的{my_blade}刺回來
			{"last": "guard", "player": ["attack", "fallstone", "fb_cleave", "triple", "fb_whirl", "needle", "lh_half"], "then": "thrust", "tell": "{name}架開你的{my}，順著你的{my_blade}滑進來，劍尖對準你的胸口。"},
		],
		"pain": {
			"light": ["{name}沒有出聲，換了一口氣。", "{name}退了一步。"],
			"heavy": ["{name}的臉抽了一下，腳步慢了。", "{name}低頭看了看傷口：「好久沒人砍得到我了。」"],
			"dying": ["{name}拄著劍喘氣，頭髮貼在額頭上。"],
		},
		"win_text": "{name}靠著牆慢慢坐下去，把長劍橫放在膝上：「拿去吧。」",
	},
	"rebel_lord": {
		"name": "瓦倫", "title": "叛將",
		"blurb": "背叛了領主、佔了山口要塞的將軍。左手一面塔盾，右手一把戰錘。",
		"hp": 960, "str": 31, "agi": 24, "armor": "heavy", "traits": [], "kinds": ["hammer"], "pron": "他",
		"weapon": "戰錘", "guard": "塔盾", "no_flee": true,
		"parry": ["{name}還沒站穩，塔盾已經擋在身前。你的{my}砍在盾面上，震得手腕發麻。", "你搶上去出手，{name}把盾一推，連你帶{my}一起推開。"],
		"scene": ["山口的舊要塞，城牆上的旗子早就燒掉了。", "要塞的中庭，地上的石板裂了好幾道縫。"],
		"start": ["一個穿全身鎧甲的男人從城門走出來，左手的塔盾比你還寬。他把戰錘往地上一頓：「一個人來？」"],
		"actions": {
			"swing": {"type": "sweep", "w": 30, "power": 1.3,
				"tell": ["{name}把戰錘往後一拉，腰一扭，橫掄過來。"],
				"hit": ["戰錘掄在你的腰上，你被打得橫著飛出去。", "錘頭砸在你的手臂上，你聽見骨頭響了一聲。"]},
			"wall": {"type": "guard", "w": 25,
				"tell": ["{name}把塔盾往地上一頓，整個人縮在盾後面。"]},
			"bash": {"type": "smash", "w": 20, "power": 0.9, "on_hit": "off_balance",
				"tell": ["{name}舉著塔盾往前一衝。"],
				"hit": ["塔盾撞在你身上，你整個人被撞開，腳下站不穩。"]},
			"crush": {"type": "smash", "w": 25, "power": 2.0, "windup": true,
				"tell": ["{name}雙手握住戰錘，舉過頭頂。"],
				"strike_tell": ["戰錘砸下來了！"],
				"hit": ["戰錘砸在你身上，你眼前一黑，什麼都聽不見了。"]},
		},
		"habits": [
			# 你砍在盾上，他舉盾撞過來
			{"last": "wall", "player": ["attack", "fallstone", "fb_cleave", "triple", "fb_whirl", "needle", "lh_half"], "then": "bash", "tell": "你的{my}還卡在盾面上，{name}已經舉著盾撞了過來。"},
		],
		"rage": {
			"hp_below": 0.3,
			"text": "{name}把塔盾丟到一邊，雙手握住了戰錘。",
			"weights": {"swing": 40, "crush": 45, "bash": 15},
		},
		"pain": {
			"light": ["劍砍在鎧甲上，刮出一道白痕。", "{name}哼了一聲。"],
			"heavy": ["鎧甲的接縫裂開，血滲了出來。{name}退了一步。", "頭盔裡傳出一聲悶哼。"],
			"dying": ["{name}的呼吸越來越重，戰錘拖在地上。"],
		},
		"win_text": "{name}跪倒在中庭的石板上，戰錘從手裡滑了出去。城牆上他的手下一個個放下了弓。",
	},

	# 練劍的年輕人（劍庭的學徒、城裡的年輕人的打法）。沒有別的年輕人報名時，劍庭選拔跟你比的也是他
	"master": {
		"name": "另一個報名的年輕人",
		"blurb": "",
		"hp": 120, "str": 11, "agi": 11, "armor": "none", "traits": ["disarmable"], "kinds": ["sword"], "pron": "他", "no_flee": true,
		"weapon": "劍", "guard": "架勢", "moves": ["knee"],
		"parry": ["你搶上去出手，{name}慌忙把劍橫過來，擋住了。"],
		"scene": ["城牆根下的空地，地上的沙被踩得很實。"],
		"start": ["{name}握著劍，朝你點了點頭。"],
		"actions": {
			"cut": {"type": "sweep", "w": 35, "power": 1.0,
				"tell": ["{name}腳下一錯，木劍從身側橫掃過來。"],
				"hit": ["{weapon}抽在你的肋下，你彎下了腰。", "啪的一聲，{weapon}掃在你的手臂上，整條手臂都麻了。"]},
			"thrust": {"type": "thrust", "w": 30, "power": 1.0,
				"tell": ["{name}往前踏了半步，劍尖直刺你的胸口。"],
				"hit": ["劍尖戳在你的胸口，你一口氣差點喘不上來。", "劍尖點在你的肩窩，整條手臂一軟。"]},
			"cleave": {"type": "smash", "w": 35, "power": 1.1,
				"tell": ["{name}雙手把木劍舉過頭頂，重心沉了下去，一劍劈下。"],
				"hit": ["{weapon}劈在你的肩膀上，你膝蓋一軟，差點跪下去。", "{weapon}敲在你的額頭上，咚的一聲。"]},
		},
		"habits": [
			# 你閃避完腳步還沒站穩，他就劈下來
			{"player": ["dodge"], "then": "cleave", "tell": "你腳步還沒站穩，{name}的木劍已經舉過頭頂：「躲完了呢？」"},
		],
		"pain": {
			"light": ["{name}輕輕「嗯」了一聲。", "{name}退了半步，嘴角動了一下。"],
			"heavy": ["{name}挑了挑眉：「不錯。」", "{name}被逼退了兩步，眼神亮了起來。"],
			"dying": ["{name}抹了一下額頭的汗。"],
		},
	},
	# 劍庭的委託：牧羊村那個說自己是劍庭出來的人。用的全是野路子，沒有一招是劍庭的
	"impostor": {
		"name": "劍術教師",
		"blurb": "",
		"hp": 170, "str": 13, "agi": 13, "armor": "light", "traits": ["disarmable"], "kinds": ["sword"], "pron": "他",
		"weapon": "長劍", "guard": "盾牌", "moves": ["knee", "dust", "fallstone"],
		"parry": ["你搶上去出手，{name}把盾往上一甩，擋住了。"],
		"fear": ["{name}的眼睛往村口瞄了一下。"],
		"fear_flee": ["{name}丟下盾，翻過籬笆跑了。"],
		"scene": ["村裡的穀倉前，幾個孩子拿著木棍排成一排。"],
		"start": ["{name}看見你的{my}，臉色變了一下，又笑了：「同門？來，讓孩子們看看。」"],
		"actions": {
			"cut": {"type": "sweep", "w": 35, "power": 1.0, "armed": true,
				"tell": ["{name}把劍往旁邊一拉，橫斬過來。"],
				"hit": ["劍刃從你腰側拖過去。", "你被斬中手臂。"]},
			"thrust": {"type": "thrust", "w": 25, "power": 1.0, "armed": true,
				"tell": ["{name}壓低身子，劍尖朝你胸口刺來。"],
				"hit": ["劍尖刺在你的肩窩上。"]},
			"wall": {"type": "guard", "w": 15,
				"tell": ["{name}把盾舉到眼前，學著劍庭的人站樁，腳下卻是虛的。"]},
			"punch": {"type": "thrust", "w": 50, "power": 0.5, "unarmed": true,
				"tell": ["{name}罵了一聲，揮拳朝你臉上打來。"],
				"hit": ["一拳正中你的鼻樑。"]},
			"pickup": {"type": "opening", "w": 50, "unarmed": true, "pickup": true,
				"tell": ["{name}彎腰去撿地上的劍，盾垂了下來。"]},
		},
		"habits": [],
		"pain": {
			"light": ["{name}退了半步。", "圍觀的孩子叫了一聲。"],
			"heavy": ["{name}的盾垂了下來，臉上的笑沒了。"],
			"dying": ["{name}拄著劍喘氣，眼睛一直往村口瞄。"],
		},
		"win_text": "{name}坐倒在地上，把劍推開：「我在劍庭門口掃過三年地，就三年。」孩子們看著他，沒有人說話。",
	},	# 公開比試（升熟手）：大師兄不在的時候，由劍庭的一個熟手下場
	"lionheart_senior": {
		"name": "劍庭的熟手",
		"blurb": "",
		"hp": 190, "str": 16, "agi": 16, "armor": "light", "traits": [], "kinds": ["sword"], "pron": "他", "no_flee": true,
		"moves": ["lh_cross", "lh_pommel", "lh_half"],
		"weapon": "長劍", "guard": "盾牌",
		"parry": ["你搶上去出手，{name}把盾一斜，你的{my}滑了開去。"],
		"scene": ["劍庭的中庭，學徒們圍成一圈。"],
		"start": ["一個熟手提著盾和劍走進場子，向你點了點頭。"],
		"actions": {
			"cut": {"type": "sweep", "w": 35, "power": 1.0,
				"tell": ["{name}從盾後面橫斬過來。"],
				"hit": ["劍刃從你腰側拖過去。", "你被斬中手臂，劍差點脫手。"]},
			"thrust": {"type": "thrust", "w": 30, "power": 1.0,
				"tell": ["{name}壓低身子，劍尖從盾邊刺出來。"],
				"hit": ["劍尖刺在你的肩窩上。"]},
			"bash": {"type": "smash", "w": 20, "power": 0.8, "on_hit": "off_balance",
				"tell": ["{name}舉盾往前一撞。"],
				"hit": ["盾撞在你胸口，你往後踉蹌了兩步。"]},
			"wall": {"type": "guard", "w": 15,
				"tell": ["{name}縮到盾後面，只露出劍尖。"]},
		},
		"habits": [],
		"pain": {
			"light": ["{name}退了半步。"],
			"heavy": ["{name}的盾垂了下來。", "圍觀的學徒叫了一聲。"],
			"dying": ["{name}拄著劍喘氣。"],
		},
		"win_text": "{name}單膝跪下，把劍橫放在地上，認輸了。",
	},
	# 公開比試（升大師）：庭主認真下場
	"lionheart_head": {
		"name": "庭主",
		"blurb": "",
		"hp": 320, "str": 21, "agi": 21, "armor": "light", "traits": [], "kinds": ["sword"], "pron": "他", "no_flee": true,
		"moves": ["lh_cross", "lh_pommel", "lh_half", "lh_advance", "lh_bind"],
		"weapon": "長劍", "guard": "架勢",
		"parry": ["你搶上去出手，{name}的劍輕輕一搭，就把你的{my}帶偏了。", "你砍過去，{name}側身讓開半步，劍刃擦著他的衣服過去。"],
		"scene": ["劍庭的中庭。人站滿了，連街上的人都擠在門口看。"],
		"start": ["{name}換下木劍，拿起一把真的長劍：「這次，我不讓你。」"],
		"actions": {
			"cut": {"type": "sweep", "w": 30, "power": 1.1,
				"tell": ["{name}腳下一錯，長劍從身側橫掃過來。"],
				"hit": ["劍刃在你的肋下拉開一道口子。", "你被掃中手臂，整條手臂都麻了。"]},
			"thrust": {"type": "thrust", "w": 30, "power": 1.1,
				"tell": ["{name}往前踏了半步，劍尖直刺你的胸口。"],
				"hit": ["劍尖刺進你的肩窩。"]},
			"cleave": {"type": "smash", "w": 20, "power": 1.5, "windup": true,
				"tell": ["{name}雙手握劍，慢慢舉過頭頂，重心沉了下去。"],
				"strike_tell": ["長劍劈下來了！"],
				"hit": ["這一劍劈在你肩頭，你膝蓋一軟，跪了一下才站起來。"]},
			"guard": {"type": "guard", "w": 20,
				"tell": ["{name}退了半步，長劍豎在身前，等你先動。"]},
		},
		"habits": [
			{"player": ["dodge"], "then": "cleave", "tell": "你腳步還沒站穩，{name}的劍已經舉過頭頂：「躲完了呢？」"},
		],
		"pain": {
			"light": ["{name}輕輕「嗯」了一聲。"],
			"heavy": ["{name}挑了挑眉：「不錯。」", "{name}被逼退了兩步，眼神亮了起來。"],
			"dying": ["{name}抹了一下額頭的汗，笑了。"],
		},
		"win_text": "{name}收起長劍，向你點了點頭。中庭裡安靜了一下，接著有人開始拍手。",
	},

}


## 對手這招靠哪一項數值
static func action_stat(action: Dictionary, type: String) -> String:
	return action.get("stat", TYPE_STAT.get(type, "str"))


## 危險度：跟境界對齊。{"realm", "text", "color"}。用比較高的那項算
static func danger(id: String) -> Dictionary:
	var d: Dictionary = ENEMIES[id]
	var value: int = maxi(d["str"], d["agi"])
	var realm: int = d.get("realm", GrowthData.realm_of_value(value))
	return {"realm": realm, "color": GrowthData.REALM_COLORS[realm],
		"stars": "★".repeat(realm + 1), "stage": GrowthData.STAGES[GrowthData.stage(realm, value)],
		"text": GrowthData.realm_text(realm, value)}
