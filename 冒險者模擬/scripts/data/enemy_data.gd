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
## realm：只有人有境界（師傅）。怪物用危險度，從數值算（danger()）。
## signature：招牌招，被打中幾次就偷學得會。action 對手的招、learn 你學到的招、seen 被打中時的提示。
## win_text / lose_text / flee_text / survive_text：戰鬥結束的句子（不寫就用預設的）。
## hide_hp：戰鬥畫面不顯示血量（師傅）。
## loot：打贏就拿到的武器（WeaponData）。稀有的劍拿在手上時，他打你也會發動那把劍的特效。
## books：身上帶的秘笈（BookData），打贏就在戰利品裡。
## parry：露出破綻時還拿兵器擋你的寫法（先吃虧，見 Battle.can_parry）。沒寫的不會擋。no_parry：這個破綻擋不了（兵器卡住）。
## title：名號（有名的強者）。no_flee：再怎麼打不過也不會逃。fear / fear_flee：怕你時的句子。

const FORCED_OPENING := {
	"trip": ["{name}摔在地上，一手撐地正要爬起來。", "{name}倒在地上，一時起不了身。"],
	"break": ["{name}的{guard}被砸開，歪到一邊，胸口整個空了出來。"],
	"interrupt": ["{name}的動作被打斷，重心還沒找回來。"],
	"stagger": ["{name}收不住勢，往前踉蹌了好幾步，背後全空了。"],
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
	"{name}整個人被打得離了地，摔在幾步外。",
	"{name}被打得往後滑出好幾步，第一次露出慌張的樣子。",
	"{name}兩腿一軟，差點跪下去。",
]
const UNFAZED := [
	"你的劍砍在{name}身上，{pron}晃都沒晃。",
	"{name}低頭看了一眼傷口，沒當一回事。",
	"你這一下砍得結結實實，{name}卻像沒感覺。",
]
## 對手比你弱太多：開打就怕，挨痛了會逃（算你贏）。no_flee 的不會逃
const FEAR := ["{name}看了你一眼，往後退了半步。", "{name}的氣勢一下子矮了一截。"]
const FEAR_FLEE := ["{name}轉身就逃，頭也不回。", "{name}突然掉頭跑了。"]
## 被嚇跑時結束的句子
const FLED_END := "對手跑了。"

## 委託板上的一般敵人（照危險度排）
const ORDER := ["wolf", "bandit_leader", "deserter", "bear", "ogre"]
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
		"weapon": "大刀", "guard": "架勢", "loot": "bandit_blade",
		"parry": ["{name}身子還歪著，大刀卻慌忙橫了過來。你的劍砍在刀背上，震得手腕發麻。", "你搶上去出劍，{name}把大刀往身前一擋，噹的一聲架住了。"],
		"fear": ["{name}的笑容僵在臉上，握刀的手緊了又鬆：「……喂，有話好說。」"],
		"fear_flee": ["{name}把大刀一扔，連滾帶爬地逃上了山。"],
		"scene": ["荒涼的山道，兩邊都是岩壁。", "官道旁的破廟前，地上還散著被搶過的行李。"],
		"start": ["{name}扛著大刀擋在路中間：「把錢留下，人可以走。」", "{name}從岩石後面跳出來，大刀在手裡轉了一圈：「錢袋扔過來。」"],
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
		"signature": {"action": "sand_kick", "learn": "sand",
			"seen": ["你一邊揉眼睛，一邊記住了他腳尖一勾的動作。", "眼睛痛得要命，那一腳是怎麼踢的，你看清楚了。"]},
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
		"weapon": "長劍", "guard": "盾牌", "loot": "knight_sword",
		"parry": ["你搶上去出劍，{name}把盾牌往上一甩，你的劍砍在盾邊上滑開了。", "你的劍砍過去，{name}的長劍橫過來一格，兩把劍撞在一起。"],
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
			{"last": "shield_wall", "player": ["attack", "vital", "combo", "sweep_kick"], "then": "thrust", "tell": "你的劍還卡在盾牌上，{name}已經從盾後壓低身子，劍尖對準你的胸口。"},
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
				"hit": ["兩隻熊掌砸在你肩上，你跪了下去，膝蓋陷進泥裡。", "熊掌把你壓倒在地，胸口的骨頭快要斷了。"]},
			"hug": {"type": "grab", "w": 20, "power": 0.6, "on_hit": "held",
				"tell": ["熊張開兩隻前臂撲過來，要把你抱住。"],
				"hit": ["熊一把將你抱住，你的雙腳離了地。", "熊的前臂把你箍住，你掙不開。"],
				"hold": {"power": 0.8,
					"tell": ["熊死死抱住你，越勒越緊。", "你的臉被壓在熊的毛皮上，快喘不過氣。"],
					"hit": ["你聽見自己的骨頭在響。", "你被勒得眼前發黑，肺裡的空氣一點一點被擠出去。"]}},
			"roar": {"type": "roar", "w": 15, "power": 0.0, "on_hit": "shaken",
				"tell": ["熊張開大嘴，胸口一鼓，朝你吼了出來。"],
				"hit": ["咆哮聲直衝你的臉，你腿一軟，腦中一片空白。", "吼聲震得你耳朵嗡嗡響，劍差點握不住。"]},
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
		"signature": {"action": "roar", "learn": "shout",
			"seen": ["你的腿還在發軟，可是那一吼是怎麼從胸口逼出來的，你好像摸到了一點門道。", "吼聲還在耳朵裡響。你想：如果是你對著野獸這樣吼呢？"]},
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
		"parry": ["食人魔胡亂把木棍往身前一擋，你的劍砍進木頭裡，拔了一下才拔出來。", "你搶上去出劍，砍在橫過來的木棍上，木屑亂飛。"],
		"scene": ["倒塌的城牆下，到處都是被砸爛的木箱和碎石。", "下著大雨的沼澤邊，泥水沒過了你的腳踝。"],
		"start": ["地面一陣震動。食人魔拖著一根大木棍走過來，咧開滿是爛牙的嘴。"],
		"actions": {
			"club_sweep": {"type": "sweep", "w": 35, "power": 1.0,
				"tell": ["食人魔單手拖著木棍往旁邊一拉，整個上身扭過去，橫掃過來。"],
				"hit": ["木棍從側面把你掃了出去，你在地上滾了好幾圈，嘴裡全是泥。", "木棍掃在你的腰上，你身體裡悶悶地響了一聲。"]},
			"club_smash": {"type": "smash", "w": 30, "power": 1.5, "windup": true,
				"tell": ["食人魔雙手把木棍舉過頭頂。", "食人魔雙手舉起木棍，嘴裡發出低沉的吼聲。"],
				"strike_tell": ["木棍朝你頭頂砸下來了！"],
				"hit": ["木棍從頭頂砸中了你，你眼前一白，整個人被砸進泥裡。", "木棍砸在你身上，你聽見自己的骨頭在響。"]},
			"grab_throw": {"type": "grab", "w": 20, "power": 1.2, "on_hit": "off_balance",
				"tell": ["食人魔張開一隻大手抓過來。"],
				"hit": ["食人魔一把抓起你，往地上狠狠一摔。", "你被那隻大手抓住，雙腳離地，接著整個人被砸進泥地裡。"]},
			"stomp": {"type": "smash", "w": 15, "power": 0.9,
				"tell": ["食人魔抬起一隻大腳往你身上踩。"],
				"hit": ["大腳把你踩進泥裡，肋骨快被踩斷了。"]},
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
		"win_text": "食人魔往後倒了下去，地面跟著一跳。你拄著劍站了好一會兒。",
	},

	# ---------- 有名字的強者（懸賞） ----------
	"merc_captain": {
		"name": "羅德里克", "title": "傭兵隊長",
		"blurb": "傭兵團「紅鬃」的隊長。獨眼。",
		"hp": 260, "str": 18, "agi": 18, "armor": "light", "traits": [], "kinds": ["sword"], "pron": "他",
		"weapon": "鋸齒劍", "guard": "架勢", "loot": "red_fang", "books": ["sunder_book"], "no_flee": true,
		"parry": ["{name}腳下還沒站穩，劍卻已經橫在身前。你砍上去，{pron}的劍卡住了你的劍刃。", "你搶上一步出劍，{name}的劍往上一挑，把你的劍架開了。"],
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
		"parry": ["你的劍砍在{name}豎起來的大劍上，嗡的一聲，虎口都麻了。", "{name}還沒站穩，大劍卻已經擋在身前。你的劍砍在寬寬的劍身上，滑了開去。"],
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
			{"last": "wall", "player": ["attack", "vital", "combo", "sweep_kick"], "then": "pierce", "tell": "{name}把擋住你的劍身一翻，劍尖對準了你的胸口。"},
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
		"parry": ["{name}還沒站穩，就把斧柄往身前一橫。你的劍砍在斧柄的鐵箍上，彈了回來。", "你搶上去出劍，{name}用斧柄硬擋，木屑飛了起來。"],
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
			"heavy": ["{name}往後退了一步，紅鬍子上沾了血。", "{name}罵了一句你聽不懂的話。"],
			"dying": ["{name}喘著粗氣，斧頭越掄越慢。"],
		},
		"win_text": "{name}仰面倒在地上，手還握著斧柄。過了一會兒，手鬆開了。",
	},
	"duelist": {
		"name": "伊薇特", "title": "決鬥家",
		"blurb": "南方來的決鬥家，右手細劍，左手短劍。據說沒輸過。",
		"hp": 240, "str": 15, "agi": 21, "armor": "none", "traits": ["disarmable"], "kinds": ["rapier"], "pron": "她",
		"weapon": "細劍", "guard": "短劍", "books": ["falcon_book"], "no_flee": true,
		"parry": ["{name}還沒站穩，左手的短劍已經架了過來，把你的劍撥開。", "你搶上去出劍，{name}用短劍一擋，細劍跟著點向你的手腕，你只好收劍。"],
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
			{"player": ["heavy", "combo"], "chance": 0.5, "then": "lunge", "tell": "你這一下用老了，{name}腳下一錯，劍尖跟著遞了過來。"},
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
		"weapon": "長劍", "guard": "護手", "loot": "nightwatch", "no_flee": true,
		"parry": ["{name}腳下一錯，長劍已經回到身前。你的劍砍在{pron}的護手上，滑了開去。", "你搶上去出劍，{name}不慌不忙地一擋，像是早就知道你會砍哪裡。"],
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
			# 你砍在他的劍上，他順著你的劍刃刺回來
			{"last": "guard", "player": ["attack", "heavy", "combo", "vital"], "then": "thrust", "tell": "{name}架開你的劍，順著你的劍刃滑進來，劍尖對準你的胸口。"},
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
		"weapon": "戰錘", "guard": "塔盾", "books": ["bastion_book"], "no_flee": true,
		"parry": ["{name}還沒站穩，塔盾已經擋在身前。你的劍砍在盾面上，震得手腕發麻。", "你搶上去出劍，{name}把盾一推，連你帶劍一起推開。"],
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
			{"last": "wall", "player": ["attack", "heavy", "combo", "vital"], "then": "bash", "tell": "你的劍還卡在盾面上，{name}已經舉著盾撞了過來。"},
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

	# 北境劍術的師傅：第 2 階的考驗「接住我三招」用。不在委託板上
	# 數值剛好是第二境入門：閃避、防禦都要比數值，差太多就撐不過
	"master": {
		"name": "師傅",
		"blurb": "",
		"hp": 999, "str": 15, "agi": 15, "armor": "light", "traits": [], "kinds": ["sword"], "pron": "他", "hide_hp": true, "realm": 1, "no_flee": true,
		"weapon": "木劍", "guard": "架勢",
		"parry": ["你搶上去出劍，師傅的木劍輕輕一搭，就把你的劍帶偏了。"],
		"scene": ["道場的木地板擦得發亮，牆上掛著一排木劍。窗外下著雪。"],
		"start": ["師傅丟給你一把木劍，自己也拿起一把，隨手挽了個劍花：「三招。接住了，進階招就教你。」"],
		"actions": {
			"cut": {"type": "sweep", "w": 35, "power": 1.0,
				"tell": ["師傅腳下一錯，木劍從身側橫掃過來。"],
				"hit": ["木劍抽在你的肋下，你彎下了腰。", "啪的一聲，木劍掃在你的手臂上，整條手臂都麻了。"]},
			"thrust": {"type": "thrust", "w": 30, "power": 1.0,
				"tell": ["師傅往前踏了半步，劍尖直刺你的胸口。"],
				"hit": ["劍尖戳在你的胸口，你一口氣差點喘不上來。", "劍尖點在你的肩窩，整條手臂一軟。"]},
			"cleave": {"type": "smash", "w": 35, "power": 1.1,
				"tell": ["師傅雙手把木劍舉過頭頂，重心沉了下去，一劍劈下。"],
				"hit": ["木劍劈在你的肩膀上，你膝蓋一軟，差點跪下去。", "木劍敲在你的額頭上，咚的一聲。"]},
		},
		"habits": [
			# 你閃避完腳步還沒站穩，他就劈下來
			{"player": ["dodge"], "then": "cleave", "tell": "你腳步還沒站穩，師傅的木劍已經舉過頭頂：「躲完了呢？」"},
		],
		"pain": {
			"light": ["師傅輕輕「嗯」了一聲。", "師傅退了半步，嘴角動了一下。"],
			"heavy": ["師傅挑了挑眉：「不錯。」", "師傅被逼退了兩步，眼神亮了起來。"],
			"dying": ["師傅抹了一下額頭的汗。"],
		},
		"lose_text": "你單膝跪地，喘得說不出話。師傅的木劍停在你的頸邊：「還不行。回去再練。」",
		"survive_text": "三招過去，你還站著。師傅收起木劍，點了點頭：「接得住。進階招，我教你。」",
		"flee_text": "你舉手認輸。師傅收起木劍：「想清楚了再來。」",
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
