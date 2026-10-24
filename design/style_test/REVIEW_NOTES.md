# Style test: review log

## LOCKED decisions (do not revisit without the user)
- Player: option A (wide-brim felt hat, teal band, glowing feather), saffron coat, teal scarf, gold ring + glow.
- Dark people: hunched, heavy coat, soot motes and smoke haze.
- Minimap: circular, top-left, parchment frame, about 20% of the width.
- Zoom: orthographic camera size 14.5. Pixel scale: 640x360 internal, 3x nearest upscale.
- Floor: irregular cobbles. Transformation edge: the dithered half-cottage / half-shed wash edge.
- Border = faint amber glow + golden motes between border people.
- Gap pulse (strong, soft, 1.2 s): coral glow + motes at the gaps only, eased, never a hard line.

**The style is locked as the target for the in-game style pass (a later round, after the living-border gameplay settles).**

## 2026-10-24: Review 5: stronger gap pulse
The user wanted the pulse stronger, then the style is locked. Peak values raised (trough unchanged): ground glow strength 0.05 + 0.34p -> 0.05 + 0.44p, glow scale 0.8 + 0.35p -> 0.8 + 0.45p, haze boost x(1+2.6p) per gap weight (was 1+2p in the toned-down pass, 1+3p in the first), coral motes scale 0.8 + 1.1p -> 0.8 + 1.3p and emission 1 + 2.6p -> 1 + 3.2p. Re-rendered `topdown_joy_050.png` (peak), `gap_pulse/frame_00..07.png`, `gap_pulse.html` and `contact_sheet.png` in one run; viewed final 050, frame_00 (trough, subtle dither) and frame_04 (peak, clear soft coral wash, no hard line, only at gaps).

## 2026-10-24: review 4 feedback -> changes made
Request: make the border gaps pulse (soft coral flicker, ~1.2 s, eased). All LOCKED items unchanged.
- `scene.gd` `set_pulse(p)` / `pulse_value(t)`: p = 0.5 - 0.5 cos(2 pi t / 1.2). At the peak the gap haze brightens (x(1+2p) via vertex weight `UV2.x`), the coral motes swell (0.8x -> 1.9x) and glow (emission 1.0 -> 3.6), and a coral dithered ground glow under each gap grows and brightens (strength 0.05 -> 0.39, scale 0.8 -> 1.15). The trough is close to the review-4 subtle look.
- `topdown_joy_050.png` is rendered at the pulse peak. `renders/gap_pulse/frame_00..07.png` (960x540, nearest upscale of a 320x180 crop) cover one period, 150 ms apart; frame 04 is the peak. `renders/gap_pulse.html` loops them at 150 ms with a strip of all 8 below (self-contained, relative paths, light/dark background).
- First pass peaked too hard (a big coral patch also at the off-screen gap); toned down the glow (0.5 -> 0.34) and haze boost (3 -> 2).
- Open: in the game this should be a shader time uniform, not frame-stepped; the same pulse could be reused for the off-screen arrow.

## 2026-10-24: review 3 feedback -> changes made (review 4 renders)
| Feedback | Change |
|---|---|
| Player A chosen, only design | Gameplay already used A; the lineup keeps the A/B/C row with A labelled "CHOSEN". |
| Dark people good | Unchanged. |
| Border haze too sandy/frosty | Haze band is now amber (not pale), much fainter (strength 1.35 -> 0.3) and narrower; the golden motes between border people are denser and do most of the work. In gaps the haze thins and turns coral, with fewer coral motes. |
| Minimap covered a border person | Gameplay camera target moved 1.4 units further north (player sits slightly lower on screen), so the whole west border person is clear of the minimap circle. Zoom unchanged. |
| Re-check 050 arrow + gap, view all PNGs | Checked: arrow visible at the left edge below the minimap, gap on the right is subtle (coral motes, dark people at it). 000/100/closeup/contact sheet/comparison all viewed in the final run. |

### Open questions for review 4
1. Is the gap now too subtle at a glance? The arrow and minimap carry it; should the gap also get a small coral glow pulse?
2. Should the player stand a bit lower on screen permanently (camera offset now -2.4) or be exactly centred?
3. Border motes: denser, sparser, or animated drift?

## 2026-10-24: review 2 feedback -> changes made (review 3 renders)
Kept: zoom (camera size 14.5), minimap contents and style, floor, pixel scale 640x360.

| # | Feedback | Change |
|---|----------|--------|
| 1 | Minimap top-left and circular | `minimap.gd` is now a round parchment-framed map (128 px diameter, 20% width) in the top-left. Same contents (warm/grey ground, buildings, border line, gaps, border people, dark dots, landmark star, player, camera view). Content is clipped to the circle. The off-screen arrow is pushed down the screen edge whenever it would come near the minimap. |
| 3 | Player less wizardly | Cone hat removed. Saffron coat, teal scarf, gold ring and glow kept. Three options, all in `people_lineup.png`: A wide-brim cocoa felt hat with teal band and glowing feather (used in all gameplay shots), B coral knit beanie with gold pom-pom, C flat cap with teal patch. |
| 4 | Border line much softer | The hard ribbon is gone. The border is now a dithered, low-opacity warm haze band (`haze.gdshader`, vertex-colour driven) plus faint golden motes floating between border people. In a gap the haze thins out and turns coral-red with a few red motes. The off-screen arrow and minimap still mark the gaps. |
| 5 | Grey people: stronger affinity | Grey people hold a grey version of their object up in front at readable size (horn / brush / flower, faintly tinted), wear a muted affinity-coloured scarf and cap band, and still carry the small pip. Still clearly grey overall. |
| 6 | Dark people rethought | Hunched, heavy long coat with raised collar, head lowered between the shoulders, dull face, flat cap pulled low, hands hanging. The umbrella cloud is replaced by drifting soot motes and a dithered smoke haze on the ground. |

Lineup is now 1920x1410 (four bands) so the three player options fit: gameplay scale row of all 10 characters, then 2x rows for grey + dark, joyful, and player options.

### Iterations
1. First render: haze nearly invisible, dark person read as a box with a black disc (hat top seen from above), grey held horn looked like a hand mirror, lineup labels overlapped.
2. Second: tilted held items, softened scarf tint, less hunch, stronger haze, fixed labels and crops.
3. Third: dark person's head lowered between shoulders instead of tilted (so a face is visible from above), haze strength raised again.

### Pipeline settings (unchanged unless noted)
- 640x360 internal, nearest 3x upscale, HUD drawn at internal resolution; ortho camera size 14.5, pitch 41.
- Toon bands 0/0.55/1 with 4x4 Bayer; depth + normal outlines; Voronoi cobbles; integer-hash wash noise.
- New: `haze.gdshader` (dithered border band), reuse of `glow.gdshader` for the dark smoke (dark colour).

### Open questions for review 3
1. Border haze: right strength? It is a warm sandy band; should it be more golden/lighter, or thinner?
2. Gap signal: is coral haze + red motes + off-screen arrow enough, or should the dark person's smoke leak across it?
3. Player hat A: keep, or prefer B (beanie) / C (flat cap)? Should the player face the camera more in play?
4. Grey people: is the scarf + held object too colourful at gameplay zoom, or about right?
5. Dark people: still a little boxy from above. Add a hood, a visibly bent back, or longer coat tails?
6. Soot motes and smoke haze: more, less, or animated drift in the real game?
7. Minimap: size and corner OK? Keep the camera rectangle?


## 2026-10-24: review 1 feedback -> changes made (review 2 renders)

Kept as the user asked: grey industrial world, warm whimsical world, the dithered half-cottage / half-shed edge,
lighting and outlines.

| # | Feedback | Change |
|---|----------|--------|
| 1 | Floor grid reads like a fence | `ground.gdshader` rewritten: no brick grid. Irregular cobbles from a Voronoi (cellular) pattern with a domain warp, about a third of the cells split into smaller stones, gaps ~1 px wide and only slightly darker than the stone (grey: cool + grime; warm: moss tint in some gaps, tiny flowers only inside gaps). Stone-to-stone colour variation reduced. No straight lines anywhere. |
| 2 | Finer pixels | Internal render 640x360 (was 480x270), nearest upscale 3x to 1920x1080. |
| 3 | Camera too far | Orthographic camera size 14.5 (was 21.5), about 1.8-2x bigger people and buildings than review 1, centred on the player (offset about 1 unit north so buildings show). Same level size; buildings are now partly cropped, as they would be in play. |
| 4 | People: bigger, more character, readable affinity | New bodies. Grey: stiff, upright, straight arms, flat cap, drab coat, a small coloured pip on lapel and cap in the affinity colour, plus a small grey version of the affinity object held in front. Joyful: tilt, twist, hop, one arm raised carrying the object, three pose variants. Music = dusty-blue coat + navy cap with cream feather + brass horn. Art = rose/terracotta coat + terracotta beret + paintbrush. Nature = sage coat + straw hat with leaf crown and flower + flower in hand. |
| 5 | Player hard to find | Own palette that no NPC uses: saffron coat, tall plum cone hat with glowing star, long teal scarf, satchel with three glowing tubes (blue/rose/sage). Warm double ring on the ground, dithered gold glow disc, warm omni light, emissive coat. Player now faces the camera diagonally. |
| 6 | Minimap + off-screen arrow | New `minimap.gd` (drawn in the same 640x360 pixel pass). ~20% width, top right, parchment frame with rounded corners. Shows warm vs grey ground (computed from the exact same noise as the ground shader), buildings, gold living-border line with red gap markers, border people as cream dots, dark people as dark dots, landmark star, player dot, and the camera view rectangle. A red arrow badge on the left screen edge points at the off-screen gap (projected through the real camera). |
| 7 | Living border | `build_border()` traces the true edge of the warm area, spaces 16 people along it (14 shown, 2 slots left empty), draws a thin gold ground ribbon between them and a thicker dashed red ribbon across the gaps. One gap is visible (right side) with a dark person pushing through; the second gap is off-screen to the west (that is what the arrow points at). In the 50% shot only. |

Side changes: landmark building (blue roof) got a gold pennant; sand-ridge grime ring around the wash slightly weaker;
noise in the wash field uses an integer hash so GDScript matches the shader exactly (border, minimap, people agree);
`firstperson.png` deleted (mode dropped); comparison image is now two 1280x720 panels (clean 2x for the pixel panel).

### Iterations
1. First render: floor still read as a web (moss-green lines too strong, too many split cells), camera slightly too close (people about 2.4x), minimap background looked like a transparency checkerboard, dark people blocked the gap, lineup crops cut off feet. Fixed: thinner/paler gaps, fewer split cells, size 14.5, flat parchment map, border shot re-framed with smaller warm area.
2. Second render: gap moved to the open right side, dark people thinned out, player turned to show their face, regular people hidden near the gap so nothing overlaps, red ribbon widened, lineup crops fixed.
3. Third render: red gap made longer and bolder; moss in warm gaps toned down again.

### Pipeline settings now in use
- Internal 640x360, SubViewport, MSAA off, nearest upscale 3x. HUD (minimap/arrow) drawn at the same internal resolution.
- Toon light: 3 bands (0 / 0.55 / 1) with a 4x4 Bayer dither (`dither_amt` 0.16). Linear tonemap.
- Outlines/creases: depth Laplacian (`dthr` 0.3) + normal crease (0.72) in `post.gdshader`, 1 px.
- Wash edge: Bayer-dithered blend with value noise (integer hash), grey grime ridges ahead of it.
- Camera: orthographic, pitch 41 degrees, size 14.5 (gameplay), 10.5 at 30 degrees yaw -22 for the close-up.
- Ground: Voronoi cobbles (scale 0.78 big, 1.95 fine, 34% of cells split), gap 0.025-0.065 world units.

### Open questions for review 2
1. Is the floor now quiet enough, or should the warm moss lines go even fainter / disappear except around flower beds?
2. Camera: is about 1.9x right, or should it come back a little (to see more of the border) or go in more?
3. The player is a tall plum-hat figure; is the silhouette too wizard-like for a gentle "joy spreader"? Alternatives: wide sun hat, or a tall flower-pot hat.
4. Dark people: the "small cloud" reads as an umbrella from this angle. Keep it, make it a smudge of smoke, or drop it?
5. Border line: thin gold line only, or also small posts/lanterns between people? Should intact stretches glow more?
6. Minimap: keep the camera rectangle? Landmark star OK? Should the border people show as dots or be hidden?
7. Grey people all look alike at gameplay zoom apart from the pip. Is the pip enough, or should coat shade vary by affinity?
8. Large dark ridge bands around the wash edge are bolder at this zoom; keep or soften further?
