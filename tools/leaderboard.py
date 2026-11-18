#!/usr/bin/env python3
"""Reduce la clasificación pública de Hyperliquid (~39 MB) a data/leaderboard.json (top por ventana)."""
import json, urllib.request, time, os
URL = "https://stats-data.hyperliquid.xyz/Mainnet/leaderboard"
raw = json.load(urllib.request.urlopen(urllib.request.Request(URL, headers={"User-Agent": "northpoint-social"}), timeout=120))
rows = raw["leaderboardRows"]
W = ["day", "week", "month", "allTime"]
def pack(r):
    p = dict(r["windowPerformances"])
    return {"a": r["ethAddress"], "n": r.get("displayName") or "", "v": round(float(r["accountValue"]), 2),
            **{w: [round(float(p[w]["pnl"]), 2), round(float(p[w]["roi"]), 5), round(float(p[w]["vlm"]), 0)] for w in W}}
rows = [r for r in rows if float(r["accountValue"]) >= 25000]
keep = {}
for w in W:
    top = sorted(rows, key=lambda r: -float(dict(r["windowPerformances"])[w]["pnl"]))[:150]
    for r in top: keep[r["ethAddress"]] = pack(r)
out = {"updated": int(time.time()), "total": len(raw["leaderboardRows"]), "rows": list(keep.values())}
os.makedirs("data", exist_ok=True)
json.dump(out, open("data/leaderboard.json", "w"), separators=(",", ":"))
print(len(out["rows"]), "traders,", os.path.getsize("data/leaderboard.json") // 1024, "KB")
