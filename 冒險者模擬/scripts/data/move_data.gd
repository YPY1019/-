class_name MoveData
extends RefCounted

## 招式資料。只有資料，沒有規則。
##
## 對手這回合的招有一個「類型」：
##   攻擊：sweep 橫掃、thrust 直刺/撲、smash 重砸、grab 擒抱、trick 詭招（踢沙等）、roar 威嚇、hold 被抱住時的勒緊
##   不是攻擊：guard 防守、opening 破綻、windup 蓄勢（下回合才打下來）
##
## vs[類型] 是你這招碰上這種類型的結果（沒寫的用 default）：
##   deal  你打出去的倍率（乘你的攻擊力）
##   take  你挨打的倍率（乘對手這招的傷害）。take > 0 代表對手的招有打中你，它的附加效果（眼睛進沙、被抱住…）也會生效
##   hit   true = 再接對手自己「打中你」的描述
##   effect 對對手的效果：trip 掃倒、break 破防、interrupt 打斷蓄勢、stagger 踉蹌、disarm 繳械、blind 撒沙、scare 嚇退、escape 掙脫
##   requires 對手要有這個特性才成立（beast 野獸、disarmable 繳得掉），不成立時改用 else
##   good  true = 這招剋這種類型。比較容易出現在選項裡（高手見招拆招）
## vs_big：對體型大的對手用的版本。
## self：用完之後自己的狀態（off_balance：下回合不能閃避、選項少一個）。
## no_repeat：用完下回合不能再用。
## stat：這招靠哪個基礎數值（str 力量、agi 敏捷）。跟對手的同一項比，決定成不成功、打多痛；用了也會練到這個數值。
## fail：失敗時的結果。成功的機率看雙方數值的差距（GrowthData.success_chance）。招有效果（掃倒、破防、掙脫…）或能少挨打時才會失敗。
## odds：這招本身比較難（負）或比較容易（正）成功。
##   沒寫 take 的話，對手出手就照樣挨打。
## text 每次隨機挑一句。{name} 對手、{pron} 他／牠、{weapon} 對手的武器、{guard} 對手的防具。

## 人人都會的一般招。跟學來的招放在同一個池子裡，不是永遠都在
const BASIC := ["attack", "defend", "dodge"]
## 每回合的選項至少有一個攻擊類、一個防守類（擲沙、怒喝不算這兩類）
const OFFENSE := ["attack", "heavy", "vital", "combo", "sunder", "falcon"]
const DEFENSE := ["defend", "dodge", "sweep_kick", "parry", "redirect", "disarm", "break_free", "bastion"]
## 撤退不是招式，永遠可以選（被抱住時不行）
const FLEE := "flee"
## 被抱住時能用的招（沒學的不會出現）
const HELD := ["struggle", "attack", "break_free", "vital"]
const LEARNABLE := ["sweep_kick", "parry", "redirect", "heavy", "vital", "disarm", "break_free", "sand", "shout", "combo", "sunder", "falcon", "bastion"]

## 你受傷後的反應（依傷勢挑一句）
## shrug：你那一項比對手高很多，打中了也不痛（取代對手「打中你」的描述）
## crushed：對手那一項比你高很多，挨一下就知道差多少
## 文字風格見 GAME_DESIGN.md「戰報的文字風格」：寫物理（重心、步法、兵器輕重）、打真實的弱點、比喻少用。
const HURT := {
	"light": ["你咬著牙沒退。", "你悶哼一聲，重新握緊了劍。", "傷口一陣抽痛，你沒去管它。"],
	"heavy": ["你眼前黑了一下，腳下一軟，又站住了。", "你退了一步，拿劍撐了一下才站穩。", "你嘴裡全是血的味道。"],
	"critical": ["你的手開始發抖，劍越來越重。", "血順著手臂流到劍柄上，握起來有點滑。", "你每吸一口氣，肋下就痛一下。"],
	"shrug": [
		"{name}打中了你。你晃了一下，站穩了。",
		"{weapon}打在你身上，你腳下沒挪半步。",
		"你硬吃了這一下，不怎麼痛。",
	],
	"crushed": [
		"你連退了好幾步，差點坐倒在地上。",
		"你沒看清這一下是怎麼來的，人已經退出了好幾步。",
		"你整條手臂都麻了，劍差點脫手。",
	],
}

const MOVES := {
	# ---------- 一般招（不用學） ----------
	"attack": {
		"name": "攻擊", "stat": "str", "desc": "普通的一劍，出手快。對方橫掃或直刺時搶先砍到，對方的攻擊會被打歪一點。對方防守時砍不進去。",
		"fail": {"deal": 1.0, "take": 1.0, "hit": true, "text": ["你想搶先出劍，慢了半拍，{pron}的攻擊先到了。"]},
		"default": {"deal": 1.0, "take": 1.0, "hit": true, "text": [
			"你不退，迎上去一劍砍向{name}。",
			"你踏前一步，劍劈向{name}的肩膀，自己的胸口也跟著露了出來。",
			"你橫劍一掃，劍鋒從{name}身側劃過。",
		]},
		"vs": {
			# 出手快：對方出快攻時搶先砍到，對方的攻擊被打歪一點
			"sweep": {"deal": 1.0, "take": 0.7, "hit": true, "text": [
				"{name}的{weapon}才拉開，你已經一劍砍了進去。{pron}這一掃的力道被打散了一半。",
				"你不等{weapon}掃到，搶先出劍。劍先到，{pron}的手勢跟著歪了。",
			]},
			"thrust": {"deal": 1.0, "take": 0.7, "hit": true, "text": [
				"{name}直衝過來，你的劍尖先碰到{pron}，{pron}的勢子頓了一下。",
				"{name}還沒衝到，你已經一劍砍了過去，{pron}的攻擊偏了幾分。",
			]},
			"guard": {"deal": 0.2, "text": [
				"你一劍砍在{guard}上，鏘的一聲，震得虎口發麻。",
				"你連砍兩劍，都被{guard}擋了下來。",
			]},
			"opening": {"deal": 1.5, "text": [
				"你跨上一步，一劍砍在{name}身上。",
				"{name}還沒站好，你的劍已經砍進了{pron}的肩頭。",
			]},
			"windup": {"deal": 1.2, "text": [
				"{name}還在蓄力，顧不上防守。你搶上前去，一劍砍了進去。",
			]},
			"hold": {"deal": 0.5, "take": 1.0, "hit": true, "text": [
				"你的手臂被箍住，只能用劍柄往{name}身上砸。",
				"你反手握劍，劍尖往{name}身上亂戳。",
			]},
		},
	},
	"defend": {
		"name": "防禦", "stat": "str", "desc": "用劍擋住攻擊，會受一點傷，擋住後能順手回砍。擋不住擒抱、撒沙和吼聲。",
		"fail": {"take": 1.0, "hit": true, "text": ["你舉劍去擋，沒擋正，被打得連人帶劍退了回來。", "你架劍去擋，劍被壓回你自己身上。"]},
		"default": {"text": [
			"你舉劍守在身前，{name}卻沒有出手。",
			"你擺好架勢等著，什麼也沒擋到。",
		]},
		"vs": {
			"sweep": {"deal": 0.4, "take": 0.4, "text": [
				"你豎劍硬擋。{weapon}撞在劍身上，你手臂一麻，腳下滑了半步。趁{pron}的力道剛過，你順手回了一劍。",
				"鏘的一聲，{weapon}被你的劍擋住。你借著反彈的勢子，劍鋒往回一帶，在{name}身上拉了一道。",
			]},
			"thrust": {"deal": 0.4, "take": 0.3, "text": [
				"你用劍身一格，{weapon}偏了開去，只在你身上擦出一道血痕。你趁勢回了一劍。",
				"你把{weapon}撥到一邊，衣服被劃破了。{name}收手之前，你往{pron}身上削了一劍。",
			]},
			"smash": {"take": 0.6, "text": [
				"你舉劍硬接。{weapon}整個壓下來，你膝蓋一彎，差點跪下去。",
				"你架劍去擋，{weapon}的重量一路壓到你手腕上，劍身都彎了。",
			]},
			"grab": {"take": 1.0, "hit": true, "text": ["你舉劍去擋，{name}卻不理你的劍，整個人撲了上來。"]},
			"trick": {"take": 1.0, "hit": true, "text": ["你舉劍護在身前，可是{name}要的根本不是你的劍。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你舉劍護在身前。聲音是擋不住的。"]},
		},
	},
	"dodge": {
		"name": "閃避", "stat": "agi", "desc": "躲開攻擊，不會受傷。但躲完腳步亂了：下回合不能再閃避，選項也少一個。躲不掉吼聲。",
		"fail": {"take": 1.0, "hit": true, "text": ["你想閃開，腳下慢了一步，還是被打中了。", "你才剛要側身，{name}已經到了眼前。"]},
		"self": "off_balance",
		"default": {"take": 0.0, "text": [
			"你往後一跳，躲開了{name}，落地時腳下一滑。",
			"你側身讓開，{name}撲了個空，你自己也差點摔倒。",
		]},
		"vs": {
			"sweep": {"take": 0.0, "text": [
				"你上身往後一仰，{weapon}貼著你胸口掃過去。你退了好幾步才站穩。",
				"你往後跳開，{weapon}掃了個空。你落地時重心還在後腳，一時回不過來。",
			]},
			"smash": {"take": 0.0, "text": [
				"你往旁邊一滾，{weapon}砸在你剛才站的地方，碎石濺了你一身。",
				"你撲到一邊。背後一聲悶響，{weapon}砸進了土裡。",
			]},
			"roar": {"take": 1.0, "hit": true, "text": ["你往後跳開，吼聲還是灌進了耳朵。"]},
			"guard": {"text": ["你往後跳開。{name}沒有出手，只是穩穩地逼近。"]},
			"opening": {"text": ["你往後跳開，白白錯過了機會。"]},
			"windup": {"text": ["你往後拉開距離。{name}還在蓄力，你什麼也沒躲到。"]},
		},
	},
	"flee": {
		"name": "撤退", "desc": "轉身逃走。這回合對方攻擊的話會挨打。",
		"default": {"take": 1.0, "hit": true, "text": ["你轉身就跑。", "你虛晃一劍，轉身就跑。"]},
		"vs": {},
	},
	"struggle": {
		"name": "掙扎", "stat": "str", "desc": "被抱住時拼命掙扎。力氣要比對方大才有把握掙開。",
		"fail": {"take": 1.0, "hit": true, "text": ["你掙了幾下，還是被死死勒住。"]},
		# 硬掙比較難，力氣要比對方大才有把握
		"odds": -0.2,
		"default": {"take": 0.0, "effect": "escape", "text": ["你腰一扭，掙了出來。", "你咬牙一掙，從{name}手裡脫了身。"]},
		"vs": {},
	},

	# ---------- 要學的招 ----------
	"sweep_kick": {
		"name": "低身斬", "stat": "agi", "desc": "對付橫掃：蹲低從底下鑽過，順勢斬對方的腳，把人斬倒。體型大的斬不倒。",
		"fail": {"deal": 0.3, "take": 1.0, "hit": true, "text": ["你壓低身子斬向{name}的腳，{pron}腳一抬就讓開了，你自己反倒吃了一記。"]},
		"default": {"deal": 0.5, "take": 1.0, "hit": true, "text": [
			"你矮身斬向{name}的腳，可是{pron}這一下不是橫著來的，你整個人露在攻擊底下。",
		]},
		"vs": {
			"sweep": {"deal": 0.5, "take": 0.0, "effect": "trip", "good": true, "text": [
				"你沉膝矮身，{weapon}從頭頂掠過，削下幾根頭髮。你借著下蹲的勢子一劍貼地斬出，正中{name}的腳踝。{pron}重心還壓在前腳，整個人往前栽倒。",
				"{weapon}橫掃過來，你蹲得幾乎貼地。{pron}這一掃用盡了力，腳下是空的。你一劍斬在{pron}小腿上，{pron}往前撲倒。",
			]},
			"smash": {"deal": 0.5, "take": 1.2, "text": ["你矮身去斬{name}的腳，正好把頭頂送到落下來的{weapon}底下。"]},
			"guard": {"deal": 0.3, "text": ["你一劍斬向{name}的腳，{pron}把{guard}往下一壓，擋住了。"]},
			"opening": {"deal": 0.8, "text": ["你一劍斬在{name}的腿上。"]},
			"windup": {"deal": 0.5, "text": ["你一劍斬在{name}的腳上，{pron}晃了晃，架勢沒散。"]},
		},
		"vs_big": {
			"sweep": {"deal": 0.3, "take": 0.5, "text": [
				"你蹲低身子，{weapon}還是擦過你的背。你一劍斬在{name}腿上，{pron}太重了，晃都沒晃。",
			]},
		},
	},
	"parry": {
		"name": "迎擊", "stat": "agi", "desc": "對付直刺和撲咬：把攻擊撥開，同時刺回去。還是會被擦到一下。",
		"fail": {"take": 1.0, "hit": true, "text": ["你想撥開{weapon}，慢了一點，劍還沒碰到，攻擊已經到了。"]},
		"default": {"text": ["你擺好撥擋的架勢，{name}卻沒有衝過來。"]},
		"vs": {
			"thrust": {"deal": 1.2, "take": 0.3, "good": true, "text": [
				"{name}直衝過來。你的劍貼上{weapon}，往外一撥，{pron}的力道落了空。你手腕一翻，劍尖順著{pron}衝過來的勢子刺了進去。",
				"{weapon}到了眼前，你側身讓過一半，劍身一帶把它引偏，劍尖直接刺回去。你的手臂被擦破了，{name}傷得更重。",
			]},
			"sweep": {"take": 0.8, "text": ["你想撥開{weapon}，可是橫掃的力道太大，你的劍被盪開，攻擊還是落在你身上。"]},
			"smash": {"take": 1.0, "text": ["你想撥開從頭頂落下的{weapon}，劍一碰上就被壓了下來。"]},
			"grab": {"take": 1.0, "hit": true, "text": ["你想撥開{name}，可是{pron}是整個身體撲上來的，撥不動。"]},
			"trick": {"take": 1.0, "hit": true, "text": ["你出劍去撥，可是來的不是兵器。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你架好劍準備撥擋。聲音撥不開。"]},
		},
	},
	"redirect": {
		"name": "逆流斬", "stat": "str", "desc": "對付重砸和橫掃：順著力道把攻擊引開，再借力斬回去（比防禦強）。對重砸最有效，能讓對方收勢不住、往前踉蹌。",
		"fail": {"take": 1.0, "hit": true, "text": ["你想順勢把{weapon}引開，沒抓準，那股力道還是壓了下來。"]},
		"default": {"text": ["你雙手虛握著劍等著，{name}卻沒有砸下來。"]},
		"vs": {
			"smash": {"deal": 0.8, "take": 0.2, "effect": "stagger", "good": true, "text": [
				"你不硬接，劍身斜斜迎上去。{weapon}順著你的劍滑開，砸進土裡。{name}整個人的重量都在這一下，收不住，往前衝過你身邊，背後全空了。你回手一劍斬在{pron}身上。",
				"{weapon}壓下來的時候，你的劍只輕輕一帶，就把它引到一旁。{name}用力過猛，往前踉蹌了兩步。你的劍已經跟著劃過了{pron}的身體。",
			]},
			"sweep": {"deal": 0.8, "take": 0.3, "good": true, "text": [
				"你的劍貼上{weapon}，順著它的方向一帶，卸掉了大半力道，再借那股勁斬了回去。",
				"{weapon}掃到你身前，你的劍一轉，把力道引向一旁，劍鋒反過來削在{name}身上。",
			]},
			"thrust": {"deal": 0.4, "take": 0.6, "text": ["你想卸開{weapon}，可是它又快又直，只卸掉一點，回手一劍也砍得很淺。"]},
			"grab": {"take": 1.0, "hit": true, "text": ["你想卸開{name}的力道，可是{pron}是整個人撲上來的。"]},
			"trick": {"take": 1.0, "hit": true, "text": ["你等著卸力，{name}卻根本沒出力。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你等著卸力。吼聲卸不掉。"]},
		},
	},
	"heavy": {
		"name": "裂盾斬", "stat": "str", "desc": "雙手全力一擊，穿透盔甲盾牌。對方防守、蓄勢、露出破綻時才是大招（能破防、打斷蓄勢）；對方正在出手時只跟攻擊差不多，還挨得更痛。收招慢：下回合不能閃避，也不能再用裂盾斬。",
		"no_repeat": true,
		"fail": {"deal": 1.0, "text": ["你全力一劍劈下，{name}硬是扛住了。", "你雙手一劍劈下去，{name}晃都沒晃。"]},
		"self": "off_balance",
		"pierce": true,
		"default": {"deal": 1.0, "take": 1.5, "hit": true, "text": [
			"你雙手舉劍，全身的重量壓上去，一劍劈向{name}。這一劍收不回來，你的胸口整個敞著。",
			"你一劍劈下，深深砍進{name}身上，{pron}的攻擊也同時落在你身上。",
		]},
		"vs": {
			"guard": {"deal": 1.5, "effect": "break", "good": true, "text": [
				"你雙手握劍，從上往下劈在{guard}上。{name}被砸得往後退了好幾步，{guard}歪到一邊。",
			]},
			"windup": {"deal": 2.0, "effect": "interrupt", "good": true, "text": [
				"{name}還在蓄力，你搶先一劍劈下去，{pron}的動作硬生生斷了。",
			]},
			"opening": {"deal": 2.5, "good": true, "text": [
				"你雙手握劍，把全身的重量壓在這一劍上，劈在{name}身上。",
				"你高高舉劍，一劍劈下。{name}來不及擋。",
			]},
		},
		"vs_big": {
			"windup": {"deal": 2.0, "text": ["你一劍劈在{name}身上，砍出一道深口子。{pron}太重了，動作沒停。"]},
		},
	},
	"vital": {
		"name": "穿隙刺", "stat": "agi", "desc": "刺向要害或盔甲縫隙，盔甲擋不住。平常也跟攻擊一樣痛；對方露出破綻、蓄勢、或抱住你時，比裂盾斬還痛。",
		"fail": {"deal": 0.5, "take": 1.0, "hit": true, "text": ["你刺向{name}的要害，{pron}一扭身讓開了，劍尖只劃破了點皮。"]},
		"pierce": true,
		"default": {"deal": 1.0, "take": 1.0, "hit": true, "text": [
			"你刺向{name}的腋下，{pron}一扭身，劍尖還是刺進了肉裡。你自己也吃了一記。",
		]},
		"vs": {
			"opening": {"deal": 2.8, "good": true, "text": [
				"{name}的脖子和領口之間露出一道縫。你跨上一步，劍尖對準那道縫刺了進去。",
				"你貼上去，劍尖從{name}腋下鑽進去，刺得很深。",
			]},
			"windup": {"deal": 2.5, "good": true, "text": [
				"{name}還在蓄力，身子繃得死緊。你一步搶進去，劍尖刺了進去。",
			]},
			"smash": {"deal": 1.5, "take": 1.0, "hit": true, "text": [
				"{name}砸下來的時候，你不退反進，迎著{pron}刺出一劍。你們同時擊中了對方。",
			]},
			"guard": {"deal": 0.0, "text": ["你刺向{name}的要害，劍尖叮的一聲撞在{guard}上，滑開了。"]},
			"hold": {"deal": 2.0, "take": 0.5, "effect": "escape", "good": true, "text": [
				"被抱住的時候你們貼得最近。你反手握劍，劍尖從{name}肋下刺進去。{pron}痛得一鬆，你掙了出來。",
			]},
		},
	},
	"disarm": {
		"name": "奪刃", "stat": "agi", "desc": "對付拿武器的對手：在對方揮過來的瞬間把武器打飛。對野獸沒用，太重的武器也絞不動。",
		"fail": {"take": 1.0, "hit": true, "text": ["你想絞掉{name}的{weapon}，{pron}手一縮，你的劍撲了個空。"]},
		"default": {"text": ["你盯著{weapon}等著，{name}沒有揮過來。"]},
		"vs": {
			"sweep": {"take": 0.5, "effect": "disarm", "good": true, "requires": "disarmable", "text": [
				"{weapon}揮過來的時候，你的劍貼上去一絞，正好扭在{name}手腕最使不上力的角度。{weapon}脫手飛出去，噹啷一聲落在遠處。",
			], "else": {"take": 1.0, "hit": true, "text": ["你想打掉{name}的武器，絞不動。"]}},
			"thrust": {"take": 0.5, "effect": "disarm", "good": true, "requires": "disarmable", "text": [
				"你一劍壓住刺過來的{weapon}，順勢往上一挑，{weapon}從{name}手裡飛了出去。",
			], "else": {"take": 1.0, "hit": true, "text": ["你想打掉{name}的武器，絞不動。"]}},
			"smash": {"take": 1.0, "hit": true, "text": ["從頭頂砸下來的力道太大，你的劍一碰上就被壓了下去，絞不動。"]},
			"grab": {"take": 1.0, "hit": true, "text": ["你盯著{name}的武器，{pron}卻直接撲上來抓你。"]},
			"trick": {"take": 1.0, "hit": true, "text": ["你盯著{name}的武器，沒注意{pron}的腳。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你盯著{name}，吼聲震得你耳朵發疼。"]},
		},
	},
	"break_free": {
		"name": "脫鎖", "stat": "str", "desc": "對付擒抱：在被抱住前鑽出去，或被抱住時掙開，順手回一劍。",
		"fail": {"take": 1.0, "hit": true, "text": ["你想掙脫，沒掙開。"]},
		"default": {"take": 1.0, "hit": true, "text": ["你壓低重心準備掙脫，可是{name}根本沒有要抓你。"]},
		"vs": {
			"grab": {"deal": 0.5, "take": 0.0, "good": true, "text": [
				"{name}撲上來的時候，你矮身從{pron}手臂底下鑽了出去，轉身一劍砍在{pron}背上。",
			]},
			"hold": {"deal": 0.5, "take": 0.3, "effect": "escape", "good": true, "text": [
				"你手肘往後一撞，{name}吃痛，手鬆了一下。你扭身掙開，順手一劍。",
				"你用頭往後一頂，撞在{name}臉上。{pron}手一鬆，你滾了出來，劍順勢劃過{pron}身上。",
			]},
			"guard": {"text": ["你壓低重心等著，{name}只是步步逼近。"]},
			"opening": {"text": ["你壓低重心等著，白白錯過了機會。"]},
			"windup": {"text": ["你壓低重心等著，{name}還在蓄力。"]},
		},
	},
	"sand": {
		"name": "擲沙", "stat": "agi", "desc": "抓一把沙撒向對方的眼睛。對方下一次攻擊很可能打偏。這回合自己不會躲。",
		"fail": {"text": ["你抓起一把沙撒過去，{name}一偏頭就躲開了。"]},
		"default": {"effect": "blind", "take": 1.0, "hit": true, "text": [
			"你彎腰抓起一把沙土往{name}臉上撒，自己也沒空躲。",
		]},
		"vs": {
			"guard": {"effect": "blind", "text": ["你抓起一把沙，從{guard}旁邊撒進{name}的眼睛。{pron}罵了一聲，拼命眨眼。"]},
			"opening": {"effect": "blind", "text": ["你趁機抓起一把沙，撒進{name}的眼睛。"]},
			"windup": {"effect": "blind", "good": true, "text": ["{name}還在蓄力，你抓起一把沙撒進{pron}的眼睛。"]},
		},
	},
	"shout": {
		"name": "怒喝", "stat": "str", "desc": "對野獸大喝一聲，把牠嚇得退縮。也能壓過對方的吼聲。對人沒什麼用。",
		"fail": {"text": ["你大喝一聲，{name}沒被嚇到。"]},
		"default": {"take": 1.0, "hit": true, "effect": "scare", "requires": "beast", "text": [
			"你張開雙臂大喝一聲，{name}往後一縮。",
		], "else": {"take": 1.0, "hit": true, "text": ["你大喝一聲，{name}冷笑了一下。"]}},
		"vs": {
			"roar": {"take": 0.0, "effect": "scare", "good": true, "requires": "beast", "text": [
				"你迎著吼聲大喝一聲，硬是蓋了過去。{name}愣住了，耳朵往後一貼。",
			], "else": {"take": 0.0, "text": ["你一聲大喝，蓋過了{name}的吼聲。"]}},
			"sweep": {"take": 0.6, "effect": "scare", "good": true, "requires": "beast", "text": [
				"你迎著{name}大喝一聲，{pron}一縮，攻擊只用了一半的力。",
			], "else": {"take": 1.0, "hit": true, "text": ["你大喝一聲，{name}不理你。"]}},
			"thrust": {"take": 0.6, "effect": "scare", "good": true, "requires": "beast", "text": [
				"你迎著{name}大喝一聲，{pron}撲到一半縮了回去，只碰到你一下。",
			], "else": {"take": 1.0, "hit": true, "text": ["你大喝一聲，{name}不理你。"]}},
			"guard": {"text": ["你大喝一聲，{name}躲在{guard}後面不為所動。"]},
			# 只有對方出手時嚇得到，不能一直喝住{pron}
			"opening": {"text": ["你大喝一聲，{name}瞪著你，沒有退。"]},
			"windup": {"text": ["你大喝一聲，{name}正專心蓄力，沒理你。"]},
		},
	},
	"combo": {
		"name": "三連斬", "stat": "str", "desc": "一口氣連砍三劍，比普通攻擊痛。但三劍砍完收不回來，擋不開對方的攻擊。砍不穿厚甲和盾。",
		"default": {"deal": 1.3, "take": 1.0, "hit": true, "text": [
			"你一劍接一劍連砍三下，{name}也同時出手了。",
			"你搶上去連砍三劍，自己的身子也全敞開了。",
		]},
		"vs": {
			# 砍得多，但三劍砍完收不回來，擋不開對方的攻擊（攻擊出手快，會把對方打歪）
			"sweep": {"deal": 1.3, "take": 1.0, "hit": true, "text": [
				"你迎著{weapon}連砍三劍，劍劍見血，{weapon}也結結實實掃了過來。",
				"你不管掃過來的{weapon}，三劍連著砍出去。兩個人同時見了血。",
			]},
			"thrust": {"deal": 1.3, "take": 1.0, "hit": true, "text": [
				"你連砍三劍，{name}不躲不閃，硬是頂著劍衝了進來。",
				"你三劍連著砍出去，{name}的{weapon}也同時到了。",
			]},
			"opening": {"deal": 2.2, "good": true, "text": [
				"你不收劍，第一劍砍下去，手腕一轉接第二劍、第三劍。{name}身上多了三道口子。",
				"你連砍三劍，劍劍都落在{name}來不及護住的地方。",
			]},
			"windup": {"deal": 1.8, "text": ["{name}還在蓄力，你一口氣砍了三劍。"]},
			"guard": {"deal": 0.4, "text": ["你連砍三劍，全砍在{guard}上，一劍也沒進去。"]},
		},
	},

	# ---------- 絕學 ----------
	# ult：喊出招名，有專屬的寫法。對手拿兵器擋也擋不到（見 Battle「先吃虧」），守夜人也架不開
	# when：什麼時候才出得來（不做次數限制，見 Battle.ult_ready）
	#   opening 對手露出大破綻；closed 對手縮在防守後面或正在蓄力；heavy 對手蓄好的重招正砸下來
	# pre：起手（之後喊出招名，再寫結果）
	# no_weak：數值輸對手也不會變弱（破綻就是破綻）
	# 從秘笈學（BookData），不在道場學
	"sunder": {
		"name": "北境裁決", "stat": "str", "desc": "北境劍術的絕學。對手露出大破綻時才用得出來（被掃倒、破防、收勢不住、喘氣、卡住）。",
		"ult": true, "when": "opening", "pierce": true, "no_weak": true,
		"pre": [
			"你等的就是這一下。",
			"{name}的空門就在眼前，你雙手握劍，往前踏了一大步。",
			"你沒有猶豫，舉劍就劈。",
		],
		"default": {"deal": 4.0, "text": [
			"這一劍從{name}的肩膀一路劈到腰，{pron}往後退了好幾步才站住。",
			"劍重重劈在{name}身上，連你自己的手都被震麻了。",
			"{name}想躲已經來不及，被劈個正著。",
		]},
		"vs": {},
	},
	"falcon": {
		"name": "隼之一刺", "stat": "agi", "desc": "南方決鬥家的絕學。對手縮在防守後面、或正在蓄力時才用得出來：從縫裡一劍刺進去，盾和兵器都擋不住（盔甲還是擋得住一些）。刺中蓄力的人，那一下就使不出來了。",
		"ult": true, "when": "closed",
		"pre": [
			"你看準了那道縫。",
			"你的腳尖往前一滑，身子壓得很低。",
			"你把劍收到腰側，劍尖對著{name}。",
		],
		"default": {"deal": 2.2, "text": [
			"劍尖從{guard}的邊上鑽進去，刺進{name}的肩窩，又拔了出來。",
			"{name}還沒看清你的劍，劍尖已經從{pron}腋下刺了進去。",
			"這一刺又快又直，正好刺進{name}護不到的那道縫。",
		]},
		"vs": {
			"windup": {"deal": 2.2, "effect": "interrupt", "text": [
				"{name}的力還沒蓄滿，你的劍尖已經刺進{pron}的手臂。{pron}這一下使不出來了。",
				"{name}舉起{weapon}的那一刻，胸口全空了。你一劍刺進去，{pron}的手垂了下來。",
			]},
		},
	},
	"bastion": {
		"name": "不落要塞", "stat": "str", "desc": "守城人的絕學。對手蓄好的重招砸下來的那一刻才用得出來：用劍硬接住，借那股力打回去。",
		"ult": true, "when": "heavy",
		"pre": [
			"你不退。",
			"你雙腳一前一後釘在地上，劍橫在頭頂。",
			"{name}的力道壓下來，你迎了上去。",
		],
		"default": {"deal": 2.6, "take": 0.0, "text": [
			"你用劍身接住這一下，膝蓋沉了一寸，沒有退。{name}的力道還壓在你劍上，你順著一推一轉，劍刃落在{pron}身上。",
			"{weapon}砸在你架起的劍上，火星四濺。你借著這股力往下一帶，{name}收不住，你的劍已經劈了回去。",
		]},
		"vs": {},
	},
}


## 查表：這招碰上這種類型的結果。traits 是對手的特性（beast、disarmable、big）
static func entry(move_id: String, intent_type: String, traits: Array) -> Dictionary:
	var m: Dictionary = MOVES[move_id]
	var e: Dictionary = m["default"]
	if traits.has("big") and m.has("vs_big") and m["vs_big"].has(intent_type):
		e = m["vs_big"][intent_type]
	elif m["vs"].has(intent_type):
		e = m["vs"][intent_type]
	if e.has("requires") and not traits.has(e["requires"]):
		e = e["else"]
	return e


static func is_basic(move_id: String) -> bool:
	return not LEARNABLE.has(move_id)
