class_name GrowthData
extends RefCounted

## 基礎數值（身體）和境界的數字。只有資料和換算，沒有規則。
##
## 力量 str：攻擊、防禦、裂盾斬、逆流斬、脫鎖、三連斬、怒喝、掙扎
## 敏捷 agi：閃避、迎擊、低身斬、奪刃、穿隙刺、擲沙
##
## 戰鬥：同一項跟同一項比。你用力量的招，比雙方的力量；對手用力量的招打你，也比雙方的力量。
##   差距 = 出手的人 − 被打的人。
##   差距到 -FAIL_GAP 以下，招一定失敗（掙不開、擋不住、閃不掉、破不了防）。
##   差距也改變傷害：每差 1 點約 10%。
##
## 怎麼長：冒險打怪。用了哪個數值的招，就練到哪個數值。
##   練多少看對手「那一項」比你高多少：比你低 GROW_OFFSET 點以上的對手練不到你。
##   數值到了瓶頸就不長，要衝破瓶頸才能再長：
##     卡在瓶頸時，打贏比瓶頸強的對手。只有這條路（師傅不能帶你過瓶頸）。
##
## 境界：衝破一次瓶頸就升一境。血量看境界。同一境再分前段、中段、後段（看數值）。

const STATS := ["str", "agi"]
const NAMES := {"str": "力量", "agi": "敏捷"}
const START := 10

# ---- 境界 ----
## 第 i 境的瓶頸（數值最多練到這裡）
const CAPS := [15, 20, 25]
## 第 i 境從哪裡算起（算前中後段用）
const REALM_FLOOR := [10, 15, 20]
const REALM_NAMES := ["第一境", "第二境", "第三境"]
## 參考品級顏色：越高越亮眼
const REALM_COLORS := ["#c9ccd1", "#6fcf7a", "#6fa8ff"]
const STAGES := ["前段", "中段", "後段"]
## 第 i 境的血量
const REALM_HP := [100, 150, 220]

# ---- 戰鬥時的比較 ----
## 招式打出去、對手打過來的基本傷害（再乘招式倍率、差距倍率）
const BASE_DAMAGE := 18.0
## 比對手低這麼多（含）就一定失敗
const FAIL_GAP := 3
## 每差 1 點，傷害差幾 %
const DAMAGE_PER_POINT := 0.1
const DAMAGE_MULT_MIN := 0.3
const DAMAGE_MULT_MAX := 1.4
## 差這麼多（含）就是「不同層次」：戰報換寫法（打中了也不痛／一下就被打飛），對手會怕、會逃
const OUTCLASS := 4

# ---- 成長 ----
## 長 1 點要多少經驗
const EXP_PER_POINT := 100.0
## 每用一次招給的經驗（再乘上成長倍率）
const EXP_PER_USE := 15.0
## 對手那一項比你低 GROW_OFFSET 點時練不到；跟你一樣時 = 1 倍
const GROW_OFFSET := 3.0
const GROW_MAX := 1.5
## 打輸、撤退只學得到一點（不然故意去送死反而練最快）
const OUTCOME_MULT := {"win": 1.0, "lose": 0.25, "flee": 0.25}


## 差距 → 傷害倍率
static func damage_mult(gap: int) -> float:
	return clampf(1.0 + gap * DAMAGE_PER_POINT, DAMAGE_MULT_MIN, DAMAGE_MULT_MAX)


static func fails(gap: int) -> bool:
	return gap <= -FAIL_GAP


## 對手那一項 vs 你那一項 → 經驗倍率
static func grow_mult(enemy_value: int, value: int) -> float:
	return clampf((enemy_value - value + GROW_OFFSET) / GROW_OFFSET, 0.0, GROW_MAX)


## 數值落在第幾境（怪物的危險度用）
static func realm_of_value(value: int) -> int:
	for i in CAPS.size():
		if value <= CAPS[i]:
			return i
	return CAPS.size() - 1


## 在這一境的前段 0、中段 1、後段 2
static func stage(realm: int, value: int) -> int:
	var span: int = CAPS[realm] - REALM_FLOOR[realm]
	return clampi(int(float(value - REALM_FLOOR[realm]) * 3.0 / span), 0, 2)


static func realm_text(realm: int, value: int) -> String:
	return "%s%s" % [REALM_NAMES[realm], STAGES[stage(realm, value)]]
