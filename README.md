# Battle City .io

A free-for-all, drop-in multiplayer tank game inspired by Battle City (NES, 1985). Godot 4.7, server-authoritative, native (UDP) and browser (WebSocket). Original art, drawn in code.

Arrows/WASD move (4 directions, like the original), Space or click fires. Kill a tank and it drops a power-up where it died: star (faster shot, then a second bullet, then steel-breaking), helmet (shield), grenade (clears bricks and bullets around you). Bricks regrow after 30-60 s.

## Run
```
godot --headless --path . -- --server            # dedicated server (UDP 7777)
godot --path . -- --join 127.0.0.1 --name=Me     # join by IP; no target = find a host on the LAN
godot --path . -- --host --name=Me               # run the server and play in one process
godot --headless --path . -- --join 127.0.0.1 --bot --name=Bot   # AI opponent for testing
```
Add `--ws` to `--server`/`--host` for WebSocket (TCP 7777) instead of UDP. Client test flags: `--lag=<ms> --loss=<0..1> --nopredict`, `--shot=<png>` (save a screenshot 6 s after joining, then quit).

## Tests
```
tools/test.sh [filter]     # headless unit tests (tests/test_*.gd)
```

## Online (GitHub Pages + Cloudflare tunnel)
1. Web export (single-threaded, so GitHub Pages needs no special headers):
   ```
   python3 -I tools/install_web_templates.py   # once: fetches only the Web export templates (~20 MB)
   tools/export_web.sh                         # writes build/web/
   tools/publish_pages.sh --push               # commits build/web to gh-pages and pushes
   ```
   Then in the repo settings choose Pages, branch `gh-pages`, root.
2. Server, anywhere you can run it, with a tunnel for `wss://`:
   ```
   godot --headless --path . -- --server --ws
   cloudflared tunnel --url http://localhost:7777      # prints https://<random>.trycloudflare.com
   ```
3. Play: `https://<user>.github.io/<repo>/?server=wss://<random>.trycloudflare.com&name=Me`
   (native clients too: `--join wss://<random>.trycloudflare.com`).

Quick-tunnel URLs change every run; a stable hostname needs a domain on Cloudflare.

### Docker server
```
docker build -t godot-mp-server .
docker run -d --restart unless-stopped -p 7777:7777 godot-mp-server              # WebSocket (default)
docker run -d --restart unless-stopped -p 7777:7777/udp -e SERVER_ARGS="" godot-mp-server   # native UDP
```
LAN discovery (UDP 7778 broadcast) doesn't cross Docker's network or routers; join by IP.

## Layout
`scripts/sim.gd` holds the authoritative game rules and is pure logic (no nodes); `scripts/tank_motion.gd` is the movement step shared by the server and the client's prediction. `server.gd`, `client.gd`, `net.gd` (all RPCs) do the networking; `render.gd`/`hud.gd` draw. Design and plan: `docs/superpowers/`.
