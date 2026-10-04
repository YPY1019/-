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
##   good  true = 這招剋這種類型。抽招時比較容易抽到（高手見招拆招）
## vs_big：對體型大的對手用的版本。
## self：用完之後自己的狀態（off_balance：下回合少想到一招）。

const BASIC := ["attack", "defend", "dodge", "flee"]
## 被抱住時能用的招（沒學的不會出現）
const HELD := ["struggle", "attack", "break_free", "vital"]
const LEARNABLE := ["sweep_kick", "parry", "redirect", "heavy", "vital", "disarm", "break_free", "sand", "shout", "combo"]

const MOVES := {
	# ---------- 基本招（不用學） ----------
	"attack": {
		"name": "攻擊", "desc": "普通的一劍。對方防守時砍不進去，對方露出破綻時特別痛。",
		"default": {"deal": 1.0, "take": 1.0, "hit": true, "text": ["你揮劍砍向{name}。", "你一劍劈向{name}的肩膀。", "你橫劍掃過{name}的身側。"]},
		"vs": {
			"guard": {"deal": 0.2, "text": ["你一劍砍在{guard}上，砍不進去。", "劍砍在{guard}上，震得你手發麻。"]},
			"opening": {"deal": 1.5, "text": ["你抓住空檔，狠狠砍了一劍。", "你趁機一劍砍中{name}。"]},
			"windup": {"deal": 1.2, "text": ["趁{name}還在蓄勢，你一劍砍了進去！"]},
			"hold": {"deal": 0.5, "take": 1.0, "hit": true, "text": ["你被緊緊勒住，只能用劍柄胡亂往{name}身上砸。"]},
		},
	},
	"defend": {
		"name": "防禦", "desc": "用劍擋住攻擊，會受一點傷，擋住後能順手回砍。擋不住擒抱、撒沙和吼聲。",
		"default": {"text": ["你擺好架勢等著，{name}沒有出手。", "你舉劍護住身前，什麼也沒擋到。"]},
		"vs": {
			"sweep": {"deal": 0.4, "take": 0.6, "text": ["你舉劍擋住{weapon}，手臂被震得發麻，順手回砍一劍。", "{weapon}重重撞在你的劍上，你咬牙撐住，回手就是一劍。"]},
			"thrust": {"deal": 0.4, "take": 0.5, "text": ["你用劍身擋偏{weapon}，只被擦到一下，順手回砍一劍。", "你把{weapon}擋到一邊，趁機回了一劍。"]},
			"smash": {"take": 0.8, "text": ["你舉劍硬接，整個人被{weapon}砸得跪了下去。", "你架劍去擋，{weapon}壓得你雙腿發抖。"]},
			"grab": {"take": 1.0, "hit": true, "text": ["你舉劍去擋，{name}卻直接撲上來。"]},
			"trick": {"take": 1.0, "hit": true, "text": ["你舉劍護身，可是那不是衝著劍來的。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你舉劍護身，可是吼聲擋不住。"]},
		},
	},
	"dodge": {
		"name": "閃避", "desc": "躲開攻擊，不會受傷。但躲完腳步亂了：下回合不能再閃避，也少想到一招。躲不掉吼聲。",
		"self": "off_balance",
		"default": {"take": 0.0, "text": ["你往後一跳，躲開了{name}的攻擊。", "你側身一閃，{name}撲了個空。"]},
		"vs": {
			"sweep": {"take": 0.0, "text": ["你往後一跳，{weapon}從你胸前掃過。", "你縮身後躍，{weapon}只掃到空氣。"]},
			"smash": {"take": 0.0, "text": ["你往旁邊一滾，{weapon}砸在你剛剛站的地方。", "你撲到一邊，背後傳來{weapon}砸地的巨響。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你往後跳開，可是吼聲躲不掉。"]},
			"guard": {"text": ["你往後跳開，什麼也沒躲到。"]},
			"opening": {"text": ["你往後跳開，白白錯過了機會。"]},
			"windup": {"text": ["你往後跳開，什麼也沒躲到。"]},
		},
	},
	"flee": {
		"name": "撤退", "desc": "轉身逃走。這回合對方攻擊的話會挨打。",
		"default": {"take": 1.0, "hit": true, "text": ["你轉身就跑。"]},
		"vs": {},
	},
	"struggle": {
		"name": "掙扎", "desc": "被抱住時拼命掙扎，有一半機會掙脫。",
		"default": {"take": 1.0, "hit": true, "text": ["你拼命掙扎。"]},
		"vs": {},
	},

	# ---------- 要學的招 ----------
	"sweep_kick": {
		"name": "掃腿", "desc": "對付橫掃：蹲低從底下鑽過，順勢把對方掃倒。體型大的掃不倒。",
		"default": {"deal": 0.5, "take": 1.0, "hit": true, "text": ["你蹲低身子去掃腿，可是{name}不是橫掃過來的。"]},
		"vs": {
			"sweep": {"deal": 0.5, "take": 0.0, "effect": "trip", "good": true, "text": ["你蹲低身子，{weapon}從你頭頂掃過。你一腳掃向{name}的腳！", "你矮身鑽過{weapon}，一腳狠狠掃在{name}的腳踝上！"]},
			"smash": {"deal": 0.5, "take": 1.2, "text": ["你蹲低身子去掃腿，正好迎上從頭頂落下的{weapon}。"]},
			"guard": {"deal": 0.3, "text": ["你一腳掃向{name}的腳，{name}站得很穩。"]},
			"opening": {"deal": 0.8, "text": ["你一腳踢在{name}的腳上。"]},
			"windup": {"deal": 0.5, "text": ["你一腳踢在{name}的腳上，{name}晃了晃，還是穩住了。"]},
		},
		"vs_big": {
			"sweep": {"deal": 0.3, "take": 0.5, "text": ["你蹲低身子，{weapon}還是擦過你的背。你一腳掃向{name}的腳——像踢到樹幹，晃都沒晃。"]},
		},
	},
	"parry": {
		"name": "撥擋反擊", "desc": "對付直刺和撲咬：把攻擊撥開，同時刺回去。還是會被擦到一下。",
		"default": {"text": ["{name}沒有衝過來，你沒東西可撥。"]},
		"vs": {
			"thrust": {"deal": 1.2, "take": 0.3, "good": true, "text": ["你看準{weapon}，用劍一撥，順勢刺了回去！", "你的劍貼著{weapon}一轉，把它帶偏，劍尖直接送了回去！"]},
			"sweep": {"take": 0.8, "text": ["你想撥開{weapon}，可是力道太大，撥不動。"]},
			"smash": {"take": 1.0, "text": ["你想撥開從頭頂落下的{weapon}，被硬生生壓了下來。"]},
			"grab": {"take": 1.0, "hit": true, "text": ["你想撥開{name}，可是牠是整個撲上來的。"]},
			"trick": {"take": 1.0, "hit": true, "text": ["你出劍去撥，可是那不是刀。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你架好劍，可是吼聲撥不開。"]},
		},
	},
	"redirect": {
		"name": "卸力", "desc": "對付重砸：順著力道把攻擊引開，讓對方收勢不住、往前踉蹌。",
		"default": {"text": ["你擺出卸力的架勢，{name}卻沒有砸下來。"]},
		"vs": {
			"smash": {"take": 0.2, "effect": "stagger", "good": true, "text": ["你順著{weapon}的力道一帶，把它引到一旁，{name}收勢不住，往前踉蹌。", "你用劍身輕輕一引，{weapon}擦著你砸進地裡，{name}整個人跟著撲了過來。"]},
			"sweep": {"take": 0.5, "text": ["你順著{weapon}的力道一帶，卸掉了一半力道。"]},
			"thrust": {"take": 0.6, "text": ["你想卸開{weapon}，可是它太快了，只卸掉一點。"]},
			"grab": {"take": 1.0, "hit": true, "text": ["你想卸開{name}的力道，可是牠是整個撲上來的。"]},
			"trick": {"take": 1.0, "hit": true, "text": ["你擺出卸力的架勢，可是那不是攻擊。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你擺出卸力的架勢，可是吼聲卸不掉。"]},
		},
	},
	"heavy": {
		"name": "重擊", "desc": "雙手全力一擊，盔甲盾牌都擋不住，能打破防守、打斷蓄勢。出手時破綻大，這回合被打會更痛。",
		"pierce": true,
		"default": {"deal": 2.0, "take": 1.5, "hit": true, "text": ["你雙手舉劍，全力劈向{name}！", "你大喝一聲，一劍重重劈下！"]},
		"vs": {
			"guard": {"deal": 1.5, "effect": "break", "good": true, "text": ["你雙手舉劍全力劈下，連人帶{guard}打得{name}退了好幾步！"]},
			"windup": {"deal": 2.0, "effect": "interrupt", "good": true, "text": ["趁{name}還在蓄勢，你全力一劍劈了上去，硬是把牠的動作打斷！"]},
			"opening": {"deal": 2.5, "good": true, "text": ["你雙手舉劍，全力劈在{name}身上！"]},
		},
		"vs_big": {
			"windup": {"deal": 2.0, "text": ["你全力一劍劈在{name}身上，可是牠的動作連停都沒停！"]},
		},
	},
	"vital": {
		"name": "要害刺", "desc": "刺向要害或盔甲縫隙，盔甲擋不住。對方露出破綻、蓄勢、或抱住你時威力最大。",
		"pierce": true,
		"default": {"deal": 0.7, "take": 1.0, "hit": true, "text": ["你刺向{name}的要害，可是對方一直在動，只刺到邊。"]},
		"vs": {
			"opening": {"deal": 3.0, "good": true, "text": ["你看準破綻，一劍刺進{name}的要害！", "你貼上去，劍尖從縫隙裡深深刺了進去！"]},
			"windup": {"deal": 2.0, "good": true, "text": ["{name}舉起雙手，腋下全空了。你一劍刺了進去！"]},
			"smash": {"deal": 1.5, "take": 1.0, "hit": true, "text": ["{name}高舉雙手砸下來的瞬間，你一劍刺向牠的腋下！"]},
			"guard": {"deal": 0.0, "text": ["你刺向{name}的要害，被{guard}擋住了。"]},
			"hold": {"deal": 2.0, "take": 0.5, "effect": "escape", "good": true, "text": ["被抱住時你們貼得最近。你一劍刺進{name}的要害，{name}吃痛鬆開了你！"]},
		},
	},
	"disarm": {
		"name": "繳械", "desc": "對付拿武器的對手：在對方揮過來的瞬間把武器打飛。對野獸沒用，太重的武器也絞不動。",
		"default": {"text": ["你盯著{weapon}，可是{name}沒有揮過來。"]},
		"vs": {
			"sweep": {"take": 0.5, "effect": "disarm", "good": true, "requires": "disarmable", "text": ["你看準{weapon}揮來的瞬間，劍身一絞，把{weapon}打飛了出去！"],
				"else": {"take": 1.0, "hit": true, "text": ["你想打掉{name}的武器，可是根本絞不動。"]}},
			"thrust": {"take": 0.5, "effect": "disarm", "good": true, "requires": "disarmable", "text": ["你一劍壓住刺來的{weapon}，順勢一挑，{weapon}脫手飛了出去！"],
				"else": {"take": 1.0, "hit": true, "text": ["你想打掉{name}的武器，可是根本絞不動。"]}},
			"smash": {"take": 1.0, "hit": true, "text": ["從頭頂砸下來的力道太大，你絞不動。"]},
			"grab": {"take": 1.0, "hit": true, "text": ["你想打掉{name}的武器，牠卻直接撲上來抱住你。"]},
			"trick": {"take": 1.0, "hit": true, "text": ["你盯著{name}的武器，沒注意牠的另一隻手。"]},
			"roar": {"take": 1.0, "hit": true, "text": ["你盯著{name}，吼聲震得你耳朵發疼。"]},
		},
	},
	"break_free": {
		"name": "掙脫", "desc": "對付擒抱：在被抱住前鑽出去，或被抱住時掙開，順手回一劍。",
		"default": {"take": 1.0, "hit": true, "text": ["你擺出掙脫的架勢，可是{name}沒有要抓你。"]},
		"vs": {
			"grab": {"deal": 0.5, "take": 0.0, "good": true, "text": ["{name}撲上來的瞬間，你一矮身從牠手臂下鑽了出去，順手一劍。"]},
			"hold": {"deal": 0.5, "take": 0.3, "effect": "escape", "good": true, "text": ["你手肘往後一撞，扭身掙開了{name}，順手一劍。"]},
			"guard": {"text": ["你擺出掙脫的架勢，{name}只是步步逼近。"]},
			"opening": {"text": ["你擺出掙脫的架勢，白白錯過了機會。"]},
			"windup": {"text": ["你擺出掙脫的架勢，{name}還在蓄勢。"]},
		},
	},
	"sand": {
		"name": "擲沙", "desc": "抓一把沙撒向對方的眼睛。對方下一次攻擊很可能打偏。這回合自己不會躲。",
		"default": {"effect": "blind", "take": 1.0, "hit": true, "text": ["你抓起一把沙，往{name}臉上撒去！"]},
		"vs": {
			"guard": {"effect": "blind", "text": ["你抓起一把沙，從{guard}旁邊撒進{name}的眼睛！"]},
			"opening": {"effect": "blind", "text": ["你趁機抓起一把沙，撒進{name}的眼睛。"]},
			"windup": {"effect": "blind", "good": true, "text": ["趁{name}還在蓄勢，你抓起一把沙撒進牠的眼睛！"]},
		},
	},
	"shout": {
		"name": "怒喝", "desc": "對野獸大喝一聲，把牠嚇得退縮。也能壓過對方的吼聲。對人沒什麼用。",
		"default": {"take": 1.0, "hit": true, "effect": "scare", "requires": "beast", "text": ["你大喝一聲！{name}嚇得一縮。"],
			"else": {"take": 1.0, "hit": true, "text": ["你大喝一聲，{name}根本不吃這一套。"]}},
		"vs": {
			"roar": {"take": 0.0, "effect": "scare", "good": true, "requires": "beast", "text": ["你一聲大喝，硬是蓋過了{name}的吼聲！{name}愣了一下。"],
				"else": {"take": 0.0, "text": ["你一聲大喝，蓋過了{name}的吼聲。"]}},
			"sweep": {"take": 0.6, "effect": "scare", "good": true, "requires": "beast", "text": ["你迎著{name}大喝一聲，{name}嚇得收了一半力。"],
				"else": {"take": 1.0, "hit": true, "text": ["你大喝一聲，{name}根本不吃這一套。"]}},
			"thrust": {"take": 0.6, "effect": "scare", "good": true, "requires": "beast", "text": ["你迎著{name}大喝一聲，{name}撲到一半縮了回去。"],
				"else": {"take": 1.0, "hit": true, "text": ["你大喝一聲，{name}根本不吃這一套。"]}},
			"guard": {"text": ["你大喝一聲，{name}躲在{guard}後面不為所動。"]},
			# 只有對方出手時嚇得到，不能一直喝住牠
			"opening": {"text": ["你大喝一聲，{name}瞪著你，沒有退。"]},
			"windup": {"text": ["你大喝一聲，{name}正專心蓄勢，沒理你。"]},
		},
	},
	"combo": {
		"name": "連環斬", "desc": "一口氣連砍三劍。對方露出破綻時最痛，但砍不穿厚甲。",
		"default": {"deal": 1.2, "take": 1.0, "hit": true, "text": ["你一連砍出三劍，{name}也同時出手。"]},
		"vs": {
			"opening": {"deal": 2.2, "good": true, "text": ["你抓住空檔，一連三劍砍在{name}身上！", "你的劍連成一片，一劍接一劍砍了下去！"]},
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
