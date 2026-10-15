# Architecture

## Hardware roles
| Machine | GPU | Role |
|---|---|---|
| **Laptop** (i9, RTX 3060 6GB) | 6 GB | Collectors (CPU), normalize/dedupe, **bge-m3 embeddings + clustering**, Postgres/SQLite, dashboard |
| **Derek's PC** (i5, RTX 3060 12GB, via Tailscale) | 12 GB | **Ollama** serving region analysts + cross-origin judge (`OLLAMA_HOST=0.0.0.0`, firewall to tailnet only) |

## Pipeline
```
sources/*.yaml ─► collectors (rss, gdelt, bluesky, mastodon, telegram, official, google_news,
                  community, youtube, wikipedia, reddit*)          *pending API approval
      │  raw JSON lines → data/raw/YYYY-MM-DD/<type>.jsonl
      ▼
normalize: NFKC, strip HTML/boilerplate (trafilatura), lang detect (fastText lid.176),
           canonical URL (unwrap Google News/AMP/trackers), map source → region/country/label
      ▼
dedupe:   exact (canonical_url, sha256(title+url)) → near-dup (simhash Hamming ≤3)
          → wire-copy detection (same lead paragraph across outlets ⇒ "syndicated_from")
      ▼
embed:    bge-m3 (fp16 ~1.2GB VRAM, laptop) on title + lead 512 tok, original language
      ▼
cluster:  online nearest-centroid (cos ≥ 0.80, 48h window) + HDBSCAN on leftovers every 30 min
          → events (clusters) with members across regions/languages
      ▼
analyze (Derek's PC, Ollama): per item → JSON {claims[], actors[], stance_per_actor, framing,
          loaded_terms[], omissions_vs_cluster[]} by the *region analyst*; then a *cross-origin judge*
          re-scores framing/claims for every cluster
      ▼
score:    per cluster × region snapshot → score_snapshots (hourly)
      ▼
dashboard: event list, region heatmap, claim matrix, blind-spot report, links to every original
```

## Item schema (`raw_items` / normalized)
| field | type | notes |
|---|---|---|
| id | bigserial | |
| source_type | text | rss, gdelt, bluesky, mastodon, telegram, official, google_news, community, youtube, wikipedia, archive, reddit |
| source_id | text | key from sources/*.yaml |
| outlet / author | text | |
| region / country | text | north_america, russia, china, japan, asia, middle_east, south_america, europe, global; ISO-3166 |
| lang | text | ISO-639-1 |
| affiliation | text | state-affiliated, public-broadcaster, independent, intergovernmental, government |
| label | text | see below |
| url, canonical_url | text | |
| title, summary, body | text | body only when license/robots allow; else summary |
| published_at, fetched_at | timestamptz | |
| content_hash, simhash | text, bigint | |
| embedding | vector(1024) | bge-m3 |
| cluster_id | bigint | |
| syndicated_from | bigint | wire copy origin |
| analysis | jsonb | region analyst output + model id |
| archive_url | text | Wayback snapshot (edit tracking) |

## Source labels
| Label | Assigned when |
|---|---|
| verified reporting | Independent/public outlet original reporting, corroborated by ≥2 independent outlets from ≥2 regions |
| official statement | Government, ministry, central bank, UN/agency feed (official.yaml) |
| **state-affiliated media** | Outlet with `affiliation: state-affiliated` (editorial control by a state, e.g. TASS, RIA, RT, Xinhua, CGTN, Global Times, Press TV, VOA/RFE/RL*) |
| expert analysis | Think tanks, academics, verified expert accounts |
| community report | Eyewitness/local posts (Mastodon, Lemmy, Reddit) from trusted accounts |
| social-media claim | Bluesky/Telegram/YouTube/X posts not yet corroborated |
| opinion | Op-ed/editorial/analysis sections |
| unverified | Default for new single-source items |
| conflicting | Overlay flag: cluster contains contradicting claims, or item corrected/removed |
\*US government-funded outlets are labeled state-affiliated too: the same rule applies to every origin.

## Models (Ollama 0.34.2 on Derek's PC, RTX 3060 12GB): installed and measured 2026-10-15
Models are stored in `D:\ollama\models`. Speeds are from one short multilingual prompt through `/api/generate` (generation t/s = eval_count / eval_duration), with `think=false`. All ran at 100% GPU (`ollama ps`).

| Role | Tag (default quant) | Disk | VRAM loaded | Gen t/s @ ctx | Origin |
|---|---|---|---|---|---|
| Main analyst (ru/es/pt/en/eu; Russia, Americas, Europe) | `gemma4:12b` | 8.0 GB | ~11.0 GB used @ 8K | **47.7 @ 8K**, 49.8 @ 4K | Google (US) |
| China/Japan/Asia analyst, CJK cross-check | `qwen3.5:9b` | 6.6 GB | 5.8 GB | **44.8 @ 8K** | Alibaba (CN) |
| Stronger Chinese cross-check (optional) | `qwen3:14b` | 9.3 GB | 10 GB | **27.8 @ 4K**; 10.7 @ 8K (VRAM nearly full, slows down) | Alibaba (CN) |
| EU judge / tiebreak | `ministral-3:14b` | 9.1 GB | 9.4 GB | **28.0 @ 8K** | Mistral (FR) |
| Multilingual judge | `aya-expanse:8b` | 5.1 GB | 6.4 GB | **49.8 @ 8K** | Cohere (CA), CC-BY-NC |
| Embeddings | `bge-m3` (567m) | 1.2 GB | 0.66 GB | 3 short texts in 21.8 s, cold load included | BAAI (CN) |

Notes:
- The first `gemma4:12b` load failed with `CUDA error: shared object initialization failed`. The retry worked, which looks like a one-time CUDA init problem. If it comes back, update the NVIDIA driver.
- Run `qwen3:14b` at a 4K context, or use `qwen3.5:9b`. At 8K it nearly fills the 12 GB and drops to about 11 t/s.
- No dedicated Japanese or Russian model was added. The Ollama library has none that both fits 12 GB and beats Gemma 4 / Qwen 3.5 on these languages. Gemma 4 handles ru/ja, and Qwen 3.5 handles ja/zh/ko.
- Cold loads from D: take 45–125 s. Batch the work by model and keep `OLLAMA_KEEP_ALIVE` long.
- bge-m3 is also on this PC, but the plan runs embeddings on the laptop (6 GB).

## Model-swap schedule (one big model resident at a time on 12 GB)
| Time (PT, MST) | Resident model | Work |
|---|---|---|
| :00–:25 each hour | gemma4:12b (8K ctx) | analyst pass for ru/es/pt/en/eu items + judge for Qwen-analyzed clusters |
| :25–:50 | qwen3.5:9b (8K ctx; qwen3:14b @4K for PRC-heavy clusters) | analyst pass for zh/ja/ko/asia items + judge for Gemma-analyzed clusters |
| :50–:60 | ministral-3:14b or aya-expanse:8b (tiebreak) | only clusters with model disagreement > 0.3 |
| 02:00–05:00 nightly | rotate | backfill, re-score last 72 h, blind-spot report at 06:00 |
Batch by model to avoid reload cost (cold load measured at 45–125 s from D:); `OLLAMA_KEEP_ALIVE=30m`, `OLLAMA_NUM_PARALLEL=2`, context 8–16K.

## Scoring (per cluster *c*, region *r*, hourly snapshot)
- **Coverage** C = 1 if region r has ≥1 non-duplicate item in c.
- **Agreement** A = |claims_r ∩ claims confirmed by ≥2 other regions| / |claims_r|
- **Omission** O = |core claims (present in ≥50% of covering regions) missing from r| / |core claims|
- **Framing gap** F = mean over key actors of |stance_r(actor) − weighted global mean stance(actor)| / 2
  (state-affiliated items weight 0.5 in the global mean; syndicated wire copies count once)
- **Model disagreement** D = mean |analyst − judge| over A, O, F
- **Consensus score** S = 100 × (0.4·A + 0.3·(1−O) + 0.3·(1−F)), reported with confidence = 1 − D
- **Blind spot** flagged when cluster covered by ≥3 regions and C_r = 0, or only state-affiliated sources in r cover it
- **Framing shift** flagged when ΔF over 24 h > 0.25

## Bias controls
- Different-origin analyst and judge; never same model for both.
- PRC-sensitive keyword list → mandatory Gemma judge; Russia/Ukraine → mandatory Qwen + Ministral judge.
- Prompts in source language; outputs in English JSON with quoted spans for every claim (auditable).
- Labels on state-affiliated media applied symmetrically to all origins.

## Data & terms
Personal, non-commercial. Store links + summaries; respect robots/terms of each source; Reddit pending approval and never used for training.
