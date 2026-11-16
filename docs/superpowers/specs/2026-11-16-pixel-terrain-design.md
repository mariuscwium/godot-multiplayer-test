# Pixel-art terrain — short design

## Intent
Replace the code-drawn terrain (flat rects and lines in `scripts/render.gd`) with pixel-art tiles for a fresher look. The author chose a "fresher pixel art" style over faithful NES. Behaviour must not change.

## Source
Tiles come from `Textures-16.png` (author's Downloads), from Screaming Brain Studios' "Tiny Texture Pack" (https://screamingbrainstudios.itch.io/tiny-texture-pack), listed as CC0 / public domain: no attribution required, redistribution allowed. A courtesy credit line goes in the README. (The designer could not verify the local file is byte-identical to that pack.)

## Goals
- Brick, steel, water (animated), ice, bush and ground drawn from tile art.
- A destroyed or regrown brick still changes in 8 px cells, as today.
- Other tanks stay hidden under bushes, as today.

## Non-goals
- Tank sprites (author is sourcing them; separate follow-up that adds loading, rotation and per-player tint).
- Bullets, power-ups, HUD, explosions/effects pack, TileMap/TileSet rewrite.
- Any gameplay, network or simulation change.

## Approaches (author picked A)
- **A. Draw tiles directly in `Render` (chosen).** One small image in the repo; each 8 px cell draws the matching quarter of its 16x16 tile (`cx % 2`, `cy % 2`) so walls look continuous but break in 8 px chunks.
- B. One PNG per tile: same result, more files.
- C. TileMapLayer/TileSet: more engine integration and a renderer rewrite for no gain at 80x80.

## Design (designer's calls except where noted)
- `assets/terrain.png`: only the used tiles, packed into one image (not the whole atlas). Tile picks, (column, row) in the source atlas: brick (3,3), steel (8,4), water frames (6,8), (7,8), (8,8), ice (3,11), bush (2,16), ground (0,10). The author sees them in the game window and may ask to swap any.
- A small lookup in `render.gd` maps tile type to source rect; water picks its frame from time; the dark ground tile fills the map area instead of black.
- Nearest-neighbour texture filtering so pixels stay crisp when the camera zooms (~3x).
- README gets a credit/licence line.

## Left to the builder
Packing layout of `terrain.png`, how the pack script is kept (a small tool under `tools/` so tiles can be re-cut), draw-call batching if needed.

## Success
Screenshots of every terrain type look right and crisp; bricks still break in 8 px chunks; the test suite is green; no behaviour change.
