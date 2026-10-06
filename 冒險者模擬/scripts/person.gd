class_name Person
extends RefCounted

## 一個人。玩家角色和世界上的人用同一種資料：數值、境界、招、裝備、位置、關係、做過的事。
## 死後換人接著玩，就是把世界上的另一個人換成玩家角色。
## 玩家角色的成長靠打（Town 結算），世界上的人的成長、移動、打架由 World 每個月推一次。
## 戰鬥時轉成 Combatant 帶進去。

var id := ""
var display_name := "你"
## 名號（傭兵隊長、決鬥家）
var title := ""
var pron := "他"
## 世界上的人跟你打的時候用的招和戰報（EnemyData 的 id）
var style := ""
## 跟你打的時候登場的句子、被打倒時的句子（沒寫就用打法的）
var start_lines: Array = []
var win_text := ""

## 世界的時間（整個世界共用一個）
var clock := Clock.new()
## 哪一年出生（開局那年是第 0 年）
var born_year := -LifeData.START_AGE
## 世界的第幾個月死（看不到，見 LifeData）。World 開局時擲
var dies_at := 999999
var dead := false
## 死在世界的第幾個月
var died_at := -1
## 這個人做過、遇過的事：[{"month", "text", "public"}]。public = 世界上的人知道（人物面板上看得到）
var history: Array = []
var money := TownData.START_MONEY
var hp := 0

## 基礎數值（練出來的底子）和長到一半的經驗。老了以後現在的身體會比底子低，見 body()
var stats := {"str": GrowthData.START, "agi": GrowthData.START}
var exp := {"str": 0.0, "agi": 0.0}
## 境界（從 0 算）。境界就是瓶頸：衝破一次瓶頸就升一境
var realm := 0
## 世界上的人的血量（打法自己的）。0 = 照境界算（玩家角色、年輕人）
var base_hp := 0
var base_sum := 0

## 學會的招式 id。基本招式不用學。
var learned: Array[String] = []
## 流派（SchoolData.ID，空的是沒有）和階位（1 學徒、2 熟手、3 大師；0 不是成員）
var school := ""
var rank := 0
## 替流派辦事累積的貢獻：還能用的、總共拿過的（升階位看總共）
var merit := 0
var merit_total := 0
## 接下的流派委託（SchoolData.JOBS 的 id）
var school_jobs: Array[String] = []
## 身上的秘笈（BookData）。讀完就學會裡面的招，書還留著
var books: Array[String] = []
## 庭主交代的事：交代過了沒、劍譜拿回去給他看過了沒
var errand_given := false
var errand_reported := false
## 拿給庭主看過的殘頁
var errand_pages: Array = []
## 有劍庭的圓盾（學了劍庭的招才有。劍庭的招要一手劍一手盾）
var shield := false
## 世界上的人：要拿去城裡武器店賣的東西（回到城裡才賣）
var to_sell: Array = []
## 跟誰打過（看過他出手，人物面板才列得出他會的招）
var fought: Array[String] = []
## 辦完還沒回去交差的事：[{"from": guild 公會 / school 劍庭, "what", "money", "merit"}]
var claims: Array = []
## 劍庭的事：辦完之後第幾個月才會再有（世界的月）
var job_back := {}
## 招式欄：玩家角色一次只能帶幾招出門（人人都會的不佔格子）。世界上的人不用（會的都帶著）
var uses_slots := false
var equipped: Array[String] = []
const SLOT_BASE := 3
const SLOT_MAX := 8
## 名聲：打贏有名的人就變有名（強者榜照這個排，不寫出數字）
var fame := 0.0
## 在公會打聽的人：人 id -> 消息斷掉的那個月（世界的月）
var inquired := {}
## 被逐出流派了（不能再回去）
var expelled := false
## 哪一年考過劍庭的選拔（一年一次）
var selection_year := -999
## 聽說誰在哪：人 id -> {"place", "month"}（玩家角色才用。地圖、人物分頁只寫這個，不寫他真正在哪）
var heard := {}
## 看過誰用過哪些招：人 id -> [招 id]（人物面板只寫看過的）
var seen := {}
## 接下的一般委託（怪物 id）。打贏才拿得到報酬
var jobs: Array[String] = []
## 打贏過的對手（委託的怪物 id、人的 id）
var beaten: Array[String] = []
## 拿著的武器和身上有的武器（買的、從人身上拿的）
var weapon := WeaponData.START
var owned_weapons: Array[String] = [WeaponData.START]

# ---- 在世界上 ----
## 在哪裡（MapData 的地點）。在路上時是出發的地方
var location := MapData.HOME
## 在往哪裡去、還要走幾個月
var travel_to := ""
var travel_left := 0
## 世界上的人怎麼過日子：villain 有懸賞的、hunter 冒險者、duelist 決鬥家、master 師傅、settled 待在家、
## youth 年輕人（在城裡練）、follower 跟著老大走。玩家角色是空的
var role := ""
## 會去的幾個地方（villain、duelist）
var haunts: Array = []
## follower 跟著誰走（他死了就接手他的人）
var follows := ""
## 跟別人的關係：別人的 id -> 關係（parent 父母、child 孩子、master 師傅、disciple 徒弟、sibling 兄弟、
## boss 老大、follower 手下）
var relations := {}
## 要找誰算帳（仇人的 id）。有仇人的人會去找他
var grudges: Array = []
## 正在追的人（懸賞、仇人、決鬥的對象）
var target := ""
## 身體還能長到哪（世界上的人）、一年大約長幾點
var potential := {}
var growth := 0.0
## 冒險者有多敢：只接比自己弱、或強不過這麼多的懸賞
var boldness := 0.5
## 在一個地方還要待幾個月才走、下次決定做什麼之前要歇幾個月
var stay_left := 0
var rest_left := 0
## 世界上的人的特別打算：{"target", "month"}（到了那個月就去找那個人）
var vow := {}


func _init() -> void:
	hp = max_hp()


# ---------- 年紀 ----------

func now() -> int:
	return clock.month


func age() -> int:
	return age_at(now())


func age_at(month: int) -> int:
	return LifeData.year_of(month) - born_year


func date_text() -> String:
	return LifeData.date_text(age(), now())


## 離壽命用完還有幾個月
func months_left() -> int:
	return maxi(0, dies_at - now())


## 病倒了（臨終）
func dying() -> bool:
	return not dead and months_left() <= LifeData.DYING_MONTHS


## 快死的徵兆有多明顯（0～1）
func omen() -> float:
	return LifeData.omen(months_left())


## 這一項老了掉幾點
func decline(stat: String) -> int:
	return LifeData.decline(stat, age())


## 現在的身體：底子減掉老了掉的。戰鬥、成長、學招的門檻都看這個
func body(stat: String) -> int:
	return maxi(1, stats[stat] - decline(stat))


func body_stats() -> Dictionary:
	var out := {}
	for s in GrowthData.STATS:
		out[s] = body(s)
	return out


## 記一筆這個人做過的事。public = false：只有自己知道（例如沒人看見是誰下的手）
func note(text: String, public := true) -> void:
	history.append({"month": now(), "text": text, "public": public})


# ---------- 血量、境界、數值 ----------

## 血量：玩家角色和年輕人看境界；世界上有打法的人看自己的底子，數值長了跟著多
func max_hp() -> int:
	if base_hp > 0:
		var sum := 0
		for s in GrowthData.STATS:
			sum += body(s)
		return maxi(1, base_hp + (sum - base_sum) * GrowthData.HP_PER_POINT)
	return GrowthData.REALM_HP[realm] + hp_bonus()


func hp_bonus() -> int:
	return 0


func cap() -> int:
	return GrowthData.CAPS[realm]


## 瓶頸看底子
func at_cap(stat: String) -> bool:
	return stats[stat] >= cap()


## 有任何一項卡在瓶頸
func stuck() -> bool:
	return GrowthData.STATS.any(func(s): return at_cap(s))


func can_break_through() -> bool:
	return realm < GrowthData.CAPS.size() - 1


## 升一境：血量上限跳一截，身上的傷不變
func break_through() -> void:
	var old_max := max_hp()
	realm += 1
	hp += max_hp() - old_max


## 用比較高的那項算前中後段（看現在的身體）
func realm_text() -> String:
	return GrowthData.realm_text(realm, maxi(body("str"), body("agi")))


func realm_color() -> String:
	return GrowthData.REALM_COLORS[realm]


func saw_move(who: String, move_id: String) -> void:
	var list: Array = seen.get(who, [])
	if not list.has(move_id):
		list.append(move_id)
	seen[who] = list


func knows(move_id: String) -> bool:
	return MoveData.is_basic(move_id) or learned.has(move_id)


func learn(move_id: String) -> void:
	if not learned.has(move_id):
		learned.append(move_id)
		# 學會的招，格子還有空就先帶上
		if uses_slots and equipped.size() < slots():
			equipped.append(move_id)


## 招式欄有幾格：第一境 SLOT_BASE 格，每升一境多一格
func slots() -> int:
	return mini(SLOT_BASE + realm, SLOT_MAX)


## 打架時用得出來的招（學來的）：玩家角色是帶在身上的，世界上的人是會的全部
func active_moves() -> Array:
	return equipped if uses_slots else learned


## 長 1 點要多少經驗（看境界）
func exp_need() -> float:
	return GrowthData.EXP_PER_POINT[realm]


## 加經驗，回傳長了幾點。到瓶頸就停住。
func add_exp(stat: String, amount: float) -> int:
	var gained := 0
	exp[stat] += amount
	while exp[stat] >= exp_need() and not at_cap(stat):
		exp[stat] -= exp_need()
		stats[stat] += 1
		gained += 1
	if at_cap(stat):
		exp[stat] = 0.0
	return gained


## 力量夠才拿得動。看底子：拿慣的劍，老了也還拿得動
func can_wield(weapon_id: String) -> bool:
	return stats["str"] >= WeaponData.get_def(weapon_id)["str"]


## 身上有的東西（武器、秘笈）
func items() -> Array:
	var out: Array = []
	out.append_array(owned_weapons)
	out.append_array(books)
	return out


func has_item(id: String) -> bool:
	return owned_weapons.has(id) or books.has(id)


func give_item(id: String) -> void:
	if BookData.is_book(id):
		if not books.has(id):
			books.append(id)
	elif not owned_weapons.has(id):
		owned_weapons.append(id)


## 把東西交出去。拿著的武器被拿走了，就換上剩下最好的
func remove_item(id: String) -> void:
	books.erase(id)
	owned_weapons.erase(id)
	if weapon == id:
		weapon = best_weapon()


## 拿得動的武器裡最好的（世界上的人只用自己打法的那一類武器，見 WeaponData.kind）
func best_weapon() -> String:
	var kinds: Array = EnemyData.ENEMIES[style].get("kinds", []) if style != "" and role != "" else []
	var best := ""
	for w in owned_weapons:
		if not can_wield(w):
			continue
		if not kinds.is_empty() and not kinds.has(WeaponData.get_def(w)["kind"]):
			continue
		if best == "" or WeaponData.get_def(w)["power"] > WeaponData.get_def(best)["power"]:
			best = w
	return best if best != "" else (owned_weapons[0] if not owned_weapons.is_empty() else WeaponData.FIST)


## 有多強（世界上的人互相打、決定要不要去找誰時用的粗略估計）：身體、武器、會的絕學
func power() -> float:
	var hi := maxi(body("str"), body("agi"))
	var lo := mini(body("str"), body("agi"))
	var w_power: float = WeaponData.get_def(weapon)["power"]
	var p := 0.6 * hi + 0.4 * lo + (w_power - 1.0) * GrowthData.POWER_PER_WEAPON
	for b in BookData.BOOKS:
		if not BookData.BOOKS[b].has("page_of") and knows(BookData.BOOKS[b]["move"]):
			p += GrowthData.POWER_PER_ULT
	return p


## full = 不管現在的血量，用滿血（木劍過招用）
func to_combatant(full := false) -> Combatant:
	var c := Combatant.new()
	c.display_name = "你"
	c.side = Combatant.Side.ALLY
	c.controlled = true
	# 自動戰鬥：冒險者自己挑招
	c.auto = true
	c.max_hp = max_hp()
	c.hp = c.max_hp if full else hp
	c.stats = body_stats()
	for s in GrowthData.STATS:
		if decline(s) > 0:
			c.aged[s] = decline(s)
	c.omen = omen()
	c.realm = realm
	c.stance = SchoolData.stance_of(self)
	c.attack_mult = WeaponData.get_def(weapon)["power"]
	c.weapon = WeaponData.get_def(weapon)["name"]
	c.weapon_id = weapon
	c.weapon_fx = WeaponData.fx(weapon)
	c.person = self
	return c
