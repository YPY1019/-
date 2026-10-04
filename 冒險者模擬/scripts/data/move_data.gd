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
## stat：這招靠哪個基礎數值（str 力量、agi 敏捷、con 體魄）。決定打多痛，用了也會練到這個數值。
## text 每次隨機挑一句。{name} 對手、{pron} 他／牠、{weapon} 對手的武器、{guard} 對手的防具。

## 人人都會的一般招。跟學來的招放在同一個池子裡，不是永遠都在
const BASIC := ["attack", "defend", "dodge"]
## 每回合的選項至少有一個攻擊類、一個防守類（擲沙、怒喝不算這兩類）
const OFFENSE := ["attack", "heavy", "vital", "combo"]
const DEFENSE := ["defend", "dodge", "sweep_kick", "parry", "redirect", "disarm", "break_free"]
## 撤退不是招式，永遠可以選（被抱住時不行）
const FLEE := "flee"
## 被抱住時能用的招（沒學的不會出現）
const HELD := ["struggle", "attack", "break_free", "vital"]
const LEARNABLE := ["sweep_kick", "parry", "redirect", "heavy", "vital", "disarm", "break_free", "sand", "shout", "combo"]

## 你受傷後的反應（依傷勢挑一句）
const HURT := {
	"light": ["你咬緊牙關，沒有退。", "你悶哼一聲，把劍握得更緊。", "傷口火辣辣地痛，你甩了甩頭。"],
	"heavy": ["你眼前一陣發黑，差點站不穩。", "痛楚像火一樣燒遍全身，你踉蹌著退了一步。", "你吐出一口血沫，硬是撐住了。"],
	"critical": ["你的視線開始模糊，手裡的劍越來越重。", "你感覺力氣正從傷口一點一點流走。", "你的腿在發抖，每一次呼吸都帶著血腥味。"],
}

const MOVES := {
	# ---------- 一般招（不用學） ----------
	"attack": {
		"name": "攻擊", "stat": "str", "desc": "普通的一劍，出手快。對方橫掃或直刺時搶先砍到，對方的攻擊會被打歪一點。對方防守時砍不進去。",
		"default": {"deal": 1.0, "take": 1.0, "hit": true, "text": [
			"你不躲不閃，迎上去一劍砍向{name}。",
			"你踏前一步，一劍劈向{name}的肩膀，同時也把自己送進了對方的攻擊裡。",
			"你咬牙橫劍一掃，劍鋒從{name}身側劃過。",
		]},
		"vs": {
			# 出手快：對方出快攻時搶先砍到，對方的攻擊被打歪一點
			"sweep": {"deal": 1.0, "take": 0.7, "hit": true, "text": [
				"你搶在{weapon}掃過來之前，一劍先砍在{name}身上，{pron}的攻擊被你打得歪了一點。",
				"你不等{name}掃過來，搶先一步出劍，劍鋒先到，{pron}的力道洩了一半。",
			]},
			"thrust": {"deal": 1.0, "take": 0.7, "hit": true, "text": [
				"你搶先一步，劍尖先一步碰到{name}，{pron}衝過來的勢子頓了一下。",
				"{name}還沒衝到，你的劍已經先砍了過去，{pron}的攻擊偏了幾分。",
			]},
			"guard": {"deal": 0.2, "text": [
				"你一劍砍在{guard}上，「鏘」的一聲，震得你虎口發麻。",
				"你連砍兩劍，全被{guard}擋了下來，連個缺口都沒砍出來。",
			]},
			"opening": {"deal": 1.5, "text": [
				"你抓住空檔撲上去，一劍狠狠砍在{name}身上。",
				"{name}還沒回過神，你的劍已經砍進了{pron}的肩頭。",
			]},
			"windup": {"deal": 1.2, "text": [
				"趁{name}還在蓄勢，你搶上前去，一劍砍進{pron}露出來的空門！",
			]},
			"hold": {"deal": 0.5, "take": 1.0, "hit": true, "text": [
				"你被緊緊勒住，只能用劍柄胡亂往{name}身上砸。",
				"你的手臂被箍住，只能反手用劍尖往{name}身上亂戳。",
			]},
		},
	},
	"defend": {
		"name": "防禦", "stat": "con", "desc": "用劍擋住攻擊，會受一點傷，擋住後能順手回砍。擋不住擒抱、撒沙和吼聲。",
		"default": {"text": [
			"你擺好架勢等著，{name}卻沒有出手，你們隔著幾步互相瞪視。",
			"你舉劍護住身前，劍尖微微發抖，什麼也沒擋到。",
		]},
		"vs": {
			"sweep": {"deal": 0.4, "take": 0.4, "text": [
				"你舉劍硬擋，{weapon}重重撞在劍身上，震得你手臂發麻；你借著反震的力道，順手回砍一劍。",
				"「鏘」的一聲，{weapon}撞在你的劍上，你腳下滑了半步，咬牙撐住，回手就是一劍。",
			]},
			"thrust": {"deal": 0.4, "take": 0.3, "text": [
				"你用劍身一格，{weapon}偏了開去，只在你身上擦出一道血痕；你趁勢回了一劍。",
				"你及時把{weapon}擋到一邊，衣服被劃破了，你順手往{name}身上削了一劍。",
			]},
			"smash": {"take": 0.6, "text": [
				"你舉劍硬接，{weapon}砸下來的力道大得嚇人，你整個人被壓得跪了下去，雙臂快要斷了。",
				"你架劍去擋，{weapon}壓得你雙腿發抖，劍身被砸得彎了一下。",
			]},
			"grab": {"take": 1.0, "hit": true, "text": ["你舉劍去擋，{name}卻根本不理你的劍，直接撲了上來。"]},
			"trick": {"take": 1.0, "hit": true, "text": ["你舉劍護身，可是對方根本不是衝著你的劍來的。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你舉劍護在身前，可是聲音是擋不住的。"]},
		},
	},
	"dodge": {
		"name": "閃避", "stat": "agi", "desc": "躲開攻擊，不會受傷。但躲完腳步亂了：下回合不能再閃避，選項也少一個。躲不掉吼聲。",
		"self": "off_balance",
		"default": {"take": 0.0, "text": [
			"你往後一跳，險險躲開了{name}，落地時腳下一滑。",
			"你側身一閃，{name}撲了個空，你自己也差點摔倒。",
		]},
		"vs": {
			"sweep": {"take": 0.0, "text": [
				"你猛地往後一仰，{weapon}貼著你的胸口掃過去，帶起的風颳得你臉頰發痛。",
				"你縮身後躍，{weapon}只掃到空氣，你踉蹌了好幾步才站穩。",
			]},
			"smash": {"take": 0.0, "text": [
				"你往旁邊一滾，{weapon}砸在你剛剛站的地方，碎石濺了你一身。",
				"你撲到一邊，背後傳來{weapon}砸地的巨響，震得你耳朵嗡嗡作響。",
			]},
			"roar": {"take": 1.0, "hit": true, "text": ["你往後跳開，可是吼聲追著你灌進耳朵裡。"]},
			"guard": {"text": ["你往後跳開，{name}只是穩穩地逼近，什麼也沒躲到。"]},
			"opening": {"text": ["你往後跳開，白白錯過了大好的機會。"]},
			"windup": {"text": ["你往後跳開拉開距離，{name}還在蓄勢，什麼也沒躲到。"]},
		},
	},
	"flee": {
		"name": "撤退", "desc": "轉身逃走。這回合對方攻擊的話會挨打。",
		"default": {"take": 1.0, "hit": true, "text": ["你轉身就跑。", "你虛晃一劍，轉身拔腿就跑。"]},
		"vs": {},
	},
	"struggle": {
		"name": "掙扎", "stat": "str", "desc": "被抱住時拼命掙扎，有一半機會掙脫。",
		"default": {"take": 1.0, "hit": true, "text": ["你拼命掙扎。"]},
		"vs": {},
	},

	# ---------- 要學的招 ----------
	"sweep_kick": {
		"name": "低身斬", "stat": "agi", "desc": "對付橫掃：蹲低從底下鑽過，順勢斬對方的腳，把人斬倒。體型大的斬不倒。",
		"default": {"deal": 0.5, "take": 1.0, "hit": true, "text": [
			"你壓低身子一劍斬向{name}的腳，可是對方根本不是橫掃過來的，你整個人暴露在攻擊底下。",
		]},
		"vs": {
			"sweep": {"deal": 0.5, "take": 0.0, "effect": "trip", "good": true, "text": [
				"你猛地矮身，{weapon}從你頭頂呼地掃過，削斷了幾根頭髮；你順勢貼地一劍，斬在{name}的腳踝上！",
				"你蹲得幾乎貼地，{weapon}從上方掠過。你一劍橫斬{name}的小腿，{pron}整個人往前栽倒。",
			]},
			"smash": {"deal": 0.5, "take": 1.2, "text": ["你壓低身子去斬{name}的腳，正好把頭頂送到落下的{weapon}底下。"]},
			"guard": {"deal": 0.3, "text": ["你一劍斬向{name}的腳，{name}把{guard}往下一壓，擋得紋風不動。"]},
			"opening": {"deal": 0.8, "text": ["你一劍斬在{name}的腿上，{pron}哼了一聲。"]},
			"windup": {"deal": 0.5, "text": ["你一劍斬在{name}的腳上，{name}晃了晃，還是穩住了架勢。"]},
		},
		"vs_big": {
			"sweep": {"deal": 0.3, "take": 0.5, "text": [
				"你蹲低身子，{weapon}還是擦過你的背，火辣辣地痛。你一劍斬在{name}的腿上——像砍在老樹根上，{pron}晃都沒晃。",
			]},
		},
	},
	"parry": {
		"name": "迎擊", "stat": "agi", "desc": "對付直刺和撲咬：把攻擊撥開，同時刺回去。還是會被擦到一下。",
		"default": {"text": ["你擺好撥擋的架勢，{name}卻沒有衝過來，你的劍撥了個空。"]},
		"vs": {
			"thrust": {"deal": 1.2, "take": 0.3, "good": true, "text": [
				"你看準{weapon}，劍身貼上去輕輕一撥，對方的力道全落了空；你手腕一翻，劍尖順勢送進了{name}的身體！",
				"{weapon}衝到眼前的一瞬間，你的劍貼著它一轉，把它帶偏，劍尖直接刺了回去。你的手臂被擦破了，但{name}傷得更重。",
			]},
			"sweep": {"take": 0.8, "text": ["你想撥開{weapon}，可是橫掃的力道太大，你的劍被整個盪開，攻擊還是落在你身上。"]},
			"smash": {"take": 1.0, "text": ["你想撥開從頭頂落下的{weapon}，劍一碰上就被硬生生壓了下來。"]},
			"grab": {"take": 1.0, "hit": true, "text": ["你想撥開{name}，可是{pron}是整個身體撲上來的，根本撥不動。"]},
			"trick": {"take": 1.0, "hit": true, "text": ["你出劍去撥，可是來的根本不是兵器。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你架好劍準備撥擋，可是聲音撥不開。"]},
		},
	},
	"redirect": {
		"name": "逆流斬", "stat": "str", "desc": "對付重砸：順著力道把攻擊引開，讓對方收勢不住、往前踉蹌。",
		"default": {"text": ["你擺出卸力的架勢，雙手虛握著劍，{name}卻沒有砸下來。"]},
		"vs": {
			"smash": {"take": 0.2, "effect": "stagger", "good": true, "text": [
				"你不硬接，劍身斜斜一引，順著{weapon}的力道把它帶到一旁。{weapon}擦著你的肩膀砸進地裡，{name}收勢不住，整個人往前撲了過來。",
				"你像推開一扇門一樣，輕輕一帶就把{weapon}引歪了。地面被砸出一個坑，{name}踉蹌著衝過你身邊，背後全空了。",
			]},
			"sweep": {"take": 0.5, "text": ["你順著{weapon}的力道一帶，卸掉了一半力道，剩下的還是打在你身上。"]},
			"thrust": {"take": 0.6, "text": ["你想卸開{weapon}，可是它來得太快太直，只卸掉一點。"]},
			"grab": {"take": 1.0, "hit": true, "text": ["你想卸開{name}的力道，可是{pron}是整個撲上來的。"]},
			"trick": {"take": 1.0, "hit": true, "text": ["你擺出卸力的架勢，可是對方根本沒出力。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你擺出卸力的架勢，可是吼聲卸不掉。"]},
		},
	},
	"heavy": {
		"name": "裂盾斬", "stat": "str", "desc": "雙手全力一擊，盔甲盾牌都擋不住，能打破防守、打斷蓄勢（體型大的打不斷）。出手時破綻大，這回合被打會更痛；用完收招慢，下回合不能閃避、選項少一個。",
		"self": "off_balance",
		"pierce": true,
		"default": {"deal": 1.4, "take": 1.5, "hit": true, "text": [
			"你雙手舉劍，把全身的力氣都壓了上去，一劍重重劈向{name}——同時也把自己的胸口完全敞開。",
			"你大喝一聲，一劍劈下，劍鋒深深砍進{name}的身體，可是對方的攻擊也結結實實落在你身上。",
		]},
		"vs": {
			"guard": {"deal": 1.5, "effect": "break", "good": true, "text": [
				"你雙手舉劍全力劈下，「轟」的一聲，連人帶{guard}把{name}劈得倒退好幾步，{guard}被震到一邊。",
			]},
			"windup": {"deal": 2.0, "effect": "interrupt", "good": true, "text": [
				"趁{name}還在蓄勢，你搶先一步全力劈了上去，硬是把{pron}的動作打斷了！",
			]},
			"opening": {"deal": 2.5, "good": true, "text": [
				"你雙手舉劍，把全身的重量都壓在這一劍上，狠狠劈在{name}身上！",
				"你看準空檔，高高舉起劍，一劍劈下，{name}的慘叫聲在四周迴盪。",
			]},
		},
		"vs_big": {
			"windup": {"deal": 2.0, "text": ["你全力一劍劈在{name}身上，砍出一道深口子——可是{pron}的動作連停都沒停！"]},
		},
	},
	"vital": {
		"name": "穿隙刺", "stat": "agi", "desc": "刺向要害或盔甲縫隙，盔甲擋不住。對方露出破綻、蓄勢、或抱住你時威力最大。",
		"pierce": true,
		"default": {"deal": 0.7, "take": 1.0, "hit": true, "text": [
			"你刺向{name}的要害，可是對方一直在動，劍尖只刺到邊，反而讓自己吃了一記。",
		]},
		"vs": {
			"opening": {"deal": 3.0, "good": true, "text": [
				"你看準破綻，整個人貼上去，一劍刺進{name}的要害，劍身沒入了一半！",
				"你的劍尖從縫隙裡鑽了進去，深深刺入{name}的身體。你拔出劍時，帶出一道血箭。",
			]},
			"windup": {"deal": 2.0, "good": true, "text": [
				"{name}把全身的力氣都蓄在下一擊上，身上的空門全露了出來。你一步搶進去，劍尖狠狠刺了進去！",
			]},
			"smash": {"deal": 1.5, "take": 1.0, "hit": true, "text": [
				"{name}砸下來的瞬間，你不退反進，迎著{pron}刺出一劍——你們同時擊中了對方。",
			]},
			"guard": {"deal": 0.0, "text": ["你刺向{name}的要害，劍尖「叮」的一聲撞在{guard}上，滑了開去。"]},
			"hold": {"deal": 2.0, "take": 0.5, "effect": "escape", "good": true, "text": [
				"被抱住時你們貼得最近。你反手握劍，一劍刺進{name}的要害，{pron}痛得大叫，鬆開了你！",
			]},
		},
	},
	"disarm": {
		"name": "奪刃", "stat": "agi", "desc": "對付拿武器的對手：在對方揮過來的瞬間把武器打飛。對野獸沒用，太重的武器也絞不動。",
		"default": {"text": ["你盯著{weapon}準備出手，可是{name}沒有揮過來。"]},
		"vs": {
			"sweep": {"take": 0.5, "effect": "disarm", "good": true, "requires": "disarmable", "text": [
				"你看準{weapon}揮來的瞬間，劍身貼上去一絞，{name}的手腕一扭，{weapon}脫手飛了出去，「噹啷」一聲落在遠處！",
			], "else": {"take": 1.0, "hit": true, "text": ["你想打掉{name}的武器，可是根本絞不動。"]}},
			"thrust": {"take": 0.5, "effect": "disarm", "good": true, "requires": "disarmable", "text": [
				"你一劍壓住刺來的{weapon}，順勢往上一挑，{weapon}從{name}手裡飛了出去，在空中轉了好幾圈！",
			], "else": {"take": 1.0, "hit": true, "text": ["你想打掉{name}的武器，可是根本絞不動。"]}},
			"smash": {"take": 1.0, "hit": true, "text": ["從頭頂砸下來的力道太大，你的劍一碰上就被壓了下去，根本絞不動。"]},
			"grab": {"take": 1.0, "hit": true, "text": ["你盯著{name}的武器，{pron}卻直接撲上來抓你。"]},
			"trick": {"take": 1.0, "hit": true, "text": ["你盯著{name}的武器，沒注意到{pron}的腳。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你盯著{name}，吼聲震得你耳朵發疼。"]},
		},
	},
	"break_free": {
		"name": "脫鎖", "stat": "str", "desc": "對付擒抱：在被抱住前鑽出去，或被抱住時掙開，順手回一劍。",
		"default": {"take": 1.0, "hit": true, "text": ["你擺出掙脫的架勢，可是{name}根本沒有要抓你。"]},
		"vs": {
			"grab": {"deal": 0.5, "take": 0.0, "good": true, "text": [
				"{name}撲上來的瞬間，你一矮身閃了出去，轉身就是一劍砍在{pron}背上。",
			]},
			"hold": {"deal": 0.5, "take": 0.3, "effect": "escape", "good": true, "text": [
				"你深吸一口氣，手肘狠狠往後一撞，趁對方吃痛的一瞬間扭身掙開，順手一劍。",
				"你用頭往後一頂，正中{name}的臉，{pron}手一鬆，你滾了出來，劍順勢劃過{pron}的身體。",
			]},
			"guard": {"text": ["你擺出掙脫的架勢，{name}只是步步逼近。"]},
			"opening": {"text": ["你擺出掙脫的架勢，白白錯過了機會。"]},
			"windup": {"text": ["你擺出掙脫的架勢，{name}還在蓄勢。"]},
		},
	},
	"sand": {
		"name": "擲沙", "stat": "agi", "desc": "抓一把沙撒向對方的眼睛。對方下一次攻擊很可能打偏。這回合自己不會躲。",
		"default": {"effect": "blind", "take": 1.0, "hit": true, "text": [
			"你彎腰抓起一把沙土，往{name}臉上狠狠撒去！可是你也沒空躲對方的攻擊。",
		]},
		"vs": {
			"guard": {"effect": "blind", "text": ["你抓起一把沙，從{guard}旁邊撒進了{name}的眼睛，{pron}罵了一聲，拼命眨眼。"]},
			"opening": {"effect": "blind", "text": ["你趁機抓起一把沙，撒進{name}的眼睛。"]},
			"windup": {"effect": "blind", "good": true, "text": ["趁{name}還在蓄勢，你抓起一把沙撒進{pron}的眼睛，{pron}一下子什麼都看不見了！"]},
		},
	},
	"shout": {
		"name": "怒喝", "stat": "con", "desc": "對野獸大喝一聲，把牠嚇得退縮。也能壓過對方的吼聲。對人沒什麼用。",
		"default": {"take": 1.0, "hit": true, "effect": "scare", "requires": "beast", "text": [
			"你張開雙臂，用盡全身力氣大喝一聲！{name}嚇得一縮。",
		], "else": {"take": 1.0, "hit": true, "text": ["你大喝一聲，{name}冷笑一聲，根本不吃這一套。"]}},
		"vs": {
			"roar": {"take": 0.0, "effect": "scare", "good": true, "requires": "beast", "text": [
				"你迎著吼聲，一聲大喝硬是蓋了過去！{name}愣住了，耳朵往後一貼。",
			], "else": {"take": 0.0, "text": ["你一聲大喝，蓋過了{name}的吼聲。"]}},
			"sweep": {"take": 0.6, "effect": "scare", "good": true, "requires": "beast", "text": [
				"你迎著{name}大喝一聲，{name}嚇得一縮，攻擊只用了一半的力。",
			], "else": {"take": 1.0, "hit": true, "text": ["你大喝一聲，{name}根本不吃這一套。"]}},
			"thrust": {"take": 0.6, "effect": "scare", "good": true, "requires": "beast", "text": [
				"你迎著{name}大喝一聲，{pron}撲到一半縮了回去，只碰到你一下。",
			], "else": {"take": 1.0, "hit": true, "text": ["你大喝一聲，{name}根本不吃這一套。"]}},
			"guard": {"text": ["你大喝一聲，{name}躲在{guard}後面不為所動。"]},
			# 只有對方出手時嚇得到，不能一直喝住{pron}
			"opening": {"text": ["你大喝一聲，{name}瞪著你，沒有退。"]},
			"windup": {"text": ["你大喝一聲，{name}正專心蓄勢，沒理你。"]},
		},
	},
	"combo": {
		"name": "三連斬", "stat": "str", "desc": "一口氣連砍三劍，每一劍都不重。對方露出破綻時最痛，平常跟普通攻擊差不多，砍不穿厚甲。",
		"default": {"deal": 0.9, "take": 1.0, "hit": true, "text": [
			"你一連砍出三劍，劍光連成一片，可是{name}也同時出手了。",
		]},
		"vs": {
			"opening": {"deal": 2.2, "good": true, "text": [
				"你抓住空檔，劍一劍接一劍落下，三道血口幾乎同時出現在{name}身上！",
				"你的劍快得只剩一片影子，{name}還沒反應過來，已經連中三劍。",
			]},
			"windup": {"deal": 1.8, "text": ["趁{name}還在蓄勢，你一連砍出三劍！"]},
			"guard": {"deal": 0.3, "text": ["你一連三劍砍在{guard}上，叮叮噹噹，一劍也沒砍進去。"]},
		},
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
