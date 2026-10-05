class_name WeaponData
extends RefCounted

## 武器：只有資料。
## 好武器從人身上拿：打倒帶著它的人就拿到（EnemyData 的 loot）。武器店只賣普通貨。
## power：你打出去的傷害乘這個倍率（所有招都算）。
## str：力量不到拿不動（不能買、不能換上）。
## rare：有名字、只有一把。fx：特效（被動），拿著它的人砍中時發動，敵人拿著也一樣（見 Battle）。
##   twin 赤牙：砍中時常會再咬一口（多一下半傷）
##   knell 喪鐘：砍中時常會把對手震得門戶大開（對手下回合露出破綻；打在你身上是站不穩）
## look：開打前就看得到的樣子。fx_desc：挨過、或拿到之後才知道的效果。

const START := "old_sword"

## 武器店賣的
const SHOP := ["steel_sword"]

## 特效發動的機率、twin 多咬一口的傷害比例
const FX_CHANCE := 0.35
const TWIN_DAMAGE := 0.5

const WEAPONS := {
	"old_sword": {"name": "舊鐵劍", "power": 1.0, "cost": 0, "str": 0,
		"desc": "從老家帶出來的劍，刃口有好幾個缺口。"},
	"steel_sword": {"name": "鋼劍", "power": 1.3, "cost": 100, "str": 12,
		"desc": "鐵匠鋪最常見的好劍，比你那把舊鐵劍利多了。"},
	"bandit_blade": {"name": "盜匪的大刀", "power": 1.2, "cost": 0, "str": 0,
		"desc": "從盜匪頭子手裡拿來的大刀。刀背生鏽，刀口倒是磨得很利。"},
	"knight_sword": {"name": "騎士長劍", "power": 1.5, "cost": 0, "str": 14,
		"desc": "逃兵騎士的長劍，又長又重，砍下去很實在。"},
	"red_fang": {"name": "赤牙", "power": 1.7, "cost": 0, "str": 0, "rare": true, "fx": "twin",
		"look": "暗紅色的刃，刃口一排鋸齒，像野獸的牙。",
		"fx_desc": "砍中時常會再咬一口。",
		"desc": "傭兵團「紅鬃」代代隊長的佩劍。鋸齒刃砍進去，拔出來時還要再咬一口。",
		"get": "你握住劍柄，暗紅色的刃上還沾著羅德里克的血。鋸齒在火光下一排排發亮，像在笑。"},
	"knell": {"name": "喪鐘", "power": 2.1, "cost": 0, "str": 0, "rare": true, "fx": "knell",
		"look": "漆黑的大劍，劍身寬得像一扇門。揮動時會發出低沉的嗡鳴。",
		"fx_desc": "砍中時常會把對手震得門戶大開。",
		"desc": "黑騎士的大劍。每砍中一下，就響一聲鐘。",
		"get": "你握住劍柄的那一刻，劍身輕輕嗡了一聲，像在認人。這麼大的劍，在你手裡卻一點也不重。"},
}


## 特效發動時的描述。out：你拿著它砍中對手；in：對手拿著它砍中你。
## {name} 對手、{pron} 他／牠、{weapon} 這把劍的名字
const FX_TEXT := {
	"twin": {
		"out": ["{weapon}的鋸齒刃一勾一扯，又在{name}身上咬下一口！", "你抽劍時手腕一翻，{weapon}的鋸齒順勢又撕開一道口子。"],
		"in": ["{weapon}的鋸齒刃一勾一扯，你身上又被咬下一塊肉！", "{name}抽劍時手腕一翻，鋸齒順勢又在你身上撕開一道口子。"],
	},
	"knell": {
		"out": ["「嗡——」{weapon}發出一聲低沉的鐘鳴，{name}被震得門戶大開！", "鐘聲在劍身裡迴盪，{name}整個人被震得往後一晃，空門全露了出來。"],
		"in": ["「嗡——」鐘聲直接灌進你的骨頭裡，你整條手臂發麻，腳下站不穩。", "{weapon}砍中你的同時響了一聲鐘，你眼前一花，差點跪下去。"],
	},
}


static func get_def(id: String) -> Dictionary:
	return WEAPONS[id]


static func fx(id: String) -> String:
	return WEAPONS[id].get("fx", "")
