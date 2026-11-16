# Tank sprites — short design

## Intent
Replace the code-drawn tanks in `scripts/render.gd` with the author's pixel-art tank sheet (`tank-sprite-sheet.png`, generated with ChatGPT from our prompt; the author owns it). Behaviour must not change.

## Source
1024x512, flat magenta (#ff00ff) background, exactly 7 colours. 4 columns = upgrade tiers (single barrel, longer barrel, twin barrels, heavy), 2 rows = tread frames; every cell is 256x256. Tanks face up. Neutral greys so each player can be tinted. The two rows differ only in the treads.

## Goals
- Every tank drawn from the sprite: rotated to its facing, tier chosen from its stars (0..3), tread frame alternating while it moves, per-player tint.
- Shield flicker, health bar and name tag stay drawn in code, as today. The code-drawn body, barrel and star pips are removed (the tier shows the stars).
- The hitbox stays 16x16 world px.

## Non-goals
Explosions/effects, other sprites (bullets, power-ups), any gameplay/network/sim change.

## Design (designer's calls; the author approved the plan and the "tanks grow with stars" size rule)
- `tools/pack_tanks.gd` cuts the sheet into `assets/tanks.png` (128x64: 4 tiers x 2 frames of 32x32). One common scale for all eight tanks so the largest (tier 4) fills a 32 px cell and tier 1 is ~85% of it; each tank centred in its cell; magenta keyed to transparent. A brightness gain is applied at pack time so multiply-tinting by player colour does not look dark.
- `TankSprite` (pure helpers): `tier(stars)`, `src_rect(stars, frame)`, `angle(facing)`.
- `Render._draw_tank` draws the 32x32 cell into the 16x16 hitbox box, rotated by `angle(facing)` about the tank centre, with nearest filtering and the player tint as modulate. "Moving" is derived from the drawn position changing between frames.
- The source sheet is kept at `assets/source/` (8 KB) so the strip can be re-cut.

## Success
Screenshots show all four tiers in all four facings, correctly oriented, tinted per player, crisp; the suite is green; names, health bars and shields unchanged.
