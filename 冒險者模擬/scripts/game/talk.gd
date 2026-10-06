class_name Talk
extends RefCounted

## 人開口說話（規則）：照他的口氣挑一句、提起跟你之間的舊事、怕你或看不起你寫成動作。文字在 TalkData。
## 路上的事（Road）、主動找你的人（Visits）、找上門的人、打起來之前的那一句都用它。
## 跟你之間的事記在他身上（Person.memo），由 World.remember 記。

var world: World


func _init(w: World) -> void:
	world = w


func hero() -> Person:
	return world.hero()


func voice(p: Person) -> String:
	return p.voice if TalkData.VOICES.has(p.voice) else "plain"


## 怕你（afraid）、看不起你（scorn）、都不是（空的）
func attitude(p: Person) -> String:
	var gap: float = hero().power() - p.power()
	if gap >= TalkData.AFRAID_GAP and voice(p) != "proud":
		return "afraid"
	if -gap >= TalkData.SCORN_GAP:
		return "scorn"
	return ""


## 怕你、看不起你的動作（都不是就空的）
func gesture(p: Person) -> String:
	var att := attitude(p)
	if att == "":
		return ""
	return fill(_pick(TalkData.GESTURE[att]), p)


## 他用自己的口氣說 situation 這件事。先提跟你之間最近的一件舊事（skip 裡的不提：這句話本身已經在說那件事）
func say(p: Person, situation: String, vals := {}, skip: Array = []) -> String:
	var by_voice: Dictionary = TalkData.SAY[situation]
	var lines: Array = by_voice.get(voice(p), by_voice["plain"])
	var text := fill(_pick(lines), p, vals)
	if skip.has("*"):
		return text
	var past := past_line(p, skip)
	return past + "\n" + text if past != "" else text


## 來找你算帳的人說的話：你殺了他的人、你打傷搶過他、上一個人欠的、來收你的懸賞
func revenge(p: Person) -> String:
	var h := hero()
	var why: Dictionary = p.grudge_why.get(h.id, {})
	var kind: String = why.get("kind", "beaten") if p.grudges.has(h.id) else ("bounty" if world.wanted(h.id) else "beaten")
	var victim := world.person(why.get("victim", ""))
	var custom: String = PeopleData.PEOPLE.get(p.id, {}).get("avenge", "")
	if kind == "kin" and custom != "" and victim != null and p.relations.has(victim.id):
		var past := past_line(p, ["killed_kin"])
		return past + "\n" + custom if past != "" else custom
	match kind:
		"kin":
			if victim != null:
				return say(p, "revenge_kin", {"{victim}": victim.display_name, "{vpron}": victim.pron, "{rel}": rel(p, victim)}, ["killed_kin"])
		"heir":
			if victim != null:
				return say(p, "revenge_heir", {"{victim}": victim.display_name, "{vpron}": victim.pron})
		"bounty":
			return say(p, "bounty")
	# 你打傷他、拿走他的東西
	var thing := "東西"
	var list := p.memo_of(h.id)
	for i in range(list.size() - 1, -1, -1):
		if list[i].get("item", "") != "" and list[i]["kind"] == "robbed_by_you":
			thing = item_name(list[i]["item"])
			break
	var gplace: String = MapData.place_name(why["place"]) if why.has("place") else "上次"
	return say(p, "revenge_beaten", {"{gplace}": gplace, "{thing}": thing}, ["robbed_by_you", "stripped", "lost_to_you", "spared"])


## 一段開場：場景（城裡、城外）。tense = 不是來好好說話的（算帳、警告、比劍），才寫怕你或看不起你的動作
func scene(p: Person, pool: Dictionary, tense := false) -> String:
	var h := hero()
	var where := "city" if MapData.is_city(h.location) and h.travel_left == 0 else "wild"
	var text := fill(_pick(pool[where]), p)
	var g := gesture(p) if tense else ""
	return text + g if g != "" else text


## 他提起跟你之間最近的一件事（沒有就空的）
func past_line(p: Person, skip: Array = []) -> String:
	var list := p.memo_of(hero().id)
	for i in range(list.size() - 1, -1, -1):
		var e: Dictionary = list[i]
		var d: Dictionary = TalkData.MEMO.get(e["kind"], {})
		if d.has("past") and not skip.has(e["kind"]):
			return memo_text(p, e, "past")
	return ""


## 別人說到他時怎麼認：接在名字後面「，就是……的那個，」（跟你沒有舊事就空的）
func ref(p: Person) -> String:
	var list := p.memo_of(hero().id)
	for i in range(list.size() - 1, -1, -1):
		var e: Dictionary = list[i]
		if TalkData.MEMO.get(e["kind"], {}).has("ref"):
			return TalkData.REF.replace("{ref}", memo_text(p, e, "ref"))
	return ""


## 人物面板上「跟你」：[{"month", "text"}]（舊的在前，一樣的事連著發生只寫一次）
func memo_lines(p: Person) -> Array:
	var out := []
	for e in p.memo_of(hero().id):
		if not TalkData.MEMO.get(e["kind"], {}).has("me"):
			continue
		var text := memo_text(p, e, "me")
		if out.is_empty() or out[-1]["text"] != text:
			out.append({"month": e["month"], "text": text})
	return out


## 跟你之間的一件事，寫成 key（me / past / ref）那種說法
func memo_text(p: Person, e: Dictionary, key: String) -> String:
	var text: String = TalkData.MEMO[e["kind"]][key]
	var item: String = e.get("item", "")
	var took := ""
	if item != "":
		took = ("、拿走你的%s" if key == "ref" else "，拿走了你的%s") % item_name(item)
	text = text.replace("{took}", took).replace("{item}", item_name(item) if item != "" else "東西")
	text = text.replace("{place}", MapData.place_name(e["place"]) if e.get("place", "") != "" else "那裡")
	var t := world.person(e.get("target", ""))
	text = text.replace("{target}", t.display_name if t != null else "那個人")
	var v := world.person(e.get("victim", ""))
	if v != null:
		text = text.replace("{victim}", v.display_name).replace("{rel}", rel(p, v))
	return text.replace("{pron}", p.pron)


## 文字裡換上他、你、在哪；vals 是其他要換的（{key} -> 字）
func fill(text: String, p: Person, vals := {}) -> String:
	var h := hero()
	for k in vals:
		text = text.replace(k, str(vals[k]))
	if p != null:
		text = text.replace("{name}", p.display_name).replace("{pron}", p.pron)
		text = text.replace("{noun}", WeaponData.get_def(p.weapon).get("noun", "兵器")).replace("{look}", look(p.weapon))
	text = text.replace("{me}", h.display_name).replace("{my}", WeaponData.get_def(h.weapon).get("noun", "兵器"))
	return text.replace("{place}", MapData.place_name(h.location))


## victim 是 p 的誰
func rel(p: Person, victim: Person) -> String:
	var she := victim.pron == "她"
	match p.relations.get(victim.id, ""):
		"parent":
			return "母親" if she else "父親"
		"child":
			return "女兒" if she else "兒子"
		"master":
			return "師傅"
		"disciple":
			return "徒弟"
		"sibling":
			return "姊妹" if she else "兄弟"
		"boss":
			return "老大"
		"follower":
			return "兄弟"
		"spouse":
			return "妻子" if she else "丈夫"
	if victim.school != "" and victim.school == p.school:
		return "同門"
	return "朋友"


## 要比劍的理由：強者榜上誰在前面
func rank_line(p: Person) -> String:
	var r := world.ranking()
	var me := r.find(hero())
	var them := r.find(p)
	if me >= 0 and (them < 0 or me < them):
		return TalkData.RANK["ahead"]
	if them >= 0:
		return TalkData.RANK["behind"]
	return TalkData.RANK["none"]


## 他為什麼要你去對付 target
func reason(p: Person, target: Person) -> String:
	var why: Dictionary = p.grudge_why.get(target.id, {})
	var custom: Dictionary = PeopleData.PEOPLE.get(p.id, {}).get("why", {})
	if custom.has(target.id):
		return custom[target.id]
	var kind: String = why.get("kind", "other")
	var text: String = TalkData.REASON.get(kind, TalkData.REASON["other"])
	var v := world.person(why.get("victim", ""))
	if kind == "kin" and v != null:
		text = text.replace("{victim}", v.display_name).replace("{rel}", rel(p, v))
	elif kind == "kin":
		text = TalkData.REASON["other"]
	text = text.replace("{gplace}", MapData.place_name(why["place"]) if why.has("place") else "那裡")
	return text.replace("{target}", target.display_name)


## 東西的名字（你自己的、你拿過的）
func item_name(id: String) -> String:
	if id == "":
		return "東西"
	if BookData.is_book(id):
		var b := BookData.get_def(id)
		return b["name"] if b.has("page_of") else "《%s》" % b["name"]
	return WeaponData.get_def(id)["name"]


## 武器、秘笈的樣子（短的，去掉句號）
func look(item: String) -> String:
	var d: Dictionary = BookData.get_def(item) if BookData.is_book(item) else WeaponData.get_def(item)
	var look: String = d.get("look", d["name"])
	return look.trim_suffix("。").split("，")[0]


func _pick(list: Array) -> String:
	return list[world.rng.randi_range(0, list.size() - 1)]
