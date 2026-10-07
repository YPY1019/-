class_name PeopleData
extends RefCounted

## 世界上有名字的人。只有資料。人數、名字、數字、誰跟誰有關係都是 Claude 的建議，試玩時調。
##
## age：開局時幾歲（後來才來的人：出現時幾歲）。數值是底子，老了會掉（見 LifeData），所以老人的底子寫得比看起來高。life：壽命（歲）的範圍，看不到。arrive：世界的第幾個月才出現（新的會來）。
## style：跟你打的時候用的招和戰報（EnemyData）。hp：血量（沒寫 = 照境界算，年輕人）。
## stats：開局的身體。potential：最多長到哪。growth：年輕時一年大約長幾點（30 歲以後就不長了）。
## weapon / items：拿著的武器、身上帶的東西（武器、秘笈）。learned：會的招（換成玩家角色時用得到）。
## place：開局在哪。home：住在哪（沒寫 = 霜溪城；不出門的時候回這裡）。haunts：會去的幾個地方（villain、duelist 在這幾個地方之間走）。
## school / rank：流派和階位（SchoolData）。role：怎麼過日子（見 Person.role）。follows：follower 跟著誰走（他死了就接手他的人）。boldness：冒險者有多敢（只接強不過自己這麼多的懸賞）。
## relations：跟別人的關係（見 Person.relations）。寫一邊就好，另一邊自動補上。
## bounty：懸賞 {"reward", "text"}（誰、做了什麼、賞多少）。
## vow：到了那個月就去找那個人（例如替師叔報仇）。
## voice：說話的口氣（TalkData.VOICES：rough 粗魯、cold 冷淡、proud 傲慢、plain 老實）。
## start：跟你打的時候登場。warn：你要動他的家人時，他傳來的話。
## avenge：他來找你算帳時說的話。crimes：有懸賞的人在外面做的事（傳聞）。arrive_text：出現時的傳聞。
## why：他跟誰有仇、為什麼（求你幫忙時說的）。

const PEOPLE := {
	# ---------- 有懸賞的人 ----------
	"roderick": {
		"name": "羅德里克", "voice": "proud", "title": "傭兵隊長", "pron": "他", "age": 38, "life": [56, 64],
		"style": "merc_captain", "hp": 450, "stats": {"str": 20, "agi": 20}, "potential": {"str": 20, "agi": 20}, "growth": 0.0,
		"weapon": "red_fang", "learned": ["knee", "fallstone", "deflect", "triple", "needle"], "items": ["verdict_1"], "place": "wheat", "haunts": ["wheat", "relay", "bridge"],
		"role": "villain",
		"bounty": {"reward": 300, "text": "傭兵團「紅鬃」洗劫了東邊的兩個村子。商會懸賞隊長羅德里克的人頭。"},
		"start": ["一個獨眼的高個子從人群裡走出來，拔出一把暗紅色的劍：「就是你要拿我的人頭？」"],
		"crimes": ["紅鬃的人在{place}搶了收稅官的馬車。", "聽說紅鬃的傭兵在{place}一帶放火燒了一座穀倉。", "{place}的商隊被紅鬃攔下來，貨被拿走了一半。"],
	},
	"magnus": {
		"name": "馬格努斯", "voice": "rough", "title": "紅鬃副隊長", "pron": "他", "age": 30, "life": [52, 62],
		"style": "merc_captain", "hp": 200, "stats": {"str": 16, "agi": 16}, "potential": {"str": 19, "agi": 18}, "growth": 0.8,
		"weapon": "knight_sword", "learned": ["knee", "fallstone", "triple"], "items": [], "place": "wheat",
		"role": "follower", "follows": "roderick", "relations": {"roderick": "boss"},
		"start": ["一個臉上有疤的傭兵拔出長劍，往你走過來：「紅鬃的事，你也敢管？」"],
		"avenge": "「隊長的劍，該回到紅鬃手上。」",
		"crimes": ["紅鬃的人又在{place}鬧事，帶頭的是一個臉上有疤的傢伙。"],
	},
	"ulf": {
		"name": "烏爾夫", "voice": "rough", "title": "劫掠者", "school": "frostbear", "rank": 2, "pron": "他", "age": 33, "life": [50, 60],
		"style": "raider", "hp": 480, "stats": {"str": 21, "agi": 15}, "potential": {"str": 21, "agi": 15}, "growth": 0.0,
		"weapon": "gatebreaker", "learned": ["fb_cleave", "fb_hug", "fb_whirl", "fb_hook", "fallstone"], "items": [], "place": "coast", "haunts": ["coast", "old_wall", "lodge"],
		"role": "villain",
		"bounty": {"reward": 300, "text": "北邊海岸的漁村被燒了兩個。劫掠者烏爾夫帶著手下往內陸來了，沿岸的領主懸賞他。"},
		"start": ["一個滿臉紅鬍子的大漢把斧頭從木樁上拔出來，咧嘴一笑：「又一個。」"],
		"warn": "一個北方口音的水手在旅店門口攔住你，塞給你一塊刻了字的木片：「烏爾夫說，埃里克是他弟弟。你動他，他就把你的城也燒了。」",
		"avenge": "「埃里克在哪裡死的，你就在哪裡死。」",
		"crimes": ["{place}那邊又有人被搶，聽說是一群紅鬍子的北方人幹的。", "有人在{place}看見烏爾夫，斧頭上還有血。"],
	},
	"erik": {
		"name": "埃里克", "voice": "rough", "title": "", "school": "frostbear", "rank": 1, "pron": "他", "age": 22, "life": [48, 60],
		"style": "raider", "hp": 220, "stats": {"str": 15, "agi": 13}, "potential": {"str": 20, "agi": 16}, "growth": 1.2,
		"weapon": "hand_axe", "learned": ["fb_cleave", "fb_hug", "knee"], "items": [], "place": "coast",
		"role": "follower", "follows": "ulf", "relations": {"ulf": "sibling"},
		"bounty": {"reward": 150, "text": "劫掠者埃里克在北岸殺了兩個漁夫。他是烏爾夫的弟弟。漁村的人湊了一筆錢懸賞他。"},
		"start": ["一個年輕的北方人甩了甩手斧，笑得跟他哥哥一模一樣：「我哥說，砍人要先砍腿。」"],
		"avenge": "「我哥的斧頭，我要拿回來。」",
	},
	"yvette": {
		"name": "伊薇特", "voice": "proud", "title": "決鬥家", "pron": "她", "age": 27, "life": [50, 64],
		"style": "duelist", "hp": 370, "stats": {"str": 15, "agi": 22}, "potential": {"str": 16, "agi": 23}, "growth": 0.6,
		"weapon": "rapier", "learned": ["deflect", "needle", "dust", "leg_rain"], "items": ["rain_book"], "place": "frost", "haunts": ["frost", "wheat", "relay"],
		"role": "duelist",
		"bounty": {"reward": 350, "text": "南方來的決鬥家伊薇特在城裡殺了三個貴族子弟，說是決鬥，沒人告得了她。死者的家族私下懸賞。"},
		"start": ["一個穿深色外套的女人等在那裡，右手細劍，左手短劍。她把劍尖往地上點了點：「你是來決鬥的？」"],
		"challenge": "一個穿深色外套的女人在旅店門口等你。她把一隻手套丟在你腳邊：「聽說你很能打。」",
	},
	"black_knight": {
		"name": "黑騎士", "voice": "cold", "title": "", "pron": "他", "age": 35, "life": [52, 62],
		"style": "black_knight", "hp": 560, "stats": {"str": 23, "agi": 21}, "potential": {"str": 23, "agi": 21}, "growth": 0.0,
		"weapon": "knell", "learned": ["fallstone", "triple", "needle", "deflect", "knee"], "items": [], "place": "relay", "haunts": ["relay"],
		"role": "villain",
		"bounty": {"reward": 400, "text": "被逐出騎士團的黑騎士佔了舊王家驛站，往來的信使一個都沒回來。騎士團私下發的懸賞。"},
		"start": ["驛站中間坐著一個穿黑甲的騎士，膝上橫著一把黑色的大劍。他站起來的時候，劍身嗡嗡地響。"],
		"crimes": ["又一個往王都送信的信使沒有回來。最後有人看見他，是在舊王家驛站附近。"],
	},
	"varen": {
		"name": "瓦倫", "voice": "proud", "title": "叛將", "pron": "他", "age": 45, "life": [56, 64],
		"style": "rebel_lord", "hp": 960, "stats": {"str": 35, "agi": 29}, "potential": {"str": 35, "agi": 29}, "growth": 0.0,
		"weapon": "warhammer", "learned": ["fallstone", "triple", "knee", "deflect", "leg_siege"], "items": ["siege_book"], "place": "fortress", "haunts": ["fortress"],
		"role": "villain",
		"bounty": {"reward": 600, "text": "叛將瓦倫佔了山口的舊要塞，往來的商隊都要給他抽成。領主派兵打了兩次都沒打下來，只好懸賞他的命。"},
		"start": ["一個穿全身鎧甲的男人從城門走出來，左手的塔盾比你還寬。他把戰錘往地上一頓：「一個人來？」"],
		"crimes": ["領主又派兵去打山口要塞，又敗回來了。", "山口要塞往南的商路，抽成又漲了。"],
	},
	"bran": {
		"name": "布蘭", "voice": "rough", "title": "", "pron": "他", "age": 24, "life": [50, 62],
		"style": "bandit_leader", "hp": 200, "stats": {"str": 16, "agi": 14}, "potential": {"str": 20, "agi": 17}, "growth": 0.8,
		"weapon": "bandit_blade", "learned": ["dust", "knee", "fallstone"], "items": [], "place": "south_road", "haunts": ["south_road", "bridge", "pasture"],
		"role": "villain", "relations": {"grayson": "parent"},
		"bounty": {"reward": 200, "text": "往南的山道上有盜匪攔路搶劫，頭目叫布蘭。商會懸賞他。"},
		"start": ["一個年輕人扛著大刀擋在路中間，臉跟葛雷森有幾分像：「把錢留下，人可以走。」"],
		"crimes": ["{place}又有商隊被搶了，帶頭的是個扛大刀的年輕人。", "布蘭的人在{place}打傷了一個收稅的。"],
	},

	# ---------- 冒險者 ----------
	"hakon": {
		"name": "哈康", "voice": "plain", "title": "冒險者", "pron": "他", "age": 36, "life": [52, 62],
		"style": "deserter", "hp": 220, "stats": {"str": 19, "agi": 18}, "potential": {"str": 19, "agi": 18}, "growth": 0.0,
		"weapon": "knight_sword", "learned": ["knee", "fallstone", "shed", "deflect"], "items": [], "place": "frost",
		"role": "hunter", "boldness": 0.3,
		"start": ["哈康把舊圓盾往前一擋，長劍搭在盾邊：「你想清楚了？」"],
	},
	"sira": {
		"name": "席拉", "voice": "plain", "title": "冒險者", "pron": "她", "age": 21, "life": [44, 56],
		"style": "merc_captain", "stats": {"str": 14, "agi": 17}, "potential": {"str": 20, "agi": 24}, "growth": 1.6,
		"weapon": "steel_sword", "learned": ["knee", "dust"], "items": [], "place": "frost",
		"role": "hunter", "boldness": 1.0,
		"start": ["席拉把紅頭巾綁緊，拔出劍：「我早就想跟你打一場了。」"],
	},
	"oskar": {
		"name": "奧斯卡", "voice": "proud", "title": "劍術教師", "pron": "他", "age": 41, "life": [54, 64],
		"style": "old_captain", "hp": 300, "stats": {"str": 20, "agi": 20}, "potential": {"str": 20, "agi": 20}, "growth": 0.0,
		"weapon": "knight_sword", "learned": ["deflect", "needle", "triple", "knee"], "items": ["verdict_3"], "place": "frost",
		"role": "hunter", "boldness": 0.0, "vow": {"target": "yvette", "month": 8},
		"start": ["奧斯卡脫下手套，慢慢拔出長劍：「我教人用劍三十年了。」"],
	},
	"leonard": {
		"name": "雷納德", "voice": "cold", "title": "白手", "pron": "他", "age": 31, "life": [56, 66], "arrive": 100,
		"style": "old_captain", "hp": 360, "stats": {"str": 20, "agi": 20}, "potential": {"str": 21, "agi": 21}, "growth": 0.3,
		"weapon": "knight_sword", "learned": ["deflect", "needle", "triple", "knee", "fallstone"], "items": [], "place": "frost",
		"role": "hunter", "boldness": 0.5,
		"start": ["雷納德把白手套一根一根摘下來，收進懷裡，才拔出劍。"],
		"arrive_text": "城裡來了一個戴白手套的騎士，在公會的懸賞板前面站了很久。",
	},

	# ---------- 獅心劍庭 ----------
	"master": {
		"name": "埃德溫", "voice": "plain", "title": "庭主", "pron": "他", "age": 52, "school": "lionheart", "rank": 3, "life": [66, 74],
		"style": "master", "hp": 999, "stats": {"str": 21, "agi": 22}, "potential": {"str": 21, "agi": 22}, "growth": 0.0,
		"weapon": "old_sword", "learned": ["lh_cross", "lh_pommel", "lh_half", "lh_advance", "lh_bind", "knee", "deflect"], "items": [], "place": "frost",
		"role": "master",
	},
	"matthias": {
		"name": "馬提亞斯", "voice": "proud", "title": "大師兄", "pron": "他", "age": 24, "life": [44, 56],
		"style": "master", "stats": {"str": 15, "agi": 15}, "potential": {"str": 21, "agi": 20}, "growth": 1.0,
		"weapon": "steel_sword", "learned": ["lh_cross", "lh_pommel", "lh_half", "knee", "fallstone"], "items": [], "school": "lionheart", "rank": 2,
		"place": "frost", "role": "youth", "relations": {"master": "master"}, "vow": {"target": "roderick", "month": 40},
		"start": ["馬提亞斯擺出獅心劍庭起手的架勢，劍尖一動不動：「庭主教的，我一招都沒忘。」"],
		"avenge": "「庭主待你不薄。」",
	},
	"allen": {
		"name": "艾倫", "voice": "plain", "title": "", "school": "lionheart", "rank": 1, "pron": "他", "age": 15, "life": [36, 44],
		"style": "master", "stats": {"str": 10, "agi": 10}, "potential": {"str": 20, "agi": 19}, "growth": 1.2,
		"weapon": "old_sword", "learned": ["lh_cross"], "items": [],
		"place": "frost", "role": "youth", "relations": {"master": "master"},
		"start": ["艾倫握著劍的手在發抖，還是站穩了：「我不會讓你過去的。」"],
		"avenge": "「我練到今天，就是為了這一天。」",
	},
	"lina": {
		"name": "莉娜", "voice": "cold", "title": "", "pron": "她", "age": 14, "life": [36, 44],
		"style": "duelist", "stats": {"str": 9, "agi": 11}, "potential": {"str": 17, "agi": 22}, "growth": 1.2,
		"weapon": "old_sword", "learned": [], "items": [],
		"place": "pasture", "home": "pasture", "role": "youth",
		"start": ["莉娜咬著嘴唇，把劍舉起來。"],
	},

	# ---------- 其他 ----------
	"grayson": {
		"name": "葛雷森", "voice": "cold", "title": "老衛隊長", "pron": "他", "age": 56, "life": [62, 68],
		"style": "old_captain", "hp": 620, "stats": {"str": 29, "agi": 30}, "potential": {"str": 29, "agi": 30}, "growth": 0.0,
		"weapon": "nightwatch", "learned": ["deflect", "needle", "triple", "knee", "shed"], "items": ["verdict_2"], "place": "wheat", "home": "wheat",
		"role": "settled",
		"start": ["葛雷森慢慢拔出長劍，劍的護手很寬，磨得發亮：「我年輕的時候，也是這樣一個人去找別人麻煩。」"],
		"warn": "葛雷森在旅店的角落叫住你。他沒有抬頭，看著杯子裡的酒：「布蘭是我兒子。他做的事，我會去管。」\n他停了一下。「別動他。」",
		"avenge": "葛雷森把長劍從鞘裡拔出來，劍的護手很寬：「我說過，別動他。」",
	},

	# ---------- 後來才來的人 ----------
	"sigurd": {
		"name": "西格德", "voice": "rough", "title": "灰狼", "pron": "他", "age": 34, "life": [50, 60], "arrive": 30,
		"style": "bandit_leader", "hp": 260, "stats": {"str": 19, "agi": 17}, "potential": {"str": 20, "agi": 18}, "growth": 0.3,
		"weapon": "bandit_blade", "learned": ["dust", "knee", "fallstone", "triple"], "items": [], "place": "pasture", "haunts": ["pasture", "lodge", "south_road"],
		"role": "villain",
		"bounty": {"reward": 250, "text": "一夥人披著灰狼皮，在牧羊村一帶搶羊、搶人。頭目叫西格德，人稱「灰狼」。牧場主人們懸賞他。"},
		"start": ["一個披著灰狼皮的男人從石牆後面站起來，舔了舔刀口。"],
		"arrive_text": "牧羊村那邊開始有人搶羊，聽說帶頭的披著一張灰狼皮。",
		"crimes": ["{place}又有羊被搶了，牧羊人被打斷了一條腿。", "灰狼的人在{place}燒了一間農舍。"],
	},
	"ora": {
		"name": "歐拉", "voice": "cold", "title": "", "school": "frostbear", "rank": 1, "pron": "她", "age": 17, "life": [36, 44], "arrive": 48,
		"style": "raider", "stats": {"str": 13, "agi": 13}, "potential": {"str": 21, "agi": 19}, "growth": 1.4,
		"weapon": "hand_axe", "learned": ["fb_cleave"], "items": [], "place": "frost",
		"role": "youth", "grudges": ["ulf"], "why": {"ulf": "烏爾夫燒了我們的村子。我父母都在裡面。"},
		"start": ["歐拉握緊{weapon}，一句話都沒說。"],
		"arrive_text": "城裡來了一個從北岸逃出來的女孩，背著一把手斧，到處問烏爾夫在哪裡。",
	},
	"hogg": {
		"name": "霍格", "voice": "rough", "title": "黑帆", "pron": "他", "age": 36, "life": [50, 60], "arrive": 120,
		"style": "raider", "hp": 340, "stats": {"str": 22, "agi": 17}, "potential": {"str": 22, "agi": 17}, "growth": 0.0,
		"weapon": "hand_axe", "learned": ["fallstone", "triple", "dust", "shed"], "items": [], "place": "coast", "haunts": ["coast", "old_wall", "lodge"],
		"role": "villain",
		"bounty": {"reward": 350, "text": "掛黑帆的船在北岸靠了岸，船長霍格帶人燒了兩座村子。沿岸的領主懸賞他。"},
		"start": ["一個少了兩根手指的男人把斧頭在手裡轉了一圈：「北岸是我的。」"],
		"arrive_text": "北岸來了一艘掛黑帆的船。",
		"crimes": ["{place}有一座村子被燒了，有人看見海上掛著黑帆。"],
	},
	"tim": {
		"name": "提姆", "voice": "plain", "title": "", "pron": "他", "age": 14, "life": [36, 44], "arrive": 110,
		"style": "master", "stats": {"str": 9, "agi": 10}, "potential": {"str": 19, "agi": 20}, "growth": 1.3,
		"weapon": "old_sword", "learned": [], "items": [], "place": "frost",
		"role": "youth",
		"start": ["提姆撿起一根木棍，擋在你面前。"],
		"arrive_text": "城門口多了一個幫人看馬的孤兒，叫提姆。",
	},
}

## 佔地方的壞人（2026-10-07 決定：人一律是世界上的人，委託板只留野獸和怪物）。
## 每一種一次只有一個：開局就有，死了過一陣子會有新的人來佔（名字、身體每次不一樣）。都有懸賞。
## style：EnemyData 的打法（身體、血、招從那裡來）；place：佔在哪；weapon：拿什麼；reward：懸賞多少；
## toll：向過路的人收多少錢（只有本來就在收錢的人）；bounty：懸賞板上的字（{name} 他的名字）；arrive：有人來佔的傳聞；crimes：做壞事的傳聞
const OUTLAWS := {
	"bandit_leader": {"title": "盜匪頭子", "place": "wheat", "weapon": "bandit_blade", "reward": 100, "voice": "rough",
		"bounty": "往麥田鎮的路上有一夥盜匪攔路搶劫，頭目叫{name}。鎮長懸賞他。",
		"arrive": "往麥田鎮的路上開始有人攔路搶劫，帶頭的扛著一把大刀。",
		"crimes": ["{place}又有人被搶了，帶頭的扛著一把大刀。", "麥田鎮的鎮長又往公會加了一筆錢。"]},
	"deserter": {"title": "逃兵騎士", "place": "bridge", "weapon": "knight_sword", "reward": 150, "voice": "cold", "toll": 30,
		"bounty": "一個叫{name}的逃兵騎士佔了石橋，向過路的人收過路費。領主的管家懸賞他。",
		"arrive": "石橋的橋頭有人收起了過路費。收錢的人穿著一身破鐵甲，說是從戰場上回來的。",
		"crimes": ["有個商人不肯在石橋付錢，被推進了河裡。"]},
	"poacher": {"title": "盜獵人", "place": "lodge", "weapon": "hunting_knife", "reward": 140, "voice": "cold",
		"bounty": "獵人小屋附近有人下套子盜獵，叫{name}。獵人公會派人去看過一次，那個人沒回來。",
		"arrive": "獵人小屋附近的林子裡，多了很多不是獵人下的套子。",
		"crimes": ["獵人小屋那邊又有一個獵人沒回來。"]},
	"smuggler": {"title": "走私頭子", "place": "coast", "weapon": "cutlass", "reward": 160, "voice": "rough",
		"bounty": "北岸漁村的碼頭有一夥走私的，頭目叫{name}，打傷了收稅的人。稅務官懸賞他。",
		"arrive": "北岸的碼頭，夜裡多了幾條沒掛燈的小船。",
		"crimes": ["北岸漁村又有一個收稅的被打傷了。"]},
	"pikeman": {"title": "逃營的長槍兵", "place": "relay", "weapon": "spear", "reward": 240, "voice": "plain", "toll": 40,
		"bounty": "一個叫{name}的逃營長槍兵佔了舊王家驛站那條路，攔下過路的馬車收錢。驛站的主人懸賞他。",
		"arrive": "舊王家驛站那條路上，有人拄著長槍攔車收錢。",
		"crimes": ["舊王家驛站那條路上，又有一輛馬車被攔了下來。"]},
	"butcher": {"title": "屠夫", "place": "old_wall", "weapon": "cleaver", "reward": 420, "voice": "cold",
		"bounty": "舊城牆的缺口裡住著一個屠夫，叫{name}。附近一直有人失蹤。城主親自發的懸賞。",
		"arrive": "舊城牆附近開始有人失蹤。",
		"crimes": ["舊城牆附近又有人失蹤了。"]},
}
## 佔地方的壞人死了，過幾個月會有新的人來佔
const OUTLAW_BACK := [8, 20]
## 佔地方的壞人、攔路的小賊的名字
const OUTLAW_NAMES := [["布魯克", "他"], ["加斯", "他"], ["戴克", "他"], ["萊爾", "他"], ["莫特", "他"], ["佩恩", "他"], ["洛克", "他"],
	["瓦德", "他"], ["黑爾", "他"], ["克林", "他"], ["雷夫", "他"], ["托爾", "他"], ["維克", "他"], ["葛倫", "他"], ["博爾", "他"],
	["薩克斯", "他"], ["德倫", "他"], ["哈根", "他"], ["柯特", "他"], ["斯坦", "他"], ["格里姆", "他"], ["巴特", "他"], ["鄧肯", "他"], ["費茲", "他"]]

## 換人接著玩時，沒有夠年輕的人可以選，就從這裡找一個剛到城裡的年輕人
## 世界上的人的孩子
const CHILD_NAMES := [["托馬斯", "他"], ["艾莉", "她"], ["盧卡", "他"], ["瑪莉安", "她"], ["約翰", "他"], ["蘿絲", "她"], ["彼得", "他"], ["安娜", "她"],
	["班", "他"], ["克拉拉", "她"], ["菲利克斯", "他"], ["朵拉", "她"], ["馬丁", "他"], ["伊莎", "她"], ["西蒙", "他"], ["露西", "她"]]
const NEWCOMER_NAMES := [["漢斯", "他"], ["瑪塔", "她"], ["奧托", "他"], ["蓋兒", "她"], ["尼爾斯", "他"], ["艾瑪", "她"],
	["卡爾", "他"], ["希達", "她"], ["魯道夫", "他"], ["布麗塔", "她"], ["阿諾", "他"], ["英格", "她"], ["戈特", "他"], ["瑪格", "她"],
	["沃爾夫", "他"], ["蒂爾達", "她"], ["恩斯特", "他"], ["阿格妮", "她"], ["貝恩", "他"], ["蘇珊", "她"]]
