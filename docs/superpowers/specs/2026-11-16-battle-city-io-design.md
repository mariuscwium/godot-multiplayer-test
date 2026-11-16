# Battle City .io — Design

## Intent and why
A free-for-all, drop-in multiplayer tank game inspired by Battle City (NES, 1985): top-down, grid-flavoured, chunky 8-bit look. Instead of 2-player co-op against AI tanks, many human players share one persistent arena and shoot each other, like an .io game with a nostalgia hook.

Audience for now: the author and friends (roughly 2–20 concurrent players). If it proves fun, the author will invest in scale and hosting later. The design should not block that, but must not pay for it now.

## Goals
- Open the game, enter a name, you are a tank in the arena. No lobby, no ready-up. Death = respawn after ~2 s.
- Feels like Battle City: 4-directional movement, fire in facing direction, one bullet in flight per tank, destructible brick, steel, bushes, water, ice.
- Kills matter: a killed tank drops a power-up at its death position; anyone can grab it; it despawns after ~10 s.
- Live kill leaderboard.
- Playable natively (ENet/UDP) and in the browser (WebSocket), reusing the existing transport options, web export, and `--bot` test client.
- Original art and sound in an 8-bit style, drawn procedurally in code. No assets or code from the ROM.

## Non-goals (for now)
- Scale beyond ~20 players: no sharding, interest management, matchmaking, accounts, or persistence across server restarts.
- AI enemy tanks, stage progression, the eagle/base (explicitly dropped: no eagle in any form).
- Cheat-proofing beyond what the server-authoritative model gives for free.
- Reverse engineering the ROM or reproducing its levels/sprites/audio.

## Anti-goals
- Becoming a clone/port of the original. Inspiration only; if a mechanic is awkward for FFA, deviate.
- A tangle: the current 400-line single `main.gd` growing further.

## Constraints
- Godot 4.7.2 (already in use; installed at `~/godot-bin`), GDScript.
- Existing repo: `main.gd`, `main.tscn`, Dockerfile, WebSocket/web export support. Keep these capabilities working.
- Server owns all game state. Clients predict their own tank only.

## Approaches considered
- **A. Extend `main.gd` in place.** Fastest to something visible; but grid collision for tanks, bullets and terrain would tangle the file. Rejected as a foundation.
- **B. Restructure within Godot (chosen).** Split into a few scripts; server runs a fixed-rate simulation that owns the tile grid and sends compact snapshots. Keeps existing netcode choices, bots, and export; matches a later scale-up path. Chosen by the author.
- **C. Rebuild as Node server + browser client.** Easiest joining (a link) but discards working Godot netcode, bots and export. Rejected.

## Decisions made with the author
- No eagle/base. Pure FFA deathmatch with terrain and power-ups.
- Power-ups drop as a kill reward (author's idea). Details are the designer's proposal, not yet challenged: drop at victim's death position, anyone can pick up, ~10 s lifetime, so kills create a contested spot. (Alternative: award directly to killer.)
- Approach B.
- Destroyed terrain regrows: each destroyed brick/steel tile rebuilds itself after ~30–60 s, but only when no tank occupies it (retry until clear). Server keeps per-tile regrow timers; regrowth is sent as terrain events and included in the join-time grid sync.
- Tank movement follows the original: four directions only, no diagonals; when turning onto the perpendicular axis the tank snaps to the nearest half-tile line, so it can enter one-tile gaps. Otherwise it moves in free pixel steps (not tile-to-tile).

## Proposed design (designer's calls — author to confirm or change)
**Structure.** Split code into roughly: map/terrain (tile grid + rendering), tank (movement, facing, firing, state), bullet, server rules (tick loop, spawning, kills, power-ups, scoring), client (input, prediction, rendering, HUD), and a thin entry script handling command-line flags. Exact split is the builder's call.

**Simulation.** Server steps at a fixed ~30 Hz. State: tile grid, tanks, bullets, power-ups, scores. Clients get snapshots of tanks/bullets/power-ups at the tick rate and terrain changes as events (initial grid sent on join). Client keeps prediction + reconciliation for its own tank (existing approach), and interpolates others.

**Hosting (designer's call).** `--server` (headless dedicated) is the primary mode; `--host` (player runs the server and plays) stays as a convenience over the same simulation, with LAN discovery unchanged. The lobby/ready/phase code is removed.

**Tanks.** Move one axis at a time (4 directions, with the half-tile snap on turning, see Decisions); collide with solid tiles (brick, steel, water) and other tanks. Fire in facing direction, one bullet in flight per tank (power-ups may alter this). Respawn at a random free spawn point after ~2 s with brief spawn shield.

**Terrain.** Brick: destroyed in sub-tile pieces by bullets. Steel: only destroyed by upgraded shots. Bush: renders over tanks, hides them from view (visual only). Water: blocks tanks, not bullets. Ice: tank slides. Map is a hand-authored tile grid in code or a text file, sized for ~20 players.

**Power-ups.** From Battle City's set: star (gun upgrade, stacking), helmet (shield for a few seconds), grenade (adapted for FFA; e.g. clear bricks/nearby bullets — builder to pick something non-trivializing), maybe shovel-equivalent omitted since no base. Upgrades and shields are lost on death.

**Scoring/HUD.** Per-player kills, live leaderboard, own status. Player names reuse existing `--name`/URL parameter and `_clean` rules.

**Bots.** The `--bot` client continues to exist and is updated to the new game (wander, chase, shoot) so a single dev can test alone.

**Art/sound.** Pixel-style shapes drawn procedurally; 4–5 colour palette per tank derived from player id. Sound optional and later.

## Online deployment (author wants this soon, free/cheap)
Target setup: the web export is hosted as static files on GitHub Pages; the dedicated server runs on a machine the author controls (or a cheap host) behind a Cloudflare tunnel that provides `wss://`. Browser clients join via `?server=wss://<host>&name=...`, as the existing README already describes. Implications the design must respect:
- Browser clients can only use WebSocket (TCP), so there is no UDP/ENet in the browser. Snapshots must stay small and tolerate head-of-line blocking; prediction/interpolation must absorb jitter. Send only changed or nearby-relevant data where it's cheap to do so.
- Pages is HTTPS, so the server URL must be `wss://`; the tunnel terminates TLS. Keep the single-threaded web export (Pages can't set COOP/COEP headers).
- Quick-tunnel URLs change every run; the `?server=` parameter handles that. A stable hostname needs a domain on Cloudflare (optional, later).
- Add a documented, repeatable way to export the web build and publish it to Pages (e.g. script + `gh-pages` branch or `docs/`), and keep `export_presets.cfg` handling consistent with the current gitignore.
- Native clients and `--bot` must keep working against the same WebSocket server, so online play can be tested end to end from this machine.

## Left to the builder
File layout, tick rate tuning, map layout, exact power-up effects/balance, tile and bullet sizes, snapshot format, interpolation details, spawn selection, and how to migrate/retire the current lobby/phase code.

## Success
Several friends can join (native or browser), play for several minutes, and say it's fun. Server stays authoritative and playable under `--lag`/`--loss` test flags.
