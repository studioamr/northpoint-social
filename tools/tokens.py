#!/usr/bin/env python3
"""Guarda en data/tokens.json las listas de tokens de Solana (tendencia, nuevos, volumen, graduados) de GeckoTerminal.
Lo corre una GitHub Action cada pocos minutos para que los visitantes no gasten el límite de 30 consultas/min de GeckoTerminal."""
import json, time, urllib.request, os
GT = 'https://api.geckoterminal.com/api/v2/networks/solana'
PATHS = {'trend': '/trending_pools?include=base_token,dex', 'new': '/new_pools?include=base_token,dex',
         'top': '/pools?include=base_token,dex&sort=h24_volume_usd_desc', 'grad': '/dexes/pumpswap/pools?include=base_token,dex'}
out = {'updated': int(time.time()), 'lists': {}}
for k, p in PATHS.items():
    for intento in range(3):
        try:
            req = urllib.request.Request(GT + p, headers={'Accept': 'application/json', 'User-Agent': 'thrive-cache'})
            out['lists'][k] = json.load(urllib.request.urlopen(req, timeout=30))
            break
        except Exception as e:
            print(k, 'reintento', intento + 1, e); time.sleep(8)
    time.sleep(2.5)
os.makedirs('data', exist_ok=True)
if out['lists']:
    json.dump(out, open('data/tokens.json', 'w'), separators=(',', ':'))
print(list(out['lists']), os.path.getsize('data/tokens.json') // 1024, 'KB')
