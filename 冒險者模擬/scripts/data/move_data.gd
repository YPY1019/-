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
## grade：等級（0 灰～5 紅，跟境界同一套顏色，見 GrowthData.GRADE_COLORS）。
## school：哪一派的招（SchoolData.ID）；空的是通用招，不屬於任何流派。
## text_mid / text_hi：境界到中段（第三、四境）、高段（第五、六境）的寫法。同一招，越強寫得越從容（見 Battle._text_for）。
## stat：這招靠哪個基礎數值（str 力量、agi 敏捷）。跟對手的同一項比，決定成不成功、打多痛；用了也會練到這個數值。
## fail：失敗時的結果。成功的機率看雙方數值的差距（GrowthData.success_chance）。招有效果（掃倒、破防、掙脫…）或能少挨打時才會失敗。
## odds：這招本身比較難（負）或比較容易（正）成功。
##   沒寫 take 的話，對手出手就照樣挨打。
## weapons：要拿哪一類武器才能用（WeaponData 的 kind）；空的 = 什麼都能用。
## act：別人用這招打你時的樣子（世界上的人跟你用同一套招）。寫法跟 EnemyData 的 actions 一樣，多了：
##   cond 什麼時候才用：foe_open 你站不穩／看不見／被抱住；low_hp 自己快撐不住。
##   沒有 act 的招（蛇蛻）只在被打時用得到，別人用不出來。
## {my}：你自己的武器（斧頭、大刀…），用在不是劍的招。
## text 每次隨機挑一句。{name} 對手、{pron} 他／牠、{weapon} 對手的武器、{guard} 對手的防具。

## 人人都會的一般招。跟學來的招放在同一個池子裡，不是永遠都在
const BASIC := ["attack", "defend", "dodge"]
## 每回合的選項至少有一個攻擊類、一個防守類
const OFFENSE := ["attack", "fallstone", "triple", "needle", "lh_pommel", "lh_half", "lh_verdict",
	"fb_cleave", "fb_whirl", "fb_execute", "fb_fury", "leg_rain", "leg_siege"]
const DEFENSE := ["defend", "dodge", "knee", "shed", "deflect", "lh_cross", "lh_advance", "lh_bind", "fb_hug", "fb_hook"]
## 撤退不是招式，永遠可以選（被抱住時不行）
const FLEE := "flee"
## 被抱住時能用的招（沒學的不會出現）
const HELD := ["struggle", "attack", "shed", "needle", "lh_half"]
const LEARNABLE := ["knee", "fallstone", "shed", "dust", "deflect", "triple", "needle",
	"lh_cross", "lh_pommel", "lh_half", "lh_advance", "lh_bind", "lh_verdict",
	"fb_cleave", "fb_hug", "fb_whirl", "fb_hook", "fb_execute", "fb_fury",
	"leg_rain", "leg_siege"]

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
		"grade": 0, "name": "攻擊", "stat": "str", "desc": "普通的一劍，出手快。對方橫掃或直刺時搶先砍到，對方的攻擊會被打歪一點。對方防守時砍不進去。",
		"fail": {"deal": 1.0, "take": 1.0, "hit": true, "text": ["你想搶先出劍，慢了半拍，{pron}的攻擊先到了。"]},
		"default": {"deal": 1.0, "take": 1.0, "hit": true, "text": [
			"你不退，迎上去一劍砍向{name}。",
			"你踏前一步，劍劈向{name}的肩膀，自己的胸口也跟著露了出來。",
			"你橫劍一掃，劍鋒從{name}身側劃過。",
		]},
		"vs": {
			# 出手快：對方出快攻時搶先砍到，對方的攻擊被打歪一點
			"sweep": {"text_mid": ["{weapon}才拉開，你的劍已經到了{name}身上，那一掃軟了下來。"], "text_hi": ["你搶在{weapon}之前出劍，劍到的時候，{name}的手勢還沒開始。"], "deal": 1.0, "take": 0.7, "hit": true, "text": [
				"{name}的{weapon}才拉開，你已經一劍砍了進去。{pron}這一掃的力道被打散了一半。",
				"你不等{weapon}掃到，搶先出劍。劍先到，{pron}的手勢跟著歪了。",
			]},
			"thrust": {"text_mid": ["{name}衝過來，你的劍尖先到，{pron}自己把自己撞歪了。"], "text_hi": ["你一劍遞出去，正好停在{name}要經過的地方。"], "deal": 1.0, "take": 0.7, "hit": true, "text": [
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
		"grade": 0, "name": "防禦", "stat": "str", "desc": "用劍擋住攻擊，會受一點傷，擋住後能順手回砍。擋不住擒抱、撒沙和吼聲。",
		"fail": {"take": 1.0, "hit": true, "text": ["你舉劍去擋，沒擋正，被打得連人帶劍退了回來。", "你架劍去擋，劍被壓回你自己身上。"]},
		"default": {"text": [
			"你舉劍守在身前，{name}卻沒有出手。",
			"你擺好架勢等著，什麼也沒擋到。",
		]},
		"vs": {
			"sweep": {"text_mid": ["你豎劍一擋，{weapon}的力道從劍身卸到腳下，你一步沒退，回手一劍。"], "text_hi": ["{weapon}撞在你的劍上，像撞上一根釘在地裡的樁。你順著反彈的勢子，劍已經回到{name}身上。"], "deal": 0.4, "take": 0.4, "text": [
				"你豎劍硬擋。{weapon}撞在劍身上，你手臂一麻，腳下滑了半步。趁{pron}的力道剛過，你順手回了一劍。",
				"鏘的一聲，{weapon}被你的劍擋住。你借著反彈的勢子，劍鋒往回一帶，在{name}身上拉了一道。",
			]},
			"thrust": {"text_mid": ["你劍身一格，{weapon}擦著劍刃滑開，你趁勢削了回去。"], "text_hi": ["你的劍只偏了一點，{weapon}就落空了。你沒有多餘的動作，回手一劍。"], "deal": 0.4, "take": 0.3, "text": [
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
		"grade": 0, "name": "閃避", "stat": "agi", "desc": "躲開攻擊，不會受傷。但躲完腳步亂了：下回合不能再閃避，選項也少一個。躲不掉吼聲。",
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
		"grade": 0, "name": "撤退", "desc": "轉身逃走。這回合對方攻擊的話會挨打。",
		"default": {"take": 1.0, "hit": true, "text": ["你轉身就跑。", "你虛晃一劍，轉身就跑。"]},
		"vs": {},
	},
	"struggle": {
		"grade": 0, "name": "掙扎", "stat": "str", "desc": "被抱住時拼命掙扎。力氣要比對方大才有把握掙開。",
		"fail": {"take": 1.0, "hit": true, "text": ["你掙了幾下，還是被死死勒住。"]},
		# 硬掙比較難，力氣要比對方大才有把握
		"odds": -0.2,
		"default": {"take": 0.0, "effect": "escape", "text": ["你腰一扭，掙了出來。", "你咬牙一掙，從{name}手裡脫了身。"]},
		"vs": {},
	},

	# ---------- 通用招（不屬於任何流派，任何武器都能用。練武場、路上的人都會） ----------
	"knee": {
		"name": "斷膝", "grade": 1, "school": "", "weapons": [], "stat": "agi",
		"desc": "對付橫掃：蹲低從底下鑽過，順勢斬對方的腳，把人放倒。體型大的放不倒。",
		"act": {"type": "sweep", "power": 0.8, "on_hit": "off_balance", "armed": true,
			"tell": ["{name}忽然矮下身子，{weapon}貼著地面往你腳上掃。", "{name}往下一沉，{weapon}斬向你的膝蓋。"],
			"hit": ["{weapon}斬在你的小腿上，你腳下一軟，踉蹌了兩步。", "膝蓋外側挨了一下，你一條腿使不上力。"]},
		"fail": {"deal": 0.3, "take": 1.0, "hit": true, "text": ["你壓低身子斬向{name}的腳，{pron}腳一抬就讓開了，你自己反倒吃了一記。"]},
		"default": {"deal": 0.5, "take": 1.0, "hit": true, "text": [
			"你矮身斬向{name}的腳，可是{pron}這一下不是橫著來的，你整個人露在攻擊底下。",
		]},
		"vs": {
			"sweep": {"text_mid": ["{weapon}橫掃過來，你早就矮下了身子。劍貼著地面一抹，正中{name}的膝蓋外側，{pron}整個人往前栽。"], "text_hi": ["{weapon}還沒掃到，你已經不在那個高度了。劍鋒貼地一帶，{name}自己往前撲倒，像是被絆了一下。"], "deal": 0.5, "take": 0.0, "effect": "trip", "good": true, "text": [
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
	"fallstone": {
		"name": "墜石", "grade": 1, "school": "", "weapons": [], "stat": "str",
		"desc": "雙手全力一擊，砸開防守、打斷蓄力。對方正在出手時用，自己也會挨得更痛。收招慢：下回合不能閃避，也不能再用。",
		"act": {"type": "smash", "power": 1.6, "windup": true, "armed": true,
			"tell": ["{name}雙手握住{weapon}，慢慢舉過頭頂，重心沉到了後腳。", "{name}往後拉開半步，雙手把{weapon}高高舉起。"],
			"strike_tell": ["{weapon}直直砸了下來！"],
			"hit": ["{weapon}砸在你肩上，你兩腿一軟，跪了一下才撐起來。", "你偏了偏頭，{weapon}還是砸在你的鎖骨上，整條手臂都麻了。"]},
		"no_repeat": true,
		"fail": {"deal": 1.0, "text": ["你全力一劍劈下，{name}硬是扛住了。", "你雙手一劍劈下去，{name}晃都沒晃。"]},
		"self": "off_balance",
		"pierce": true,
		"default": {"deal": 1.0, "take": 1.5, "hit": true, "text": [
			"你雙手舉劍，全身的重量壓上去，一劍劈向{name}。這一劍收不回來，你的胸口整個敞著。",
			"你一劍劈下，深深砍進{name}身上，{pron}的攻擊也同時落在你身上。",
		]},
		"vs": {
			"guard": {"text_mid": ["你看準{guard}的邊緣，雙手一劍劈下。{guard}被劈得歪到一邊，{name}的胸口露了出來。"], "text_hi": ["你一劍劈在{guard}最吃力的地方，不快，但很沉。{guard}整個被砸開，{name}的手臂也跟著垂了下去。"], "deal": 1.5, "effect": "break", "good": true, "text": [
				"你雙手握劍，從上往下劈在{guard}上。{name}被砸得往後退了好幾步，{guard}歪到一邊。",
			]},
			"windup": {"text_mid": ["{name}的力還沒蓄滿，你一劍劈在{pron}抬起的手臂上，那一下硬生生被打斷。"], "text_hi": ["你等的就是{name}吸氣的那一刻。一劍劈下，{pron}蓄了半天的力，全散了。"], "deal": 2.0, "effect": "interrupt", "good": true, "text": [
				"{name}還在蓄力，你搶先一劍劈下去，{pron}的動作硬生生斷了。",
			]},
			"opening": {"text_mid": ["{name}還沒站穩，你雙手握劍，一劍從肩頭劈了下去。"], "text_hi": ["你不急，等{name}的重心完全歪了，才一劍劈下。這一劍劈得很實。"], "deal": 2.5, "good": true, "text": [
				"你雙手握劍，把全身的重量壓在這一劍上，劈在{name}身上。",
				"你高高舉劍，一劍劈下。{name}來不及擋。",
			]},
		},
		"vs_big": {
			"windup": {"deal": 2.0, "text": ["你一劍劈在{name}身上，砍出一道深口子。{pron}太重了，動作沒停。"]},
		},
	},
	"shed": {
		"name": "蛇蛻", "grade": 1, "school": "", "weapons": [], "stat": "str",
		"desc": "對付擒抱：在被抱住前鑽出去，或被抱住時掙開，順手回一劍。",
		"fail": {"take": 1.0, "hit": true, "text": ["你想掙脫，沒掙開。"]},
		"default": {"take": 1.0, "hit": true, "text": ["你壓低重心準備掙脫，可是{name}根本沒有要抓你。"]},
		"vs": {
			"grab": {"text_mid": ["{name}撲過來抓你，你一縮肩膀，從{pron}手臂底下滑了出去，順手一劍。"], "text_hi": ["{name}的手才碰到你的衣服，你已經不在那裡了。你從{pron}身側繞出去，劍在{pron}背上劃了一道。"], "deal": 0.5, "take": 0.0, "good": true, "text": [
				"{name}撲上來的時候，你矮身從{pron}手臂底下鑽了出去，轉身一劍砍在{pron}背上。",
			]},
			"hold": {"text_mid": ["你肩膀一沉一扭，從{name}手裡滑了出來，回手一劍。"], "text_hi": ["你只是換了一口氣，身子一轉就脫了出來。{name}的手還箍著空的。"], "deal": 0.5, "take": 0.3, "effect": "escape", "good": true, "text": [
				"你手肘往後一撞，{name}吃痛，手鬆了一下。你扭身掙開，順手一劍。",
				"你用頭往後一頂，撞在{name}臉上。{pron}手一鬆，你滾了出來，劍順勢劃過{pron}身上。",
			]},
			"guard": {"text": ["你壓低重心等著，{name}只是步步逼近。"]},
			"opening": {"text": ["你壓低重心等著，白白錯過了機會。"]},
			"windup": {"text": ["你壓低重心等著，{name}還在蓄力。"]},
		},
	},
	"dust": {
		"name": "揚塵", "grade": 1, "school": "", "weapons": [], "stat": "agi",
		"desc": "腳尖一勾，把沙土踢進對方眼睛。對方下一次出手很可能落空。這回合自己不閃不擋。",
		"act": {"type": "trick", "power": 0.0, "on_hit": "blind",
			"tell": ["{name}腳尖往地上一勾。", "{name}的腳在地上一搓，像是站不穩。"],
			"hit": ["一把沙土踢進你的眼睛，你什麼都看不清了。", "沙子撒了你一臉，你閉上眼，耳邊是{pron}的笑聲。"]},
		"fail": {"text": ["你腳尖一勾，沙土撒過去，{name}一偏頭就讓開了。"]},
		"default": {"effect": "blind", "take": 1.0, "hit": true, "text": [
			"你腳尖一勾，一把沙土直撲{name}的臉，自己也沒空躲{pron}這一下。",
		]},
		"vs": {
			"guard": {"effect": "blind", "text": ["{name}縮在{guard}後面，你一腳把沙土從旁邊踢進{pron}的眼睛。{pron}罵了一聲，拼命眨眼。"]},
			"opening": {"effect": "blind", "text": ["你趁{name}還沒站穩，一腳沙土踢進{pron}眼裡。"]},
			"windup": {"effect": "blind", "good": true, "text_mid": ["{name}的力還在往上提，眼睛死盯著你。你腳下一勾，沙土正好撲進{pron}睜大的眼睛。"], "text": ["{name}還在蓄力，你一腳把沙土踢進{pron}的眼睛。"]},
		},
	},
	"deflect": {
		"name": "撥鋒", "grade": 2, "school": "", "weapons": [], "stat": "agi",
		"desc": "對付直刺和撲咬：把攻擊撥開，同時刺回去。還是會被擦到一下。",
		"act": {"type": "thrust", "power": 1.0, "armed": true,
			"tell": ["{name}的{weapon}貼著你的劍刃滑了進來。", "{name}一撥你的劍，{weapon}順勢往你胸口送。"],
			"hit": ["{weapon}從你劍下鑽進來，刺在你的肋下。", "你的劍被撥開，肩膀上挨了一下。"]},
		"fail": {"take": 1.0, "hit": true, "text": ["你想撥開{weapon}，慢了一點，劍還沒碰到，攻擊已經到了。"]},
		"default": {"text": ["你擺好撥擋的架勢，{name}卻沒有衝過來。"]},
		"vs": {
			"thrust": {"text_mid": ["{name}衝過來，你劍身一搭一撥，{weapon}擦著你的肩膀過去。劍尖已經在{pron}身上了。"], "text_hi": ["你沒有退。劍只動了一寸，{weapon}就從你身邊滑了過去，{name}自己撞上了你的劍尖。"], "deal": 1.2, "take": 0.3, "good": true, "text": [
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
	"triple": {
		"name": "三疊斬", "grade": 2, "school": "", "weapons": [], "stat": "str",
		"desc": "一口氣連砍三下，比普通攻擊痛。但三下砍完收不回來，擋不開對方的攻擊。砍不穿厚甲和盾。",
		"act": {"type": "sweep", "power": 1.4, "armed": true,
			"tell": ["{name}踏前一步，{weapon}一下接一下連著砍過來。", "{name}的{weapon}從左到右、再從右到左，三下連成一氣。"],
			"hit": ["你擋住了第一下，後兩下都落在你身上。", "三下砍完，你的手臂和肩膀各多了一道口子。"]},
		"default": {"deal": 1.3, "take": 1.0, "hit": true, "text": [
			"你一劍接一劍連砍三下，{name}也同時出手了。",
			"你搶上去連砍三劍，自己的身子也全敞開了。",
		]},
		"vs": {
			"sweep": {"deal": 1.3, "take": 1.0, "hit": true, "text": [
				"你迎著{weapon}連砍三劍，劍劍見血，{weapon}也結結實實掃了過來。",
				"你不管掃過來的{weapon}，三劍連著砍出去。兩個人同時見了血。",
			]},
			"thrust": {"deal": 1.3, "take": 1.0, "hit": true, "text": [
				"你連砍三劍，{name}不躲不閃，硬是頂著劍衝了進來。",
				"你三劍連著砍出去，{name}的{weapon}也同時到了。",
			]},
			"opening": {"text_mid": ["你連砍三劍，一劍比一劍深，{name}只來得及擋住第一劍。"], "text_hi": ["三劍連成一劍。{name}只聽見一聲，身上卻多了三道口子。"], "deal": 2.2, "good": true, "text": [
				"你不收劍，第一劍砍下去，手腕一轉接第二劍、第三劍。{name}身上多了三道口子。",
				"你連砍三劍，劍劍都落在{name}來不及護住的地方。",
			]},
			"windup": {"deal": 1.8, "text": ["{name}還在蓄力，你一口氣砍了三劍。"]},
			"guard": {"deal": 0.4, "text": ["你連砍三劍，全砍在{guard}上，一劍也沒進去。"]},
		},
	},
	"needle": {
		"name": "針眼", "grade": 2, "school": "", "weapons": [], "stat": "agi",
		"desc": "刺向要害或盔甲縫隙，盔甲擋不住。對方露出破綻、蓄勢、或抱住你時特別痛。",
		"act": {"type": "thrust", "power": 1.1, "armed": true,
			"tell": ["{name}壓低身子，{weapon}的尖對準你腋下那道縫。", "{name}盯著你的領口，{weapon}直直刺來。"],
			"hit": ["{weapon}從你腋下鑽進去，你整條手臂一冷。", "{weapon}刺在你的領口邊上，差一點就是喉嚨。"]},
		"fail": {"deal": 0.5, "take": 1.0, "hit": true, "text": ["你刺向{name}的要害，{pron}一扭身讓開了，劍尖只劃破了點皮。"]},
		"pierce": true,
		"default": {"deal": 1.0, "take": 1.0, "hit": true, "text": [
			"你刺向{name}的腋下，{pron}一扭身，劍尖還是刺進了肉裡。你自己也吃了一記。",
		]},
		"vs": {
			"opening": {"text_mid": ["{name}還沒站穩，脖子和領口之間那道縫全露了出來。你的劍尖已經在裡面了。"], "text_hi": ["你只往前送了一寸。劍尖找到{name}甲片之間的縫，一點都沒偏。"], "deal": 2.6, "good": true, "text": [
				"{name}的脖子和領口之間露出一道縫。你跨上一步，劍尖對準那道縫刺了進去。",
				"你貼上去，劍尖從{name}腋下鑽進去，刺得很深。",
			]},
			"windup": {"text_mid": ["{name}舉高了手臂蓄力，腋下全空了。你一劍刺了進去。"], "text_hi": ["{name}的手才舉起來，你的劍尖已經在{pron}腋下那條縫裡了。"], "deal": 2.3, "good": true, "text": [
				"{name}還在蓄力，身子繃得死緊。你一步搶進去，劍尖刺了進去。",
			]},
			"smash": {"deal": 1.4, "take": 1.0, "hit": true, "text": [
				"{name}砸下來的時候，你不退反進，迎著{pron}刺出一劍。你們同時擊中了對方。",
			]},
			"guard": {"deal": 0.0, "text": ["你刺向{name}的要害，劍尖叮的一聲撞在{guard}上，滑開了。"]},
			"hold": {"text_mid": ["你被箍著，反手一劍往{name}的肋下縫隙一捅，{pron}手一鬆。"], "text_hi": ["你沒有掙扎，只是把劍轉了個方向。劍尖找到{name}的縫，{pron}自己鬆了手。"], "deal": 1.8, "take": 0.5, "effect": "escape", "good": true, "text": [
				"被抱住的時候你們貼得最近。你反手握劍，劍尖從{name}肋下刺進去。{pron}痛得一鬆，你掙了出來。",
			]},
		},
	},

	# ---------- 獅心劍庭（正統騎士，劍與盾） ----------
	"lh_cross": {
		"name": "十字鐵壁", "grade": 2, "school": "lionheart", "weapons": ["sword", "greatsword"], "stat": "str",
		"desc": "盾和劍交叉架住重劈、橫掃，不硬接，順著力道卸開，再借力斬回去。對重劈最有效，能讓對方收勢不住、往前踉蹌。",
		"act": {"type": "guard",
			"tell": ["{name}把盾和劍交叉架在身前，一步不讓。", "{name}的盾往前一推，劍斜斜搭在盾邊上，等你先動。"]},
		"fail": {"take": 1.0, "hit": true, "text": ["你想用盾劍把{weapon}卸開，沒架準，那股力道還是壓了下來。"]},
		"default": {"text": ["你盾劍交叉守在身前，{name}卻沒有砸下來。"]},
		"vs": {
			"smash": {"text_mid": ["{weapon}砸下來，你盾劍交叉斜架，重量順著盾面滑到地上。{name}收不住勢往前衝，你回手一劍。"], "text_hi": ["你只把盾斜斜一抬。{weapon}落在盾面上，順著滑了下去。{name}整個人跟著撲了出去，背後空了。"], "deal": 0.8, "take": 0.2, "effect": "stagger", "good": true, "text": [
				"你不硬接，盾和劍交叉斜斜迎上去。{weapon}順著盾面滑開，砸進土裡。{name}整個人的重量都在這一下，收不住，往前衝過你身邊，背後全空了。你回手一劍斬在{pron}身上。",
				"{weapon}壓下來的時候，你的盾只輕輕一帶，就把它引到一旁。{name}用力過猛，往前踉蹌了兩步。你的劍已經跟著劃過了{pron}的身體。",
			]},
			"sweep": {"text_mid": ["你迎著{weapon}把盾斜斜一架，橫掃的力道往外一送，劍順勢劈回去。"], "text_hi": ["{weapon}掃到你身前，被盾邊輕輕一引就偏了。你手腕一轉，劍已經落在{name}身上。"], "deal": 0.8, "take": 0.3, "good": true, "text": [
				"{weapon}撞上你交叉的盾劍，你順著它的方向一帶，卸掉了大半力道，再借那股勁斬了回去。",
				"{weapon}掃到你身前，你的盾一轉，把力道引向一旁，劍鋒反過來削在{name}身上。",
			]},
			"thrust": {"deal": 0.4, "take": 0.6, "text": ["你想用盾卸開{weapon}，可是它又快又直，只卸掉一點，回手一劍也砍得很淺。"]},
			"grab": {"take": 1.0, "hit": true, "text": ["你架好盾劍，{name}卻是整個人撲上來的。"]},
			"trick": {"take": 1.0, "hit": true, "text": ["你架好盾劍等著，{name}卻根本沒出力。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你架好盾劍。吼聲擋不住。"]},
		},
	},
	"lh_pommel": {
		"name": "碎齒", "grade": 2, "school": "lionheart", "weapons": ["sword", "greatsword"], "stat": "str",
		"desc": "不用劍刃，用劍柄的配重球直接砸對方的臉。出手短、快，專門打斷蓄力，也能砸退撲上來的人。",
		"act": {"type": "smash", "power": 0.7, "on_hit": "shaken", "armed": true,
			"tell": ["{name}劍尖一沉，劍柄朝你臉上砸來。", "{name}貼上來，倒握著劍，柄頭對準你的鼻樑。"],
			"hit": ["劍柄砸在你的顴骨上，你眼前一白，耳朵嗡嗡響。", "你嘴裡一陣血腥味，牙齒鬆了一顆。"]},
		"fail": {"deal": 0.2, "take": 1.0, "hit": true, "text": ["你倒過劍柄去砸{name}，{pron}偏頭讓開了，你自己貼得太近，挨了一下。"]},
		"default": {"deal": 0.6, "take": 1.0, "hit": true, "text": ["你搶上半步，劍柄砸在{name}的臉上，{pron}的攻擊也落在你身上。"]},
		"vs": {
			"windup": {"text_mid": ["{name}舉起{weapon}的那一刻，你已經到了{pron}身前，劍柄砸在{pron}的下巴上，那一下沒了。"], "text_hi": ["你沒有出劍，只是往前一步，劍柄頂在{name}的嘴上。{pron}蓄的那股力全散了。"], "deal": 0.8, "effect": "interrupt", "good": true, "text": [
				"{name}還在蓄力，你搶上去，劍柄砸在{pron}的嘴上。{pron}吐出一口血，動作斷了。",
			]},
			"grab": {"text_mid": ["{name}撲上來，你劍柄往下一砸，正中{pron}的眉骨，{pron}踉蹌著退開。"], "deal": 0.6, "take": 0.0, "effect": "stagger", "good": true, "text": [
				"{name}撲上來抓你，你倒過劍柄迎著{pron}的臉砸過去。{pron}撞上劍柄，往後踉蹌了兩步。",
			]},
			"thrust": {"deal": 0.6, "take": 0.8, "text": ["{weapon}刺過來，你側身讓過一半，劍柄砸在{name}的肩上，砸得不深。"]},
			"guard": {"deal": 0.4, "text": ["你一記劍柄砸在{guard}上，{name}晃了晃，沒退。"]},
			"opening": {"deal": 1.0, "text": ["你一記劍柄砸在{name}的太陽穴上。"]},
		},
	},
	"lh_half": {
		"name": "獅王卸甲", "grade": 3, "school": "lionheart", "weapons": ["sword", "greatsword"], "stat": "agi",
		"desc": "半劍握法：左手握住劍身，把長劍當短矛用，專刺鎧甲的縫。盔甲擋不住。對方露出破綻、蓄勢、抱住你時最致命。",
		"act": {"type": "thrust", "power": 1.4, "armed": true,
			"tell": ["{name}左手握住劍身，劍尖對準你甲片之間的縫。", "{name}把劍收短，像拿短矛一樣，劍尖找你的腋下。"],
			"hit": ["劍尖從你甲片的縫裡鑽進去，冷得像一根冰。", "你只覺得腋下一涼，接著才痛。"]},
		"fail": {"deal": 0.5, "take": 1.0, "hit": true, "text": ["你半握劍身刺向{name}的甲縫，{pron}一擰身，劍尖刮在甲片上滑開了。"]},
		"pierce": true,
		"default": {"deal": 1.1, "take": 1.0, "hit": true, "text": [
			"你左手握住劍身，劍尖往{name}的腋下一送，刺進了肉裡。你自己也吃了一記。",
		]},
		"vs": {
			"opening": {"text_mid": ["你左手握住劍身，劍尖從{name}腋下甲片的縫隙送了進去。"], "text_hi": ["你半握劍身，像拿短矛一樣一送。劍尖穿過甲片之間那條縫，一寸不差。"], "deal": 3.0, "good": true, "text": [
				"你左手握住劍身，貼上{name}，劍尖對準{pron}領口的縫刺了進去。",
				"{name}還沒站穩，你把劍收短，從{pron}腋下的甲縫裡一捅到底。",
			]},
			"windup": {"text_mid": ["{name}舉高了手臂蓄力，腋下全空了。你握住劍身，一劍刺了進去。"], "text_hi": ["{name}的手才舉起來，你的劍尖已經在{pron}腋下那條縫裡了。"], "deal": 2.6, "good": true, "text": [
				"{name}雙手舉起{weapon}，腋下的甲片翻了開來。你握住劍身，一步搶進去刺了個正著。",
			]},
			"smash": {"deal": 1.6, "take": 1.0, "hit": true, "text": [
				"{name}砸下來的時候，你不退反進，半握著劍迎上去一刺。你們同時擊中了對方。",
			]},
			"guard": {"deal": 0.3, "text": ["你半握劍身去找{name}的縫，劍尖撞在{guard}上滑開了。"]},
			"hold": {"text_mid": ["你被箍著，反手握住劍身，劍尖往{name}的肋下縫隙一捅，{pron}手一鬆。"], "text_hi": ["你沒有掙扎，只是把劍身轉了個方向。劍尖找到{name}甲片的縫，{pron}自己鬆了手。"], "deal": 2.2, "take": 0.4, "effect": "escape", "good": true, "text": [
				"被抱住的時候你們貼得最近。你握住劍身，劍尖從{name}肋下的甲縫刺進去。{pron}痛得一鬆，你掙了出來。",
			]},
		},
	},
	"lh_advance": {
		"name": "鐵壁推進", "grade": 3, "school": "lionheart", "weapons": ["sword", "greatsword"], "stat": "str",
		"desc": "盾頂在身前，短步往前壓。擋住直刺和撲抱，把對方撞得站不穩；碰上縮在防守後面的人，連人帶盾推開。",
		"act": {"type": "smash", "power": 0.8, "on_hit": "off_balance", "armed": true,
			"tell": ["{name}把盾頂在身前，一步一步往你身上壓過來。", "{name}縮在盾後面，肩膀一沉，整個人往前撞。"],
			"hit": ["盾面撞在你胸口，你往後退了好幾步，腳下一亂。", "你被連人帶劍推開，差點坐倒在地上。"]},
		"fail": {"take": 1.0, "hit": true, "text": ["你頂著盾往前壓，{name}側身一讓，你撲了個空。"]},
		"default": {"deal": 0.3, "take": 1.0, "hit": true, "text": ["你頂著盾往前壓了兩步，{name}的攻擊照樣落在你身上。"]},
		"vs": {
			"thrust": {"text_mid": ["{weapon}刺在你的盾心上，你腳下沒停，盾一頂，{name}往後一仰。"], "text_hi": ["你連看都沒看{weapon}，盾往前一送，{name}自己撞了上來，腳下全亂了。"], "deal": 0.3, "take": 0.1, "effect": "stagger", "good": true, "text": [
				"{weapon}刺在你的盾上，你順著那股力往前一頂，{name}被撞得往後踉蹌，重心全歪了。",
			]},
			"grab": {"deal": 0.3, "take": 0.0, "effect": "stagger", "good": true, "text": [
				"{name}撲上來，正好撞在你頂出去的盾上。{pron}的手抓不到你，人被彈了回去。",
			]},
			"guard": {"text_mid": ["你短步往前壓，盾撞在{guard}上，{name}連人帶{guard}被推開，胸口空了出來。"], "deal": 0.4, "effect": "break", "good": true, "text": [
				"{name}縮在{guard}後面，你就頂著盾往前壓。兩面防守撞在一起，{name}被推得往後一歪，{guard}垂了下來。",
			]},
			"sweep": {"deal": 0.3, "take": 0.5, "text": ["{weapon}從側面掃過來，你的盾只擋住一半。"]},
			"smash": {"take": 0.8, "text": ["{weapon}從頭頂砸下來，你舉盾去頂，整條手臂都麻了。"]},
		},
	},
	"lh_bind": {
		"name": "斷鋒", "grade": 4, "school": "lionheart", "weapons": ["sword", "greatsword"], "stat": "agi",
		"desc": "在對方揮過來的瞬間，用盾邊卡住對方的兵器，劍身一絞，把兵器從他手裡奪下來。對野獸沒用，太重的兵器也絞不動。",
		"act": {"type": "trick", "power": 0.4, "on_hit": "off_balance", "armed": true,
			"tell": ["{name}的盾邊忽然卡上你的劍，{pron}的劍跟著一絞。", "{name}迎著你的劍一搭一壓。"],
			"hit": ["你的手腕被絞得一扭，劍差點脫手，人往前栽了半步。", "你的劍被卡住，你被帶得失了重心。"]},
		"fail": {"take": 1.0, "hit": true, "text": ["你想用盾邊卡住{name}的{weapon}，{pron}手一縮，你撲了個空。"]},
		"default": {"text": ["你盯著{weapon}等著，{name}沒有揮過來。"]},
		"vs": {
			"sweep": {"text_mid": ["{weapon}掃過來，你盾邊一卡，劍身一絞，{name}手腕一麻，{weapon}飛了出去。"], "text_hi": ["你的盾碰上{weapon}，只一卡一挑。{name}還在揮，手上已經空了。"], "take": 0.4, "effect": "disarm", "good": true, "requires": "disarmable", "text": [
				"{weapon}揮過來的時候，你的盾邊正好卡住它，劍身貼上去一絞，扭在{name}手腕最使不上力的角度。{weapon}脫手飛出去，噹啷一聲落在遠處。",
			], "else": {"take": 1.0, "hit": true, "text": ["你想奪下{name}的兵器，絞不動。"]}},
			"thrust": {"text_mid": ["{weapon}刺過來，你盾邊一壓，劍身一轉，把它從{name}手裡絞了出去。"], "text_hi": ["你迎著{weapon}一搭，手腕輕輕一翻。{weapon}落在地上，{name}愣了一下。"], "take": 0.4, "effect": "disarm", "good": true, "requires": "disarmable", "text": [
				"你用盾壓住刺過來的{weapon}，劍順勢往上一挑，{weapon}從{name}手裡飛了出去。",
			], "else": {"take": 1.0, "hit": true, "text": ["你想奪下{name}的兵器，絞不動。"]}},
			"smash": {"take": 1.0, "hit": true, "text": ["從頭頂砸下來的力道太大，你的盾一碰上就被壓了下去，卡不住。"]},
			"grab": {"take": 1.0, "hit": true, "text": ["你盯著{name}的兵器，{pron}卻直接撲上來抓你。"]},
			"trick": {"take": 1.0, "hit": true, "text": ["你盯著{name}的兵器，沒注意{pron}的腳。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你盯著{name}，吼聲震得你耳朵發疼。"]},
		},
	},

	# ---------- 霜熊戰團（北方戰團，刀斧） ----------
	"fb_cleave": {
		"name": "裂冰劈", "grade": 2, "school": "frostbear", "weapons": ["axe", "blade"], "stat": "str",
		"desc": "雙手從頭頂直劈下來，不管對方的兵器在哪。劈得開盾和甲，打得斷蓄力。收招慢：下回合不能閃避，也不能再用。",
		"act": {"type": "smash", "power": 1.8, "windup": true, "armed": true,
			"tell": ["{name}雙手握住{weapon}，舉過頭頂，整個人往後一仰。", "{name}兩腳一前一後踩實，{weapon}高高舉起。"],
			"strike_tell": ["{weapon}劈下來了！"],
			"hit": ["{weapon}劈在你肩上，你整條手臂都沒了知覺。", "你偏了一下頭，刃口砍在你的鎖骨上。"]},
		"no_repeat": true,
		"self": "off_balance",
		"pierce": true,
		"fail": {"deal": 1.0, "text": ["你一記劈下，{name}硬是扛住了。"]},
		"default": {"deal": 1.2, "take": 1.3, "hit": true, "text": [
			"你雙手掄起{my}劈下去，劈進{name}身上，{pron}的攻擊也同時落在你身上。",
		]},
		"vs": {
			"guard": {"text_mid": ["你一記劈在{guard}正中，{guard}從中間裂開，{name}的手臂跟著垂了下去。"], "deal": 1.8, "effect": "break", "good": true, "text": [
				"你雙手掄起{my}，從上往下劈在{guard}上。{guard}被劈得歪到一邊，{name}的胸口露了出來。",
			]},
			"windup": {"deal": 2.0, "effect": "interrupt", "good": true, "text": [
				"{name}還在蓄力，你的{my}已經劈了下去，{pron}的動作斷了。",
			]},
			"opening": {"text_mid": ["{name}還沒站穩，你的{my}從{pron}的肩頭一路劈下去。"], "deal": 2.6, "good": true, "text": [
				"你雙手掄起{my}，把全身的重量壓上去，劈在{name}身上。",
			]},
		},
	},
	"fb_hug": {
		"name": "熊擁", "grade": 2, "school": "frostbear", "weapons": [], "stat": "str",
		"desc": "迎著對方的直刺貼身撲上去，把人抱住摔倒，下一下就是破綻。對付縮在防守後面的人，連人帶盾抱住。",
		"act": {"type": "grab", "power": 0.8, "on_hit": "held",
			"tell": ["{name}張開雙臂，低著頭朝你撲過來。", "{name}忽然丟開架勢，整個人撲向你的腰。"],
			"hit": ["{name}一把抱住你的腰，你兩腳離了地。", "你被{name}箍住了，肋骨被勒得咯咯響。"],
			"hold": {"power": 0.6,
				"tell": ["{name}箍著你不放，雙臂越收越緊。", "{name}把你往地上壓。"],
				"hit": ["你吸不到氣，眼前發黑。", "你的肋骨又響了一聲。"]}},
		"fail": {"take": 1.0, "hit": true, "text": ["你撲上去抱{name}，{pron}側身一讓，你撲了個空。"]},
		"default": {"deal": 0.3, "take": 1.0, "hit": true, "text": ["你撲上去想抱住{name}，{pron}的攻擊先落在你身上。"]},
		"vs": {
			"thrust": {"text_mid": ["{weapon}從你肋邊擦過去，你已經貼在{name}身上，雙臂一箍，把{pron}摔在地上。"], "deal": 0.4, "take": 0.4, "effect": "trip", "good": true, "text": [
				"{weapon}刺過來，你不躲，迎著它撲上去。{weapon}擦破你的腰，你已經抱住{name}，一扭身把{pron}摔倒在地。",
			]},
			"guard": {"deal": 0.3, "effect": "break", "good": true, "text": [
				"{name}縮在{guard}後面，你連人帶{guard}一起抱住，往旁邊一摔。{guard}脫了手。",
			]},
			"sweep": {"deal": 0.3, "take": 0.8, "effect": "trip", "text": ["{weapon}掃在你背上，你還是抱住了{name}，兩個人一起滾倒在地上。"]},
			"smash": {"take": 1.2, "hit": true, "text": ["你撲上去，正好迎上砸下來的{weapon}。"]},
		},
	},
	"fb_whirl": {
		"name": "巨熊破陣", "grade": 3, "school": "frostbear", "weapons": ["axe", "blade"], "stat": "str",
		"desc": "腰一扭，斧頭跟著身子轉，左一下右一下連著劈。擋得了這下擋不了下一下，對方的防守也頂不住。轉完腳下是空的。",
		"act": {"type": "sweep", "power": 1.5, "armed": true,
			"tell": ["{name}腰一扭，{weapon}跟著整個人轉了過來，左一下，右一下。", "{name}掄起{weapon}原地一旋，刃口連著掃過來。"],
			"hit": ["你擋住了第一下，第二下砍進了你的大腿。", "刃口從你肋下拖過去，你被帶得轉了半圈。"]},
		"self": "off_balance",
		"default": {"deal": 1.5, "take": 1.0, "hit": true, "text": [
			"你掄起{my}連轉兩圈，刃口一下接一下劈在{name}身上，{pron}的攻擊也落在你身上。",
		]},
		"vs": {
			"guard": {"text_mid": ["{name}擋住了第一下，第二下從{guard}的邊上繞了進去，第三下把{guard}整個掃開。"], "deal": 1.1, "effect": "break", "good": true, "text": [
				"你掄著{my}一圈接一圈劈在{guard}上，第三下終於把{guard}打歪，{name}的身子露了出來。",
			]},
			"opening": {"deal": 2.4, "good": true, "text": [
				"{name}還沒站穩，你的{my}轉著劈過去，一下、兩下，{pron}身上多了兩道深口子。",
			]},
			"windup": {"deal": 1.8, "text": ["{name}還在蓄力，你的{my}已經轉著劈到了{pron}身上。"]},
		},
	},
	"fb_hook": {
		"name": "斷柄", "grade": 3, "school": "frostbear", "weapons": ["axe"], "stat": "str",
		"desc": "用斧頭的鉤勾住對方的兵器，往回一扯，把兵器從他手裡扯下來。對野獸沒用，太重的兵器也扯不動。",
		"act": {"type": "trick", "power": 0.4, "on_hit": "off_balance", "armed": true,
			"tell": ["{name}的斧鉤勾上你的劍，往回一扯。", "{name}斧頭一翻，用鉤子去找你的劍。"],
			"hit": ["你的劍被扯得往前一帶，人跟著栽了半步。", "你的手腕被扯得一扭，劍差點脫手。"]},
		"fail": {"take": 1.0, "hit": true, "text": ["你的斧鉤去勾{name}的{weapon}，勾了個空。"]},
		"default": {"text": ["你斧鉤朝前，等著{name}的兵器過來，{pron}卻沒揮過來。"]},
		"vs": {
			"sweep": {"take": 0.5, "effect": "disarm", "good": true, "requires": "disarmable", "text": [
				"{weapon}掃過來，你的斧鉤正好勾住它，往回一扯，{weapon}從{name}手裡飛了出去。",
			], "else": {"take": 1.0, "hit": true, "text": ["你勾住了{name}的兵器，扯不動。"]}},
			"smash": {"take": 0.6, "effect": "disarm", "good": true, "requires": "disarmable", "text": [
				"{weapon}砸下來，你側身讓開，斧鉤順勢勾住它往下一扯，{name}兩手一空。",
			], "else": {"take": 1.0, "hit": true, "text": ["你勾住了{name}的兵器，扯不動。"]}},
			"thrust": {"take": 0.8, "text": ["{weapon}又快又直，你的斧鉤勾不住。"]},
			"grab": {"take": 1.0, "hit": true, "text": ["你盯著{name}的兵器，{pron}卻直接撲上來抓你。"]},
		},
	},
	"fb_execute": {
		"name": "斷肢處刑", "grade": 4, "school": "frostbear", "weapons": ["axe", "blade"], "stat": "str",
		"desc": "對方露出大破綻的時候才用得出來：一斧斬在手臂或腿上，斬得很深。",
		"when": "opening",
		"act": {"type": "smash", "power": 2.2, "armed": true, "cond": "foe_open",
			"tell": ["{name}看你站不穩了，{weapon}從側面掄過來，對準你的膝蓋。", "{name}不急，{weapon}慢慢舉起來，盯著你的手臂。"],
			"hit": ["刃口斬在你的大腿上，你的腿一下子沒了力氣。", "你的手臂被斬中，劍掉在地上，你又撿了起來。"]},
		"pierce": true,
		"default": {"deal": 3.2, "text": [
			"{name}還沒站穩，你的{my}斬在{pron}的膝蓋上。{pron}整個人矮了一截。",
			"你的{my}斬在{name}持兵器的手臂上，斬得很深。",
		]},
		"vs": {},
	},
	"fb_fury": {
		"name": "凜冬狂怒", "grade": 5, "school": "frostbear", "weapons": ["axe", "blade"], "stat": "str",
		"desc": "霜熊戰團的絕學。血流到快撐不住的時候才用得出來：不管挨多少刀，斧頭只往前劈。數值輸對手也照樣痛。",
		"ult": true, "when": "low_hp", "no_weak": true,
		"act": {"type": "sweep", "power": 2.0, "armed": true, "cond": "low_hp",
			"tell": ["{name}渾身是血，忽然笑了起來，{weapon}掄圓了朝你劈過來，一下也不停。"],
			"hit": ["你擋了兩下，第三下劈開了你的防守，砍進你的肩膀。"]},
		"pre": [
			"你身上的血已經流得差不多了。你笑了一聲。",
			"痛的感覺忽然不見了。",
		],
		"default": {"deal": 2.8, "take": 1.0, "hit": true, "text": [
			"你不躲不擋，{my}一下接一下往{name}身上劈。{pron}的攻擊落在你身上，你也不管。",
			"你迎著{name}劈過去，挨了一下，再劈一下。{pron}先退了。",
		]},
		"vs": {},
	},

	# ---------- 傳說的招（秘笈在有名的人身上） ----------
	# ult：喊出招名，有專屬的寫法。對手拿兵器擋也擋不到（見 Battle「先吃虧」），守夜人也架不開
	# when：什麼時候才出得來（見 Battle.ult_ready）
	#   opening 對手露出大破綻；closed 對手縮在防守後面或正在蓄力；heavy 對手蓄好的重招正砸下來；low_hp 自己快撐不住
	# pre：起手（之後喊出招名，再寫結果）
	# no_weak：數值輸對手也不會變弱（破綻就是破綻）
	"lh_verdict": {
		"name": "王權裁定", "grade": 5, "school": "lionheart", "weapons": ["sword", "greatsword"], "stat": "str",
		"desc": "獅心劍庭的絕學。對手露出大破綻時才用得出來：盾撞破他的重心，劍同時從下往上貫穿喉嚨。攻和守在同一刻完成。",
		"ult": true, "when": "opening", "pierce": true, "no_weak": true,
		"act": {"type": "smash", "power": 2.4, "armed": true, "cond": "foe_open",
			"tell": ["你腳下還沒站穩，{name}的盾已經撞了上來。"],
			"hit": ["盾撞在你胸口，你重心一歪，{name}的劍已經從下往上到了你的喉前，你只來得及偏開一寸。"]},
		"pre": [
			"{name}的重心歪了。你沒有猶豫。",
			"你等的就是這一下。",
		],
		"default": {"deal": 4.0, "text": [
			"你的盾撞上{name}的胸口，{pron}往後一仰，你的劍同時從下往上送進{pron}的喉下。",
			"盾和劍在同一刻到。{name}被撞得雙腳離地，劍尖已經在{pron}領口裡了。",
		]},
		"vs": {},
	},
	"leg_rain": {
		"name": "針雨", "grade": 4, "school": "", "weapons": ["rapier"], "stat": "agi",
		"desc": "南方決鬥家傳下來的細劍絕技。對手縮在防守後面、或正在蓄力時才用得出來：劍尖連抖，七八下刺擊幾乎同時到，盾和兵器只擋得住一兩下。刺中蓄力的人，那一下就使不出來了。",
		"ult": true, "when": "closed",
		"act": {"type": "thrust", "power": 1.7, "armed": true,
			"tell": ["{name}的劍尖連抖，七八下刺擊幾乎同時朝你來。"],
			"hit": ["你擋住了兩下，其餘的都刺在你身上，一個個小洞往外冒血。"]},
		"pre": [
			"你的手腕放鬆，劍尖開始抖。",
			"你的腳尖往前一滑，身子壓得很低。",
		],
		"default": {"deal": 2.4, "text": [
			"劍尖一下接一下從{guard}的邊上鑽進去，{name}擋住了第一下，後面幾下全落在{pron}身上。",
			"{name}只看到劍尖晃了一下，身上已經多了五六個小洞。",
		]},
		"vs": {
			"windup": {"deal": 2.4, "effect": "interrupt", "text": [
				"{name}的力還沒蓄滿，你的劍尖已經連著刺進{pron}的手臂。{pron}這一下使不出來了。",
			]},
		},
	},
	"leg_siege": {
		"name": "崩城", "grade": 5, "school": "", "weapons": ["hammer"], "stat": "str",
		"desc": "守城人的戰錘絕技。對手蓄好的重招砸下來的那一刻才用得出來：用錘柄硬接住，借那股力一錘砸回去。",
		"ult": true, "when": "heavy",
		"act": {"type": "smash", "power": 2.6, "windup": true, "armed": true,
			"tell": ["{name}把戰錘往後一拉，整個人像一張拉滿的弓。"],
			"strike_tell": ["戰錘砸下來了！"],
			"hit": ["戰錘砸在你身上，你眼前一黑，什麼都聽不見了。"]},
		"pre": [
			"你不退。",
			"你雙腳一前一後釘在地上，錘柄橫在頭頂。",
		],
		"default": {"deal": 2.8, "take": 0.0, "text": [
			"你用錘柄接住這一下，膝蓋沉了一寸，沒有退。{name}的力道還壓在上面，你順著一推一轉，錘頭砸在{pron}身上。",
			"{weapon}砸在你架起的錘柄上，火星四濺。你借著這股力往下一帶，{name}收不住，你的錘已經掄了回去。",
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


## 拿著這把武器用得出這招嗎（weapons 空的 = 什麼都行）
static func usable(move_id: String, weapon_id: String) -> bool:
	var kinds: Array = MOVES[move_id].get("weapons", [])
	return kinds.is_empty() or kinds.has(WeaponData.get_def(weapon_id)["kind"])


## 招名的說法：「斷膝」
static func call_name(move_id: String) -> String:
	return "「%s」" % MOVES[move_id]["name"]


static func grade(move_id: String) -> int:
	return MOVES[move_id].get("grade", 0)


static func color(move_id: String) -> String:
	return GrowthData.GRADE_COLORS[grade(move_id)]


## 哪一派的招（空的是通用招）
static func school(move_id: String) -> String:
	return MOVES[move_id].get("school", "")
