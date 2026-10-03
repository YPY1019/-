class_name MoveData
extends RefCounted

## 招式資料。只有資料，沒有規則。
##
## 每個招式對每種敵人動作（intent）有一格結果：
##   deal  : 你打出去的倍率（乘上你的攻擊力）
##   take  : 你挨打的倍率（乘上敵人那一招的傷害）
##   text  : 這一格發生什麼事。{name} 敵人名、{weapon} 敵人武器、{guard} 敵人防具
##   hit   : true = 後面接敵人自己的「打中你」描述
##   effect: trip（掃倒）、guard_broken（破防）、smash_missed（砸空）

## 敵人動作類型的傷害倍率
const INTENT_POWER := {
	"sweep": 1.0,    # 橫掃
	"thrust": 0.8,   # 直衝 / 突刺
	"smash": 1.4,    # 從上面重砸
	"guard": 0.0,    # 防守
	"opening": 0.0,  # 破綻
}

## 位置不好（閃避、掃腿之後）：下回合攻擊打折、挨打更痛
const BAD_POSITION_MULT := 0.5
const BAD_POSITION_TAKE := 1.3

const ORDER := ["attack", "defend", "dodge", "flee", "sweep_kick", "parry", "heavy", "vital"]

const MOVES := {
	"attack": {
		"name": "攻擊",
		"basic": true,
		"desc": "普通的一劍。對方防守時砍不進去。",
		"vs": {
			"sweep": {"deal": 1.0, "take": 1.0, "hit": true, "text": "你揮劍砍向{name}。"},
			"thrust": {"deal": 1.0, "take": 1.0, "hit": true, "text": "你揮劍砍向{name}。"},
			"smash": {"deal": 1.0, "take": 1.0, "hit": true, "text": "你揮劍砍向{name}。"},
			"guard": {"deal": 0.2, "text": "你一劍砍在{guard}上，砍不進去。"},
			"opening": {"deal": 1.5, "text": "你趁機一劍砍中{name}。"},
		},
	},
	"defend": {
		"name": "防禦",
		"basic": true,
		"desc": "用劍擋住攻擊，會受一點傷，但能馬上回砍一劍。",
		"vs": {
			"sweep": {"deal": 0.5, "take": 0.5, "text": "你舉劍擋住{weapon}，手臂被震得發麻，順手回砍一劍。"},
			"thrust": {"deal": 0.5, "take": 0.4, "text": "你用劍身擋偏{weapon}，只被擦到一下，順手回砍一劍。"},
			"smash": {"deal": 0.0, "take": 0.8, "text": "你舉劍硬接，整個人被{weapon}砸得跪了下去。"},
			"guard": {"deal": 0.0, "text": "你擺好架勢等著，{name}也只是步步逼近。"},
			"opening": {"deal": 0.0, "text": "你擺好架勢等著，白白錯過了機會。"},
		},
	},
	"dodge": {
		"name": "閃避",
		"basic": true,
		"desc": "躲開攻擊，不會受傷。但躲完位置不好：下回合攻擊減半、挨打更痛，也躲不乾淨。",
		"bad_position": true,
		# 位置不好時又閃避：只躲掉一半，位置還是不好
		"off_balance": {"deal": 0.0, "take": 0.6, "hit": true, "text": "你腳步還沒站穩，只躲開一半。"},
		"vs": {
			"sweep": {"deal": 0.0, "take": 0.0, "text": "你往後一跳，{weapon}從你胸前掃過。"},
			"thrust": {"deal": 0.0, "take": 0.0, "text": "你往旁邊一閃，{name}從你身邊衝了過去。"},
			"smash": {"deal": 0.0, "take": 0.0, "text": "你往旁邊一滾，{weapon}砸在你剛剛站的地方。"},
			"guard": {"deal": 0.0, "text": "你往後退了幾步。"},
			"opening": {"deal": 0.0, "text": "你往後退了幾步，白白錯過了機會。"},
		},
	},
	"flee": {
		"name": "撤退",
		"basic": true,
		"desc": "轉身逃走。這回合對方攻擊的話會挨打。",
		"vs": {
			"sweep": {"take": 1.0, "hit": true, "text": "你轉身就跑。"},
			"thrust": {"take": 1.0, "hit": true, "text": "你轉身就跑。"},
			"smash": {"take": 1.0, "hit": true, "text": "你轉身就跑。"},
			"guard": {"text": "你轉身就跑。"},
			"opening": {"text": "你轉身就跑。"},
		},
	},
	"sweep_kick": {
		"name": "掃腿",
		"basic": false,
		"desc": "對付從側面橫掃過來的攻擊：蹲低從底下鑽過，順勢把對方掃倒。蹲下去之後位置不好：下回合攻擊減半、挨打更痛。",
		"bad_position": true,
		"vs": {
			"sweep": {"deal": 0.5, "take": 0.0, "effect": "trip", "text": "你蹲低身子，{weapon}從你頭頂掃過。你一腳掃向{name}的腳！"},
			"thrust": {"deal": 0.5, "take": 1.0, "hit": true, "text": "你蹲低身子去掃腿，{name}卻是正面衝過來。"},
			"smash": {"deal": 0.5, "take": 1.2, "text": "你蹲低身子去掃腿，正好迎上從頭頂落下的{weapon}。"},
			"guard": {"deal": 0.3, "text": "你一腳掃向{name}的腳，{name}站得很穩。"},
			"opening": {"deal": 0.5, "text": "你一腳踢中{name}的腳。"},
		},
		# 對體型大的敵人：鑽不乾淨、也掃不倒
		"vs_big": {
			"sweep": {"deal": 0.3, "take": 0.5, "text": "你蹲低身子，{weapon}還是擦過你的背。你一腳掃向{name}的腳——像踢到樹幹，晃都沒晃。"},
		},
	},
	"parry": {
		"name": "撥擋反擊",
		"basic": false,
		"desc": "對付正面衝過來的攻擊：把攻擊撥開，同時刺回去。還是會被擦到一下。",
		"vs": {
			"thrust": {"deal": 1.2, "take": 0.3, "text": "你看準{weapon}，用劍一撥，順勢刺了回去！不過還是被擦到一下。"},
			"sweep": {"deal": 0.0, "take": 0.8, "text": "你想撥開{weapon}，可是力道太大，撥不動。"},
			"smash": {"deal": 0.0, "take": 1.0, "text": "你想撥開從頭頂落下的{weapon}，被硬生生壓了下來。"},
			"guard": {"deal": 0.0, "text": "{name}沒有出手，你沒東西可撥。"},
			"opening": {"deal": 0.0, "text": "{name}沒有出手，你沒東西可撥，白白錯過了機會。"},
		},
	},
	"heavy": {
		"name": "重擊",
		"basic": false,
		"desc": "雙手全力一擊，盔甲和盾牌都擋不住。出手時破綻大，這回合被打會更痛。",
		"pierce": true,
		"vs": {
			"sweep": {"deal": 2.0, "take": 1.5, "hit": true, "text": "你雙手舉劍全力劈下，{name}也同時出手。"},
			"thrust": {"deal": 2.0, "take": 1.5, "hit": true, "text": "你雙手舉劍全力劈下，{name}也同時出手。"},
			"smash": {"deal": 2.0, "take": 1.5, "hit": true, "text": "你和{name}同時全力劈下。"},
			"guard": {"deal": 1.5, "effect": "guard_broken", "text": "你雙手舉劍全力劈下，連人帶{guard}打得{name}退了好幾步！"},
			"opening": {"deal": 2.5, "text": "你雙手舉劍，全力劈在{name}身上！"},
		},
	},
	"vital": {
		"name": "要害刺",
		"basic": false,
		"desc": "刺向要害或盔甲縫隙，盔甲擋不住。對方露出破綻時威力最大。",
		"pierce": true,
		"vs": {
			"opening": {"deal": 3.0, "text": "你看準破綻，一劍刺進{name}的要害！"},
			"smash": {"deal": 2.0, "take": 1.0, "hit": true, "text": "{name}高舉雙手，腋下全空了。你一劍刺了進去！"},
			"sweep": {"deal": 0.7, "take": 1.0, "hit": true, "text": "你刺向{name}的要害，可是對方動作太大，只刺到邊。"},
			"thrust": {"deal": 0.7, "take": 1.0, "hit": true, "text": "你刺向{name}的要害，可是對方動作太大，只刺到邊。"},
			"guard": {"deal": 0.0, "text": "你刺向{name}的要害，被{guard}擋住了。"},
		},
	},
}


## 查表：這個招式碰上這種敵人動作的結果
static func entry(move_id: String, intent_type: String, bad_position: bool, big: bool) -> Dictionary:
	var m: Dictionary = MOVES[move_id]
	if bad_position and m.has("off_balance"):
		return m["off_balance"]
	if big and m.has("vs_big") and m["vs_big"].has(intent_type):
		return m["vs_big"][intent_type]
	return m["vs"][intent_type]


static func learnable_ids() -> Array:
	var ids := []
	for id in ORDER:
		if not MOVES[id]["basic"]:
			ids.append(id)
	return ids
