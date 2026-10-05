class_name BookData
extends RefCounted

## 秘笈：只有資料。
## 拿到之後在城裡花時間（月）讀完，就學會裡面的招。從強者身上拿（EnemyData 的 books），或師傅給。
## grade：品級，跟境界用同一套顏色（GrowthData.REALM_COLORS），不用看字就知道高低。
## look：還在別人身上時看得到的樣子（委託板）。
## got：拿到的那一刻。read：讀完的那一刻。

const BOOKS := {
	"sunder_book": {
		"name": "北境裁決", "move": "sunder", "grade": 2, "months": 12,
		"look": "一本舊劍譜，封皮燒焦了一角",
		"desc": "封皮燒焦了一角。裡面是一頁一頁的劍圖，旁邊的字是手寫的。",
		"got": "你從羅德里克懷裡摸出一本書。封皮燒焦了一角，書頁上還有乾掉的血。\n第一頁寫著：北境裁決。",
		"read": "最後一頁的劍圖，你照著比了一百多遍。\n那一劍不找對手的兵器，等對手站不穩的時候，直接劈向人。",
	},
	"falcon_book": {
		"name": "隼之一刺", "move": "falcon", "grade": 2, "months": 18,
		"look": "一本用皮繩綁著的小冊子",
		"desc": "南方一個決鬥家門派的劍譜。字很小，畫的全是腳步。",
		"got": "伊薇特的外套內袋裡有一本小冊子，用皮繩綁著。翻開來，第一頁畫著一隻往下俯衝的隼。",
		"read": "你照著冊子上的腳步，在旅店後院走了一年半。\n最後一頁只畫了一個人側著身子，劍尖從對手的盾邊刺了進去。",
	},
	"bastion_book": {
		"name": "不落要塞", "move": "bastion", "grade": 2, "months": 24,
		"look": "一本封面釘著鐵片的舊劍譜",
		"desc": "守城人的劍術。圖上的人都站著不動，用劍接住從頭頂砸下來的東西。",
		"got": "瓦倫的腰帶上掛著一本書，封面釘著鐵片。第一頁寫著：不落要塞。",
		"read": "書上最後一張圖，一個人用劍架住頭頂的大錘，腳下的石板裂了，人沒有退。\n你照著站了兩年。",
	},
}


static func is_book(id: String) -> bool:
	return BOOKS.has(id)


static func get_def(id: String) -> Dictionary:
	return BOOKS[id]


static func color(id: String) -> String:
	return GrowthData.REALM_COLORS[BOOKS[id]["grade"]]
