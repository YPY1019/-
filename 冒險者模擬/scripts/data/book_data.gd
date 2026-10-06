class_name BookData
extends RefCounted

## 秘笈：只有資料。
## 拿到之後在城裡花時間（月）讀完，就學會裡面的招。從強者身上拿。
## grade：等級，跟境界、招用同一套顏色（GrowthData.GRADE_COLORS），不用看字就知道高低。
## look：還在別人身上時看得到的樣子（委託板）。
## got：拿到的那一刻（{p:from} 是從誰身上拿的）。read：讀完的那一刻。
## realm：境界到了才看得懂（傳給下一個人時，他要先練到這裡）。
## 殘頁：高級的劍譜散成幾張（pages），湊齊了才讀得懂（page_of：是哪一本的）。殘頁上只畫招，不寫筆記。
##   殘頁不會憑空消失：拿著的人死了沒人繼承，就落到別人手上（World._die）。

const BOOKS := {
	# 庭主師弟的劍譜，十年前紅鬃燒村那一夜燒得只剩三疊，散了
	"verdict_book": {
		"name": "王權裁定", "move": "lh_verdict", "grade": 5, "months": 12, "realm": 2,
		"pages": ["verdict_1", "verdict_2", "verdict_3"],
		"complete": "三疊燒焦的紙攤在桌上，邊緣的焦痕對得起來。拼起來是一個人，左手舉盾往前撞，右手的劍從下往上走。\n最上面那張的角落畫著一頭站起來的獅子，底下寫著：王權裁定。",
		"read": "你照著拼好的劍圖比了一百多遍。\n盾往前撞，劍從下往上送，兩隻手要在同一刻到。",
	},
	"verdict_1": {
		"name": "燒焦的劍圖（盾）", "page_of": "verdict_book", "move": "lh_verdict", "grade": 5, "months": 12, "realm": 2,
		"look": "幾張燒焦的紙，畫著一個人舉盾往前撞",
		"desc": "邊緣燒焦了。畫的是一個人左手舉盾、往前撞的步法，一張接一張，沒有字。",
		"got": "你從{p:from}懷裡摸出幾張燒焦的紙。上面畫著一個人舉著盾往前撞，紙上還有乾掉的血。",
	},
	"verdict_2": {
		"name": "燒焦的劍圖（劍）", "page_of": "verdict_book", "move": "lh_verdict", "grade": 5, "months": 12, "realm": 2,
		"look": "幾張燒焦的紙，畫著一把劍從下往上走",
		"desc": "邊緣燒焦了。畫的是右手的劍從腰下往上送，劍尖停在對手的喉下，沒有字。",
		"got": "{p:from}身上有幾張折起來的紙，邊緣燒焦了。攤開來，畫著一把劍從下往上，停在一個人的喉下。",
	},
	"verdict_3": {
		"name": "燒焦的劍圖（步）", "page_of": "verdict_book", "move": "lh_verdict", "grade": 5, "months": 12, "realm": 2,
		"look": "幾張燒焦的紙，畫滿了腳印",
		"desc": "邊緣燒焦了。畫的全是腳印，一前一後，最後一步踩得很深，沒有字。",
		"got": "你在{p:from}身上找到幾張燒焦的紙。上面沒有人，只有一排腳印，最後一步踩得很深。",
	},
	"rain_book": {
		"name": "針雨", "move": "leg_rain", "grade": 4, "months": 18, "realm": 2,
		"look": "一本用皮繩綁著的小冊子",
		"desc": "南方一個決鬥家門派的劍譜。字很小，畫的全是腳步。",
		"got": "{p:from}身上有一本小冊子，用皮繩綁著。翻開來，第一頁畫著一個側身的人，劍尖周圍點滿了小點。",
		"read": "你照著冊子上的腳步，在旅店後院走了一年半。\n最後一頁只畫了一隻手腕，旁邊寫著：放鬆。",
	},
	"siege_book": {
		"name": "崩城", "move": "leg_siege", "grade": 5, "months": 24, "realm": 2,
		"look": "一本封面釘著鐵片的舊劍譜",
		"desc": "守城人的錘法。圖上的人都站著不動，用錘柄接住從頭頂砸下來的東西。",
		"got": "{p:from}的腰帶上掛著一本書，封面釘著鐵片。第一頁寫著：崩城。",
		"read": "書上最後一張圖，一個人用錘柄架住頭頂的大錘，腳下的石板裂了，人沒有退。\n你照著站了兩年。",
	},
}


static func is_book(id: String) -> bool:
	return BOOKS.has(id)


## 殘頁是哪一本的（不是殘頁就是自己）
static func set_of(id: String) -> String:
	return BOOKS[id].get("page_of", id)


## 這幾樣東西湊得成這一本嗎（不是殘頁的一定湊得成）
static func complete(books: Array, id: String) -> bool:
	var s := set_of(id)
	for page in BOOKS[s].get("pages", [s]):
		if not books.has(page):
			return false
	return true


static func get_def(id: String) -> Dictionary:
	return BOOKS[id]


static func color(id: String) -> String:
	return GrowthData.GRADE_COLORS[BOOKS[id]["grade"]]
