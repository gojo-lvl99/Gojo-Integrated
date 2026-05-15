# ⚡ GOJO I/O
> all protocols, one exchange.

8-in-1 disposable proxy server — VLESS, VMess, Trojan, Shadowsocks × WebSocket + HTTPUpgrade.
Built on Xray-core + nginx. One-click deploy on Google Cloud Run.

---

## Protocols

| Protocol | Transport | Path |
|---|---|---|
| VLESS | WebSocket | `/gojo/vless-ws/[suffix]?ed=2180` |
| VLESS | HTTPUpgrade | `/gojo/vless-hu/[suffix]` |
| VMess | WebSocket | `/gojo/vmess-ws/[suffix]?ed=2180` |
| VMess | HTTPUpgrade | `/gojo/vmess-hu/[suffix]` |
| Trojan | WebSocket | `/gojo/trojan-ws/[suffix]?ed=2180` |
| Trojan | HTTPUpgrade | `/gojo/trojan-hu/[suffix]` |
| Shadowsocks | WebSocket | `/gojo/ss-ws/[suffix]?ed=2180` |
| Shadowsocks | HTTPUpgrade | `/gojo/ss-hu/[suffix]` |

Path suffixes are randomly generated on every refresh cycle.

---

## Deploy on Cloud Run

### Via gcloud CLI
```bash
gcloud run deploy gojo-io \
  --image gojolvl99/integrated-io:latest \
  --platform managed \
  --region us-central1 \
  --port 8080 \
  --memory 2Gi \
  --cpu 1 \
  --min-instances 1 \
  --max-instances 1 \
  --concurrency 1000 \
  --timeout 3600 \
  --set-env-vars DURATION=6h,MAX_CONN=100 \
  --allow-unauthenticated
```

### Via Cloud Run Console
1. Container image: `hidden`
2. Port: `8080`
3. Set Environment Variables:

| Variable | Value | Description |
|---|---|---|
| `DURATION` | `6h` / `2d` / `1m` / `unli` | Credential lifetime per cycle |
| `MAX_CONN` | `100` | Max simultaneous connections |

---

## Duration Format

| Input | Meaning |
|---|---|
| `6h` | 6 hours |
| `12h` | 12 hours |
| `2d` | 2 days |
| `1m` | 1 month |
| `unli` | No expiry — uptime only |

---

## Refresh Schedule

| Duration set | Refresh interval |
|---|---|
| ≤ 7 days | Every 6 hours |
| > 7 days or `unli` | Every 5 hours 30 minutes |

Each refresh cycle includes 1 hour maintenance window.
New UUID, Password, and path suffixes are generated on every cycle.

---

## How It Works

```
Cloud Run :443 (TLS terminated by GCP)
     ↓
nginx :8080
     ├── /               → Landing page + Config room
     ├── /status.json    → Live server status
     ├── /maintenance.html → Served during refresh window
     ├── /gojo/vless-ws/ → Xray :10001
     ├── /gojo/vless-hu/ → Xray :10002
     ├── /gojo/vmess-ws/ → Xray :10003
     ├── /gojo/vmess-hu/ → Xray :10004
     ├── /gojo/trojan-ws/→ Xray :10005
     ├── /gojo/trojan-hu/→ Xray :10006
     ├── /gojo/ss-ws/    → Xray :10007
     └── /gojo/ss-hu/    → Xray :10008
```

---

## Credits

*"Throughout heaven and earth, I alone am the containerized one."*

⚡ GoJo · v1.0.0 · Xray-core + nginx
Credits are always appreciated. 🙏
[github.com/gojo-lvl99](https://github.com/gojo-lvl99)

