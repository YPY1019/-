class_name BookData
extends RefCounted

## 秘笈：只有資料。
## 拿到之後在城裡花天數讀完，就學會裡面的招。從強者身上拿（EnemyData 的 books），或師傅給。
## grade：品級，跟境界用同一套顏色（GrowthData.REALM_COLORS），不用看字就知道高低。
## look：還在別人身上時看得到的樣子（委託板）。
## got：拿到的那一刻。read：讀完的那一刻。

const BOOKS := {
	"sunder_book": {
		"name": "北境裁決", "move": "sunder", "grade": 2, "days": 10,
		"look": "一本舊劍譜，封皮燒焦了一角",
		"desc": "封皮燒焦了一角。裡面是一頁一頁的劍圖，旁邊的字是手寫的。",
		"got": "你從羅德里克懷裡摸出一本書。封皮燒焦了一角，書頁上還有乾掉的血。\n第一頁寫著：北境裁決。",
		"read": "最後一頁的劍圖，你照著比了一百多遍。\n那一劍不找對手的兵器，等對手站不穩的時候，直接劈向人。",
	},
}


static func is_book(id: String) -> bool:
	return BOOKS.has(id)


static func get_def(id: String) -> Dictionary:
	return BOOKS[id]


static func color(id: String) -> String:
	return GrowthData.REALM_COLORS[BOOKS[id]["grade"]]
