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

Early development. Collector spec and pipeline design are in progress.

## Planned stack

- Python (asyncpraw, feedparser)
- Local LLMs via Ollama / llama.cpp (Gemma, Qwen, Mistral families)
- bge-m3 multilingual embeddings
- SQLite or Postgres
