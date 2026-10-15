"""Query GDELT DOC 2.0 ArtList per country (sources/gdelt.yaml). GDELT rate-limits: keep >=6s between calls."""
import sys, time, requests
from collectors.common import UA, load_sources, item, write
def main():
    cfg = load_sources("gdelt"); base = cfg["doc_api"]["base"]; items = []
    for q in cfg["doc_api"]["queries"]:
        params = {"query": q["query"], "mode": "artlist", "format": "json", "maxrecords": 75, "timespan": cfg["doc_api"].get("timespan","1h"), "sort": "datedesc"}
        for attempt in range(3):
            r = requests.get(base, params=params, headers=UA, timeout=30)
            if r.status_code == 429: time.sleep(20); continue
            break
        try: arts = r.json().get("articles", [])
        except Exception: arts = []; print(f"[warn] {q['id']}: {r.status_code}", file=sys.stderr)
        items += [item(source_type="gdelt", source_id=q["id"], outlet=a.get("domain"), region=q["region"], country=a.get("sourcecountry"),
                       lang=a.get("language"), title=a.get("title",""), url=a.get("url",""), published_at=a.get("seendate")) for a in arts]
        time.sleep(cfg["doc_api"].get("min_interval_s", 6))
    p = write(items, "gdelt"); print(f"{len(items)} articles -> {p}")
if __name__ == "__main__": main()
