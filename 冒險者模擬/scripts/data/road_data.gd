class_name RoadData
extends RefCounted

## 路上的事：出門走路時偶爾碰上（走越久越容易碰上）。只有資料，怎麼處理在 Town（road_event / answer_road）。
## 一件事是好幾步（參考 CK3）：每一步一段文字、幾個選項，選了可能接下一步、開打、或結束。
## 每件事都跟冒險有關：要不要打、錢、聽到誰在哪。
##
## steps：步驟 id -> {"text", "options"}，從 "start" 開始。
## 選項：
##   label 按鈕的字。need 要有這個才看得到這個選項：{"money": 至少多少錢}、{"member": true 是劍庭的人}
##   check {"stat": "str"/"agi", "vs": 數值}：你那一項夠不夠，夠就照 ok、不夠照 fail
##   結果（寫在選項上，或 ok / fail 裡）：
##     text 寫進紀錄的一句；next 接哪一步（沒寫就結束，接著走路）
##     fight 跟誰打（EnemyData id；"stalker" 看你多強挑野獸）；fight_person true 跟碰到的人打；win 打贏了接哪一步
##     money 錢 +/-（"purse" 錢袋裡的錢）；rob true 被拿走身上幾成的錢；hear true 聽說一個有名的人在哪
##     merit 劍庭的貢獻；fame 名聲；hurt 掉最大血量的幾成；delay 多走幾個月；item 拿到的武器（WeaponData id）
## 文字裡：{my} 你的武器、{name}{pron} 碰到的人、{n} 錢、{who}{place} 聽說的人和他在哪

## 每走一個月，碰上一件事的機率
const CHANCE_PER_MONTH := 0.12
## 路上打起來時的場景
const SCENE := ["荒涼的路上，兩邊是枯草和石頭。", "路邊的樹林裡，地上的落葉很厚。", "一段沒有人家的山路，風很大。"]
## 錢袋裡的錢
const PURSE := [10, 40]
## 攔路的拿走你身上幾成的錢（至少 MIN）
const ROB_SHARE := 0.2
const ROB_MIN := 10

const EVENTS := {
	"robbers": {"w": 30, "title": "攔路的人", "steps": {
		"start": {"text": "路邊的樹後跳出兩個人，一個拿棍子，一個拿柴刀：「錢袋留下，人可以走。」", "options": [
			{"label": "動手", "fight": "highwayman", "win": "search"},
			{"label": "把錢袋丟過去", "rob": true, "text": "你把錢袋丟過去，裡面有 {n} 銀。他們撿起錢袋，讓開了路。"},
			{"label": "看清楚他們", "next": "look"},
		]},
		"look": {"text": "拿柴刀的那個手在抖，刀刃上全是缺口。拿棍子的那個比你還瘦，腳上的鞋破了兩個洞。兩個人都不敢先上前。", "options": [
			{"label": "丟幾個銀幣給他們", "need": {"money": 10}, "money": -10,
				"text": "你丟了 10 銀過去。兩個人愣了一下，撿起錢，往山裡走了。拿棍子的那個走了幾步，回頭看了你一眼。"},
			{"label": "拔出{my}嚇他們", "check": {"stat": "str", "vs": 13},
				"ok": {"text": "你把{my}拔出來，往前走了一步。兩個人互看一眼，轉身就跑。"},
				"fail": {"text": "他們沒有退。拿柴刀的那個咬著牙衝了上來。", "fight": "highwayman", "win": "search"}},
			{"label": "動手", "fight": "highwayman", "win": "search"},
		]},
		"search": {"text": "拿柴刀的那個倒在地上，懷裡掉出一封信。信封的角上有血。", "options": [
			{"label": "拆開來看", "hear": true, "text": "信上只有幾行字：最近在{place}看到{who}，別往那邊走。"},
			{"label": "丟掉", "text": "你把信丟進路邊的溝裡。"},
		]},
	}},
	"wounded": {"w": 20, "title": "受傷的商人", "steps": {
		"start": {"text": "路邊坐著一個商人，腿上綁著撕下來的衣服，血還在滲。他的騾子和貨都不見了。", "options": [
			{"label": "幫他包紮", "next": "talk"},
			{"label": "走過去", "text": "你從他身邊走了過去。"},
		]},
		"talk": {"text": "你替他重新包了腿。他說搶他的是兩個人，往林子裡去了，貨裡有一把他要送去霜溪城的新劍。", "options": [
			{"label": "去追", "check": {"stat": "agi", "vs": 12},
				"ok": {"text": "地上的腳印很新。你在林子邊追上了他們。", "fight": "highwayman", "win": "returned"},
				"fail": {"text": "你在林子裡找了半天，只找到被拆開的貨箱。"}},
			{"label": "問他路上還看到了誰", "hear": true, "text": "他說前幾天在{place}看見過{who}。"},
			{"label": "扶他上路", "money": 10, "text": "你扶著他走了一段，到了有人家的地方。他塞給你 10 銀，怎麼都不肯收回去。"},
		]},
		"returned": {"text": "你把搶來的貨扛了回來。商人打開木箱，那把劍還在，鞘上的油紙都沒破。", "options": [
			{"label": "把劍還給他", "money": 40, "text": "他把劍收好，數了 40 銀給你。"},
			{"label": "留下那把劍", "item": "steel_sword", "text": "你把劍收進自己的行李。商人張了張嘴，沒說話。"},
		]},
	}},
	"caravan": {"w": 15, "title": "商隊", "steps": {
		"start": {"text": "你追上一支往同方向的商隊。領隊看了看你的{my}，問你要不要一起走，管飯，路上幫忙看著貨。", "options": [
			{"label": "一起走", "next": "night"},
			{"label": "自己走", "text": "你謝過領隊，自己往前走。"},
		]},
		"night": {"text": "第三天夜裡輪到你守貨。林子裡有火光晃了一下，又滅了。", "options": [
			{"label": "叫醒大家", "money": 30,
				"text": "商隊的人拿起棍子圍成一圈，把火堆撥旺。林子裡的人看見了，沒有出來。分手的時候，領隊數了 30 銀給你。"},
			{"label": "自己過去看看", "fight": "highwayman", "win": "hero"},
			{"label": "當作沒看見", "text": "天亮的時候，少了兩箱貨。領隊看了你一眼，什麼都沒說，到了地方也沒給你錢。"},
		]},
		"hero": {"text": "你一個人收拾了摸過來的人。領隊天亮才知道，看你的眼神不一樣了。", "options": [
			{"label": "繼續走", "money": 60, "fame": 2.0, "text": "分手的時候，領隊數了 60 銀給你，說會跟人提起你。"},
		]},
	}},
	"stalked": {"w": 15, "title": "跟在後面的東西", "steps": {
		"start": {"text": "天快黑的時候，你聽見後面的草叢裡有東西跟著，一直沒有走遠。", "options": [
			{"label": "回頭看看", "fight": "stalker"},
			{"label": "加快腳步", "check": {"stat": "agi", "vs": 12},
				"ok": {"text": "你加快腳步，走到有人家的地方，那東西沒再跟上來。"},
				"fail": {"text": "你才走了幾步，牠就從草叢裡竄了出來。", "fight": "stalker"}},
			{"label": "找地方生火", "next": "fire"},
		]},
		"fire": {"text": "你找了塊背風的石頭生起火。火光照出草叢裡兩點綠光，一直沒有靠近。", "options": [
			{"label": "守到天亮", "text": "天亮的時候，草叢裡什麼都沒有。"},
			{"label": "拿著火把過去", "fight": "stalker"},
		]},
	}},
	"corpse": {"w": 10, "title": "路邊的人", "steps": {
		"start": {"text": "路邊的溝裡躺著一個人，身上被翻過了，腰間還掛著一個沒被拿走的小錢袋。", "options": [
			{"label": "拿走錢袋", "money": "purse", "text": "你解下錢袋，裡面有 {n} 銀。"},
			{"label": "看看是誰", "next": "who"},
			{"label": "不碰", "text": "你繞了過去。"},
		]},
		"who": {"text": "他穿著一件灰衣，手裡還握著斷掉的劍。傷口在背上，是從後面砍進去的。", "options": [
			{"label": "把他埋了", "text": "你在路邊挖了個坑，把他埋了，斷劍插在土堆上。"},
			{"label": "把斷劍帶回劍庭", "need": {"member": true}, "merit": 5,
				"text": "你把斷劍帶回劍庭。大師兄認出了劍柄上的記號，記下了你這份心（貢獻 +5）。"},
			{"label": "拿走錢袋", "money": "purse", "text": "你解下錢袋，裡面有 {n} 銀。"},
		]},
	}},
	"traveler": {"w": 20, "title": "", "steps": {
		"start": {"text": "你在路邊的酒館歇腳，{name}也坐在角落裡。{pron}看了你一眼。", "options": [
			{"label": "點個頭", "text": "你朝{pron}點了點頭。{pron}也點了點頭，沒有說話。"},
			{"label": "請{pron}喝一杯", "need": {"money": 5}, "money": -5, "next": "drink"},
			{"label": "動手", "fight_person": true},
		]},
		"drink": {"text": "{name}接過酒，喝了一口，看著你。", "options": [
			{"label": "問{pron}最近去過哪", "hear": true, "text": "{pron}說前陣子在{place}碰到{who}。"},
			{"label": "什麼都不問", "text": "你們喝完了那一壺，各自上路。"},
		]},
	}},
	"flood": {"w": 10, "title": "斷橋", "steps": {
		"start": {"text": "下了三天大雨，前面的橋被沖斷了。河水是黃的，打著旋往下流。", "options": [
			{"label": "繞路", "delay": 1, "text": "你沿著河往上游走，多走了一個月才找到能過的地方。"},
			{"label": "涉水過河", "check": {"stat": "str", "vs": 14},
				"ok": {"text": "你把{my}綁在背上，踩著水底的石頭過了河，衣服全濕了。"},
				"fail": {"text": "河水比看起來急。你被沖了好幾步，撞在石頭上，好不容易才爬上岸。", "hurt": 0.15}},
		]},
	}},
}
