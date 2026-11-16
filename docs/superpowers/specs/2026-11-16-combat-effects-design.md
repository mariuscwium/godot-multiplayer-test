# Combat and pickup effects — short design

## Intent
Make fights and pickups feel alive by playing pixel-art animations from the Super Pixel Effects Gigapack (free) at the right moments. The author picked all four groups after seeing candidates: bullet impacts, pickups/upgrades, respawn warp-in + muzzle flash, brick-break dust. Behaviour of the game itself must not change.

## Source and licence
Free Super Pixel Effects Gigapack (Will Tice / unTied Games): allowed inside a game with attribution; the pack itself must not be redistributed. The repo holds only the handful of sheets used (`assets/fx/`), and the README credits the pack.

## Goals
- Effects at: bullet hits a tank / steel / brick; brick destroyed; a tank fires; a tank (re)spawns; star, helmet and grenade pickups; a tank heals a point; a power-up drops. The existing tank-destroyed explosion moves onto the same system.
- Adding a new effect later is one table entry plus one emit.
- Effects never alter gameplay, hit boxes, or what is hidden except that they are visible even over bushes (as the tank explosion already is).

## Non-goals
Sound, looping auras (shield sparkle), kill-streak text/coins, any simulation or network behaviour change beyond the new event.

## Design (designer's calls)
- **Registry**: `Effects` (pure): per kind the sheet path, frame size, frame count, fps, draw size in world px, and a base angle if it can be rotated. Helpers `frame_at(kind, age)`, `src_rect(kind, frame)`, `duration(kind)`. `ExplosionFx` is replaced by it.
- **Event**: the server emits `{"k":"fx","fx":<kind>,"pos":Vector2,"rot":float}` (reliable, with the other events). The client appends `{kind,pos,rot,born_ms}` to its active list (unknown kinds ignored; list capped at 64) and `Render` draws them above everything. Kill events keep spawning the tank explosion and the screen shake as they do now.
- **Where the simulation emits**: one `Sim._fx(kind, pos, rot)` helper. Hits: one effect per bullet at its impact point (not per cell). Muzzle: at the bullet's spawn point, rotated to facing. Warp: tank centre on every (re)spawn. Pickups: tank centre; the grenade also plays a big blast sized to its 6-cell radius. Heal: tank centre per healed point. Drop: power-up centre. Brick dust: once per bullet that destroys a cell.
- **Picks** (variant colours chosen for contrast on the sand ground): tank hit `symmetrical_impact_002_small_blue`, brick hit `symmetrical_impact_001_small_yellow`, steel `scifi_spark_burst_001_small_yellow`, brick dust `symmetrical_smoke_burst_001_small_brown`, muzzle `scifi_muzzle_flash_001_small_yellow`, warp `scifi_warp_003_small_blue`, star `spell_attack_up_001_small_red`, helmet `spell_defense_up_001_small_blue`, grenade blast `stylized_explosion_001_large_yellow`, heal `spell_heal_001_small_red`, drop `round_sparkle_burst_001_small_blue`. Draw sizes are tuned by eye (about half native for the 48-64 px sheets).

## Left to the builder
Exact draw sizes and per-effect fps tweaks, how the pack tool locates variants, effect layering order.

## Success
Every listed trigger shows its effect in screenshots/previews and in a live run; the suite is green; effects add no script errors over a bot soak; frame rates stay normal.
