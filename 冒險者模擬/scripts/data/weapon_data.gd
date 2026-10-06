class_name WeaponData
extends RefCounted

## 武器：只有資料。
## 好武器從人身上拿：打倒帶著它的人就拿到（EnemyData 的 loot）。武器店只賣普通貨。
## power：你打出去的傷害乘這個倍率（所有招都算）。
## str：力量不到拿不動（不能買、不能換上）。
## rare：有名字、只有一把。fx：特效（被動），拿著它的人砍中時發動，敵人拿著也一樣（見 Battle）。
##   twin 紅鬃之牙：砍中時常會再咬一口（多一下半傷）
##   knell 喪鐘：砍中時常會把對手震開（對手下回合露出破綻；打在你身上是站不穩）
##   rend 碎門者：砍得穿甲（盔甲擋不住）；對手拿著時，你擋它常常擋不住一半
##   ward 守夜人：常用護手把砍過來的攻擊架開（傷害剩 WARD_TAKE）。絕學架不開
##   特效不寫在任何說明裡，只在戰報裡看得到（show don't tell）。
## look：看得到的樣子（人物面板上寫這個，不寫名字：要自己認出那把劍）。
## kind：哪一類（世界上的人只用自己打法那一類的武器，拿到別類的只帶在身上）。
## noun：世界上的人拿著它跟你打時，戰報裡怎麼叫它。
## 傳家的稀有武器也要力量夠才拿得動（換人接著玩時，下一個人要練到門檻）。

const START := "old_sword"
## 什麼都沒有的時候
const FIST := "fist"

## 武器店賣的
const SHOP := ["steel_sword"]

## 特效發動的機率、twin 多咬一口的傷害比例和上限（不然碰上絕學會多咬一百多）
const FX_CHANCE := 0.35
const TWIN_DAMAGE := 0.5
const TWIN_MAX := 15
## ward 架開之後剩幾成傷害
const WARD_TAKE := 0.3

const WEAPONS := {
	"fist": {"name": "空手", "noun": "拳頭", "kind": "fist", "power": 0.7, "cost": 0, "str": 0,
		"look": "空著手。", "desc": "什麼都沒拿。"},
	"old_sword": {"name": "舊鐵劍", "noun": "劍", "kind": "sword", "power": 1.0, "cost": 0, "str": 0,
		"look": "一把舊鐵劍，刃口有好幾個缺口。", "desc": "從老家帶出來的劍，刃口有好幾個缺口。"},
	"steel_sword": {"name": "鋼劍", "noun": "鋼劍", "kind": "sword", "power": 1.3, "cost": 100, "str": 12,
		"look": "一把鋼劍。", "desc": "鐵匠鋪最常見的好劍，比你那把舊鐵劍利多了。"},
	"bandit_blade": {"name": "盜匪的大刀", "noun": "大刀", "kind": "blade", "power": 1.2, "cost": 0, "str": 0,
		"look": "一把刀背生鏽的大刀。", "desc": "盜匪愛用的大刀。刀背生鏽，刀口倒是磨得很利。"},
	"knight_sword": {"name": "騎士長劍", "noun": "長劍", "kind": "sword", "power": 1.5, "cost": 0, "str": 14,
		"look": "一把騎士的長劍。", "desc": "騎士的長劍，又長又重，砍下去很實在。"},
	"rapier": {"name": "細劍", "noun": "細劍", "kind": "rapier", "power": 1.3, "cost": 0, "str": 0,
		"look": "一把細劍和一把短劍。", "desc": "南方決鬥家用的細劍，又輕又快。"},
	"hand_axe": {"name": "手斧", "noun": "斧頭", "kind": "axe", "power": 1.3, "cost": 0, "str": 13,
		"look": "一把手斧。", "desc": "北方海上來的人愛用的斧頭。"},
	"warhammer": {"name": "戰錘", "noun": "戰錘", "kind": "hammer", "power": 1.5, "cost": 0, "str": 18,
		"look": "一把戰錘和一面塔盾。", "desc": "很沉的戰錘。"},
	"red_fang": {"name": "紅鬃之牙", "noun": "鋸齒劍", "kind": "sword", "power": 1.7, "cost": 0, "str": 16, "rare": true, "fx": "twin",
		"look": "暗紅色的劍，刃口有一排鋸齒。",
		"desc": "傭兵團「紅鬃」歷代隊長傳下來的劍，刃口有一排鋸齒。"},
	"knell": {"name": "喪鐘", "noun": "大劍", "kind": "greatsword", "power": 1.8, "cost": 0, "str": 19, "rare": true, "fx": "knell",
		"look": "黑色的大劍，劍身很寬，揮起來會嗡嗡響。",
		"desc": "黑騎士的大劍。劍身很寬，揮起來會嗡嗡響。"},
	"gatebreaker": {"name": "碎門者", "noun": "雙刃斧", "kind": "axe", "power": 1.7, "cost": 0, "str": 17, "rare": true, "fx": "rend",
		"look": "雙刃大斧，斧刃上全是缺口。",
		"desc": "烏爾夫的斧頭。據說劈開過三座城門。"},
	"nightwatch": {"name": "守夜人", "noun": "長劍", "kind": "sword", "power": 1.9, "cost": 0, "str": 20, "rare": true, "fx": "ward",
		"look": "老式的長劍，護手很寬，磨得發亮。",
		"desc": "王都衛隊的隊長一代傳一代的長劍。護手很寬。"},
}


## 特效發動時的描述。out：你拿著它砍中對手；in：對手拿著它砍中你。
## {name} 對手、{pron} 他／牠、{weapon} 這把劍的名字
const FX_TEXT := {
	"twin": {
		"out": ["抽劍的時候，鋸齒又在{name}身上扯開一道口子。", "你把劍往回一拉，鋸齒刮過{name}的傷口，又撕下一塊肉。"],
		"in": ["{pron}抽劍的時候，鋸齒又在你身上扯開一道口子。", "{pron}把劍往回一拉，鋸齒刮過你的傷口，痛得你叫出聲。"],
	},
	"knell": {
		"out": ["劍身嗡的一聲，{name}被震得往後一晃，架勢全散了。", "{name}被震得手腳發軟，一時站不穩。"],
		"in": ["劍身嗡的一聲，你被震得手臂發麻，腳下站不穩。", "你耳朵裡嗡嗡作響，差點跪下去。"],
	},
	"rend": {
		"out": ["斧刃連甲帶肉劈了進去。", "{name}的甲片被劈開，斧頭砍進了肉裡。"],
		"in": ["你舉劍去擋，斧頭連你的劍一起壓了下來。", "斧頭劈在你的劍上，力道沒卸掉多少。"],
	},
	"ward": {
		"out": ["你用寬寬的護手架住這一下，力道滑了開去。", "你手腕一翻，護手接住了{name}的攻擊。"],
		"in": ["{name}手腕一翻，寬寬的護手接住了你的劍。", "你的劍砍在{name}的護手上，滑了開去。"],
	},
}


static func get_def(id: String) -> Dictionary:
	return WEAPONS[id]


## twin 多咬一口的傷害
static func twin_extra(dmg: int) -> int:
	return clampi(roundi(dmg * TWIN_DAMAGE), 1, TWIN_MAX)


static func is_rare(id: String) -> bool:
	return WEAPONS[id].get("rare", false)


static func fx(id: String) -> String:
	return WEAPONS[id].get("fx", "")
