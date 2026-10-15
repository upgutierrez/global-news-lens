"""Fetch all verified RSS feeds in sources/rss.yaml (and official.yaml with --official)."""
import sys, concurrent.futures as cf, requests, feedparser
from collectors.common import UA, load_sources, item, write
def fetch(src):
    try:
        r = requests.get(src["url"], headers=UA, timeout=20); r.raise_for_status()
        f = feedparser.parse(r.content)
        return [item(source_type=src["_type"], source_id=src["id"], outlet=src["name"], region=src["region"],
                     country=src.get("country"), lang=src["lang"], affiliation=src.get("affiliation"),
                     title=e.get("title",""), url=e.get("link",""), summary=e.get("summary","")[:2000],
                     published_at=e.get("published") or e.get("updated")) for e in f.entries]
    except Exception as e:
        print(f"[warn] {src['id']}: {e}", file=sys.stderr); return []
def main():
    name = "official" if "--official" in sys.argv else "rss"
    cfg = load_sources(name); srcs = []
    for region, lst in cfg["regions"].items():
        for s in lst: srcs.append({**s, "region": region, "_type": name})
    with cf.ThreadPoolExecutor(16) as ex: items = [i for batch in ex.map(fetch, srcs) for i in batch]
    p = write(items, name); print(f"{len(items)} items from {len(srcs)} feeds -> {p}")
if __name__ == "__main__": main()
