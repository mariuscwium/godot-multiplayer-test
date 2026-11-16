# Combat and Pickup Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Play animations from the effects pack at combat and pickup moments through one generic effects system.

**Architecture:** `Effects` registry (pure) + a generic `fx` event emitted by `Sim._fx` + client active list + `Render` drawing. Each group of effects adds table entries, emit calls and tests.

**Tech Stack:** Godot 4.7.2 / GDScript, headless tests (`tools/test.sh`).

**Spec:** `docs/superpowers/specs/2026-11-16-combat-effects-design.md`

## Global Constraints
- Pack: `/mnt/c/Users/wium/Downloads/Super Pixel Effects Gigapack (Free Version) v3.2.0/Super Pixel Effects Gigapack (Free Version)/spritesheet/`; only the sheets used are copied to `assets/fx/<kind>.png`; README credits Will Tice / unTied Games.
- Pack animations are meant to play at 15 FPS (66.7 ms/frame).
- No gameplay/network behaviour change beyond the `fx` event; effects draw above bushes.
- Active effects capped at 64 on the client.
- Branch `battle-city`; commit per task; every behavioural change test-first.

## Review Focus
1. Event spam: no effect is emitted per cell or per tick; a held fire key must not flood (at most one muzzle effect per bullet) (Task 2/4 tests).
2. An unknown or malformed `fx` event must not crash a client (Task 1 test).
3. A missing effect texture must fail loudly at startup (Task 1).
4. Effects must not appear for events that did not happen: shield-absorbed hit still shows a hit effect but no damage effect, a blocked fire (bullet limit) shows no muzzle flash (Tasks 2, 4 tests).
5. Rotation of the muzzle flash matches the facing in all four directions (Task 4 preview).

## File Structure
- Create `scripts/effects.gd` (`Effects`), `tools/pack_fx.gd` (copies and verifies sheets), `assets/fx/*.png`, `tests/test_effects.gd`.
- Modify `scripts/sim.gd` (`_fx` and emit sites), `scripts/client.gd` (`fx` list, event handling), `scripts/render.gd` (draw), `README.md`; delete `scripts/explosion_fx.gd` and `tests/test_explosion_fx.gd` (migrated).

---

### Task 1: Generic effects system (and the tank explosion on it)

**Interfaces:**
- Produces (`class_name Effects`): `const DEFS: Dictionary` kind -> `{path, fw, fh, frames, fps, size, base_angle}`; `static func has(kind: String) -> bool`; `static func duration(kind: String) -> float` (`frames / fps`); `static func frame_at(kind: String, age_s: float) -> int` (-1 when over, clamps negative age to 0); `static func src_rect(kind: String, frame: int) -> Rect2` (row-major in the sheet, `cols = sheet_width / fw`, so `DEFS` carries `cols`). Kind `tank_explosion` = the existing small yellow explosion, size 48.
- `Client`: `fx: Array` of `{kind, pos, rot, born_ms}`; `on_events` handles `{"k":"fx","fx":String,"pos":Vector2,"rot":float}` (ignore unknown kind or malformed event; cap 64, oldest dropped); the `kill` event appends a `tank_explosion` effect; `prune_fx(now_ms)` uses each kind's duration.
- `Sim`: `func _fx(kind: String, pos: Vector2, rot: float = 0.0) -> void` emitting the `fx` event.

- [ ] **Step 1: Tests** in `tests/test_effects.gd`: `test_frame_at_uses_each_kinds_fps_and_length` (tank_explosion: frame 0 at 0, 1 at 0.07, 8 at 0.59, -1 at 0.61); `test_every_def_matches_its_sheet` (for each kind: texture loads via `Render.load_nearest_texture`, `get_size() == Vector2(cols*fw, ceil(frames/cols)*fh)`, `size > 0`); `test_src_rect_is_row_major`; `test_client_plays_fx_events` (known kind appended with pos/rot; unknown kind and a dictionary missing `pos` ignored without error); `test_client_caps_active_effects_at_64`; `test_kill_event_starts_tank_explosion` (migrated); `test_prune_uses_per_kind_duration`; `test_sim_fx_helper_emits_event` (a Sim with `_fx("tank_explosion", Vector2(5,5), 0.5)` then `drain_events()` contains the event).
- [ ] **Step 2: Run** `tools/test.sh effects` — Expected: FAIL.
- [ ] **Step 3: Implement** `Effects`, `Sim._fx`, the client changes, and `Render._draw_effects` (replaces `_draw_explosions`; draws each active effect centred at `pos`, `size` x `size` world px, rotated by `rot + base_angle` via `draw_set_transform`, reset afterwards; all textures loaded at startup with the loud-failure check). Delete `ExplosionFx` and its test file; migrate existing references. `tools/pack_fx.gd` copies the named variants from the pack into `assets/fx/` and prints frames/frame size/cols for each (run once per task for the sheets that task needs).
- [ ] **Step 4: Run** `tools/test.sh` — Expected: all PASS. Run a bot soak (server + 4 bots, 40 s): kills and 0 errors; screenshot confirms the tank explosion still plays.
- [ ] **Step 5: Commit** `Add generic effects system`.

### Task 2: Bullet impacts

- [ ] **Step 1: Tests** in `tests/test_sim_combat.gd`: `test_hit_on_a_tank_emits_an_impact` (kind `hit_tank` at the bullet's position, also when a shield absorbs it); `test_hit_on_steel_emits_sparks` (`hit_steel`); `test_hit_on_brick_emits_an_impact` (`hit_brick`, exactly one for a bullet that damages two cells); `test_no_impact_effect_when_a_bullet_expires_in_the_open` (range expiry emits none).
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement** the emits in `_resolve_bullets` (one per consumed bullet, at `b.pos`), add the three kinds to `Effects.DEFS` and copy their sheets with `tools/pack_fx.gd`. **Step 4: Run** the suite — Expected: PASS.
- [ ] **Step 5: Preview** every kind in a scratch scene next to a tank at in-game scale; tune `size`. **Step 6: Commit** `Add bullet impact effects`.

### Task 3: Pickups and upgrades

- [ ] **Step 1: Tests** in `tests/test_sim_powerups.gd`: `test_star_pickup_emits_its_effect` (`pickup_star` at the taker's centre, also when the star is at max and gives nothing), `test_helmet_pickup_emits_its_effect`, `test_grenade_emits_a_blast` (`blast` at the taker's centre), `test_heal_tick_emits_a_heart_effect` (one `heal` per healed point), `test_drop_emits_a_sparkle` (`drop_sparkle` at the power-up centre).
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement** emits in `_apply_powerup`, the healing step and `drop_powerup`; add kinds (`blast` = `stylized_explosion_001_large_yellow`, size 96) and copy sheets. **Step 4: Run** — Expected: PASS. **Step 5: Preview** and tune sizes. **Step 6: Commit** `Add pickup and upgrade effects`.

### Task 4: Respawn warp-in and muzzle flash

- [ ] **Step 1: Tests** in `tests/test_sim_combat.gd`: `test_spawn_and_respawn_emit_a_warp_at_the_tank_centre`; `test_firing_emits_one_muzzle_flash_per_bullet_rotated_to_the_facing` (all four facings: `rot == TankSprite.angle(facing) - base_angle`-consistent value, defined by the test as the facing angle plus the effect's `base_angle`); `test_refused_fire_emits_no_flash` (bullet limit reached, or dead tank).
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement** in `_respawn` and `_fire`; add kinds `warp_in` and `muzzle`; copy sheets. **Step 4: Run** — Expected: PASS. **Step 5: Preview** the flash in all four facings and the warp at tank scale; confirm the flash direction matches the barrel. **Step 6: Commit** `Add warp-in and muzzle flash`.

### Task 5: Brick-break dust

- [ ] **Step 1: Tests**: `test_destroying_brick_emits_one_dust_puff_per_bullet` (second hit on a two-cell wall: exactly one `brick_dust`; first hit: none), `test_heavy_shot_dust` (3-star shot destroying brick or steel: one `brick_dust`).
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement** in `_bullet_hit_terrain` (emit once if any cell was destroyed); add kind; copy sheet. **Step 4: Run** — Expected: PASS. **Step 5: Commit** `Add brick-break dust`.

### Task 6: Credits and live verification

- [ ] **Step 1:** README credit already covers the pack; update it to list "explosion, impacts, muzzle flash, warp, pickups, heal, dust" and keep the licence note.
- [ ] **Step 2: Live run**: server + 6 bots 60 s, then a watcher client with `--shot` screenshots; confirm 0 errors, no resyncs, effects visible in at least one screenshot; web build still loads in headless Chromium and shows effects.
- [ ] **Step 3: Commit** `Credit the effects pack`.
