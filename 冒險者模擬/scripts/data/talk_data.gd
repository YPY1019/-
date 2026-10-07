class_name TalkData
extends RefCounted

## 人開口說話：口氣、記得跟你之間的事、主動來找你、來告訴你跟你有關的事。只有文字和數字。
## 說什麼、什麼時候來，在 Talk（說話）和 Visits（誰來找你）。
## 2026-10-07 決定：資訊推少、自己去聽多；人開口、記得你；平常也有人主動找你；選了之後有後續。
##
## 口氣（VOICES）是這個人的個性。怕不怕你、看不看得起你不寫在話裡，寫在動作裡（GESTURE）。
## 文字裡：{name}{pron}{noun}{look} 說話的人、他、他的兵器（叫法、樣子）；{me} 你的名字；{my} 你的兵器；{place} 在哪
##   {target}{tpron}{tplace} 說到的另一個人、他在哪；{victim}{vpron}{rel} 死的人、是說話的人的誰
##   {gplace} 結仇的地方；{thing} 被拿走的東西；{rank} 強者榜上的事；{reason} 為什麼找你幫忙
##   {lead}{lpron}{leadplace} 你在找的人、他在哪
##   {past}（在 Talk 裡接在最前面）：他記得跟你之間最近的一件事

const VOICES := ["rough", "cold", "proud", "plain"]

## 你比他強這麼多（Person.power），他怕你；他比你強這麼多，他看不起你
const AFRAID_GAP := 2.0
const SCORN_GAP := 2.0

## 怕你、看不起你：寫動作，不寫話
const GESTURE := {
	"afraid": [
		"{name}說話的時候，眼睛一直沒對上你。",
		"{name}站的地方，離你比平常人遠了一步。",
		"{name}說話的時候，一直看著你握{my}的手。",
	],
	"scorn": [
		"{name}上下打量了你一眼。",
		"{name}說話的時候，手一直沒碰{noun}。",
		"{name}說話的時候，眼睛一直在看別處。",
	],
}

## 誰來找你的時候，你在做什麼（城裡、城外）
const SCENE := {
	"city": [
		"你在旅店樓下吃飯。{name}端著杯子走過來，在你對面坐下。",
		"你從公會出來，{name}站在台階底下，看樣子等了有一陣子。",
		"你回到旅店，{name}坐在樓梯口，看見你就站了起來。",
		"你在武器店門口看人磨劍，{name}在你旁邊站定了。",
	],
	"wild": [
		"你在{place}找了個背風的地方歇腳。{name}從另一頭走過來，在你旁邊站定。",
		"你在{place}喝水，{name}在旁邊等你喝完。",
	],
}
## 來找你算帳的人（城裡、城外）
const COMER_SCENE := {
	"city": [
		"你在旅店樓下吃飯，門被推開了。{name}站在門口看了一圈，看到了你。",
		"你從公會出來，{name}堵在台階底下，{look}就在手邊。",
	],
	"wild": [
		"{name}從{place}的另一頭走過來，在你前面十步的地方停下。",
	],
}

## 說的話：情況 -> 口氣 -> 幾種說法（隨便挑一種）
const SAY := {
	# ---------- 來算帳的 ----------
	"revenge_kin": {
		"rough": ["「{victim}是我{rel}。我找你找了很久。」", "「你殺了我{rel}。今天你別想走。」"],
		"cold": ["「{victim}。」{pron}只說了這個名字，就把{noun}拔了出來。", "「{victim}是我{rel}。我不想跟你多說。」"],
		"proud": ["「{victim}是我{rel}。你這種人，也配動{vpron}？」"],
		"plain": ["「{victim}是我{rel}。{vpron}死的時候，我不在那裡。」"],
	},
	"revenge_beaten": {
		"rough": ["「{gplace}那次，你拿走了我的{thing}。今天連本帶利拿回來。」"],
		"cold": ["「{gplace}。你拿了我的{thing}。」"],
		"proud": ["「{gplace}那次是我大意。我的{thing}，我來拿回去。」"],
		"plain": ["「{gplace}那次的事，我一直記著。把我的{thing}還來。」"],
	},
	"revenge_heir": {
		"rough": ["「{victim}欠我的，{vpron}死了，你來還。」"],
		"cold": ["「{victim}的帳，算在你頭上。」"],
		"proud": ["「{victim}死得太早了，只好找你。」"],
		"plain": ["「我跟{victim}有一筆帳沒算完。{vpron}的東西在你身上，帳也在你身上。」"],
	},
	"bounty": {
		"rough": ["{pron}從懷裡掏出一張揉皺的紙，抖開來。上面畫的是你，畫得不太像。「死活不論。」"],
		"cold": ["{pron}把一張摺起來的紙攤開給你看。上面畫的是你。「跟我回霜溪城。」"],
		"proud": ["「公會的牆上有你的畫像。」{pron}把紙摺好，收回懷裡。「畫得比你本人好看。」"],
		"plain": ["「公會貼了你的懸賞。」{pron}嘆了口氣。「我只是來領錢的，你別讓我難做。」"],
	},
	# ---------- 比劍 ----------
	"challenge": {
		"rough": ["「{rank}來，打一場。點到為止，誰輸了誰請酒。」"],
		"cold": ["「{rank}比一場。點到為止。」"],
		"proud": ["「{rank}我想看看是不是真的。」"],
		"plain": ["「{rank}我想跟你比一場，點到為止。」"],
	},
	"challenge_no": {
		"rough": ["{name}「呸」了一聲：「沒種。」"],
		"cold": ["{name}什麼都沒說，轉身走了。"],
		"proud": ["「怕了？」{name}沒等你回答，轉身走了。"],
		"plain": ["「那就下次。」{name}朝你點了點頭，走了。"],
	},
	# ---------- 傳話警告 ----------
	"warn": {
		"rough": ["「聽說你接了{target}的懸賞。{target}是我{rel}。你敢動{tpron}，我先動你。」"],
		"cold": ["「{target}是我{rel}。別動{tpron}。」"],
		"proud": ["「聽說你接了{target}的懸賞。{target}是我{rel}。你自己掂量。」"],
		"plain": ["「{target}是我{rel}。{tpron}做的事我知道，我會去管。你把懸賞退了吧。」"],
	},
	# ---------- 求你幫忙 ----------
	"ask_help": {
		"rough": ["「{reason}我打不過{tpron}。你行。」"],
		"cold": ["「{reason}我殺不了{tpron}。」{pron}看著你。「你可以。」"],
		"proud": ["「{reason}這種事，我本來不求人。」{pron}停了一下。「我打不過{tpron}。」"],
		"plain": ["「{reason}我打不過{tpron}。我知道這不關你的事。」"],
	},
	"ask_no": {
		"rough": ["{name}把杯子重重放下，走了。"],
		"cold": ["「我知道了。」{name}站起來，走了。"],
		"proud": ["「當我沒說。」"],
		"plain": ["「我知道了。」{name}低下頭，過了一會兒才走。"],
	},
	"thanks": {
		"rough": ["「{target}死了，我聽說了。」{pron}把一個錢袋塞進你手裡。「拿著，別跟我推。」"],
		"cold": ["「{target}的事，謝了。」{pron}把一個錢袋放在桌上，推到你面前。"],
		"proud": ["「{target}死了。」{pron}看著你，過了一會兒才說：「這份情我記著。」{pron}把一個錢袋放在你手邊。"],
		"plain": ["「{target}死了，我去{tpron}死的地方看過了。」{pron}把一個錢袋交給你。「我只有這些。」"],
	},
	"broke": {
		"rough": ["「你答應過我{target}的事。{target}到現在還活得好好的。」"],
		"cold": ["{name}看見你，沒有打招呼。「{target}還活著。」"],
		"proud": ["「你答應過的事，看來是隨口說說。」"],
		"plain": ["「{target}的事，你是不是忘了？」"],
	},
	# ---------- 報恩 ----------
	"repay": {
		"rough": ["「這個你拿著。不拿就是看不起我。」"],
		"cold": ["「我不喜歡欠人。」"],
		"proud": ["「我不欠人東西。」"],
		"plain": ["「我一直想找機會謝你。」"],
	},
	# ---------- 邀你一起去打懸賞 ----------
	"invite": {
		"rough": ["「{target}的懸賞，我一個人吃不下。一起去，賞錢{share}。」"],
		"cold": ["「{target}。兩個人去，賞錢{share}。去不去？」"],
		"proud": ["「{target}的懸賞我要了。你願意的話，可以跟著來，賞錢{share}。」"],
		"plain": ["「我想去接{target}的懸賞，一個人怕不夠。你要不要一起？賞錢{share}。」"],
	},
	"invite_no": {
		"rough": ["「隨你。」"],
		"cold": ["{name}點了一下頭，沒再說什麼。"],
		"proud": ["「那賞錢我一個人拿。」"],
		"plain": ["「那我再找找別人。」"],
	},
	# ---------- 收過路費 ----------
	"toll": {
		"rough": ["「過去可以，{toll} 銀。」"],
		"cold": ["「{toll} 銀。」{name}用下巴指了指腳邊的木箱。"],
		"proud": ["「這條路有主人了。{toll} 銀，不二價。」"],
		"plain": ["「{toll} 銀，誰過都一樣。我也要吃飯。」"],
	},
	# ---------- 來告訴你一件事（認識的人） ----------
	"tell": {
		"rough": ["「喂，有件事你最好知道。」"],
		"cold": ["「有件事。」"],
		"proud": ["「有件事，我猜你還不知道。」"],
		"plain": ["「有件事要跟你說。」"],
	},
	# ---------- 路上 ----------
	"rob": {
		"rough": ["「東西留下，人可以走。」"],
		"cold": ["「錢袋。」"],
		"proud": ["「把錢袋丟過來。我今天心情好，不殺人。」"],
		"plain": ["「我們只要錢。別逼我們動手。」"],
	},
	"traveler": {
		"rough": ["{pron}朝你舉了舉杯子，酒灑了一點在桌上。"],
		"cold": ["{pron}看了你一眼，又低頭喝自己的酒。"],
		"proud": ["{pron}看了你腰上的{my}一眼，嘴角往下撇了撇。"],
		"plain": ["{pron}朝你點了點頭，把桌上的東西往裡挪了挪。"],
	},
	"saved": {
		"rough": ["「差一點。」{pron}喘著氣。「這次欠你的。」"],
		"cold": ["「欠你一次。」"],
		"proud": ["「我本來撐得住。」{pron}看了看身上的傷，沒有再說下去。過了一會兒：「謝了。」"],
		"plain": ["「要不是你，我今天就死在這裡了。這次欠你的。」"],
	},
	# ---------- 打起來之前（交過手、有過節的人） ----------
	"again": {
		"rough": ["「又是你。」{name}啐了一口，把{noun}握緊了。"],
		"cold": ["{name}認出了你，什麼都沒說，把{noun}舉了起來。"],
		"proud": ["「又見面了。」{name}慢慢把{noun}舉起來。"],
		"plain": ["「是你。」{name}嘆了口氣，把{noun}舉了起來。"],
	},
}

## 跟你之間的事（記在他身上，見 Person.memo）。{place} 在哪 {item} 東西 {target} 說到的人 {victim}{rel} 死的人、是他的誰
##   me：人物面板上寫的（你這邊看）；past：他說話時提起來（沒寫的就不提）；ref：別人說到他時怎麼認（「就是……的那個」）
const MEMO := {
	"beat_you": {"me": "{pron}在{place}打倒了你{took}。", "past": "「{place}那次，你倒下去的樣子我還記得。」", "ref": "在{place}打倒你{took}"},
	"lost_to_you": {"me": "你在{place}打倒了{pron}。", "past": "「{place}那次是你贏。」", "ref": "在{place}被你打倒"},
	"spared": {"me": "你在{place}放了{pron}一條生路。", "past": "「{place}那次，你沒殺我。」", "ref": "你在{place}放走"},
	"robbed_by_you": {"me": "你在{place}拿走了{pron}的{item}。", "past": "「{place}那次，你拿走了我的{item}。」", "ref": "在{place}被你拿走{item}"},
	"duel_won": {"me": "你在{place}跟{pron}比劍，輸了。", "past": "「{place}那一場，是我贏。」", "ref": "在{place}跟你比劍、贏了你"},
	"duel_lost": {"me": "你在{place}跟{pron}比劍，贏了。", "past": "「{place}那一場是你贏。我回去又練了。」", "ref": "在{place}跟你比劍、輸給你"},
	"duel_declined": {"me": "{pron}在{place}找你比劍，你沒比。", "past": "「上次在{place}，你不肯跟我比。」", "ref": "在{place}找你比劍"},
	"saved": {"me": "{pron}在{place}被人圍住，你救了{pron}。", "past": "「{place}那次，要不是你，我已經死了。」", "ref": "你在{place}救下來"},
	"left": {"me": "{pron}在{place}被人圍住，你轉身走了。", "past": "「{place}那次，你看見我被圍住，轉身就走了。」", "ref": "在{place}被人圍住、你沒管"},
	"buried": {"me": "你在{place}埋了{pron}的{rel}{victim}。", "past": "「我{rel}是你埋的。」", "ref": "你埋了{pron}{rel}"},
	"killed_kin": {"me": "你殺了{pron}的{rel}{victim}。", "ref": "你殺了{pron}{rel}"},
	"paid": {"me": "你在{place}付了{pron}錢，了結了舊帳。", "past": "「錢我收了，那件事已經了了。」", "ref": "在{place}收了你的錢、了結舊帳"},
	"bribed": {"me": "{pron}在{place}收了你的錢，放你走了。", "past": "「{place}那次，我收了你的錢。」", "ref": "在{place}收了你的錢、放你走"},
	"backed_off": {"me": "{pron}在{place}堵你，被你叫了回去。", "past": "「{place}那次，我退了一步。」", "ref": "在{place}堵你、又退回去"},
	"warned": {"me": "{pron}叫你別動{target}。", "past": "「我叫過你別動{target}。」", "ref": "叫你別動{target}"},
	"warn_heeded": {"me": "{pron}叫你別動{target}，你把懸賞退了。", "past": "「{target}的事，我記著。」", "ref": "叫你別動{target}"},
	"warn_defied": {"me": "{pron}叫你別動{target}，你說懸賞已經接了。", "past": "「我跟你說過，別動{target}。」", "ref": "叫你別動{target}"},
	"promised": {"me": "你答應{pron}去對付{target}。", "past": "「你答應過我{target}的事。」", "ref": "求你去對付{target}"},
	"refused": {"me": "{pron}求你去對付{target}，你沒答應。", "past": "「上次我求你，你說不關你的事。」", "ref": "求你去對付{target}"},
	"kept": {"me": "你替{pron}對付了{target}。", "past": "「{target}的事，我還欠你。」", "ref": "你替{pron}對付了{target}"},
	"broke": {"me": "你答應{pron}去對付{target}，沒有去。", "past": "「你答應過我的事，你沒辦。」", "ref": "求你去對付{target}"},
	"invite_declined": {"me": "{pron}找你一起去打{target}，你沒去。", "past": "「上次叫你一起去，你不去。」", "ref": "找你一起去打{target}"},
	"hunted_with": {"me": "你跟{pron}一起去打{target}。", "past": "「{place}那一仗，是我們兩個一起打的。」", "ref": "跟你一起去打{target}"},
	"gift": {"me": "{pron}還了欠你的情。"},
	"pitied": {"me": "{pron}在{place}攔路，你丟了錢給{pron}。", "past": "「{place}那次，你丟給我的錢，我還記得。」", "ref": "在{place}攔路、你丟了錢給{pron}"},
	"robbed_you": {"me": "{pron}在{place}攔路，搶了你的錢。", "past": "「{place}那次，你的錢袋是我拿的。」", "ref": "在{place}搶了你的錢"},
	"scared": {"me": "{pron}在{place}攔你，被你嚇跑了。", "past": "「{place}那次，我跑了。這次不會。」", "ref": "在{place}攔你、被你嚇跑"},
	"stripped": {"me": "{pron}在{place}攔路，被你打倒，你搜光了{pron}身上。", "past": "「{place}那次，你連我身上幾個銅板都拿走了。」", "ref": "在{place}被你打倒、搜光身上"},
	"paid_toll": {"me": "你在{place}付了{pron}過路費。"},
}

## 有人來找你：每回來一次最多幾件（傳話加主動找你）、主動找你的最多幾件
const PER_RETURN := 2
const APPROACH_PER_RETURN := 1
## 主動找你：條件成立時，每回來一次碰上的機率；同一種事隔幾個月才再有；同一個人隔幾個月才再來
const VISIT_CHANCE := {"challenge": 0.25, "ask_help": 0.35, "repay": 0.5, "invite": 0.25, "thanks": 1.0, "broke": 0.6, "warn": 1.0, "toll": 1.0}
const VISIT_AGAIN := {"challenge": 18, "ask_help": 18, "repay": 12, "invite": 18, "thanks": 0, "broke": 24, "warn": 0, "toll": 0}
const PERSON_AGAIN := 18
## 傳話：幾個月沒傳到就不傳了
const TIDING_STALE := 18
## 答應了沒去辦：過幾個月他會來問
const PROMISE_DUE := 30
## 求你幫忙的人要先聽說過你（名聲），或跟你有過交情
const ASK_FAME := 3.0
## 謝禮
const THANKS_MONEY := [40, 90]
## 一起去打懸賞：兩個人加起來比較強的那個再加多少（看起來）
const TEAM_BONUS := 1.0
## 一起去打輸了，他死在那裡的機率
const TEAM_DEATH := 0.3
## 一起去打懸賞：他要找跟他差不多的人（你比他弱不過這麼多）；他比你弱，就讓你拿多一點
const INVITE_GAP := 0.5
const SHARE_MORE := 0.6
const SHARE_TEXT := {false: "對半", true: "你拿六成"}

## 城裡固定的人（不是世界上會打架的人）：來告訴你事情的
const TELLERS := {
	"inn": {"title": "旅店老闆娘 葛蕾塔", "pron": "她", "scene": [
		"你回到旅店，老闆娘葛蕾塔把你叫到櫃台邊，壓低了聲音。",
		"葛蕾塔把一碗湯放在你面前，沒有走開。",
	]},
	"guild": {"title": "公會書記 歐文", "pron": "他", "scene": [
		"公會的書記歐文從櫃台後面探出頭來，朝你招手。",
	]},
	"shop": {"title": "武器店老闆 布魯諾", "pron": "他", "scene": [
		"武器店的布魯諾在門口叫住你，手上還拿著磨刀石。",
	]},
}
## 傳話：發生了什麼跟你有關的事（認識的人、城裡的人來告訴你）。{about}{apron} 說到的人；{ref} 他是誰（跟你的舊事）
const TIDINGS := {
	"hunted": "「{about}{ref}在打聽你。」",
	"bounty_taker": "「{about}{ref}接了你的懸賞，在公會問了很多你的事。」",
	"kin_knows": "「{victim}的{rel}{about}，知道是你下的手了。{apron}收拾了東西出城去了，走之前說，總有一天會回來找你。」",
	"heir_grudge": "「{about}{ref}聽說{old}死了，東西都到了你手上。{apron}在打聽你。」",
	"bounty_on_you": "「牆上多了一張懸賞，畫的是你。」{pron}看了看四周。「說你在{place}殺了{victim}。」",
	"item_sold": "「你以前的{item}，{seller}拿來賣了。我掛在牆上了。」",
}
## 有人死了（跟你有過節、有交情的人）
const DEATH := {
	"killed": "「{about}{ref}死了。在{place}，是{killer}下的手。」",
	"anon": "「{about}{ref}死了。屍體是在{place}找到的，沒人說得清是誰下的手。」",
	"old": "「{about}{ref}死了。病了一個冬天，沒撐過去。」",
}
## 你被拿走的東西，現在在哪
const ITEM_NOW := {
	"held": "「你被拿走的{item}，現在在{holder}手上。」",
	"shop": "「你被拿走的{item}，後來掛到了武器店的牆上。」",
	"buried": "「你被拿走的{item}，跟著{apron}下葬了。」",
}
## 說到的人是誰（跟你的舊事）：接在名字後面「，就是……的那個，」
const REF := "，就是{ref}的那個，"
## 問他在哪
const WHERE_REPLY := "{teller}說，最後有人在{where}看見{apron}。"
const WHERE_UNKNOWN := "{teller}說，沒人知道{apron}現在在哪。"

## 找你幫忙的理由（他為什麼記仇）
const REASON := {
	"kin": "{target}殺了我{rel}{victim}。",
	"beaten": "{target}在{gplace}打傷了我，拿走了我身上的東西。",
	"other": "我跟{target}有仇。",
}
## 強者榜上誰在前面（比劍的理由）
const RANK := {
	"ahead": "公會牆上，你的名字寫在我前面。",
	"behind": "公會牆上，我排在你前面。有人說你不服。",
	"none": "聽說你很能打。",
}

## 一起去打懸賞的結果
const HUNT_WIN := "你們在{place}找到了{target}。{name}從正面上，你繞到{tpron}側面。打完的時候，{name}的{noun}上全是血。"
const HUNT_WIN_TAKE := "{name}從{target}身上拿走了{things}。"
const HUNT_LOSE := "你們在{place}找到了{target}。{tpron}比你們想的難纏。你扶著{name}退了回來，兩個人身上都是傷。"
const HUNT_DEAD := "你們在{place}找到了{target}。{name}沒有退下來。你一個人回到了{home}。"
const HUNT_GONE := "你們到了{place}，{target}已經不在那裡了。白跑了一趟。"
