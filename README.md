# Global News Lens

A personal, non-commercial tool that compares how news outlets and online communities in different countries cover the same world events. It runs entirely on my own hardware with local open-weight LLMs.

## What it does

1. Collects news from RSS feeds and public sources across North America, Russia, China, Japan, wider Asia, and South America.
2. Reads public posts and top comments from a fixed list of about 50 news and country-focused subreddits as early signals and public reaction (never treated as verified news).
3. Groups items about the same event across languages using multilingual embeddings.
4. Compares claims and framing between regions with local LLMs from different origins, and scores agreement, omissions, and framing gaps.
5. Shows results on a private dashboard, always linking back to the original article and Reddit thread.

## Reddit usage (read-only)

- One OAuth script app with a descriptive User-Agent, about 60 requests per minute (under the free limit).
- Read-only: no posting, commenting, voting, messaging, or moderation actions.
- Stores only IDs, links, score snapshots over time, and short summaries; stored text is deleted when content is removed on Reddit.
- No AI training or fine-tuning on Reddit data, and no sale or sharing of data.

## Status

Early development. Source lists verified 2026-10-15 (see `docs/source-verification.md`). RSS collector works; SearXNG and RSSHub run via docker-compose; GDELT collector written but GDELT was rate-limiting (HTTP 429) during testing. Reddit collector pending API approval.

## Repository structure

```
sources/                 # verified source lists (one YAML per source type)
  rss.yaml               # outlets by region, with affiliation (state-affiliated / public-broadcaster / independent) + language
  official.yaml          # governments, foreign ministries, UN, USGS, GDACS, central banks
  gdelt.yaml             # GDELT DOC 2.0 queries per country/language + GKG file feed
  google_bing_news.yaml  # Google News per-country editions (Bing dropped)
  bluesky.yaml           # public AppView author feeds of outlets/journalists
  mastodon.yaml          # instance hashtag + account RSS
  telegram.yaml          # public channels (self-hosted RSSHub / t.me/s previews)
  community.yaml         # Hacker News (Algolia), Lemmy
  youtube.yaml           # news channel RSS by channel id
  wikipedia.yaml         # current events portal, recent changes, EventStreams
  archive.yaml           # Wayback availability API for edit tracking
collectors/              # Python collectors (rss.py, gdelt.py, common.py)
docs/
  architecture.md        # pipeline, item schema, labels, scoring, model-swap schedule
  reddit-collector.md    # Reddit spec (PENDING API approval)
  source-verification.md # what was verified/dropped and why
requirements.txt
```

## Setup on Derek's PC (Windows 11, Docker Desktop + WSL2)

```powershell
git clone https://github.com/upgutierrez/global-news-lens D:\global-news-lens
cd D:\global-news-lens
copy .env.example .env      # set TS_IP to the PC's Tailscale IPv4 (tailscale ip -4) and a random SEARXNG_SECRET
docker compose up -d        # SearXNG + RSSHub, restart: unless-stopped
```

| Service | Local | Tailscale | Notes |
|---|---|---|---|
| SearXNG | http://127.0.0.1:8888 | http://100.100.43.107:8888 | JSON at `/search?q=...&format=json&language=ja`; limiter off (local use only) |
| RSSHub | http://127.0.0.1:1200 | http://100.100.43.107:1200 | e.g. `/telegram/channel/meduzalive` |
| Ollama | http://127.0.0.1:11434 | port 11434 via `tailscale serve` (tailnet only) | models in `D:\ollama\models` |

Ports are bound to 127.0.0.1 and the Tailscale IP only, never 0.0.0.0. If the Tailscale IP changes, update `.env` and run `docker compose up -d` again.

## Quick start

```bash
pip install -r requirements.txt
python -m collectors.rss              # news RSS -> data/raw/<date>/rss.jsonl
python -m collectors.rss --official   # official feeds
python -m collectors.gdelt            # GDELT (slow: >=6 s between calls)
```

## Planned stack

- Python (asyncpraw, feedparser)
- Local LLMs via Ollama / llama.cpp (Gemma, Qwen, Mistral families)
- bge-m3 multilingual embeddings
- SQLite or Postgres
