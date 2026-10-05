class_name WeaponData
extends RefCounted

## 武器：只有資料。
## 武器店的劍越貴越強，但要力量夠才拿得動：力量不到門檻就不能買。
## power：你打出去的傷害乘這個倍率（所有招都算）。

const START := "old_sword"

const ORDER := ["old_sword", "steel_sword", "knight_sword", "mithril_sword"]

const WEAPONS := {
	"old_sword": {"name": "舊鐵劍", "power": 1.0, "cost": 0, "str": 0,
		"desc": "從老家帶出來的劍，刃口有好幾個缺口。"},
	"steel_sword": {"name": "鋼劍", "power": 1.3, "cost": 100, "str": 12,
		"desc": "鐵匠鋪最常見的好劍，比你那把舊鐵劍利多了。"},
	"knight_sword": {"name": "騎士長劍", "power": 1.6, "cost": 250, "str": 14,
		"desc": "騎士團淘汰下來的長劍，又長又重，砍下去很實在。"},
	"mithril_sword": {"name": "秘銀劍", "power": 2.0, "cost": 500, "str": 17,
		"desc": "矮人鍛造的秘銀劍，輕得不像話，卻能把鐵甲連人劈開。"},
}


static func get_def(id: String) -> Dictionary:
	return WEAPONS[id]
