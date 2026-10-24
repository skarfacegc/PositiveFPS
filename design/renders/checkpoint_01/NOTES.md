# Graphics checkpoint 1: notes

Made by `python tools/checkpoint_shots.py` (the real game level, fixed seed, scripted scenario, frozen rules at the gap
pulse peak, mid-night). Files: `overview.png` and `gap_closeup.png` (styled), the `_placeholder` / `_styled` versions of
both, `compare.png` (placeholder left, styled right), `timings.txt`.

## Styled vs placeholder
Styled (the locked style, ported from `design/style_test`, using the game's own values):
- Pixel pipeline: 3D at 640x360 (same height for any window, width follows the aspect) in a SubViewport that shares the
  game world, nearest upscale, toon bands + Bayer dither, depth/normal outlines, warm sun with long shadows.
- Ground (irregular cobbles, grey vs warm from the paint weights, dithered edge), plaza walls.
- Buildings and landmark: industrial block, whimsical block after beautify (short dithered dissolve), post lantern and ring.
- People (grey / joyful / dark), the player, the border (amber haze, golden motes, coral gap glow and motes pulsing
  over 1.2 s), the minimap (round parchment style, drawn crisp at window resolution), the landmark hold ring.

Still placeholder (counted by F3 as "on placeholder"): projectiles, blooms, floor effects (burst ring, grace ring),
the target highlight ring, HUD text and the screen-edge gap arrows, the percentage and joy-number labels, the landmark label.

Differences from REVIEW_NOTES: camera ortho size is the game's 16.7 (notes say 14.5); the HUD and minimap are not in the
pixel pass; styled blocks are drawn about 1 m taller than their collision box (the kiosk model, 3.9 x 3.6 footprint) so
doors and windows fit; the landmark is a taller kiosk with a chimney, tank barrel and pennant.

## Readability check (styled, mid-night)
- Player: findable (saffron coat, teal scarf, wide hat with glowing feather, gold ring and glow), but in a crowded ring
  they can sit between people. The gold ring helps; nothing was changed.
- Dark people: clear (hunched dark silhouettes, soot motes, smoke haze) against the cobbles even at night.
- Landmark: clear (blue kiosk, chimney, gold pennant, glowing beacon).
- Gaps: first pass the coral wash was too faint at mid-night. Fixed: glow strength 0.05+0.44p became 0.12+0.6p and the
  glow patch grew from 5 m to 6.5 m. Now the coral dither and motes are easy to see next to the golden intact stretches.
- Contrast is lower than the placeholder at night overall (dark blue world); the lit warm area is the focus.

## Findings
- The current rules open every stretch of a loop at once (spacing over BORDER_MAX_GAP), so one gap on a healthy loop does
  not happen by itself (only a very small border of about 5 people is all gap). For the shots, two stretches are marked as
  gaps by hand in the scenario script. Worth a gameplay decision.
- Frame cost in the shots run (vsync off, RTX 4070 Ti Super): see `timings.txt`, about 1.0 ms placeholder and 1.4-1.6 ms styled.

## Known gaps
- Whole-building swap only (no half-and-half edge); the grey/warm ground edge is dithered from the weights.
- No per-affinity colour on the ground paint in styled mode (always the warm cobble).
- Joy-number labels and the target highlight render in the pixel view (blocky text); the gap arrows are window-crisp.
