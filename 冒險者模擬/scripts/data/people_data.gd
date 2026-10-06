class_name PeopleData
extends RefCounted

## 世界上有名字的人。只有資料。人數、名字、數字、誰跟誰有關係都是 Claude 的建議，試玩時調。
##
## age：開局時幾歲（後來才來的人：出現時幾歲）。數值是底子，老了會掉（見 LifeData），所以老人的底子寫得比看起來高。life：壽命（歲）的範圍，看不到。arrive：世界的第幾個月才出現（新的會來）。
## style：跟你打的時候用的招和戰報（EnemyData）。hp：血量（沒寫 = 照境界算，年輕人）。
## stats：開局的身體。potential：最多長到哪。growth：年輕時一年大約長幾點（30 歲以後就不長了）。
## weapon / items：拿著的武器、身上帶的東西（武器、秘笈）。learned：會的招（換成玩家角色時用得到）。
## place：開局在哪。haunts：會去的幾個地方（villain、duelist 在這幾個地方之間走）。
## role：怎麼過日子（見 Person.role）。follows：follower 跟著誰走（他死了就接手他的人）。boldness：冒險者有多敢（只接強不過自己這麼多的懸賞）。
## relations：跟別人的關係（見 Person.relations）。寫一邊就好，另一邊自動補上。
## bounty：懸賞 {"reward", "text"}（誰、做了什麼、賞多少）。
## vow：到了那個月就去找那個人（例如替師叔報仇）。
## blurb：人物面板上看得到的樣子。start：跟你打的時候登場。warn：你要動他的家人時，他傳來的話。
## avenge：他來找你算帳時說的話。crimes：有懸賞的人在外面做的事（傳聞）。arrive_text：出現時的傳聞。

const PEOPLE := {
	# ---------- 有懸賞的人 ----------
	"roderick": {
		"name": "羅德里克", "title": "傭兵隊長", "pron": "他", "age": 38, "life": [56, 64],
		"style": "merc_captain", "hp": 400, "stats": {"str": 20, "agi": 20}, "potential": {"str": 20, "agi": 20}, "growth": 0.0,
		"weapon": "red_fang", "items": ["sunder_book"], "place": "wheat", "haunts": ["wheat", "relay", "bridge"],
		"role": "villain",
		"bounty": {"reward": 300, "text": "傭兵團「紅鬃」洗劫了東邊的兩個村子。商會懸賞隊長羅德里克的人頭。"},
		"blurb": "傭兵團「紅鬃」的隊長。獨眼，個子很高，身邊總跟著十幾個傭兵。",
		"start": ["一個獨眼的高個子從人群裡走出來，拔出一把暗紅色的劍：「就是你要拿我的人頭？」"],
		"crimes": ["紅鬃的人在{place}搶了收稅官的馬車。", "聽說紅鬃的傭兵在{place}一帶放火燒了一座穀倉。", "{place}的商隊被紅鬃攔下來，貨被拿走了一半。"],
	},
	"magnus": {
		"name": "馬格努斯", "title": "紅鬃副隊長", "pron": "他", "age": 30, "life": [52, 62],
		"style": "merc_captain", "hp": 200, "stats": {"str": 16, "agi": 16}, "potential": {"str": 19, "agi": 18}, "growth": 0.8,
		"weapon": "knight_sword", "items": [], "place": "wheat",
		"role": "follower", "follows": "roderick", "relations": {"roderick": "boss"},
		"blurb": "紅鬃的副隊長。臉上有一道從額頭到下巴的疤。羅德里克走到哪，他跟到哪。",
		"start": ["一個臉上有疤的傭兵拔出長劍，往你走過來：「隊長的劍，你也配拿？」"],
		"avenge": "「隊長的劍，該回到紅鬃手上。」",
		"crimes": ["紅鬃的人又在{place}鬧事，帶頭的是一個臉上有疤的傢伙。"],
	},
	"ulf": {
		"name": "烏爾夫", "title": "劫掠者", "pron": "他", "age": 33, "life": [50, 60],
		"style": "raider", "hp": 440, "stats": {"str": 21, "agi": 15}, "potential": {"str": 21, "agi": 15}, "growth": 0.0,
		"weapon": "gatebreaker", "items": [], "place": "coast", "haunts": ["coast", "old_wall", "lodge"],
		"role": "villain",
		"bounty": {"reward": 300, "text": "北邊海岸的漁村被燒了兩個。劫掠者烏爾夫帶著手下往內陸來了，沿岸的領主懸賞他。"},
		"blurb": "從北邊海上來的劫掠者，滿臉紅鬍子，扛著一把雙刃大斧。打起來不要命。",
		"start": ["一個滿臉紅鬍子的大漢把斧頭從木樁上拔出來，咧嘴一笑：「又一個。」"],
		"warn": "一個北方口音的水手在旅店門口攔住你，塞給你一塊刻了字的木片：「烏爾夫說，埃里克是他弟弟。你動他，他就把你的城也燒了。」",
		"avenge": "「埃里克在哪裡死的，你就在哪裡死。」",
		"crimes": ["{place}那邊又有人被搶，聽說是一群紅鬍子的北方人幹的。", "有人在{place}看見烏爾夫，斧頭上還有血。"],
	},
	"erik": {
		"name": "埃里克", "title": "", "pron": "他", "age": 22, "life": [48, 60],
		"style": "raider", "hp": 220, "stats": {"str": 15, "agi": 13}, "potential": {"str": 20, "agi": 16}, "growth": 1.2,
		"weapon": "hand_axe", "items": [], "place": "coast",
		"role": "follower", "follows": "ulf", "relations": {"ulf": "sibling"},
		"bounty": {"reward": 150, "text": "劫掠者埃里克在北岸殺了兩個漁夫。他是烏爾夫的弟弟。漁村的人湊了一筆錢懸賞他。"},
		"blurb": "烏爾夫的弟弟。鬍子還沒長齊，斧頭已經用得很兇。",
		"start": ["一個年輕的北方人甩了甩手斧，笑得跟他哥哥一模一樣：「我哥說，砍人要先砍腿。」"],
		"avenge": "「我哥的斧頭，我要拿回來。」",
	},
	"yvette": {
		"name": "伊薇特", "title": "決鬥家", "pron": "她", "age": 27, "life": [50, 64],
		"style": "duelist", "hp": 340, "stats": {"str": 15, "agi": 22}, "potential": {"str": 16, "agi": 23}, "growth": 0.6,
		"weapon": "rapier", "items": ["falcon_book"], "learned": ["falcon"], "place": "frost", "haunts": ["frost", "wheat", "relay"],
		"role": "duelist",
		"bounty": {"reward": 350, "text": "南方來的決鬥家伊薇特在城裡殺了三個貴族子弟，說是決鬥，沒人告得了她。死者的家族私下懸賞。"},
		"blurb": "南方來的決鬥家，右手細劍，左手短劍。據說沒輸過。哪裡有高手，她就往哪裡去。",
		"start": ["一個穿深色外套的女人等在那裡，右手細劍，左手短劍。她把劍尖往地上點了點：「你是來決鬥的？」"],
		"challenge": "一個穿深色外套的女人在旅店門口等你。她把一隻手套丟在你腳邊：「聽說你很能打。」",
	},
	"black_knight": {
		"name": "黑騎士", "title": "", "pron": "他", "age": 35, "life": [52, 62],
		"style": "black_knight", "hp": 520, "stats": {"str": 23, "agi": 21}, "potential": {"str": 23, "agi": 21}, "growth": 0.0,
		"weapon": "knell", "items": [], "place": "relay", "haunts": ["relay"],
		"role": "villain",
		"bounty": {"reward": 400, "text": "被逐出騎士團的黑騎士佔了舊王家驛站，往來的信使一個都沒回來。騎士團私下發的懸賞。"},
		"blurb": "全身黑甲的騎士，被騎士團趕了出來。沒人知道他的名字。背著一把很寬的大劍。",
		"start": ["驛站中間坐著一個穿黑甲的騎士，膝上橫著一把黑色的大劍。他站起來的時候，劍身嗡嗡地響。"],
		"crimes": ["又一個往王都送信的信使沒有回來。最後有人看見他，是在舊王家驛站附近。"],
	},
	"varen": {
		"name": "瓦倫", "title": "叛將", "pron": "他", "age": 45, "life": [56, 64],
		"style": "rebel_lord", "hp": 960, "stats": {"str": 35, "agi": 29}, "potential": {"str": 35, "agi": 29}, "growth": 0.0,
		"weapon": "warhammer", "items": ["bastion_book"], "learned": ["bastion"], "place": "fortress", "haunts": ["fortress"],
		"role": "villain",
		"bounty": {"reward": 600, "text": "叛將瓦倫佔了山口的舊要塞，往來的商隊都要給他抽成。領主派兵打了兩次都沒打下來，只好懸賞他的命。"},
		"blurb": "背叛了領主、佔了山口要塞的將軍。左手一面塔盾，右手一把戰錘。手下有兩百個兵。",
		"start": ["一個穿全身鎧甲的男人從城門走出來，左手的塔盾比你還寬。他把戰錘往地上一頓：「一個人來？」"],
		"crimes": ["領主又派兵去打山口要塞，又敗回來了。", "山口要塞往南的商路，抽成又漲了。"],
	},
	"bran": {
		"name": "布蘭", "title": "", "pron": "他", "age": 24, "life": [50, 62],
		"style": "bandit_leader", "hp": 200, "stats": {"str": 16, "agi": 14}, "potential": {"str": 20, "agi": 17}, "growth": 0.8,
		"weapon": "bandit_blade", "items": [], "place": "south_road", "haunts": ["south_road", "bridge", "pasture"],
		"role": "villain", "relations": {"grayson": "parent"},
		"bounty": {"reward": 200, "text": "往南的山道上有盜匪攔路搶劫，頭目叫布蘭。商會懸賞他。"},
		"blurb": "南山道上的盜匪頭目。年輕，刀使得很兇。據說是葛雷森的兒子，兩個人好幾年沒說過話。",
		"start": ["一個年輕人扛著大刀擋在路中間，臉跟葛雷森有幾分像：「把錢留下，人可以走。」"],
		"crimes": ["{place}又有商隊被搶了，帶頭的是個扛大刀的年輕人。", "布蘭的人在{place}打傷了一個收稅的。"],
	},

	# ---------- 冒險者 ----------
	"hakon": {
		"name": "哈康", "title": "冒險者", "pron": "他", "age": 36, "life": [52, 62],
		"style": "deserter", "hp": 220, "stats": {"str": 19, "agi": 18}, "potential": {"str": 19, "agi": 18}, "growth": 0.0,
		"weapon": "knight_sword", "items": [], "place": "frost",
		"role": "hunter", "boldness": 0.3,
		"blurb": "在北境混了二十年的冒險者，左手一面舊圓盾。話不多，只接有把握的懸賞。",
		"start": ["哈康把舊圓盾往前一擋，長劍搭在盾邊：「你想清楚了？」"],
	},
	"sira": {
		"name": "席拉", "title": "冒險者", "pron": "她", "age": 21, "life": [44, 56],
		"style": "merc_captain", "stats": {"str": 14, "agi": 17}, "potential": {"str": 20, "agi": 24}, "growth": 1.6,
		"weapon": "steel_sword", "items": [], "place": "frost",
		"role": "hunter", "boldness": 1.0,
		"blurb": "剛出道沒幾年的冒險者，綁著一條紅頭巾。膽子很大，什麼懸賞都想接。",
		"start": ["席拉把紅頭巾綁緊，拔出劍：「我早就想跟你打一場了。」"],
	},
	"oskar": {
		"name": "奧斯卡", "title": "劍術教師", "pron": "他", "age": 41, "life": [54, 64],
		"style": "old_captain", "hp": 300, "stats": {"str": 20, "agi": 20}, "potential": {"str": 20, "agi": 20}, "growth": 0.0,
		"weapon": "knight_sword", "items": [], "place": "frost",
		"role": "hunter", "boldness": 0.0, "vow": {"target": "yvette", "month": 8},
		"blurb": "貴族家裡請的劍術教師。被伊薇特殺掉的人裡，有一個是他教出來的學生。",
		"start": ["奧斯卡脫下手套，慢慢拔出長劍：「我教人用劍三十年了。」"],
	},
	"leonard": {
		"name": "雷納德", "title": "白手", "pron": "他", "age": 31, "life": [56, 66], "arrive": 100,
		"style": "old_captain", "hp": 420, "stats": {"str": 23, "agi": 22}, "potential": {"str": 24, "agi": 23}, "growth": 0.3,
		"weapon": "knight_sword", "items": [], "place": "frost",
		"role": "hunter", "boldness": 0.5,
		"blurb": "從南方來的騎士，戴著一雙白手套。據說他接下的懸賞，沒有一張是撕不下來的。",
		"start": ["雷納德把白手套一根一根摘下來，收進懷裡，才拔出劍。"],
		"arrive_text": "城裡來了一個戴白手套的騎士，在公會的懸賞板前面站了很久。",
	},

	# ---------- 北境劍術道場 ----------
	"master": {
		"name": "師傅", "title": "北境劍術", "pron": "他", "age": 52, "life": [66, 74],
		"style": "master", "hp": 999, "stats": {"str": 21, "agi": 22}, "potential": {"str": 21, "agi": 22}, "growth": 0.0,
		"weapon": "old_sword", "items": [], "place": "frost",
		"role": "master",
		"blurb": "北境劍術道場的師傅。話很少，每天天還沒亮就在道場裡了。十年前，他的師弟死在紅鬃手上。",
	},
	"matthias": {
		"name": "馬提亞斯", "title": "大師兄", "pron": "他", "age": 24, "life": [44, 56],
		"style": "master", "stats": {"str": 15, "agi": 15}, "potential": {"str": 21, "agi": 20}, "growth": 1.0,
		"weapon": "steel_sword", "items": [], "learned": ["parry", "sweep_kick", "heavy", "redirect", "disarm", "break_free"], "approved": 2,
		"place": "frost", "role": "youth", "relations": {"master": "master"}, "vow": {"target": "roderick", "month": 40},
		"blurb": "北境劍術的大師兄。師叔死的那年他十四歲，那一夜是他背著師傅從火場裡出來的。",
		"start": ["馬提亞斯擺出北境劍術起手的架勢，劍尖一動不動：「師傅教的，我一招都沒忘。」"],
		"avenge": "「師傅待你不薄。」",
	},
	"allen": {
		"name": "艾倫", "title": "學徒", "pron": "他", "age": 15, "life": [36, 44],
		"style": "master", "stats": {"str": 10, "agi": 10}, "potential": {"str": 20, "agi": 19}, "growth": 1.2,
		"weapon": "old_sword", "items": [], "learned": ["parry"],
		"place": "frost", "role": "youth", "relations": {"master": "master"},
		"blurb": "道場裡年紀最小的學徒。每天第一個到、最後一個走，劍還握不太穩。",
		"start": ["艾倫握著劍的手在發抖，還是站穩了：「我不會讓你過去的。」"],
		"avenge": "「我練到今天，就是為了這一天。」",
	},
	"lina": {
		"name": "莉娜", "title": "", "pron": "她", "age": 14, "life": [36, 44],
		"style": "duelist", "stats": {"str": 9, "agi": 11}, "potential": {"str": 17, "agi": 22}, "growth": 1.2,
		"weapon": "old_sword", "items": [],
		"place": "frost", "role": "youth",
		"blurb": "旅店老闆娘的女兒。常常躲在道場的窗外偷看，被發現了就跑。",
		"start": ["莉娜咬著嘴唇，把劍舉起來。"],
	},

	# ---------- 其他 ----------
	"grayson": {
		"name": "葛雷森", "title": "老衛隊長", "pron": "他", "age": 56, "life": [62, 68],
		"style": "old_captain", "hp": 620, "stats": {"str": 29, "agi": 30}, "potential": {"str": 29, "agi": 30}, "growth": 0.0,
		"weapon": "nightwatch", "items": [], "place": "frost",
		"role": "settled",
		"blurb": "以前王都衛隊的隊長，老了以後搬到北境的霜溪城。頭髮白了，劍還是很穩。常一個人坐在旅店的角落喝酒。",
		"start": ["葛雷森慢慢拔出長劍，劍的護手很寬，磨得發亮：「我年輕的時候，也是這樣一個人去找別人麻煩。」"],
		"warn": "葛雷森在旅店的角落叫住你。他沒有抬頭，看著杯子裡的酒：「布蘭是我兒子。他做的事，我會去管。」\n他停了一下。「別動他。」",
		"avenge": "葛雷森把長劍從鞘裡拔出來，劍的護手很寬：「我說過，別動他。」",
	},

	# ---------- 後來才來的人 ----------
	"sigurd": {
		"name": "西格德", "title": "灰狼", "pron": "他", "age": 34, "life": [50, 60], "arrive": 30,
		"style": "bandit_leader", "hp": 260, "stats": {"str": 19, "agi": 17}, "potential": {"str": 20, "agi": 18}, "growth": 0.3,
		"weapon": "bandit_blade", "items": [], "place": "pasture", "haunts": ["pasture", "lodge", "south_road"],
		"role": "villain",
		"bounty": {"reward": 250, "text": "一夥人披著灰狼皮，在牧羊村一帶搶羊、搶人。頭目叫西格德，人稱「灰狼」。牧場主人們懸賞他。"},
		"blurb": "披著一張灰狼皮的盜匪頭目。從西邊的山裡下來，手下都怕他。",
		"start": ["一個披著灰狼皮的男人從石牆後面站起來，舔了舔刀口。"],
		"arrive_text": "牧羊村那邊開始有人搶羊，聽說帶頭的披著一張灰狼皮。",
		"crimes": ["{place}又有羊被搶了，牧羊人被打斷了一條腿。", "灰狼的人在{place}燒了一間農舍。"],
	},
	"ora": {
		"name": "歐拉", "title": "", "pron": "她", "age": 17, "life": [36, 44], "arrive": 48,
		"style": "raider", "stats": {"str": 13, "agi": 13}, "potential": {"str": 21, "agi": 19}, "growth": 1.4,
		"weapon": "hand_axe", "items": [], "place": "frost",
		"role": "youth", "grudges": ["ulf"],
		"blurb": "從北岸逃出來的女孩。她的村子是烏爾夫燒掉的。每天在城外的空地上劈木樁，劈到手流血。",
		"start": ["歐拉握緊手斧，一句話都沒說。"],
		"arrive_text": "城裡來了一個從北岸逃出來的女孩，背著一把手斧，到處問烏爾夫在哪裡。",
	},
	"hogg": {
		"name": "霍格", "title": "黑帆", "pron": "他", "age": 36, "life": [50, 60], "arrive": 120,
		"style": "raider", "hp": 340, "stats": {"str": 22, "agi": 17}, "potential": {"str": 22, "agi": 17}, "growth": 0.0,
		"weapon": "hand_axe", "items": [], "place": "coast", "haunts": ["coast", "old_wall", "lodge"],
		"role": "villain",
		"bounty": {"reward": 350, "text": "掛黑帆的船在北岸靠了岸，船長霍格帶人燒了兩座村子。沿岸的領主懸賞他。"},
		"blurb": "掛黑帆的海盜船長。少了兩根手指，斧頭照樣握得很穩。",
		"start": ["一個少了兩根手指的男人把斧頭在手裡轉了一圈：「北岸是我的。」"],
		"arrive_text": "北岸來了一艘掛黑帆的船。",
		"crimes": ["{place}有一座村子被燒了，有人看見海上掛著黑帆。"],
	},
	"tim": {
		"name": "提姆", "title": "", "pron": "他", "age": 14, "life": [36, 44], "arrive": 110,
		"style": "master", "stats": {"str": 9, "agi": 10}, "potential": {"str": 19, "agi": 20}, "growth": 1.3,
		"weapon": "old_sword", "items": [], "place": "frost",
		"role": "youth",
		"blurb": "在城門口幫人看馬的孤兒。聽人講冒險者的故事，可以聽一整天。",
		"start": ["提姆撿起一根木棍，擋在你面前。"],
		"arrive_text": "城門口多了一個幫人看馬的孤兒，叫提姆。",
	},
}

## 換人接著玩時，沒有夠年輕的人可以選，就從這裡找一個剛到城裡的年輕人
const NEWCOMER_NAMES := [["漢斯", "他"], ["瑪塔", "她"], ["奧托", "他"], ["蓋兒", "她"], ["尼爾斯", "他"], ["艾瑪", "她"]]
const NEWCOMER_BLURB := "剛到霜溪城的年輕人，什麼都還不會，只有一把舊鐵劍。"
