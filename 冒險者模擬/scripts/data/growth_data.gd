class_name GrowthData
extends RefCounted

## 基礎數值（身體）和境界的數字。只有資料和換算，沒有規則。
##
## 力量 str：攻擊、防禦、劈柴、十字鐵壁、泥鰍、怒獅三撲、掙扎
## 敏捷 agi：閃避、獅爪、割麥、斷牙、獅王卸甲
##
## 戰鬥：同一項跟同一項比。你用力量的招，比雙方的力量；對手用力量的招打你，也比雙方的力量。
##   差距 = 出手的人 − 被打的人。
##   差距決定招成功的機率（success_chance）：差越多越容易失敗（掙不開、擋不住、閃不掉、破不了防），但不是一刀切。
##   差距也改變傷害：每差 1 點約 10%。
##
## 怎麼長：冒險打怪。用了哪個數值的招，就練到哪個數值。
##   練多少看對手「那一項」比你高多少：比你低 GROW_OFFSET 點以上的對手練不到你。
##   數值到了瓶頸就不長，要衝破瓶頸才能再長：
##     卡在瓶頸時，打贏比瓶頸強的對手。只有這條路（流派的人不能帶你過瓶頸）。
##
## 境界：6 層，衝破一次瓶頸就升一境。血量看境界。同一境再分前段、中段、後段（看數值）。

const STATS := ["str", "agi"]
const NAMES := {"str": "力量", "agi": "敏捷"}
const START := 10

# ---- 等級的顏色 ----
## 境界、武學、秘笈、稀有武器共用同一套 6 個顏色（參考龍胤立志傳）：灰、綠、藍、紫、橙、紅。看到紫色就是同一個檔次
const GRADE_COLORS := ["#c9ccd1", "#6fcf7a", "#6fa8ff", "#b98cff", "#ffa64d", "#ff6b6b"]
const GRADE_NAMES := ["灰", "綠", "藍", "紫", "橙", "紅"]

# ---- 境界 ----
## 第 i 境的瓶頸（數值最多練到這裡）
const CAPS := [12, 15, 18, 21, 25, 30]
## 第 i 境從哪裡算起（算前中後段用）
const REALM_FLOOR := [10, 12, 15, 18, 21, 25]
## 境界的名字還沒定（GAME_DESIGN.md「還沒決定」）
const REALM_NAMES := ["第一境", "第二境", "第三境", "第四境", "第五境", "第六境"]
const REALM_COLORS := GRADE_COLORS
const STAGES := ["前段", "中段", "後段"]
## 第 i 境的血量
const REALM_HP := [100, 125, 155, 190, 230, 280]
## 世界上有打法的人：數值每長 1 點，血量多幾點（掉 1 點就少幾點）
const HP_PER_POINT := 12

# ---- 世界上的人互相打（World） ----
## 粗略的強弱：0.6 × 比較高的那項 ＋ 0.4 × 比較低的那項 ＋ 武器 ＋ 絕學
const POWER_PER_WEAPON := 3.0
const POWER_PER_ULT := 1.0
## 血越厚越難打倒：每多 e 倍的血（以 HP_BASE 為準）多算這麼多
const POWER_PER_HP := 4.0
const HP_BASE := 150.0
## 強弱差這麼多，勝率大約 73%（差兩倍約 88%）
const POWER_SPREAD := 1.0

# ---- 戰鬥時的比較 ----
## 招式打出去、對手打過來的基本傷害（再乘招式倍率、差距倍率）
const BASE_DAMAGE := 18.0
## 招成功的機率：差距 0 時 SUCCESS_BASE，每差 1 點加減 SUCCESS_PER_POINT
const SUCCESS_BASE := 0.85
const SUCCESS_PER_POINT := 0.1
const SUCCESS_MIN := 0.05
const SUCCESS_MAX := 0.97
## 每差 1 點，傷害差幾 %
const DAMAGE_PER_POINT := 0.1
const DAMAGE_MULT_MIN := 0.3
const DAMAGE_MULT_MAX := 1.4
## 差這麼多（含）就是「不同層次」：戰報換寫法（打中了也不痛／一下就被打飛），對手會怕、會逃
const OUTCLASS := 4

# ---- 成長 ----
## 第 i 境長 1 點要多少經驗（境界越高越難長）
const EXP_PER_POINT := [100.0, 140.0, 190.0, 250.0, 320.0, 400.0]
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


## 差距 → 招成功的機率（odds：這招本身難一點或容易一點）
static func success_chance(gap: int, odds := 0.0) -> float:
	return clampf(SUCCESS_BASE + gap * SUCCESS_PER_POINT + odds, SUCCESS_MIN, SUCCESS_MAX)


## 對手那一項 vs 你那一項 → 經驗倍率
static func grow_mult(enemy_value: int, value: int) -> float:
	return clampf((enemy_value - value + GROW_OFFSET) / GROW_OFFSET, 0.0, GROW_MAX)


## 數值落在第幾境（怪物的危險度用）
static func realm_of_value(value: int) -> int:
	for i in CAPS.size():
		if value <= CAPS[i]:
			return i
	return CAPS.size() - 1


## 世界上的人：底子落在第幾境（他們不用衝瓶頸，長到哪就是哪）
static func realm_of_stats(stats: Dictionary) -> int:
	return realm_of_value(maxi(stats["str"], stats["agi"]))


## a 打贏 b 的機率（世界上的人互相打）
static func win_chance(power_a: float, power_b: float) -> float:
	return 1.0 / (1.0 + exp(-(power_a - power_b) / POWER_SPREAD))


## 在這一境的前段 0、中段 1、後段 2。後段 = 頂到瓶頸了；前段、中段把這一境的下半、上半分開
## （每一境只差三五點，照三等分算的話，前段只有一點，升境那一仗多長一點就直接跳中段）
static func stage(realm: int, value: int) -> int:
	if value >= CAPS[realm]:
		return 2
	var span: int = maxi(1, CAPS[realm] - REALM_FLOOR[realm])
	return 0 if value - REALM_FLOOR[realm] < ceili(span / 2.0) else 1


static func realm_text(realm: int, value: int) -> String:
	return "%s%s" % [REALM_NAMES[realm], STAGES[stage(realm, value)]]
