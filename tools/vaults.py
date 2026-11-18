#!/usr/bin/env python3
"""Reduce los vaults públicos de Hyperliquid (~14 MB) a data/vaults.json: los 60 activos con más dinero administrado."""
import json, urllib.request, time, os
raw = json.load(urllib.request.urlopen(urllib.request.Request("https://stats-data.hyperliquid.xyz/Mainnet/vaults", headers={"User-Agent": "northpoint-social"}), timeout=120))
def pnl(v, w):
    s = dict(v["pnls"]).get(w) or []
    return round(float(s[-1]) - float(s[0]), 2) if len(s) > 1 else 0.0
act = [v for v in raw if not v["summary"].get("isClosed") and float(v["summary"].get("tvl") or 0) > 25000]
act.sort(key=lambda v: -float(v["summary"]["tvl"]))
rows = [{"a": v["summary"]["vaultAddress"], "n": v["summary"]["name"], "l": v["summary"]["leader"], "tvl": round(float(v["summary"]["tvl"]), 2),
         "apr": round(float(v.get("apr") or 0), 4), "day": pnl(v, "day"), "week": pnl(v, "week"), "month": pnl(v, "month"), "allTime": pnl(v, "allTime"),
         "t": v["summary"].get("createTimeMillis")} for v in act[:60]]
os.makedirs("data", exist_ok=True)
json.dump({"updated": int(time.time()), "total": len(raw), "active": len(act), "rows": rows}, open("data/vaults.json", "w"), separators=(",", ":"))
print(len(rows), "vaults,", os.path.getsize("data/vaults.json") // 1024, "KB")
