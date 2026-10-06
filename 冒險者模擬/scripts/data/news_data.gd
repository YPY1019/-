class_name NewsData
extends RefCounted

## 世界上發生的事傳開來的寫法（傳聞，在酒館聽得到）。只有資料。跟你有關的事有人來說，寫法在 TalkData。
## {p:id} 換成那個人的名字（是你就寫「你」）；{place} 地名；{item} 東西的樣子。
## 有些事有時候會說是誰做的，有時候不說（要自己在人物面板上認出那把劍）：見 World。

## 有人被殺了，知道是誰下的手
const KILL := [
	"{p:killer}在{place}殺了{p:victim}。",
	"聽說{p:victim}死在{place}，是{p:killer}下的手。",
	"{p:victim}在{place}跟{p:killer}交手，沒有再站起來。",
]
## 有人被殺了，沒人說得清是誰
const KILL_ANON := [
	"聽說{p:victim}死了。屍體是在{place}找到的。",
	"{p:victim}死在{place}。沒人說得清是誰下的手。",
	"有人在{place}看見{p:victim}的屍體，身上的東西都被拿走了。",
]
## 有人被打傷、東西被拿走（沒死）
const ROB := [
	"{p:winner}在{place}打傷了{p:loser}，拿走了{p:loser}身上的東西。",
]
const ROB_ANON := [
	"{p:loser}在{place}被人打成重傷，醒來的時候，身上的東西不見了。",
]
## 有人通過了劍庭的春季選拔
const JOINED := "開春，{p:who}通過了獅心劍庭的選拔，換上了學徒的灰衣。"
## 死人身上的殘頁落到別人手上
const PAGE_PASSED := "{p:who}的遺物裡有幾張燒焦的紙，後來落到了{p:to}手上。"
## 有人把用不上的好東西賣給了武器店
const SOLD := "{p:who}把{item}賣給了霜溪城的武器店。"
## 比劍認輸（決鬥大多點到為止）
const DUEL_WON := "{p:winner}在{place}跟{p:loser}比劍，{p:loser}認輸了。"
## 世界上的人自己的人生（不是打架的事）
const RETIRED := "{p:who}把兵器掛在牆上，說不出城了。"
const MARRIED := "{p:a}跟{p:b}成親了。"
const BORN := "{p:who}家裡多了一個孩子。"
const GROWN_UP := "{p:parent}的孩子{p:who}長大了，背著劍進了霜溪城。"
const DISCIPLE := "{p:master}收了{p:disciple}當徒弟。"
const PROMOTED := "{p:who}在劍庭的比試裡贏了，升為{rank}。"
const NEWCOMER := ["城裡來了一個從南邊來的%s，叫{p:who}。", "霜溪城的旅店住進一個外地來的%s，叫{p:who}，說是來接懸賞的。"]
## 決鬥
const DUEL := [
	"{p:a}向{p:b}下了戰書。",
]
## 老死、病死
const DIED := [
	"{p:who}老死了。",
	"{p:who}病了一個冬天，沒有撐過去。",
	"{p:who}在睡夢中走了。",
]
## 死後東西給了家人、徒弟；沒有人就跟著下葬
const INHERIT := "{p:who}身上的東西，留給了{p:heir}。"
const BURIED := "{p:who}身上的東西，跟著下葬了。"
## 懸賞撤下來了（人死了）
const BOUNTY_GONE := "公會把{p:who}的懸賞撕了下來。"
## 有人接下懸賞
const BOUNTY_TAKEN := "{p:hunter}接下了{p:target}的懸賞。"
## 老大死了，手下接手
const TAKEOVER := "{p:boss}死後，{p:who}接手了{p:boss}的人。"
const TAKEOVER_BOUNTY := "{p:boss}死了，{p:who}接手了{p:boss}的人，還在外面搶。懸賞{p:who}。"
## 有人變強了（境界升了）
const GREW := [
	"聽說{p:who}在{place}一個人打退了一群盜匪。",
	"{p:who}練劍的木樁又換了一根。",
	"有人說{p:who}最近出手快得看不清。",
	"{p:who}在酒館跟人比腕力，連贏了十幾個。",
]
## 家人、師徒、手下被殺了，要找兇手算帳
const GRIEF := "{p:who}聽說了{p:victim}的事。"
## 為了誓言出城
const VOW := "{p:who}背著劍出了城，說是要去找{p:target}。"
## 換人接著玩：世界記得上一個人
const REMEMBER := [
	"城裡的人還在說{p:who}的事。",
	"旅店老闆娘把{p:who}住過的房間收拾乾淨，好一陣子沒讓別人住。",
]
## 你殺了不該殺的人：公會貼出你的懸賞（懸賞板上的字）
const MURDER_BOUNTY := "{p:who}在{place}殺了{p:victim}。苦主湊了一筆錢，懸賞{p:who}的人頭。"
