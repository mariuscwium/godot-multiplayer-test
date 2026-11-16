# Battle City .io Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A drop-in free-for-all tank game (Battle City flavoured) playable natively and in the browser, with a server-authoritative fixed-tick simulation, deployable online via GitHub Pages + a Cloudflare tunnel.

**Architecture:** A pure-logic `Sim` (RefCounted, no nodes) owns the tile grid, tanks, bullets, power-ups and scores and is unit-tested headless. A thin `Server` node ticks the Sim at 30 Hz and talks RPC; a `Client` node predicts only the local tank (sharing `TankMotion` with the Sim), interpolates others, and draws everything procedurally. `main.gd` shrinks to flag parsing.

**Tech Stack:** Godot 4.7.2 (`~/godot-bin/Godot_v4.7.2-stable_linux.x86_64`, referred to below as `$G`), GDScript, ENet + WebSocket multiplayer peers, a script-based headless test runner (no addons).

**Spec:** `docs/superpowers/specs/2026-11-16-battle-city-io-design.md`

## Global Constraints
- Godot 4.7.2; GDScript only; no copied ROM assets/code; all art drawn in code.
- Server owns all state; clients predict only their own tank.
- No eagle/base, no lobby/ready-up/phases. Death = respawn after 2.0 s with a 3.0 s spawn shield.
- Movement: 4 directions only; turning onto the perpendicular axis snaps to the nearest 8 px line; otherwise free pixel steps.
- One bullet in flight per tank (stars change this, see Task 4). Bricks destroyed in 8 px cells; steel only by 3-star shots.
- Destroyed brick/steel regrows after a random 30-60 s, only when no tank overlaps the cell.
- Kill drops a power-up at the victim's position; anyone can take it; despawns after 10 s.
- Browser clients: WebSocket only (TCP), `wss://` from Pages, single-threaded web export, `?server=wss://host&name=X`.
- `--bot`, `--lag=<ms>`, `--loss=<0..1>`, `--nopredict`, `--name=`, `--ws`, `--host`, `--server`, `--join [target]` keep working.
- Commit only on branch `battle-city`; never commit `export_presets.cfg` or `build/`.

## Review Focus
1. Spawn point occupied or adjacent to a tank when someone joins/respawns: spawn must pick a free point (Task 4).
2. Two tanks shooting each other in the same tick: both die, both credited (Task 4).
3. A tank sitting on a destroyed cell when its regrow timer fires: regrow waits (Task 2).
4. Malicious/garbled input: `dir` outside -1..3, NaN/huge seq, input for another tank's id, input from a dead tank (Task 7).
5. Disconnect while owning in-flight bullets and with a pending respawn: no crash, bullets still resolve, no ghost tank (Tasks 4, 7).
6. Names: empty, 40 chars, duplicates, control characters (Task 9).
7. Join mid-round: client receives the full grid and roster before the first snapshot, and sees currently-regrowing cells correctly (Task 7).

## File Structure
- `scripts/cfg.gd` (`class_name Cfg`): constants. 
- `scripts/game_map.gd` (`GameMap`): grid, loading, queries, destruction, regrowth.
- `scripts/tank_motion.gd` (`TankMotion`): pure movement step shared by Sim and Client.
- `scripts/sim.gd` (`Sim`): tanks, bullets, power-ups, scores, events.
- `scripts/protocol.gd` (`Protocol`): snapshot/event encode+decode.
- `scripts/server.gd`, `scripts/client.gd`, `scripts/render.gd`, `scripts/hud.gd`: nodes.
- `scripts/bot.gd` (`Bot`), `scripts/discovery.gd` (LAN discovery moved out of `main.gd`).
- `maps/arena.txt`: 80x80 cell map. Legend `.` empty, `B` brick, `S` steel, `G` bush, `W` water, `I` ice, `P` spawn point (treated as empty).
- `tests/run_tests.gd`, `tests/t.gd`, `tests/test_*.gd`; `tools/export_web.sh`, `tools/publish_pages.sh`.

---

### Task 1: Branch, test runner, constants

**Files:** Create `tests/run_tests.gd`, `tests/t.gd`, `tests/test_runner_selfcheck.gd`, `scripts/cfg.gd`; modify `project.godot` (physics ticks 30).

**Interfaces:**
- Produces: `T.eq(actual, expected, msg: String)`, `T.ok(cond: bool, msg: String)` (static; record failures). Runner: `$G --headless --path . -s tests/run_tests.gd` loads every `res://tests/test_*.gd`, calls each method named `test_*` on a fresh instance, prints `PASS n / FAIL m`, exits 1 on any failure.
- `Cfg`: `CELL=8`, `MAP_W=80`, `MAP_H=80`, `TANK_PX=16`, `TANK_SPEED=60.0`, `BULLET_SPEED=180.0`, `BULLET_SPEED_FAST=300.0`, `TICK_HZ=30`, `RESPAWN_S=2.0`, `SPAWN_SHIELD_S=3.0`, `HELMET_S=8.0`, `POWERUP_TTL=10.0`, `REGROW_MIN=30.0`, `REGROW_MAX=60.0`, `MAX_STARS=3`, `ICE_SLIDE_S=0.25`; `enum Tile {EMPTY, BRICK, STEEL, BUSH, WATER, ICE}`; `enum Dir {UP, RIGHT, DOWN, LEFT}` with `Cfg.NONE = -1`; `static func dir_vec(d: int) -> Vector2`.

- [ ] **Step 1:** `git checkout -b battle-city`; commit the existing `--bot` changes and docs (`git add main.gd README.md docs`; message `Add --bot client and battle-city design/plan`).
- [ ] **Step 2:** Write `tests/test_runner_selfcheck.gd` with `test_dir_vec`: `T.eq(Cfg.dir_vec(Cfg.Dir.LEFT), Vector2(-1,0), "left")` and the other three directions.
- [ ] **Step 3:** Run `$G --headless --path . --import` once (builds the global class cache), then the runner. Expected: FAIL (`Cfg` missing).
- [ ] **Step 4:** Implement the runner, `T`, `Cfg`; set `physics/common/physics_ticks_per_second=30` in `project.godot`. Runner must also exit 1 if a test script fails to parse.
- [ ] **Step 5:** Run the runner. Expected: `PASS 1 / FAIL 0`, exit 0. Commit.

### Task 2: GameMap (terrain, destruction, regrowth)

**Files:** Create `scripts/game_map.gd`, `maps/arena.txt`, `tests/test_game_map.gd`.

**Interfaces:**
- Consumes: `Cfg`.
- Produces (`class_name GameMap`): `static func from_text(text: String) -> GameMap`; `var w: int`, `var h: int`; `func get_cell(cx: int, cy: int) -> int` (out of bounds returns `Tile.STEEL`); `func set_cell(cx, cy, t: int) -> void`; `func tank_blocked(rect: Rect2) -> bool` (brick, steel, water; map edge blocks); `func bullet_blocked_at(cx, cy) -> int` (returns tile; water/bush/ice/empty are passable); `func destroy(cx, cy, now: float) -> bool` (brick/steel only; records original tile + regrow time `now + rand(REGROW_MIN..MAX)`); `func regrow_due(now: float, occupied: Callable) -> Array` (`occupied(rect: Rect2) -> bool`; returns `[[cx, cy, tile], ...]` regrown this call, skipping occupied cells which stay pending); `func spawn_points() -> Array` (cell-centre `Vector2` px for each `P`); `func to_bytes() -> PackedByteArray` / `static func from_bytes(w, h, b) -> GameMap` (join-time sync; currently-destroyed cells are sent as their *current* tile plus a separate list is not needed since clients only render current state).

- [ ] **Step 1:** Tests: `test_from_text_dimensions` (3x2 text gives w=3,h=2); `test_edge_is_steel`; `test_tank_blocked_by_brick_not_bush`; `test_water_blocks_tank_not_bullet`; `test_destroy_brick_then_regrow` (destroy at t=0, `regrow_due(29.9)` empty, `regrow_due(60.1)` returns the cell, `get_cell` is BRICK again); `test_regrow_waits_for_occupant` (occupied callable true: stays pending; later false: regrows); `test_bytes_roundtrip`.
- [ ] **Step 2:** Run; expected FAIL.
- [ ] **Step 3:** Implement. Pending regrow stored in a Dictionary keyed by `cy * w + cx`. Author `maps/arena.txt` (80x80, border steel optional since edges block): a ring of brick clusters, steel pillars at the centre, water ponds, bush patches, ice strips, and 24 `P` spawns spread evenly with a 3-cell clear zone around each. Add `test_arena_loads`: 80x80, at least 20 spawn points, every spawn cell and its 2x2 tank rect not blocked.
- [ ] **Step 4:** Run; expected PASS. Commit.

### Task 3: TankMotion (movement with half-tile snap and ice)

**Files:** Create `scripts/tank_motion.gd`, `tests/test_tank_motion.gd`.

**Interfaces:**
- Consumes: `GameMap.tank_blocked`, `Cfg`.
- Produces (`class_name TankMotion`): `static func step(map: GameMap, pos: Vector2, facing: int, input_dir: int, slide_t: float, dt: float) -> Dictionary` returning `{pos: Vector2, facing: int, slide_t: float}`. `pos` is the tank's top-left in px. Rules: `input_dir == NONE` keeps position (unless on ice with `slide_t > 0`, then continue in `facing` and decrement `slide_t`); pressing a new direction on the perpendicular axis first rounds the cross-axis coordinate to the nearest multiple of 8 (if that rounded rect is not blocked) then moves `TANK_SPEED * dt`; movement is axis-aligned and stops flush against blockers (no tunnelling at `dt <= 0.1`); standing on ice at release sets `slide_t = ICE_SLIDE_S`.

- [ ] **Step 1:** Tests: `test_moves_right_in_open` (60 px/s over 0.5 s moves 30 px); `test_stops_flush_at_brick` (final x so the tank rect touches the brick, not inside); `test_turn_snaps_to_8px` (start y=13, press right: y becomes 16 and the tank enters a 2-cell-high gap); `test_snap_refused_when_blocked` (snapping would overlap steel: position unchanged on that axis); `test_ice_slides_after_release` (slide_t starts `ICE_SLIDE_S`, position keeps advancing, then stops); `test_no_tunnel_large_dt` (dt=0.1, tank next to a 1-cell wall).
- [ ] **Step 2:** Run; expected FAIL.
- [ ] **Step 3:** Implement as a pure static function; use small helper `static func _try_move(map, pos, delta: Vector2) -> Vector2` resolving by clamping to the blocker edge.
- [ ] **Step 4:** Run; expected PASS. Commit.

### Task 4: Sim part 1 — tanks, spawning, firing, bullets, kills

**Files:** Create `scripts/sim.gd`, `tests/test_sim_combat.gd`.

**Interfaces:**
- Consumes: `GameMap`, `TankMotion.step`, `Cfg`.
- Produces (`class_name Sim`): `func _init(map: GameMap, seed: int = 0)`; `var map`, `var tanks: Dictionary` (id → `Sim.Tank`), `var bullets: Array`, `var powerups: Array`, `var tick: int`, `var time: float`; `class Tank` fields: `id, name, pos (top-left px), facing, alive, respawn_t, shield_t, stars, kills, input_dir, input_fire, ack_seq, slide_t`; `func add_tank(id: int, name: String) -> void` (spawns immediately with shield); `func remove_tank(id: int) -> void`; `func set_input(id: int, dir: int, fire: bool, seq: int) -> void` (ignores unknown/dead ids; clamps `dir` to -1..3 else NONE); `func step(dt: float) -> void`; `func drain_events() -> Array` of Dictionaries: `{k:"kill", killer:int, victim:int}`, `{k:"cells", c: Array of [cx, cy, tile]}`, `{k:"spawn", id}`; `func tank_rect(t: Tank) -> Rect2`.
- Combat rules: firing spawns a bullet at the muzzle moving in `facing` at `BULLET_SPEED` (`BULLET_SPEED_FAST` with 1+ stars); in-flight limit 1 (2 with 2+ stars); bullet vs bullet from different owners cancel; bullet vs tank (not owner) kills unless `shield_t > 0` (then the bullet is consumed); bullet into brick destroys the 2 cells across its width on that row/column; steel is destroyed only if shooter has 3 stars, otherwise the bullet is consumed; off-map consumed. Kill: `kills += 1` for killer if still present, victim `alive=false`, `respawn_t=RESPAWN_S`, stars reset to 0. Respawn picks the spawn point farthest from all living tanks and not overlapping any.

- [ ] **Step 1:** Tests (build a tiny map from text in each): `test_add_tank_spawns_free_of_others` (add 3 tanks to a map with 3 spawns: no rects overlap); `test_spawn_when_all_spawns_occupied_falls_back_to_farthest`; `test_fire_creates_one_bullet_limit` (two fire inputs: one bullet); `test_bullet_kills_tank_and_credits_killer`; `test_shield_absorbs_bullet`; `test_mutual_kill_same_tick` (two tanks facing each other fire on the same step: both die, both `kills == 1`); `test_brick_destroyed_two_cells_wide`; `test_steel_needs_three_stars`; `test_bullets_cancel`; `test_respawn_after_2s_with_shield`; `test_remove_tank_keeps_its_bullets_flying` (bullet still resolves, kill credit skipped without crash); `test_set_input_rejects_bad_dir` (dir=7 becomes NONE).
- [ ] **Step 2:** Run; expected FAIL.
- [ ] **Step 3:** Implement. Regrow ticking (Task 2's `regrow_due`) is called from `step`, passing an occupancy check against living tank rects, and emits `cells` events. Bullets move in sub-steps of at most 4 px so they cannot skip a cell.
- [ ] **Step 4:** Run; expected PASS. Commit.

### Task 5: Sim part 2 — power-ups

**Files:** Modify `scripts/sim.gd`; create `tests/test_sim_powerups.gd`.

**Interfaces:**
- Produces: `enum PowerType {STAR, HELMET, GRENADE}` (in `Cfg`); powerup Dictionary `{id: int, pos: Vector2 (cell-aligned top-left), type: int, ttl: float}` in `Sim.powerups`; events `{k:"pickup", id: int, tank: int, type: int}` and `{k:"powerup_gone", id: int}`.
- Rules: a kill drops one random type at the victim's position snapped to the 8 px grid; any living tank whose rect overlaps picks it up; `ttl` starts at `POWERUP_TTL`. STAR: `stars = min(stars+1, MAX_STARS)`. HELMET: `shield_t = HELMET_S`. GRENADE (designer's call for FFA): destroys all brick cells and all bullets within 6 cells of the picker, never damages tanks; emits a `cells` event. Stars, shield, and any held effects reset on death.

- [ ] **Step 1:** Tests: `test_kill_drops_powerup_at_victim`; `test_powerup_expires_after_10s`; `test_pickup_star_caps_at_3`; `test_pickup_helmet_sets_shield`; `test_grenade_clears_nearby_brick_and_bullets_not_tanks`; `test_death_resets_stars`; `test_dead_tank_cannot_pickup`.
- [ ] **Step 2:** Run; expected FAIL. **Step 3:** Implement. **Step 4:** Run; expected PASS. Commit.

### Task 6: Protocol (snapshots and events)

**Files:** Create `scripts/protocol.gd`, `tests/test_protocol.gd`.

**Interfaces:**
- Consumes: `Sim`.
- Produces (`class_name Protocol`): `static func encode_snapshot(sim: Sim) -> Array` = `[tick: int, tanks: PackedInt32Array, bullets: PackedInt32Array, powerups: PackedInt32Array]`. Positions are fixed-point px*16. Tank record (9 ints): `id, x, y, facing, flags (bit0 alive, bit1 shield), stars, kills, ack_seq, slide`. Bullet record (6): `id, x, y, dir, owner, fast`. Powerup record (4): `id, x, y, type`. `static func decode_snapshot(a: Array) -> Dictionary` with keys `tick, tanks (id → {pos: Vector2, facing, alive, shield, stars, kills, ack}), bullets (Array of {id,pos,dir,owner,fast}), powerups (Array of {id,pos,type})`. `static func encode_roster(sim) -> Dictionary` (id → name) and `static func clean_name(raw: String, id: int) -> String` (strip control chars, trim, max 12 chars, fallback `P<id>`).

- [ ] **Step 1:** Tests: `test_snapshot_roundtrip` (positions equal within 1/16 px; flags and kills preserved); `test_snapshot_is_compact` (10 tanks and 10 bullets encode to under 700 bytes via `var_to_bytes`); `test_clean_name_cases` (`""`→`P7`, 40 chars→12, `"a\nb\t"`→`"ab"`, `"  Bob  "`→`Bob`).
- [ ] **Step 2:** Run; expected FAIL. **Step 3:** Implement. **Step 4:** Run; expected PASS. Commit.

### Task 7: Server node

**Files:** Create `scripts/server.gd`; modify `main.gd` minimally to instantiate it (final trim in Task 10).

**Interfaces:**
- Consumes: `Sim`, `Protocol`, `GameMap`.
- Produces (`class_name Server extends Node`): `func start(port: int, ws: bool) -> void`; each physics tick (30 Hz) calls `sim.step(1.0/Cfg.TICK_HZ)`, broadcasts `Protocol.encode_snapshot` via an unreliable-ordered RPC `c_snapshot(Array)` on the client, and forwards `drain_events()` via a reliable RPC `c_events(Array)`. Server RPCs: `register(name: String)` (reliable, any_peer; ignores repeat registration; sends `c_welcome(w, h, grid_bytes, roster, snapshot)` to that peer only, then broadcasts roster change), `input(seq: int, dir: int, fire: bool)` (unreliable_ordered, any_peer; uses `get_remote_sender_id()`, never a client-supplied id; rejects non-int/NaN-ish seq, out-of-range dir, and seq <= last seen). `peer_disconnected` removes the tank. Prints `joined: <name> (id)`, `left: <name>`, and `kill: <killer> -> <victim>` for log-based tests.

- [ ] **Step 1:** Add `tests/test_server_validation.gd` for the pure helper `Server.sanitize_input(seq: Variant, dir: Variant, fire: Variant, last_seq: int) -> Dictionary` (returns `{}` when rejected): `test_rejects_bad_dir`, `test_rejects_stale_seq`, `test_rejects_wrong_types` (float NaN, String), `test_accepts_valid`.
- [ ] **Step 2:** Run; expected FAIL. **Step 3:** Implement the helper and the node. **Step 4:** Run tests; expected PASS.
- [ ] **Step 5:** Smoke: `$G --headless --path . -- --server &`, then a scripted second Godot process using the Task 8 client (or a short `tests/smoke_join.gd` SceneTree script using `ENetMultiplayerPeer` and calling `register`/`input`) verifying `joined:` appears in the server log and a `c_welcome` arrives. If Task 8 is not yet available, defer this step to Task 8's verification. Commit.

### Task 8: Client (prediction, interpolation, input)

**Files:** Create `scripts/client.gd`; extend `main.gd`.

**Interfaces:**
- Consumes: `Protocol`, `TankMotion`, `GameMap`.
- Produces (`class_name Client extends Node2D`): `func connect_to(target: String) -> void` (ENet for plain host/IP, WebSocket for `ws://`/`wss://`); `var my_id: int`; `var map: GameMap`; `var view: Dictionary` (latest decoded snapshot); `var shown: Dictionary` (id → interpolated `Vector2`); RPC receivers `c_welcome`, `c_snapshot`, `c_events`. Each physics tick the client reads arrow-key direction (last pressed wins, ignoring input while chat is not a thing: there is no chat) and Space/click fire, increments `seq`, appends to `pending`, sends `input.rpc_id(1, seq, dir, fire)` through the existing `--lag/--loss` fake-network queue, and applies `TankMotion.step` locally. On snapshot: drop `pending` entries with `seq <= ack`, set the local tank to the server position, replay the rest; `--nopredict` skips replay. Remote tanks use exponential smoothing (as today). Camera follows the local tank, clamped to the map.

- [ ] **Step 1:** Add `tests/test_client_reconcile.gd` for the pure helper `Client.reconcile(map: GameMap, server_pos: Vector2, facing: int, pending: Array, ack: int) -> Dictionary` (`{pos, pending}`): `test_drops_acked_inputs`, `test_replays_unacked_from_server_pos` (3 unacked right-inputs advance 3 ticks' worth), `test_empty_pending_returns_server_pos`.
- [ ] **Step 2:** Run; expected FAIL. **Step 3:** Implement helper and node. **Step 4:** Run; expected PASS.
- [ ] **Step 5:** Verify end to end: start `--server`, run a native client with `--bot` (Task 9 bot may be stubbed to "always right + fire"): server log shows `joined:`; client log has no errors. Commit.

### Task 9: Rendering, HUD, name handling

**Files:** Create `scripts/render.gd`, `scripts/hud.gd`; modify `client.gd` to add them.

**Interfaces:**
- Consumes: `Client.view`, `Client.shown`, `Client.map`, `Protocol.clean_name`.
- Produces: `Render` (`Node2D`, `_draw` only) draws terrain by cell colour/pattern (brick red with mortar lines, steel grey, water blue animated, ice pale blue, bush green drawn *after* tanks and bullets so tanks inside are hidden from other players except the local tank's own tank), tanks as 16x16 pixel-art-style shapes (tracks, body, barrel by facing; colour from player id hue; shield flicker; star pips), bullets, power-ups (distinct glyph per type, blinking in the last 3 s). `Hud` (`CanvasLayer`) shows a top-5 kill leaderboard plus your own kills/stars, a "respawning in N" banner when dead, and connection messages (`Could not connect`, `Host disconnected`). Web name comes from `?name=`; native from `--name=`.

- [ ] **Step 1:** Run a client against a local server with two bots; take a screenshot (`$G --path . ... --write-movie` is not required: use the Windows-visible window plus `/ss`, or `--headless` skipped) and verify by eye: terrain drawn, bush hides a bot standing in it, leaderboard updates after a kill, respawn banner shows. List what was seen in the task report.
- [ ] **Step 2:** Add `tests/test_render_helpers.gd` for the pure helper `Render.hue_for(id: int) -> float` (stable, in 0..1, differs for ids 1..20): `test_hue_in_range`, `test_hue_distinct_for_first_20_ids`. Run; expected FAIL, then implement, then PASS. Commit.

### Task 10: Entry point, hosting modes, discovery cleanup

**Files:** Rewrite `main.gd` (flags only, under ~120 lines); create `scripts/discovery.gd`; modify `main.tscn` only if needed.

**Interfaces:**
- Consumes: `Server`, `Client`.
- Produces: `--server` (headless dedicated: Server only), `--host` (Server + Client in the same process; the client treats the local tank as server-authoritative: no prediction, reads the Sim directly), `--join [target]` (Client; no target = LAN discovery via `Discovery`), `--ws` (WebSocket transport for server/host), web builds read `server` and `name` from the page URL. `Discovery` has `start_announcing(name)`, `start_finding() -> void` emitting signal `found(ip: String)` and `timeout`. All lobby/ready/phase/chat code is deleted.

- [ ] **Step 1:** Run the full test suite; expected all PASS (no regressions). 
- [ ] **Step 2:** Verify each mode by command (listing expected output): `--server` prints `dedicated server listening on UDP 7777`; `--server --ws` prints `... TCP (WebSocket) 7777`; `--host` shows a window with your tank; `--join 127.0.0.1` joins; `--join ws://127.0.0.1:7777` against a `--ws` server joins. Commit.

### Task 11: Bot

**Files:** Create `scripts/bot.gd`, `tests/test_bot.gd`; modify `client.gd` to use it for `--bot`.

**Interfaces:**
- Consumes: `Client.view`, `GameMap`.
- Produces (`class_name Bot`): `static func decide(map: GameMap, me: Dictionary, others: Array, rng: RandomNumberGenerator) -> Dictionary` returning `{dir: int, fire: bool}`. Behaviour: pick the nearest living enemy; move along the axis with larger distance; fire when roughly aligned (within 8 px on the cross axis) and within 200 px; if the next step is blocked by brick, fire (to clear it) else turn to the other axis; wander randomly when no enemies; add small reaction jitter so bots are beatable.

- [ ] **Step 1:** Tests: `test_aligned_enemy_fires`; `test_blocked_by_brick_fires_to_clear`; `test_no_enemies_wanders` (returns valid dir in -1..3); `test_never_outputs_invalid_dir` (1000 random states).
- [ ] **Step 2:** Run; expected FAIL. **Step 3:** Implement. **Step 4:** Run; expected PASS.
- [ ] **Step 5:** Soak: server plus 6 bots for 60 s, expected server log contains multiple `kill:` lines and no errors; kill one bot mid-run and confirm the server keeps running. Commit.

### Task 12: Online deployment

**Files:** Create `tools/export_web.sh`, `tools/publish_pages.sh`; modify `Dockerfile`, `README.md`, `.gitignore` (keep `export_presets.cfg` and `build/` ignored).

**Interfaces:**
- Produces: `tools/export_web.sh` (creates the Web preset on demand if `export_presets.cfg` is missing, writes `build/web/index.html`; fails loudly if export templates are absent, printing the install instruction); `tools/publish_pages.sh` (copies `build/web/` into a `gh-pages` branch via a temporary git worktree and pushes only when run with `--push`); Dockerfile copies `scripts/`, `maps/`, `main.gd`, `main.tscn`, `project.godot` and runs `--server --ws` by default with an env override; README gains an "Online" section: run `--server --ws`, `cloudflared tunnel --url http://localhost:7777`, open `https://<user>.github.io/<repo>/?server=wss://<tunnel>&name=Me`.

- [ ] **Step 1:** Run `tools/export_web.sh`; expected `build/web/index.html` exists (if templates are missing, the script exits non-zero with instructions and the task reports it rather than silently passing).
- [ ] **Step 2:** Serve `build/web/` locally (`python3 -m http.server`) and, with a `--server --ws` instance running, load the page with Playwright: confirm it connects (`?server=ws://localhost:7777` locally), the canvas renders, and a native `--bot --join ws://...` shows up as another tank.
- [ ] **Step 3:** Run `docker build` and confirm the image starts and listens. Commit. Pushing to GitHub Pages and starting a tunnel require the author's approval and credentials, so the task stops after producing the commands and reports exactly what to run.

### Task 13: Lag and loss playtest

**Files:** none new; findings go in a short section of `README.md`.

- [ ] **Step 1:** Run a client with `--lag=120 --loss=0.05` against a server with two bots for 2 minutes; verify the local tank never visibly rubber-bands more than 1 cell, and bullets/kills stay consistent with what the server logged.
- [ ] **Step 2:** Run with `--nopredict` for comparison and record the difference in `README.md`. Run the full test suite one last time; expected all PASS. Commit.

---

## Self-review notes
- Spec coverage: drop-in/respawn (T4,10), movement incl. snap/ice (T3), terrain set (T2,9), bullets/stars (T4), kill-drop power-ups (T5), leaderboard (T9), regrowth (T2,4), native + web + deployment (T7,8,10,12), bots (T11), lag flags (T8,13), no eagle/lobby (T10).
- Open calls made by the plan rather than the spec: grenade behaviour, star effects (fast shot, two bullets, steel), 80x80 map, 30 Hz tick, fixed-point snapshot format, tile = 8 px cells with 16 px tanks, one hit kills.
