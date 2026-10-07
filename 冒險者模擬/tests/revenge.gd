extends SceneTree

## 報仇（開發用）：你殺了埃里克，看烏爾夫什麼時候出城、去哪練、什麼時候回來、什麼時候來找你；
## 再讓他打贏你一次，看殺親之仇是不是會把你殺了。也印出打傷搶過的仇（養好傷就來，不會殺你）。
## 執行：Godot --headless --path . --script res://tests/revenge.gd

func _init() -> void:
	var town := Town.new(4)
	var w := town.world
	var h := town.hero
	h.stats = {"str": 20, "agi": 20}
	h.realm = 3
	h.dies_at = 99999
	h.hp = h.max_hp()
	var ulf := w.person("ulf")
	w.hero_won(w.person("erik"), true)
	var why: Dictionary = ulf.grudge_why[h.id]
	print("你殺了埃里克（第 %d 個月）。烏爾夫：%s，第 %d 個月準備好，去%s練" % [w.month(), why["kind"], why["ready"], MapData.place_name(why["spot"])])
	print("傳話：", w.tidings.map(func(t): return t["kind"]))
	var last := ""
	for i in 48:
		town._pass_months(1)
		if ulf.dead:
			print("第 %d 個月：烏爾夫死了" % w.month())
			break
		var line := "在%s%s%s" % [MapData.place_name(ulf.location), "（路上）" if ulf.travel_left > 0 else "", "，在找你" if ulf.target == h.id else ""]
		if line != last:
			print("第 %d 個月：烏爾夫%s　身體 %d/%d" % [w.month(), line, ulf.body("str"), ulf.body("agi")])
			last = line
		if ulf.target == h.id:
			break
	print("\n== 讓烏爾夫打贏你 ==")
	h.stats = {"str": 10, "agi": 10}
	h.realm = 0
	h.hp = h.max_hp()
	ulf.location = h.location
	ulf.travel_left = 0
	var b := town.start_person("ulf")
	var r := AutoPilot.new().play(b)
	print("結果：", r["outcome"])
	for m in town.finish_person(b):
		print("　", m["text"])
	print("你死了：", h.dead)

	print("\n== 打傷搶過的仇 ==")
	var town2 := Town.new(5)
	var w2 := town2.world
	var hk := w2.person("hakon")
	w2.add_grudge(hk, w2.hero_id, "beaten")
	print("哈康第 %d 個月準備好（現在第 %d 個月），會不會殺你：%s" % [hk.grudge_why[w2.hero_id]["ready"], w2.month(), w2.revenge_lethal(hk)])
	quit()
