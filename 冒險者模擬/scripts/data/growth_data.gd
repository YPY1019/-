class_name GrowthData
extends RefCounted

## 基礎數值（身體）的數字。只有資料和換算，沒有規則。
##
## 力量 str：攻擊、裂盾斬、逆流斬、脫鎖、三連斬
## 敏捷 agi：閃避、迎擊、低身斬、奪刃、穿隙刺、擲沙
## 體魄 con：血量；防禦、怒喝；挨打也會練到
##
## 怎麼長：冒險打怪。用了哪個數值的招，就練到哪個數值。
##   練到多少看對手的「強度」(EnemyData 的 level) 比你的數值高多少：比你弱的對手練不到你。
##   數值到了瓶頸就不長，要衝破瓶頸才能再長：
##     第一次打贏強度高過瓶頸的對手，或找師傅特訓。

const STATS := ["str", "agi", "con"]
const NAMES := {"str": "力量", "agi": "敏捷", "con": "體魄"}
const START := 10
## 瓶頸，一層一層往上
const CAPS := [15, 20, 25]

## 長 1 點要多少經驗
const EXP_PER_POINT := 100.0
## 每用一次招給的經驗（再乘上強度差）
const EXP_PER_USE := 15.0
## 對手強度比你的數值高 GAP_DIV 點時，強度差 = 1 倍
const GAP_DIV := 3.0
const GAP_MAX := 1.5
## 打輸、撤退只學得到一點（不然故意去送死反而練最快）
const OUTCOME_MULT := {"win": 1.0, "lose": 0.25, "flee": 0.25}
## 每掉 10% 血量，算體魄用了一次
const HURT_PER_USE := 0.1

## 數值每 1 點，招式多痛幾 %（數值 10 = 原本的威力）
const POWER_PER_POINT := 0.06
const HP_BASE := 60
const HP_PER_CON := 4


static func power(value: int) -> float:
	return 10.0 * (1.0 + (value - START) * POWER_PER_POINT)


static func max_hp(con: int) -> int:
	return HP_BASE + con * HP_PER_CON


## 對手強度比你的數值高多少，換成經驗的倍數
static func gap_mult(enemy_level: int, value: int) -> float:
	return clampf((enemy_level - value) / GAP_DIV, 0.0, GAP_MAX)
