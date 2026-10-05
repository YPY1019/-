class_name WeaponData
extends RefCounted

## 武器：只有資料。
## 好武器從人身上拿：打倒帶著它的人就拿到（EnemyData 的 loot）。武器店只賣普通貨。
## power：你打出去的傷害乘這個倍率（所有招都算）。
## str：力量不到拿不動（不能買、不能換上）。
## rare：有名字、只有一把。fx：特效（被動），拿著它的人砍中時發動，敵人拿著也一樣（見 Battle）。
##   twin 紅鬃之牙：砍中時常會再咬一口（多一下半傷）
##   knell 喪鐘：砍中時常會把對手震開（對手下回合露出破綻；打在你身上是站不穩）
##   特效不寫在任何說明裡，只在戰報裡看得到（show don't tell）。
## look：開打前就看得到的樣子。

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
	"red_fang": {"name": "紅鬃之牙", "power": 1.7, "cost": 0, "str": 0, "rare": true, "fx": "twin",
		"look": "暗紅色的劍，刃口有一排鋸齒。",
		"desc": "傭兵團「紅鬃」歷代隊長傳下來的劍，刃口有一排鋸齒。"},
	"knell": {"name": "喪鐘", "power": 2.1, "cost": 0, "str": 0, "rare": true, "fx": "knell",
		"look": "黑色的大劍，劍身很寬，揮起來會嗡嗡響。",
		"desc": "黑騎士的大劍。劍身很寬，揮起來會嗡嗡響。"},
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
}


static func get_def(id: String) -> Dictionary:
	return WEAPONS[id]


static func fx(id: String) -> String:
	return WEAPONS[id].get("fx", "")
