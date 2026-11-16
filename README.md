# godot-multiplayer-test

Small Godot 4.7 multiplayer experiment: server-authoritative movement with client prediction, shooting, lobby/ready-up rounds, chat, LAN discovery, and a dedicated server.

## Run
```
godot --path . -- --host --name=Me      # host and play
godot --path . -- --server              # dedicated server (no player); add --headless for no window
godot --path . -- --join                # find a host on the LAN
godot --path . -- --join <ip>           # join by IP (UDP 7777)
godot --headless --path . -- --join <ip> --bot --name=Bot   # AI bot client: readies up, chases, shoots
```
## WebSocket / online (free path)
```
godot --headless --path . -- --server --ws              # WebSocket on TCP 7777, plain ws
cloudflared tunnel --url http://localhost:7777          # public wss:// URL, Cloudflare terminates TLS
godot --path . -- --join wss://<name>.trycloudflare.com # native client over the tunnel
```
Web export (single-threaded, so no COOP/COEP headers needed): `godot --headless --path . --export-release Web build/web/index.html`
(needs the Godot 4.7.2 export templates installed), serve `build/web/`, then open
`index.html?server=wss://<host>&name=Me`. `export_presets.cfg` and `build/` are gitignored; recreate the preset in the editor.
Quick-tunnel URLs are random and change each run; a stable hostname needs a domain on Cloudflare.

Extra client flags for testing: `--lag=<ms> --loss=<0..1> --nopredict`.

Controls: arrows move, click shoots, Enter chats, R readies up. A round starts when 2+ players are ready; first to 5 kills wins.

## Dedicated server (Docker)
```
docker build -t godot-mp-server .
docker run -d --restart unless-stopped -p 7777:7777/udp godot-mp-server
```
LAN discovery (UDP 7778 broadcast) doesn't cross Docker Desktop's network or routers; join by IP.
