class_name RoadData
extends RefCounted

## 路上的事：只有文字和選項。碰不碰得上、碰上誰、選了之後怎樣，在 Road。
## 路上的事從世界長出來（2026-10-07 決定）：碰到的是世界上真的人、跟你做過的事有關，結果留在世界上。
##   人找上你（多數）：仇人堵你、有懸賞的人攔路、榜上的人要比劍、同門被圍、欠你情的人、路上碰到的人。
##   寫好的事（少數）：世界上的條件成立才有（有人剛死在路邊、剛被搶過的村子、被搶的商人）。
##   沒名字的人（攔路的小賊）活下來，就變成世界上的人。
##   沒有理由就不會碰上事：每件事有自己每個月的機率（CHANCE），條件不成立就是 0。
##
## 一件事是好幾步（參考 CK3）：每一步一段文字、幾個選項，選了可能接下一步、開打、或結束。
## who：這件事的主角（世界上的人）；other：另一個人（被圍的同門身邊的敵人、死人的兇手）。
## title：對話框上寫誰。"who"/"other" = 寫那個人（境界的顏色）；其他字照寫。步驟自己寫了 title 就用步驟的（還沒看清楚是誰）。
##
## 選項：
##   label 按鈕的字。
##   need 要這樣才看得到：money 至少多少錢、pay / bribe 錢夠付、member 是劍庭的人、took_bounty 接了 who 的懸賞、
##     kind 他為什麼找你（kin 你殺了他的人、beaten 你打傷搶過他、bounty 來收你的懸賞、heir 上一個人欠的）、lead 有你在找的人的消息
##   check：{"stat": "str"/"agi", "vs": 數字 或 "who"/"other", "bonus": 加在你那邊} 或 {"power": "who"/"other"}（看起來誰比較強）。
##     有機率，不是一刀切；成功照 ok、不成功照 fail
##   結果（寫在選項上，或 ok / fail 裡）：
##     text 寫進紀錄的一句；next 接哪一步（沒寫就結束，接著走路）
##     fight 跟誰打："who"/"other"/"thug" 沒名字的小賊/EnemyData id；win 打贏了接哪一步
##     duel true 跟 who 比劍（點到為止）
##     money 錢 +/-（"purse" 錢袋裡的錢）；rob 被拿走身上幾成的錢；pay 付錢了結他的仇；bribe 付錢讓來收懸賞的人走
##     hear "who"/"other"/"lead"/"notable"：知道那個人在哪
##     fame、merit、hurt（掉最大血量的幾成）、delay（多走幾個月）、item（拿到的武器）
##     escape "who"/"other"：他這次沒追上（過一陣子再來）；backoff true：who 被你嚇退，很久不敢來
##     grateful "who"：他欠你一份情；repaid true：他還了這份情
##     leave_fight true：你走開，other 跟 who 自己打
##     bury true：把 who 埋了（他的家人欠你一份情）
##     drifter 沒名字的小賊活下來，變成世界上的人：robbed 他搶了你、pitied 你給了他錢、fled 被你嚇跑、spared 你打倒他又放了他、stripped 你打倒他還搜他身上
##     note "who"/"other" 的經歷上記一筆（大家都知道）：{"who": 文字}
##     memo who 記下跟你之間的這件事（TalkData.MEMO 的 kind），之後說話會提
## 文字裡：{my} 你的兵器 {me} 你的名字 {road} 往哪裡的路上 {place} 在哪一帶 {dest} 要去的地方
##   {name}{pron}{look}{noun} who 的名字、他、拿的東西（樣子、叫法）；{other}{opron}{olook} other 的
##   {n} 錢 {pay} {bribe} 要付多少 {line} 找上你算帳的人說的話 {wound} 傷口 {wplace} who 往哪裡去了
##   {say:情況} who 用自己的口氣說話（TalkData.SAY，先提跟你的舊事）、{voice:情況} 不提舊事、{past} 只提舊事、{gesture} 怕你或看不起你的動作
##   {lead}{leadplace}{lead_line} 你在找的人和他在哪 {who}{where} 聽說的人和他在哪

## 每件事每走一個月的機率（條件成立時）
const CHANCE := {
	"ambush": 0.3,  # 正在找你的人；記仇但還沒動身的是 AMBUSH_IDLE
	"robbers": 0.08,
	"robbers_shy": 0.06,
	"challenge": 0.03,
	"kin_help": 0.06,
	"corpse": 0.2,
	"raided": 0.1,
	"merchant": 0.02,
	"repay": 0.08,
	"traveler": 0.015,
	"caravan": 0.01,
	"thug": 0.02,
}
const AMBUSH_IDLE := 0.06
## 同一件事隔多久才會再碰到（月）；同一個人隔多久才會再找你（月）。寫好的事一輩子一次（ONCE）
const AGAIN := {"robbers": 10, "robbers_shy": 10, "challenge": 18, "kin_help": 36, "merchant": 24, "repay": 18, "traveler": 12,
	"caravan": 60, "thug": 18, "raided": 12, "corpse": 0, "ambush": 0}
const PERSON_AGAIN := 24
const ONCE := ["corpse"]
## 你比他強這麼多（Person.power），攔路的就不敢出來
const STRONGER_GAP := 2.0
## 比劍：找比自己強不過這麼多、弱不過這麼多的人
const CHALLENGE_RANGE := [-2.5, 1.0]
## 你要有點名氣，才有人在路上等你比劍
const CHALLENGE_FAME := 6.0
## 付錢了結仇：基本 + 每一境；收懸賞的人：懸賞的幾成
const PAY_BASE := 40
const PAY_PER_REALM := 30
const BRIBE_SHARE := 0.5
## 欠你情的人送的錢
const GIFT := [20, 50]
## 路上打起來時的場景
const SCENE := ["荒涼的路上，兩邊是枯草和石頭。", "路邊的樹林裡，地上的落葉很厚。", "一段沒有人家的山路，風很大。"]
## 錢袋裡的錢
const PURSE := [10, 40]
## 攔路的拿走你身上幾成的錢（至少 MIN）
const ROB_SHARE := 0.2
const ROB_MIN := 10

## 被殺的人身上的傷口（看兇手拿的兵器）
const WOUNDS := {
	"sword": "傷口在胸口，一劍透了過去，乾乾淨淨。",
	"greatsword": "{pron}幾乎被攔腰砍成兩截。",
	"rapier": "喉嚨上只有一個小孔，血流得不多。",
	"blade": "脖子上一道很寬的刀口，砍了兩下才砍進去。",
	"axe": "肩膀被劈開了，骨頭都碎了。",
	"hammer": "頭上塌下去一塊。",
	"polearm": "肚子上一個洞，前後都透了。",
	"fist": "身上沒有刀傷。脖子歪成一個不對的角度。",
}

const EVENTS := {
	# ---------- 人找上你 ----------
	"ambush": {"title": "who", "steps": {
		"start": {"title": "路邊", "text": "{road}，路邊有一片草被踩倒了，倒下去的方向朝著路。草還沒直起來。四周很靜，連鳥叫都沒有。", "options": [
			{"label": "握住{my}，照走", "next": "face"},
			{"label": "離開大路，從林子裡繞過去", "check": {"stat": "agi", "vs": "who"},
				"ok": {"text": "你在林子裡多繞了半天，衣服被荊棘勾破了好幾處。出林子的時候回頭看了一眼：路邊的石頭上坐著一個人，{look}擱在腳邊，一直望著大路。{who_line}", "escape": "who", "hear": "who"},
				"fail": {"text": "你才鑽進林子，前面的樹後就走出一個人。", "next": "face"}},
			{"label": "撿一塊石頭，往草裡丟", "text": "石頭落進草裡。草裡站起來一個人，拍掉身上的草屑。", "next": "face"},
		]},
		"face": {"text": "{name}擋在路中間，手上拿著{look}。{gesture}\n{line}", "options": [
			{"label": "拔出{my}", "fight": "who"},
			{"label": "想辦法走掉", "check": {"stat": "agi", "vs": "who"},
				"ok": {"text": "你往旁邊的斜坡一滑，滾進溝裡，爬起來就跑。{name}追了一段，停下來了。", "escape": "who"},
				"fail": {"text": "你才轉身，{name}已經擋在你前面。", "fight": "who"}},
			{"label": "給{pron} {pay} 銀，了結這件事", "need": {"kind": "beaten", "pay": true}, "pay": true, "memo": "paid",
				"text": "{name}把錢袋掂了掂，收進懷裡。{pron}看了你很久：「這件事到這裡。」"},
			{"label": "給{pron} {bribe} 銀，當作沒看見你", "need": {"kind": "bounty", "bribe": true}, "bribe": true, "memo": "bribed",
				"text": "{name}看了看錢袋，又看了看手上的紙。{pron}把紙對摺兩次，塞回懷裡，轉身走了。"},
			{"label": "叫{pron}回去", "check": {"power": "who"},
				"ok": {"text": "{name}握著{noun}的手指一根一根收緊，又鬆開。{pron}看著你，看了很久，最後往後退了一步：「我會再來。」", "backoff": true, "memo": "backed_off"},
				"fail": {"text": "{name}沒有說話，往前走了一步。", "fight": "who"}},
		]},
	}},
	"robbers": {"title": "who", "steps": {
		"start": {"text": "{road}，一棵倒下來的樹橫在路中間，斷口很新，是剛砍的。樹後站起來三四個人，帶頭的手上拿著{look}。{gesture}\n{say:rob}", "options": [
			{"label": "「懸賞單上有你。」", "need": {"took_bounty": true}, "fight": "who",
				"text": "帶頭的臉上的笑不見了。他身後的人慢慢散開，把路的兩頭堵住。"},
			{"label": "動手", "fight": "who"},
			{"label": "把錢袋丟過去", "rob": true, "memo": "robbed_you", "note": {"who": "在{place}攔路，搶了{p:hero}"},
				"text": "你把錢袋丟過去，裡面有 {n} 銀。帶頭的撿起來掂了掂，讓開了路。你走過去的時候，後面有人笑了一聲。"},
			{"label": "拔出{my}，往前走", "check": {"power": "who"},
				"ok": {"text": "帶頭的盯著你握{my}的手。你走到離他三步的地方，他往旁邊讓了一步。他身後的人沒有動。", "fame": 0.5, "memo": "scared"},
				"fail": {"text": "帶頭的笑了一聲，迎了上來。", "fight": "who"}},
		]},
	}},
	"robbers_shy": {"title": "who", "steps": {
		"start": {"text": "{road}，路邊的樹後有人影動了一下。幾個人探出頭來，看清楚是你，又縮了回去。最後縮回去的那個，手上拿著{look}。", "options": [
			{"label": "追進林子", "fight": "who", "text": "你追進林子。{name}跑不過你，停下來，轉過身。"},
			{"label": "照走", "text": "你沒有停。走出很遠，林子裡都沒有聲音。"},
		]},
	}},
	"challenge": {"title": "who", "steps": {
		"start": {"text": "{road}，岔路口的里程石上坐著一個人，{look}擱在膝上，腳邊的乾糧袋已經空了一半，看樣子等了好幾天。看見你，{pron}站了起來：「你是{me}？」", "options": [
			{"label": "「是我。」", "next": "ask"},
			{"label": "「認錯人了。」", "memo": "duel_declined", "note": {"who": "在{place}等{p:hero}比劍，{p:hero}說{pron}認錯人了"},
				"text": "{name}沒有攔你。你走出很遠，還覺得背上有{pron}的目光。"},
		]},
		"ask": {"text": "{say:challenge}\n{name}把{noun}抽出來一半，等你回話。", "options": [
			{"label": "比", "duel": true},
			{"label": "「不比。」", "fame": -0.5, "memo": "duel_declined", "note": {"who": "在{place}找{p:hero}比劍，{p:hero}不肯"},
				"text": "{voice:challenge_no}"},
		]},
	}},
	"kin_help": {"title": "who", "steps": {
		"start": {"text": "{road}，前面有兵器相碰的聲音，還有人在喊。轉過山坳，一個穿劍庭灰衣的人背靠著石牆，是{name}。{pron}的左臂垂著，血順著袖口往下滴。圍著{pron}的有三個人，帶頭的拿著{olook}。", "options": [
			{"label": "上去幫{pron}", "fight": "other", "win": "thanks", "text": "你衝了上去。帶頭的回過頭來。"},
			{"label": "大喊一聲", "check": {"power": "other"},
				"ok": {"text": "那幾個人回頭看了你一眼，又看了看你的{my}。帶頭的罵了一聲，帶著人退進林子。", "escape": "other", "next": "thanks"},
				"fail": {"text": "帶頭的回頭看了你一眼，沒有停手，只分了一個人過來擋你。你推開那個人，帶頭的轉過身來。", "fight": "other", "win": "thanks"}},
			{"label": "轉身走開", "leave_fight": true, "text": "你轉身走了。身後的聲音響了很久才停。"},
		]},
		"thanks": {"text": "{name}靠著石牆坐下來，把劍插回鞘裡，手還在抖。\n{voice:saved}", "options": [
			{"label": "扶{pron}回劍庭", "grateful": "who", "merit": 8, "memo": "saved", "note": {"who": "在{place}被圍，{p:hero}救了{pron}"},
				"text": "你扶著{name}走了一段。回到劍庭，{pron}把路上的事說了一遍。（貢獻 +8）"},
			{"label": "「路上小心。」", "grateful": "who", "memo": "saved", "note": {"who": "在{place}被圍，{p:hero}救了{pron}"},
				"text": "{name}點了點頭，一跛一跛地往城裡走了。"},
		]},
	}},
	"repay": {"title": "who", "steps": {
		"start": {"text": "{road}，路邊茶棚裡有人叫了你一聲。是{name}。{pron}把凳子往旁邊挪了挪，讓你坐，又跟老闆多要了一個杯子。\n{say:repay}", "options": [
			{"label": "聽{pron}說", "need": {"lead": true}, "hear": "lead", "repaid": true, "memo": "gift", "text": "{name}壓低了聲音：{lead_line}"},
			{"label": "收下{pron}塞過來的布包", "money": "gift", "repaid": true, "memo": "gift", "text": "布包裡是 {n} 銀。"},
			{"label": "喝完茶就走", "text": "你們喝完了那壺茶。{name}搶著付了錢。"},
		]},
	}},
	"traveler": {"title": "who", "steps": {
		"start": {"text": "你在路邊的酒館歇腳。屋裡很暗，爐火燒得正旺。{name}也坐在角落裡，{look}靠在桌邊。{voice:traveler}{past}", "options": [
			{"label": "點個頭", "text": "你朝{pron}點了點頭。{pron}也點了點頭，沒有說話。"},
			{"label": "請{pron}喝一杯", "need": {"money": 5}, "money": -5, "next": "drink"},
			{"label": "動手", "fight": "who"},
		]},
		"drink": {"text": "{name}接過酒，喝了一口，看著你。", "options": [
			{"label": "問{pron}有沒有看過{lead}", "need": {"lead": true}, "hear": "lead", "text": "{name}想了想：「{leadplace}。上個月的事。」"},
			{"label": "問{pron}外面最近有什麼事", "hear": "notable", "text": "{pron}說前陣子在{where}碰到{who}。"},
			{"label": "什麼都不問", "text": "你們喝完了那一壺，各自上路。"},
		]},
	}},

	# ---------- 寫好的事（世界上的條件成立才有） ----------
	"corpse": {"title": "who", "steps": {
		"start": {"title": "路邊的人", "text": "{road}，路邊的烏鴉一直不肯飛走。草叢裡躺著一個人，死了沒幾天。", "options": [
			{"label": "過去看", "next": "look"},
			{"label": "繞過去", "text": "你繞了過去。烏鴉叫了兩聲，又落回草叢裡。"},
		]},
		"look": {"text": "{who_line}{wound}{pron}身上被翻過了，靴子也被人脫走了。", "options": [
			{"label": "看地上的腳印", "next": "trail"},
			{"label": "把{pron}埋了", "bury": true, "text": "你在路邊挖了個坑，把{name}埋了，插了一根樹枝當記號。"},
			{"label": "摸{pron}的腰帶", "money": "purse", "text": "腰帶的夾層裡縫著幾個銀幣，一共 {n} 銀。"},
		]},
		"trail": {"text": "腳印很亂。有一行比別的都深，往{kplace}的方向去了。", "options": [
			{"label": "把{pron}埋了", "bury": true, "text": "你在路邊挖了個坑，把{name}埋了，插了一根樹枝當記號。"},
			{"label": "走", "text": "你沿著大路往前走。那行腳印在路口拐了彎。"},
		]},
	}},
	"raided": {"title": "路邊的村子", "steps": {
		"start": {"text": "{road}經過一個村子。村口的房子只剩幾根燒黑的柱子，還在冒煙。一個老婦人坐在路邊，懷裡抱著一隻雞。", "options": [
			{"label": "問她出了什麼事", "next": "tell"},
			{"label": "走過去", "text": "老婦人一直看著你走過去。"},
		]},
		"tell": {"text": "「帶頭的那個，手上拿著{look}。」她朝{wplace}的方向抬了抬下巴。「搶完往那邊去了。」", "options": [
			{"label": "幫她把東西搬出來", "fame": 0.5, "text": "你幫她從灰裡翻出還能用的東西：一口鍋，半袋麥子。她要把那隻雞塞給你，你沒要。"},
			{"label": "「我會找到他。」", "need": {"took_bounty": true}, "hear": "who", "text": "老婦人看了你一眼，又看了你的{my}一眼，沒有說話。"},
			{"label": "走", "text": "你繼續往前走。"},
		]},
	}},
	"merchant": {"title": "受傷的商人", "steps": {
		"start": {"text": "{road}，路邊坐著一個商人，腿上綁著撕下來的衣服，血還在滲。他的騾子和貨都不見了。", "options": [
			{"label": "幫他包紮", "next": "talk"},
			{"label": "走過去", "text": "你從他身邊走了過去。"},
		]},
		"talk": {"text": "你替他重新包了腿。他說搶他的人拿著{look}，往{wplace}去了。貨裡有一把要送去霜溪城的鋼劍。", "options": [
			{"label": "去追", "check": {"stat": "agi", "vs": "who", "bonus": 2},
				"ok": {"text": "騾子的蹄印很新。你在半路追上了他們，帶頭的回過身來。", "fight": "who", "win": "returned"},
				"fail": {"text": "你追到天黑，蹄印在一條河邊斷了。"}},
			{"label": "扶他上路", "money": 10, "text": "你扶著他走了一段，到了有人家的地方。他塞給你 10 銀，怎麼都不肯收回去。"},
		]},
		"returned": {"title": "受傷的商人", "text": "你把騾子牽了回來。商人打開木箱，那把劍還在，鞘上的油紙都沒破。", "options": [
			{"label": "把劍還給他", "money": 40, "fame": 0.5, "text": "他把劍收好，數了 40 銀給你。"},
			{"label": "留下那把劍", "item": "steel_sword", "text": "你把劍收進自己的行李。商人張了張嘴，沒說話。"},
		]},
	}},
	"caravan": {"title": "商隊", "steps": {
		"start": {"text": "{road}，你追上一支往同方向的商隊。領隊看了看你的{my}，問你要不要一起走，管飯，路上幫忙看著貨。", "options": [
			{"label": "一起走", "next": "night"},
			{"label": "自己走", "text": "你謝過領隊，自己往前走。"},
		]},
		"night": {"text": "第三天夜裡輪到你守貨。林子裡有火光晃了一下，又滅了。", "options": [
			{"label": "叫醒大家", "money": 30,
				"text": "商隊的人拿起棍子圍成一圈，把火堆撥旺。林子裡的人看見了，沒有出來。分手的時候，領隊數了 30 銀給你。"},
			{"label": "自己過去看看", "fight": "raider", "win": "hero"},
			{"label": "當作沒看見", "text": "天亮的時候，少了兩箱貨。領隊看了你一眼，什麼都沒說，到了地方也沒給你錢。"},
		]},
		"hero": {"text": "你一個人收拾了摸過來的人。領隊天亮才知道，看你的眼神不一樣了。", "options": [
			{"label": "繼續走", "money": 60, "fame": 2.0, "text": "分手的時候，領隊數了 60 銀給你，說會跟人提起你。"},
		]},
	}},
	# 沒名字的小賊：活下來就變成世界上的人
	"thug": {"title": "攔路的人", "steps": {
		"start": {"text": "{road}，路邊的樹後跳出兩個人，一個拿棍子，一個拿柴刀：「錢袋留下，人可以走。」", "options": [
			{"label": "動手", "fight": "thug", "win": "down"},
			{"label": "把錢袋丟過去", "rob": true, "drifter": "robbed", "text": "你把錢袋丟過去，裡面有 {n} 銀。他們撿起錢袋，讓開了路。"},
			{"label": "看清楚他們", "next": "look"},
		]},
		"look": {"text": "拿柴刀的那個手在抖，刀刃上全是缺口。拿棍子的那個比你還瘦，腳上的鞋破了兩個洞。兩個人都不敢先上前。", "options": [
			{"label": "丟幾個銀幣給他們", "need": {"money": 10}, "money": -10, "drifter": "pitied",
				"text": "你丟了 10 銀過去。兩個人愣了一下，撿起錢，往山裡走了。拿柴刀的那個走了幾步，回頭看了你一眼。"},
			{"label": "拔出{my}嚇他們", "check": {"stat": "str", "vs": 13},
				"ok": {"text": "你把{my}拔出來，往前走了一步。兩個人互看一眼，轉身就跑。", "drifter": "fled"},
				"fail": {"text": "他們沒有退。拿柴刀的那個咬著牙衝了上來。", "fight": "thug", "win": "down"}},
			{"label": "動手", "fight": "thug", "win": "down"},
		]},
		"down": {"text": "拿棍子的那個早就跑得沒影了。拿柴刀的那個倒在地上，柴刀落在你腳邊。他抬頭看著你，嘴唇在抖。", "options": [
			{"label": "結果他", "text": "你結果了他，把屍體拖進路邊的溝裡。"},
			{"label": "放他走", "drifter": "spared",
				"text": "你把柴刀踢回給他，讓開了路。他撿起柴刀，一跛一跛地走進樹林，走了幾步，回頭看了你一眼。"},
			{"label": "搜他身上，再放他走", "money": "purse", "drifter": "stripped",
				"text": "你從他懷裡摸出 {n} 銀，才讓他走。他撿起柴刀，一跛一跛地走進樹林，沒有回頭。"},
		]},
	}},
}
