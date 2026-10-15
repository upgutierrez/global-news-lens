# Source verification report
Checked 2026-10-15 from the box (single HTTP GET; feeds must parse with ≥1 entry, APIs must return JSON).

## Kept

| type | kept / tried |
|---|---|
| rss | 66 / 82 |
| official | 14 / 22 |
| bluesky | 20 / 23 |
| mastodon | 12 / 15 |
| telegram | 15 / 42 |
| google_news | 19 / 19 |
| bing_news | 0 / 7 |
| youtube | 14 / 18 |
| wikipedia | 7 / 8 |
| community | 7 / 7 |
| archive | 1 / 2 |
| gdelt | 7 / 20 |
| gdelt_gkg | 0 / 1 |

## Dropped / failed

### rss
- Washington Post World — `https://feeds.washingtonpost.com/rss/world` — HTTP 502
- CBC World — `https://www.cbc.ca/webfeed/rss/rss-world` — ReadTimeout
- Xinhua English — `http://www.xinhuanet.com/english/rss/worldrss.xml` — ConnectTimeout
- China Daily World — `http://www.chinadaily.com.cn/rss/world_rss.xml` — ConnectTimeout
- People's Daily EN — `http://en.people.cn/rss/90777.xml` — ConnectTimeout
- Caixin Global — `https://www.caixinglobal.com/rss/` — HTTP 403
- Focus Taiwan (CNA) — `https://focustaiwan.tw/rss/aall.xml` — HTTP 404
- NHK World English — `https://www3.nhk.or.jp/nhkworld/en/news/rss.xml` — HTTP 404
- Kyodo/Japan Wire — `https://english.kyodonews.net/rss/news.xml` — HTTP 404
- Nikkei Asia — `https://asia.nikkei.com/rss/feed/nar` — ReadTimeout
- Mainichi EN — `https://mainichi.jp/english/rss/etc/english.rss` — no entries
- Korea Herald — `https://www.koreaherald.com/common/rss_xml.php?ct=102` — no entries
- KCNA Watch — `https://kcnawatch.org/feed/` — no entries
- Arab News — `https://www.arabnews.com/rss.xml` — HTTP 403
- teleSUR — `https://www.telesurtv.net/rss/RssPortada.xml` — HTTP 404
- RFE/RL — `https://www.rferl.org/api/zrqiteuuir` — no entries

### official
- White House — `https://www.whitehouse.gov/feed/` — HTTP 404
- Kremlin EN — `http://en.kremlin.ru/events/all/feed` — ConnectTimeout
- Kremlin RU — `http://kremlin.ru/events/all/feed` — ConnectTimeout
- China MFA press — `https://www.fmprc.gov.cn/rss/zyxw.xml` — no entries
- Japan MOFA — `https://www.mofa.go.jp/rss/index.rdf` — HTTP 403
- Japan PM Office — `https://japan.kantei.go.jp/index-e.rdf` — HTTP 404
- India MEA — `https://www.mea.gov.in/rss.htm` — no entries
- EU EEAS — `https://www.eeas.europa.eu/eeas/press-material_en?f%5B0%5D=pm_category%3AStatement/Declaration&format=rss` — no entries

### bluesky
- bbc.co.uk — `https://public.api.bsky.app/xrpc/app.bsky.feed.getAuthorFeed?actor=bbc.co.uk&limit=5` — HTTP 400
- ft.com — `https://public.api.bsky.app/xrpc/app.bsky.feed.getAuthorFeed?actor=ft.com&limit=5` — HTTP 400
- dw.com — `https://public.api.bsky.app/xrpc/app.bsky.feed.getAuthorFeed?actor=dw.com&limit=5` — HTTP 400

### mastodon
- mastodon.social/@bbcnews — `https://mastodon.social/%40bbcnews.rss` — no entries
- mastodon.social/@Reuters — `https://mastodon.social/%40Reuters.rss` — HTTP 410
- mastodon.social/@aljazeera — `https://mastodon.social/%40aljazeera.rss` — no entries

### bing_news
- en-us — `https://www.bing.com/news/search?q=world&format=rss&setmkt=en-us` — no entries
- ru-ru — `https://www.bing.com/news/search?q=world&format=rss&setmkt=ru-ru` — no entries
- zh-cn — `https://www.bing.com/news/search?q=world&format=rss&setmkt=zh-cn` — no entries
- ja-jp — `https://www.bing.com/news/search?q=world&format=rss&setmkt=ja-jp` — no entries
- pt-br — `https://www.bing.com/news/search?q=world&format=rss&setmkt=pt-br` — no entries
- es-ar — `https://www.bing.com/news/search?q=world&format=rss&setmkt=es-ar` — no entries
- de-de — `https://www.bing.com/news/search?q=world&format=rss&setmkt=de-de` — no entries

### youtube
- RT — `https://www.youtube.com/feeds/videos.xml?channel_id=UCpwvZwUam-URkxB7g4USKpg` — HTTP 404
- Folha de S.Paulo — `https://www.youtube.com/feeds/videos.xml?channel_id=UCRgkZxs-WK2gwt7pIe0Pc9A` — HTTP 404
- Arirang News — `https://www.youtube.com/feeds/videos.xml?channel_id=UCzznGAeIY2lnRNDmbGCOxIw` — HTTP 404
- Meduza — `https://www.youtube.com/feeds/videos.xml?channel_id=UCB3tB5U5bJxQkdL6sp6HXqA` — HTTP 404

### wikipedia
- Wikinews (en) RSS — `https://en.wikinews.org/w/index.php?title=Special:NewsFeed&feed=atom` — HTTP 404

### archive
- Wayback CDX — `https://web.archive.org/cdx/search/cdx?url=bbc.co.uk/news/world&limit=5&output=json` — ReadTimeout

### Telegram host notes
- rsshub.app: HTTP 403 on all routes; rsshub.rssforever.com: timeouts/503. Use self-hosted RSSHub or t.me/s previews.
