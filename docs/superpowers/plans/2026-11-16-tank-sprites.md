# Tank Sprites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Draw tanks from the pixel-art tank sheet (rotated, tiered by stars, tread-animated, tinted) instead of code-drawn shapes.

**Architecture:** A pack tool cuts `assets/source/tank-sprite-sheet.png` into `assets/tanks.png`; a pure `TankSprite` helper maps (stars, frame, facing) to a source rect and angle; `Render._draw_tank` draws through it.

**Tech Stack:** Godot 4.7.2 / GDScript, headless test runner (`tools/test.sh`).

**Spec:** `docs/superpowers/specs/2026-11-16-tank-sprites-design.md`

## Global Constraints
- Sheet: 1024x512, 4 tier columns x 2 tread-frame rows, 256x256 cells, magenta `#ff00ff` background, tanks face up.
- Output strip `assets/tanks.png`: 128x64, tier `t` frame `f` at `(t*32, f*32, 32, 32)`.
- Tank hitbox stays `Cfg.TANK_PX` (16) world px; nearest-neighbour filtering on the texture (not the Render node, which would blur name tags).
- Tier = `clampi(stars, 0, Cfg.MAX_STARS)`; facing angles: UP 0, RIGHT PI/2, DOWN PI, LEFT 3*PI/2.
- Shield flicker, health bar and name tag unchanged; star pips and code-drawn body/barrel removed.
- Branch `battle-city`; commit only named files; no gameplay/network/sim changes.

## Review Focus
1. Magenta must not leak: no opaque magenta/pink fringe pixels in `tanks.png` (Task 1 test).
2. Rotation must keep the tank centred on its hitbox in all four facings (Task 2 screenshot).
3. A tank standing still must not animate; a moving one must (Task 2 helper test + check).
4. Missing/unimported `assets/tanks.png` must fail loudly, not draw nothing (Task 2).
5. Name tags, health bars and the shield flicker must be unchanged and still readable over the sprite (Task 2 screenshot).

## File Structure
- Create `tools/pack_tanks.gd`, `assets/tanks.png`, `assets/source/tank-sprite-sheet.png` (copied), `scripts/tank_sprite.gd`, `tests/test_tank_sprite.gd`.
- Modify `scripts/render.gd`.

---

### Task 1: Pack the sprites and add the lookup

**Files:** Create `tools/pack_tanks.gd`, `assets/tanks.png`, `scripts/tank_sprite.gd`; Test `tests/test_tank_sprite.gd`.

**Interfaces:**
- Produces (`class_name TankSprite`): `const CELL_PX := 32`; `static func tier(stars: int) -> int`; `static func src_rect(stars: int, frame: int) -> Rect2` (frame 0 or 1, other values wrap with `posmod`); `static func angle(facing: int) -> float`.

- [ ] **Step 1: Write the failing tests** in `tests/test_tank_sprite.gd`: `test_tier_clamps` (`tier(-1)==0`, `tier(0)==0`, `tier(3)==3`, `tier(9)==3`); `test_src_rect` (`src_rect(0,0)==Rect2(0,0,32,32)`, `(2,1)==Rect2(64,32,32,32)`, `(9,3)==Rect2(96,32,32,32)`); `test_angle` (UP 0, RIGHT PI/2, DOWN PI, LEFT 3*PI/2); `test_tanks_png_has_eight_clean_tanks`: load `res://assets/tanks.png` as a `Texture2D`, `get_image()` is 128x64; for each of the 8 cells: more than 300 opaque pixels, corner pixel (0,0) of the cell fully transparent, and no opaque pixel with `r>0.9 and b>0.9 and g<0.25` (magenta leak) anywhere in the image.
- [ ] **Step 2: Run** `tools/test.sh tank_sprite` — Expected: FAIL (`TankSprite` missing, no png).
- [ ] **Step 3: Implement `TankSprite`** per the Interfaces block.
- [ ] **Step 4: Implement `tools/pack_tanks.gd`** (`extends SceneTree`; run `godot --headless --path . -s tools/pack_tanks.gd -- assets/source/tank-sprite-sheet.png`): key magenta (exact match plus a small tolerance), take each cell's used rect, one common scale so the largest tank's longer side becomes 30 px (leaves a 1 px margin) using `INTERPOLATE_LANCZOS`, centre each in its 32x32 cell, apply a brightness gain constant (`GAIN := 1.35`, clamped to 1.0) to opaque pixels, write `assets/tanks.png` (128x64); exit non-zero with a message if the sheet is missing or is not 1024x512. Run it, then `godot --headless --path . --import`.
- [ ] **Step 5: Run** `tools/test.sh` — Expected: all PASS, no `SCRIPT ERROR`.
- [ ] **Step 6: Commit** `tools/pack_tanks.gd assets scripts/tank_sprite.gd scripts/tank_sprite.gd.uid tests/test_tank_sprite.gd tests/test_tank_sprite.gd.uid tools/pack_tanks.gd.uid` — `Add tank sprite strip and lookup`.

### Task 2: Draw tanks from the sprites

**Files:** Modify `scripts/render.gd`, `tests/test_render_helpers.gd`.

**Interfaces:**
- Consumes: `TankSprite.src_rect/angle`, `Render.hue_for`, existing `load_terrain_texture` pattern.
- Produces: `static func load_nearest_texture(path: String) -> Texture2D` in `Render` (generalises `load_terrain_texture`, which stays as a thin wrapper so its test still passes); `static func is_moving(prev: Variant, now: Vector2) -> bool` (false when `prev` is null or the distance is under 0.05 px).

- [ ] **Step 1: Write the failing tests** in `tests/test_render_helpers.gd`: `test_tank_texture_is_nearest_canvas_texture` (`Render.load_nearest_texture("res://assets/tanks.png")` is a `CanvasTexture`, filter `TEXTURE_FILTER_NEAREST`, size `Vector2(128, 64)`); `test_is_moving` (`is_moving(null, Vector2(5,5))==false`, `is_moving(Vector2(5,5), Vector2(5,5))==false`, `is_moving(Vector2(5,5), Vector2(5.5,5))==true`).
- [ ] **Step 2: Run** `tools/test.sh render` — Expected: FAIL.
- [ ] **Step 3: Implement** `load_nearest_texture` and `is_moving`; load the tank texture in `_ready` with a loud failure like the terrain one (`push_error` + `get_tree().quit(1)`).
- [ ] **Step 4: Rewrite `_draw_tank`**: remember each tank's previous drawn position in a Dictionary keyed by id; frame `int(t * 10) % 2` while moving, else 0; `draw_set_transform(pos + Vector2(8, 8), TankSprite.angle(facing))`, `draw_texture_rect_region(tanks, Rect2(-8, -8, 16, 16), TankSprite.src_rect(stars, frame), tint)` with `tint = Color.from_hsv(hue_for(id), 0.55, 1.0)`, then `draw_set_transform(Vector2.ZERO, 0.0)`; keep the shield flicker, health bar and name tag code unchanged; delete the old body/treads/barrel/star-pip drawing. Forget ids of tanks that left.
- [ ] **Step 5: Run** `tools/test.sh` — Expected: all PASS.
- [ ] **Step 6: Verify visually** with a scratch preview script (outside the repo) that draws every tier in all four facings through `Render._draw_tank`, plus two live `--shot` screenshots with bots; read them: orientation correct, tank centred in its box, tint reads, nothing magenta, name/health bar/shield intact, standing tanks static.
- [ ] **Step 7: Verify web**: `tools/export_web.sh`, headless Chromium over ws as before; confirm tanks render.
- [ ] **Step 8: Commit** `scripts/render.gd tests/test_render_helpers.gd` — `Draw tanks from sprites`.
