> **Status: PENDING Reddit Data API approval.** Not active until approved; subreddit list unverified.

# Reddit Collector Spec — Multi-Country News System
Version 0.1 · 2026-10-15 · Owner: Ulises

## 1. Purpose & position in the pipeline
Reddit is a **signal layer, not a source of truth**. It detects early or under-reported stories, regional reactions, corrections, and links to the original sources. Every Reddit item enters the shared pipeline as a `raw_item` (source_type=`reddit`) and goes through the same normalize → dedupe → embed (bge-m3, laptop) → cluster → per-country model analysis (Derek's RTX 3060) steps as RSS. A Reddit post can never carry the `verified reporting` label by itself; only the outlet it links to can.

## 2. Access rules (checked 2026-10-15)
- **Approval required.** Under the Responsible Builder Policy you must request access and get explicit approval before using the Data API. Register a "script" app at reddit.com/prefs/apps, and use one account per use case. Registering multiple accounts to get around limits is prohibited.
- **OAuth required.** Traffic without OAuth is blocked. Testing from this box confirmed it: unauthenticated `about.json` calls failed for every subreddit.
- **Rate limit (free tier):** **100 queries per minute per OAuth client ID**, averaged over a 10-minute window. Budget for **≤ 60 QPM** to leave headroom. Watch the `X-Ratelimit-Remaining`, `-Used` and `-Reset` response headers.
- **User-Agent** must be unique and descriptive: `linux:ulises-newsradar:0.1.0 (by /u/<username>)`. Default user-agents are heavily throttled.
- **No AI training.** You may not use Reddit content to train or fine-tune ML/AI models without permission, and you may not sell or share the data. **Allowed in this design:** running inference and analysis on it (summaries, embeddings for clustering, scoring), with nothing used for training. Never fine-tune the per-country models on Reddit text, and never export Reddit text to third parties.
- **Deletion compliance:** content deleted on Reddit must be removed from your store. The removal tracker (§5.5) does this: store only the fact that an item was deleted plus metadata, not the text.
- **Commercial use, or research beyond these limits**, needs a separate agreement with Reddit.
- Sources: https://support.reddithelp.com/hc/en-us/articles/16160319875092-Reddit-Data-API-Wiki · https://support.reddithelp.com/hc/en-us/articles/42728983564564-Responsible-Builder-Policy · https://redditinc.com/policies/data-api-terms · https://support.reddithelp.com/hc/en-us/articles/14945211791892-Developer-Platform-Accessing-Reddit-Data

## 3. Library choice
**asyncpraw** (async version of PRAW). It handles OAuth, rate-limit headers, `MoreComments` expansion, and streams.
- Why: the collector runs many subreddit polls concurrently with a single shared limiter, and it fits an asyncio pipeline next to the RSS fetchers.
- PRAW (sync) is fine for one-off backfills and debugging.
- Settings: `ratelimit_seconds=300`; make one Reddit client and reuse it; read-only script auth.
- Put a token bucket in front of it (aiolimiter: 60 per 60 s) so a burst in comment expansion can't use up the budget.

## 4. Starter subreddit lists
> ⚠ **Unverified.** Reddit blocked every check from this box (no OAuth), so none of these subreddits could be confirmed to exist, and no sizes are listed. Run `scripts/verify_subs.py` once OAuth credentials exist. It calls `subreddit.load()` and records `subscribers`, `subreddit_type`, `over18` and posts/day, then removes anything that is missing, private or banned. Treat the names below as candidates.

| Region | English-language | Native-language | Notes |
|---|---|---|---|
| North America | news, politics, canada, CanadaPolitics, mexico, PuertoRico | mexico (es), Quebec (fr) | US partisan balance: also add Conservative and progressive subs, tagged `opinion` |
| Russia | russia, AskARussian, RussiaLago*, ukraine, UkrainianConflict | liberta (ru), Pikabu-style mirrors* | Heavy brigading and moderation bias in both directions; trust mostly the links, not the comments |
| China | China, Sino, taiwan, HongKong, China_irl | China_irl (zh) | China_irl and Sino lean opposite ways; tag the community's stance |
| Japan | japan, japannews, japanlife | newsokur (ja), lowlevelaware (ja)* | Japanese-language Reddit is small; rely on RSS more |
| Wider Asia | korea, india, IndiaSpeaks, pakistan, bangladesh, Philippines, indonesia, singapore, malaysia, vietnam, thailand, southeastasia | hanguk (ko)*, indonesia (id) | India subs are strongly polarized; tag stance |
| South America | brasil, argentina, chile, colombia, peru, vzla, uruguay, LatinAmerica | same subs (pt/es) | Mostly native-language already |
| Global | worldnews, geopolitics, anime_titties (world news despite the name), europe, CredibleDefense, OSINT, journalism | — | CredibleDefense and OSINT flairs/expertise feed expert scoring |
`*` = low confidence that the name exists.

## 5. Features
### 5.1 Post ingestion
- Poll `new` (and `rising` for velocity) for each subreddit.
- Store: id, sub, title, selftext hash, url, domain, author (hashed), created_utc, flair, score, upvote_ratio, num_comments.
- Also store `crosspost_parent` and the language (from fastText lid.176, or the subreddit's default language).

### 5.2 Comment mining
For posts that qualify (velocity ≥ threshold, or the post joins an existing cluster):
- Fetch the top 50 comments plus the full tree to depth 3, with `replace_more(limit=8)`.
- Extract: links to sources, eyewitness markers ("I'm in", "here in", local-language equivalents), and correction cues ("source?", "this is old", "fake", "debunked", "actually").
- Send the comments to the per-country model as **reactions**, not as facts.

### 5.3 Velocity detection
- velocity = Δscore/Δt and Δcomments/Δt, sampled at T+15m, 1h, 3h, 6h, 24h.
- Normalize by subreddit: z-score against the sub's rolling 14-day median for posts of the same age.
- Mark a post `surging` when z ≥ 3 at ≤ 2 h old. A surging post gets comment mining plus a forced RSS search for coverage of that event.

### 5.4 Cross-sub spread
- Link items through the same resolved URL, crosspost_parent, or a bge-m3 title similarity ≥ 0.80 within 48 h.
- Per event, record: number of distinct subs, regions reached, time to first post in each region, and language spread.
- A story that spreads across subs in one region but never reaches other regions is a blind-spot candidate.

### 5.5 Correction / removal tracking
Re-fetch tracked posts at 1 h, 6 h, 24 h, 72 h, and record each change:
- `removed_by_category` (moderator / deleted / automod / reddit)
- title flair changes (e.g. "Misleading", "Unverified", "Old")
- a locked post
- a stickied mod comment
- edits containing "EDIT: correction"

On author deletion: purge the stored text and keep only the event row.

Each removal or correction lowers the item's trust and posts a `conflicting` signal into its cluster.

### 5.6 Link resolution to original source
- Expand shorteners and redirects with HEAD/GET (limit 5 hops); strip tracking parameters.
- Unwrap archive.org, archive.ph and AMP to the canonical URL.
- Look up the domain in `outlets` (shared with RSS) to get country, state-affiliation and outlet type.
- Image, video and self posts → `social-media claim` or `community report`.
- If the original article isn't already in the RSS store, queue it for the article fetcher.

### 5.7 Account trust scoring (0–1, per author hash, stored pseudonymously)
`trust = 0.25·age_score + 0.20·karma_score + 0.20·history_diversity + 0.20·past_accuracy + 0.15·flair_bonus − penalties`
- age_score = min(age_days/730, 1).
- karma_score = log-scaled; drops to 0 below 100 karma.
- history_diversity = 1 − the share of the user's last 100 items that are in one sub.
- past_accuracy = (their items later confirmed by clusters) / (items they posted), with a prior of 0.5 and n = 10.
- Penalties: removed-for-misinformation count; posting the same link to ≥ 5 subs within 1 h (spam or campaign); account < 30 days old posting on geopolitics.
- Only public profile fields are used; no data is shared out.

### 5.8 Expert flairs
- Allowlist of subreddits with flair verification: AskHistorians, CredibleDefense, AskEconomics, askscience, …
- Flair pattern → `expert analysis`, with weight 1.2.
- Flair without verification has no weight.

### 5.9 Sentiment drift
- For each cluster × region, take comment stance and sentiment toward each key actor from the per-country model (−1..+1), in hourly buckets.
- drift = slope over 24 h; a sign flip triggers a `framing shift` event.
- Compare Reddit's drift for a region with that region's RSS media framing. A gap means the public and the media disagree.

### 5.10 Blind-spot report (daily, 06:00 PT)
For each cluster:
- Regions with Reddit activity but **no** RSS coverage, and the reverse.
- Regions whose state-affiliated media cover the story while that region's Reddit is silent, or the reverse.
- Top omissions (claims present in ≥ 3 regions but missing from region X).
Output as Markdown and JSON in `reports/blindspot-YYYY-MM-DD.md`.

## 6. Source label mapping
| Condition | Label |
|---|---|
| Link to an outlet with type=wire/newspaper/broadcaster, not state-affiliated | verified reporting (inherited from the outlet, pending cross-source confirmation) |
| Link to a .gov site, an official spokesperson, or a press release | official statement |
| Outlet tagged state_affiliated | state-affiliated media |
| Verified-expert flair, or a link to a think tank or academic source | expert analysis |
| Text/self post with eyewitness markers, account trust ≥ 0.5 | community report |
| Link to X/Telegram/TikTok/Weibo/VK, or a screenshot | social-media claim |
| Opinion flair, op-ed URL pattern, or an opinion subreddit | opinion |
| None of the above, or trust < 0.3 | unverified |
| Removed or corrected, or the cluster has contradicting claims | conflicting (overlay flag) |

## 7. Database schema (Postgres + pgvector; SQLite works with JSON text in place of arrays)
```sql
CREATE TABLE subreddits (
  name TEXT PRIMARY KEY, region TEXT, country TEXT, lang TEXT,
  stance_tag TEXT, subscribers INT, posts_per_day REAL,
  verified_at TIMESTAMPTZ, status TEXT CHECK (status IN ('active','missing','private','banned','paused')),
  poll_tier SMALLINT DEFAULT 2);

CREATE TABLE authors (
  author_hash TEXT PRIMARY KEY,       -- sha256(username + salt)
  created_utc TIMESTAMPTZ, karma INT, trust REAL, trust_components JSONB,
  removals INT DEFAULT 0, confirmed INT DEFAULT 0, posted INT DEFAULT 0, updated_at TIMESTAMPTZ);

CREATE TABLE posts (
  id TEXT PRIMARY KEY, subreddit TEXT REFERENCES subreddits, author_hash TEXT,
  title TEXT, selftext TEXT, url TEXT, resolved_url TEXT, domain TEXT, outlet_id INT,
  lang TEXT, flair TEXT, created_utc TIMESTAMPTZ, crosspost_parent TEXT,
  label TEXT, label_conf REAL, is_deleted BOOL DEFAULT FALSE, removed_by TEXT,
  first_seen TIMESTAMPTZ, last_polled TIMESTAMPTZ, next_poll TIMESTAMPTZ, raw_item_id BIGINT);

CREATE TABLE post_snapshots (            -- time series for velocity
  post_id TEXT REFERENCES posts, ts TIMESTAMPTZ, score INT, upvote_ratio REAL,
  num_comments INT, velocity_z REAL, PRIMARY KEY (post_id, ts));

CREATE TABLE comments (
  id TEXT PRIMARY KEY, post_id TEXT REFERENCES posts, parent_id TEXT, depth SMALLINT,
  author_hash TEXT, body TEXT, score INT, created_utc TIMESTAMPTZ, flair TEXT,
  is_expert BOOL, links TEXT[], cues TEXT[], stance JSONB, is_deleted BOOL DEFAULT FALSE);

CREATE TABLE moderation_events (
  id BIGSERIAL PRIMARY KEY, post_id TEXT, ts TIMESTAMPTZ,
  kind TEXT,  -- removed_mod|deleted|locked|flair_change|sticky_correction|edit_correction
  detail JSONB);

CREATE TABLE raw_items (                 -- shared with RSS
  id BIGSERIAL PRIMARY KEY, source_type TEXT, source_ref TEXT, title TEXT, body TEXT,
  url TEXT, lang TEXT, region TEXT, published TIMESTAMPTZ, label TEXT,
  content_hash TEXT, simhash BIGINT, embedding VECTOR(1024), cluster_id BIGINT);

CREATE TABLE clusters (id BIGSERIAL PRIMARY KEY, centroid VECTOR(1024), first_seen TIMESTAMPTZ, title TEXT, status TEXT);

CREATE TABLE cluster_spread (
  cluster_id BIGINT, region TEXT, subreddit TEXT, first_post_ts TIMESTAMPTZ,
  post_count INT, PRIMARY KEY (cluster_id, region, subreddit));

CREATE TABLE score_snapshots (           -- consensus/framing scores over time
  cluster_id BIGINT, region TEXT, ts TIMESTAMPTZ, source_type TEXT,
  agreement REAL, omission REAL, framing_gap REAL, sentiment JSONB,
  consensus REAL, model_disagreement REAL, model_ids TEXT[],
  PRIMARY KEY (cluster_id, region, ts, source_type));
CREATE INDEX ON posts (next_poll); CREATE INDEX ON raw_items USING hnsw (embedding vector_cosine_ops);
```

## 8. Polling schedule (budget ≈ 60 QPM = 3,600/hour)
| Job | Frequency | Approx. calls/hour |
|---|---|---|
| Tier 1 subs (global and major per region, ~15): `new` limit 100 | every 5 min | 180 |
| Tier 2 subs (~35) `new` | every 15 min | 140 |
| Tier 3 (small or native-language) | every 60 min | ~20 |
| `rising` on tier 1 | every 10 min | 90 |
| Snapshots of tracked posts (velocity) at T+15m/1h/3h/6h/24h, batched 100 ids per `/api/info` | rolling | ~50 |
| Comment mining (surging or clustered posts) | on trigger, ≤ 40 posts/hour × ~5 calls | ~200 |
| Removal/correction re-checks at 1h/6h/24h/72h via `/api/info` batches | rolling | ~30 |
| Author trust refresh (new authors in clustered items) | hourly, ≤ 300 | ~300 |
| Sub verification | daily 03:00 PT | ~60/day |
Total ≈ 1,000–1,100/hour, about 30% of the budget. The remaining headroom covers bursts during breaking news. If the `X-Ratelimit-Remaining` header falls below 100, pause tiers 3 → 2 and trust refresh first.

## 9. Config example (`config/reddit.yaml`)
```yaml
reddit:
  user_agent: "linux:ulises-newsradar:0.1.0 (by /u/YOUR_USERNAME)"
  client_id: ${REDDIT_CLIENT_ID}
  client_secret: ${REDDIT_CLIENT_SECRET}
  username: ${REDDIT_USERNAME}
  password: ${REDDIT_PASSWORD}
  qpm_budget: 60
  pause_when_remaining_below: 100
storage:
  dsn: postgresql://news@derek-pc.tailnet:5432/news   # or sqlite:///data/news.db
  author_salt: ${AUTHOR_SALT}
regions:
  north_america: {tier1: [news, politics, canada], tier2: [CanadaPolitics, mexico], tier3: [Quebec, PuertoRico]}
  russia:        {tier1: [russia, ukraine], tier2: [AskARussian, UkrainianConflict], tier3: [liberta]}
  china:         {tier1: [China, taiwan], tier2: [Sino, HongKong, China_irl]}
  japan:         {tier1: [japan], tier2: [japannews, japanlife], tier3: [newsokur]}
  wider_asia:    {tier1: [india, korea], tier2: [pakistan, Philippines, indonesia, singapore, vietnam, southeastasia], tier3: [bangladesh, malaysia, thailand]}
  south_america: {tier1: [brasil, argentina], tier2: [chile, colombia, vzla, peru], tier3: [uruguay, LatinAmerica]}
  global:        {tier1: [worldnews, geopolitics], tier2: [europe, anime_titties, CredibleDefense, OSINT]}
sub_meta:
  China_irl: {lang: zh, stance_tag: critical_of_prc}
  Sino:      {lang: en, stance_tag: pro_prc}
  liberta:   {lang: ru}
  newsokur:  {lang: ja}
keywords:            # boosts priority; multilingual
  - {term: "sanctions", langs: {ru: "санкции", zh: "制裁", ja: "制裁", es: "sanciones", pt: "sanções"}}
  - {term: "election",  langs: {ru: "выборы", zh: "选举", ja: "選挙", es: "elecciones", pt: "eleições"}}
  - {term: "protest",   langs: {ru: "протест", zh: "抗议", ja: "抗議", es: "protesta", pt: "protesto"}}
thresholds:
  velocity_z_surging: 3.0
  surging_max_age_min: 120
  cluster_sim: 0.80
  cluster_window_h: 48
  min_trust_community_report: 0.5
  unverified_below_trust: 0.3
  spam_same_link_subs_1h: 5
  comment_mining: {top_n: 50, depth: 3, replace_more: 8, max_posts_per_hour: 40}
snapshots_min: [15, 60, 180, 360, 1440]
recheck_min: [60, 360, 1440, 4320]
expert_flair_subs:
  AskHistorians: {pattern: ".*", weight: 1.2}
  CredibleDefense: {pattern: "(?i)verified|expert", weight: 1.2}
  AskEconomics: {pattern: "(?i)quality contributor|economist", weight: 1.2}
trusted_domains: [reuters.com, apnews.com, bbc.co.uk, nhk.or.jp, folha.uol.com.br, meduza.io, caixinglobal.com]
state_affiliated_domains: [tass.ru, rt.com, ria.ru, xinhuanet.com, globaltimes.cn, cgtn.com, telesurtv.net]
ignored_domains: [youtube.com/shorts]
ignored_authors: [AutoModerator]
ignored_flairs: ["Meme", "Humor", "Shitpost"]
privacy:
  store_usernames: false
  purge_deleted_text: true
  no_training_use: true    # Reddit Data API Terms
```

## 10. How items flow into normalize → dedupe → cluster
1. **Collect** (asyncpraw on the laptop or Derek's PC, CPU only) → `posts` / `comments` / `post_snapshots`.
2. **Resolve** the link → `resolved_url`, `outlet_id`. If it's a new article, put the URL in the RSS article-fetch queue so the original enters as its own `raw_item`.
3. **Normalize:** NFKC, strip markdown and emoji, detect the language, map the subreddit to region, compute `content_hash` = sha256(normalized title + resolved_url) and `simhash`(title + selftext). Write to `raw_items` (source_type=`reddit`, label from §6).
4. **Dedupe:**
   - exact: same `resolved_url` or `content_hash` → attach as a spread record (`cluster_spread`), not a new item;
   - near-duplicate: simhash Hamming ≤ 3 → same.
   - Crossposts always collapse into their parent.
5. **Embed** on the laptop GPU with bge-m3 (title + first 512 tokens of selftext or top comment summary), into `raw_items.embedding`.
6. **Cluster:** online assignment to the nearest cluster centroid (cosine ≥ 0.80, 48 h window); otherwise HDBSCAN on the leftovers every 30 min to start new clusters. Reddit-only clusters get the status `signal_only` until RSS coverage appears.
7. **Analyze** on Derek's RTX 3060 with the per-country model for the item's language/region:
   - claims, actors, stance;
   - comments → reaction stance;
   - a second model from a different origin cross-checks (see the earlier design).
8. **Score:** write `score_snapshots` hourly per cluster × region × source_type (`reddit` vs `rss`), so public reaction and media framing are compared, not merged.
9. **Report:** daily blind-spot report plus `framing shift` / `surging` alerts.

## 11. Open items
- Get Reddit API approval, then run `verify_subs.py` and fill in subscriber counts.
- Hand-curate `state_affiliated_domains` (Wikipedia's state media list and the EU/US designations are good starting points).
- Check that comment mining stays inside the QPM budget during a major breaking-news day.
