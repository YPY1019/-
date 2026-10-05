class_name PlayLog
extends RefCounted

## 試玩紀錄檔：城裡發生的事和每一場戰鬥，一行一行寫進文字檔，給 Claude 看怎麼玩的。
## 從編輯器執行時寫在專案的「試玩紀錄」資料夾，一次遊戲一個檔案。

const DIR_NAME := "試玩紀錄"

var path := ""


func _init() -> void:
	var base := "res://" if OS.has_feature("editor") else "user://"
	var dir := ProjectSettings.globalize_path(base + DIR_NAME)
	DirAccess.make_dir_recursive_absolute(dir)
	# 讓 Godot 不要掃這個資料夾
	if not FileAccess.file_exists(dir + "/.gdignore"):
		FileAccess.open(dir + "/.gdignore", FileAccess.WRITE)
	var t := Time.get_datetime_dict_from_system()
	path = "%s/%04d-%02d-%02d_%02d%02d%02d.txt" % [dir, t["year"], t["month"], t["day"], t["hour"], t["minute"], t["second"]]


func write(lines: Array) -> void:
	if lines.is_empty():
		return
	var f: FileAccess
	if FileAccess.file_exists(path):
		f = FileAccess.open(path, FileAccess.READ_WRITE)
		f.seek_end()
	else:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	for line in lines:
		f.store_line(str(line))


## 城鎮的訊息清單
func messages(msgs: Array) -> void:
	write(msgs.map(func(m): return m["text"]))


## 你現在的狀態，一行
func status(h: Adventurer) -> void:
	write(["【第 %d 天】%d 銀　血 %d/%d　%s（瓶頸 %d）　力量 %d　敏捷 %d　招：%s" % [
		h.day, h.money, h.hp, h.max_hp(), h.realm_text(), h.cap(), h.stats["str"], h.stats["agi"],
		"、".join(h.learned.map(func(id): return MoveData.MOVES[id]["name"]))]])


## 開打：雙方數值
func battle_start(title: String, b: Battle) -> void:
	var me := b.allies[0]
	var foe := b.enemies[0]
	write(["", "======== %s ========" % title,
		"你：力量 %d、敏捷 %d、血 %d/%d　｜　%s：力量 %d、敏捷 %d、血 %d" % [
			me.stats["str"], me.stats["agi"], me.hp, me.max_hp, foe.display_name, foe.stats["str"], foe.stats["agi"], foe.max_hp]])


## 打完：整場的紀錄和結果
func battle_end(b: Battle) -> void:
	var me := b.allies[0]
	write(b.record)
	write(["======== 結果：%s，剩血 %d/%d，%d 回合 ========" % [b.outcome, me.hp, me.max_hp, b.round_no]])
