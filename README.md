# godot-multiplayer-test

Small Godot 4.7 multiplayer experiment: server-authoritative movement with client prediction, shooting, lobby/ready-up rounds, chat, LAN discovery, and a dedicated server.

## Run
```
godot --path . -- --host --name=Me      # host and play
godot --path . -- --server              # dedicated server (no player); add --headless for no window
godot --path . -- --join                # find a host on the LAN
godot --path . -- --join <ip>           # join by IP (UDP 7777)
```
Extra client flags for testing: `--lag=<ms> --loss=<0..1> --nopredict`.

Controls: arrows move, click shoots, Enter chats, R readies up. A round starts when 2+ players are ready; first to 5 kills wins.

## Dedicated server (Docker)
```
docker build -t godot-mp-server .
docker run -d --restart unless-stopped -p 7777:7777/udp godot-mp-server
```
LAN discovery (UDP 7778 broadcast) doesn't cross Docker Desktop's network or routers; join by IP.
