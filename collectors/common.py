import json, hashlib, datetime as dt, pathlib, yaml
UA = {"User-Agent": "global-news-lens/0.1 (personal research; +https://github.com/upgutierrez/global-news-lens)"}
ROOT = pathlib.Path(__file__).resolve().parent.parent
def load_sources(name):
    return yaml.safe_load(open(ROOT / "sources" / f"{name}.yaml", encoding="utf-8"))
def item(**kw):
    kw.setdefault("fetched_at", dt.datetime.now(dt.timezone.utc).isoformat())
    kw["content_hash"] = hashlib.sha256((kw.get("title","") + kw.get("url","")).encode()).hexdigest()
    return kw
def write(items, source_type):
    d = ROOT / "data" / "raw" / dt.date.today().isoformat(); d.mkdir(parents=True, exist_ok=True)
    p = d / f"{source_type}.jsonl"
    with open(p, "a", encoding="utf-8") as f:
        for i in items: f.write(json.dumps(i, ensure_ascii=False) + "\n")
    return p
