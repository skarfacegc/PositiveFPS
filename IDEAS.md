# PositiveFPS — Game Ideas

Finished round history and resolved issues live in `IDEAS_RESOLVED.md` (one line per round at its top). This file keeps
the current state, the standing ideas and backlog, and the latest rounds. To find code use `SOURCE_MAP.md`
(`python tools/source_map.py`); for where things live and how to brief an agent use `ARCHITECTURE.md`.

## Current state (as of 2026-11-04, after the checkpoint 5 follow-up playtest)

**What the game is.** A gentle top-down territory game in Godot 4.7 (GDScript, strict typing). Dimmed people slowly take
over a plaza; the player rescues them with joy, and the rescued form a living border that holds the gloom back and paints
the land inside. One night per level, dusk to dawn (about 3 minutes); reaching dawn wins and is rated 1 to 3 dawn lights.
Tone: warm and gentle, joy shared and never a cure. Player-facing text uses the gloom terms (wistful, gloomy, dimmed),
never "dark people". Art is original, technique-level inspiration only.

**Mechanics as they stand (round 24 plus checkpoint 5 and its follow-up).**
- **Joy and elements:** music, art and nature (a soft cycle: matched 2x, strong 1.5x, weak 1x). Pointing at a person fires
  automatically; a person needs enough joy to be rescued (grace, then the border). Moods: guarded (front-only joy),
  skittish (flees), glum (x3 when looking up), sheltered (umbrella shield, four hits).
- **Gloom:** unrescued people go wistful, gloomy, then dimmed. Dimmed people press the border and reach for the player. The
  night has phases: calm opening, rising, midnight (hardest, dimmed sinks staggered by `DIM_ARRIVAL_MIN_GAP`), easing.
- **Border:** rescued people form a loop. Gaps open where members falter or spacing is too wide. A member drained too far
  wobbles about five seconds before relapsing; a joy hit saves them. Relapses are gated (`RELAPSE_GATE_GAP`).
- **Spirit:** 0 to 100, start 50; +20 a rescue. At 0 the player goes dim (half speed, no fire, border loses heart). Spare
  spirit at a full meter pools and warms the most strained border member (`spirit_warmth.gd`).
- **Spirit actions:** beacon (50): hold E to aim a zone preview, release to place, right-click cancels; the zone stretches
  toward it and the arm stays, limited by headcount. F (25) patches the gap or strained spot nearest the cursor for 12 s.
  G or Q (30, 8 s cooldown) bursts: lifts dimmed people nearby and pushes back those on the border line.
- **Landmarks:** Bandstand, Garden (about 14 m from the start), Bell Tower. Holding one (3 s inside the border) boosts
  joy; the third dawn light needs 75% rescued and 2 landmarks.
- **First light:** over the last 45 s a square front moves in from the map edge; people it passes lift and stop draining.
- **Cues:** rings on strained border people, gap arrows, wobble edge pointers and minimap blips, landmark pointers, a cue
  panel beside the spirit meter (glows when F or G can be used), one-time prompts per mood.

**Controls.** WASD move, Shift run, mouse to point, hold E / release E beacon (right-click cancels), F patch, G or Q
burst, F2 targeting mode, mouse wheel zoom, F3 debug, F4 switch look, R restart, M menu. Menu: Play (Enter, 1, click), Look.

**Look modes.** Placeholder (default, plain shapes, what the tests run) and styled (pixel-diorama 3D: toon, outline, ground
and post shaders, in a 640x360 SubViewport). F4 or the menu switches mid-game. Gameplay rounds touch the placeholder only;
the styled look changes only in graphics checkpoints (latest: checkpoint 5, then a follow-up for the preview and HUD).
Still placeholder in styled mode: the target highlight, the beacon marker and the HUD text labels.

**Open items** (each checked against the code on 2026-11-05):
- Confirm in the next styled playtest that the game log has no shader instance errors (the screenshot run had 0).
- The first light square itself still looks like a hard square edge; only the explanation was added. Soften it or make
  it a ring if the user still finds it odd.
- A wobble pointer can still overlap an ordinary prompt shown at the bottom middle (the PromptBar is not an avoid rect).
- The second arm is much shorter than the first (7.3 m against 34.2 m at 24 people); a design call (a reserve for it would
  give back the reach gain). Earlier arm retreat, if pull-in feels late.
- Whether one burst per 8 s keeps pace with arrivals every 9 s (bursts were barely used in the last recordings).
- The minimap redraw spike (8 ms per redraw; tests turn the automatic redraw off).
- The player's jog barely differs from the walk in the styled look.
- Sound cues: not designed yet.
- The limited preview checkpoint shot uses "inside the zone already", not a dimmed block (minor).
- The agent dashboard may show a finished agent as running (not rechecked).
- Dawn lights are easy (60% rescued plus one landmark was enough in earlier rounds; now 75% and 2); watch in the next
  recording whether the third light is earned.
- Wider-world and progression ideas (below) are not scheduled.

**Resolved since they were last listed (moved text stays in `IDEAS_RESOLVED.md`):** `topdown_main.gd` size (992 then 805
lines, split into `crowd_movement.gd`); `config.gd` and `border.gd` near the 1000-line cap (now 444 and 821; `config_base.gd`
and `border_shape.gd` hold the rest); the determinism check's 1088 differing lines and the `looks_*` wobble (the styled look
read the wall clock; fixed in `140c94e`, `KNOWN_REAL_TIME_UNITS` is empty); the how-to-play key list lacking E
(`how_to_play_keys_test`); the HUD burst text overlapping the spirit label and the thick coral stripe preview (follow-up
build: outline only, spirit label above its bar); styled look lagging for first light, reactions and the cue panel
(checkpoint 5); shader instance errors in styled play, the wobble pointer over the HUD, the preview staying up after a
focus loss, and first light having no explanation (snag round, 2026-11-05).

**Push status.** `origin/main` is `4d8ea8d`; rounds 23 onward are unpushed (local main is ahead). Rounds are not pushed
until the user asks.

**Pointers.** `README.md` (player docs), `ARCHITECTURE.md` (script map, tools, gotchas, how to brief an agent),
`SOURCE_MAP.md` (every script's public functions with line numbers, generated), `IDEAS_RESOLVED.md` (history),
`tools/COVERAGE_TOOL_NOTES.md`, `.claude/skills/` (brief-build-agent, finish-round, launch-playtest). Latest recordings
with logs: `recordings/playtests/`.
## Core concept
- Structurally an FPS, with some key differences
- "Weapons" are things that spread joy: paintbrush, guitar, flowers, ...
- Music / art / nature stand in for "elemental" damage types
- Different people find joy in different ways: some through music, some through art, some through time in nature
- Instead of killing, you're rescuing people from a lack of joy (used generically — not clinical depression)
- Everyone you rescue helps rebuild the part of town where the mission took place
- The more people you rescue, the more you build (rescue count drives how far the rebuild goes)
  - Uses thresholds: hit X rescues → next building unlocks
  - It's purely a count: it doesn't matter *who* you rescue (revisit only if a specific-person mechanic turns out to be useful)
  - Maybe: some regions have a boss whose rescue unlocks special/unique shops or items
- New buildings == new items / power-ups / etc.
- **The grey is the real "enemy":** areas where you've helped people become vibrant and colourful; areas you haven't stay washed-out and grey. At some (TBD) interval the grey boundary pushes back out. This push/pull over territory could be the game's long-term tension.
- **Idea (2026-10-22): buildings are captured by land, not just count.** Each building has a footprint; it converts to "useful" once enough of the ground around it is painted. Ties painted ground to progression and makes positioning matter; grey pushing back could un-capture a half-won building. Decided: land **replaces** rescue-count thresholds (rescues matter because rescued people paint land). During a mission a building can be lost if grey retakes its land; whatever is converted when the timer ends is kept permanently.
- **Idea (2026-10-22): transformation theme, not just colour.** The grey world is cold / mechanical / steampunk-ish (iron, rivets, pipes, smokestacks, rigid uniforms, routine postures); joy transforms it to whimsical / fantasy / warm (curved roofs, lanterns, banners, vines, expressive clothes). Applies to buildings AND characters. Transformation moments: gears unwind into flowers, pipes sprout vines, smokestack steam becomes notes/paint swirls. Genre-level inspiration only; the specific mix is ours. Decided: grey people stay clearly human: drab industrial uniforms, stiff clockwork-like motion and routines (set paths, checking watches); joy loosens them up. Leading visual direction: pixel-diorama 3D (see design/style_mockups.html).
- **Idea (2026-10-22): joy is contagious too** (gentler than darkness). A person's "cover" = fraction of painted ground within a few metres of them (threshold ~60%). Cover is **graded by depth**: protection is strongest in the middle of a painted area and weakest at its edges, so establishing space matters and is somewhat durable. **Darkness can only creep in at the edges:** dark spreading and drain affect people (grey or rescued) only in the edge band, scaled by how shallow their cover is; deep inside, everyone is safe. With enough cover: grey people stop darkening and are lightened step by step toward light grey (~10 s per level; never rescued by contagion alone), and partial joy doesn't fade. **Ground transitions slower than people:** painted ground spreads and fades back more slowly than people change, so territory lags and persists (a relapse doesn't instantly erase the area).
- **Pressure is time, not enemies:** each mission gives you a limited time to help as many people as possible. Your rescue count at the end sets how much of the town you can restore. A gentler kind of shooter.

## Style pillars (from design mockups v1–v3, 2026-10-22)
Guides a Godot style test (round 6 or later). Mockups: design/style_mockups*.html. Original style only; technique-level inspiration, no copying other games.
- **Rendering:** pixel-diorama 3D: simple low-poly 3D rendered at low resolution (~320x180–480x270) with crisp upscaling, soft toon shading, 1px outlines, light ordered dithering, warm late-afternoon light, long shadows. Pixelated but not 8-bit.
- **Theme:** cold / mechanical / industrial grey world → whimsical / warm / fantasy. Buildings, props AND people transform, not just colour.
- **Industrial density:** around v3's level: pipes, valves, ducts/pipe bridges, exhaust fans, louvered vents, drain grates, grate platforms, gas tanks, boilers, hazard kerbs. Each has a whimsical counterpart (fan → pinwheel, vent → birdhouse, grate → flower bed, duct → vine arch, tank → flower barrel, boiler → kettle tea stall). Keep it readable; avoid busy corners.
- **Grey-world palette (provisional):** cool steel grey base with brown only as grime: rust streaks, soot, mud ("rust & soot accents"). Sepia overall tint was the alternative; confirm in the Godot style test.
- **Joy palette:** earthy and cozy, not sugary: warm saturated colours, not neon or candy pastels. Music = dusty blue, art = warm rose/terracotta, nature = sage.
- **People:** clearly human. Grey = drab industrial uniforms, stiff clockwork routines (set paths, pocket watches). Joyful = relaxed or dancing, affinity-tinted clothes, playful hats.
- **Wash edge:** the joy front moves like a wave through sand. Grey grime is pushed into rippling, staff-line-like ridges ahead of it, and colour blooms behind. Transformation moments at the edge (gear → flower, pipe → vine, steam → notes).
- **Capture moment:** no sparkles and no "panels unfold". Steam release was preferred but isn't essential; design the real moment in Godot (it needs softer, less abrupt timing).
- **Motion and feel** (timing, easing, sound) get refined in Godot, not in mockups.

## Open questions / threads to pull on
- **Rescue mechanic:** Is there a "joy" meter you fill up? Do people withdraw or drift away rather than attack?
- **Elements:** Launch with three: **music, art, nature**, arranged as a soft cycle (music → art → nature → music).
  - Matched element does the most, the one it's "strong" against a bit less, the "weak" matchup least (never useless)
  - Fits inside the three: dance (music), pets/animals (nature), craft/making (art)
  - Maybe later: **food/cooking** and **play/sport** as extra elements (5 elements also makes a clean cycle)
  - Maybe: new elements unlock via rebuilt buildings (e.g. bakery → food, playground → play), bringing new people with that affinity
  - Considered and set aside: humour (hard to make a weapon), stories/words (overlaps art), connection/kindness (better as the *outcome* of every rescue)
- **Element affinities:** Each person responds best to one of music / art / nature, so the player has a reason to read the person and switch "weapons" mid-fight.
  - Affinity is shown by visible cues (clothes, what they carry, etc.)
  - Like other shooters, a non-optimal element still works, just less effectively
  - Possible hierarchy between elements, e.g. music affects art-types more than nature-types (rock-paper-scissors-ish, but softer). Needs working out: is it a cycle or a ranking?
- **Threats:** Settled for now: no enemies, the clock is the pressure. Open: is the clock visible and fixed, or can you extend it (e.g. each rescue adds a little time)? Is there any environmental hazard at all, or purely time?
- **Player health:** Does the player have their own mood/energy that drains, and get topped up by rescued people?
- **Building → unlock mapping:** e.g. music shop → guitar upgrades, garden centre → flower variants, café → healing item.
- **Visual progression / style:** Town goes from desaturated to full colour as it's rebuilt. Current POC look is placeholder; want a richer, less plain style later.
- **Tone:** Keep it light and warm. Joy is something shared with people, not a cure applied to them.
- **Enemy tiers & bosses:** formalise grey levels into distinct types (light 'routine' people as the bulk, grey normal,
  dark 'spreaders' rarer and tougher) and design bosses (e.g. a heavily gloomed figure with a big gloom aura) in a
  dedicated later round.

## Vision: the wider world (discussion, 2026-10-24)
Long-term direction, not scheduled. The round 11 draft above is unaffected.

The current level is one small town in a larger grey world. A travelling troupe brings the world back to life one town
at a time.

- **Town capture is the current level.** Enclosing and holding the landmark captures the town. Each town is a level
  with its own layout and its own special people (see "Level goals and progression" below).
- **Why we want a town** (these can stack):
  - **The troupe:** some rescued people travel on with you and start the first border in the next town. A well-run
    town gives a stronger start in the next.
  - **Crafts live in towns:** each special person belongs to a town, so the choice of next town decides which
    progression branch grows.
  - **The map warms:** a captured town lights up on the world map, the land around it turns from grey to colour and
    roads open from it.
  - **A bigger aim:** undecided. One option is a long dusk over the world, with each captured town bringing the dawn
    closer (it ties into the dusk-to-dawn level timer). Tone is undecided.
- **Captured towns stay mostly safe.** Threats to a captured town come only as special events, not as constant
  defence.
- **Towns are the focus for now.** Exploration between towns is appealing and can play differently from the town loop
  (roads through grey country, small encounters, travel risk to the troupe), but it isn't designed in depth yet.
  Inspiration is technique-level only: a walkable world between levels.

**Build in layers, each playable on its own**
1. **Node map:** choose the next town from 2 or 3. Troupe and unlocks carry over. Towns are today's level with
   different layouts. Tests whether the "why" works. About one round of work, no style pass needed.
2. **Progression tree:** special people placed in particular towns, four branches.
3. **Walkable overland:** replaces the node map; roads and encounters.
4. **Story and the final town.**

## Level goals and progression (discussion, 2026-10-24)
Side goals inside a level grant abilities or things to place. The "why" is that the people you rescue give something
back: every unlock has a face and a small story.

- Each town has 2 or 3 side goals, each a **special person** (busker, painter, gardener, lamplighter), usually standing
  outside the border, so reaching them means overextending.
- Rescuing one advances their branch by one step: **unlock, then upgrade, then placeable**, in order. Unlocks carry over
  between towns.
- Placeables come in a small stock per town (for example 2 of each unlocked one). Darkness may wear down placeables
  outside the border (open question).
- Suggested start: paint only, since it drives the painted ground and cover (open question: or let the player pick).

| Branch | Step 1 | Step 2 | Step 3 (placeable) |
|---|---|---|---|
| Busker | Music: homing notes ("they hum you the tune") | Harmony: notes jump to a second person ("their band joins in") | Gramophone: plays joy around it ("they leave you their records") |
| Painter | Wide brush: bigger splash ("a looser wrist") | Murals: buildings beautify faster ("they paint the walls with you") | Easel: a small patch of lasting cover ("they set up and keep painting") |
| Gardener | Flowers: blooms that give cover ("they give you seeds") | Hardy blooms: longer cover ("which ones survive the night") | Garden bed: slows darkening nearby ("they plant where you point") |
| Lamplighter | Lantern: a portable border post ("a spare lamp") | Brighter lanterns: hold a longer stretch ("they trim the wick") | Beacon: dark people on the minimap ("they light the tower") |

**Why chase a side goal mid-level:** an immediate edge (a lantern holds a stretch you otherwise couldn't), a choice of
which branch grows, and a real overextension trade-off.

**Suggested first test:** the Busker and Lamplighter branches only (one weapon, one placeable), before building all four.

**Key risk: balance with one starting element (user priority).** All tuning so far assumed every element is available.
When implementation starts, give this focused attention as its own step, not a side effect:
- Check that a one-element start can capture the first town at a fair difficulty, with no unlocks at all.
- Check each element is viable alone, if the player may pick the starting element.
- Make sure unlocks feel like a real boost without becoming required, so a skipped side goal never makes a town
  unwinnable.
- Expect retuning of rescue speed, grey pressure and the night curve for the one-element case. Use the existing config
  values and F3 readouts, and add a playtest question on how the opening feels with one element.

**Open questions:** starting element (paint or player's pick); placeable stock and whether darkness erodes them; the
story tone and the bigger aim.

## Graphics checkpoint 5 playtest and follow-up plan (2026-11-04)

Played `dd9454e` once in the styled look, recorded (`20261104-173313`): a win, 2 of 3 dawn lights (41 rescued, 68%;
ground 14%; Garden at 61 s). Midnight had no gaps and no relapses (round 24: 32 and 12 midnight gaps): 6 gaps in all, all
in the first 15 s. Spare spirit made 50 gifts (2000 joy) to 7 people, with spirit at 100 through midnight. 0 wobbles,
1 burst (lifted nobody), 2 patches on strained spots. No gap blinks at the end. So little trouble meant little of the new
fight art was seen.

**What the user said:** the night felt pleasantly calm (keep it). The styled look is nicer but harder to read. The border
visuals were very distracting: the preview in general and the red striped preview in particular. The recorder's shots show
why: the limited preview hatches a red-and-white striped area over much of the screen whenever the cursor aims where the
zone can't grow, which is most of the time. The burst text also overlaps "Spirit 100/100" in every shot. More graphics
work next; fix the worst and keep the rest.

### Plan (one agent)

- **E: hold to aim, release to place,** in both looks. No preview while just moving the cursor. Holding E shows the zone
  preview, which follows the cursor; releasing E places the beacon; right-click while holding cancels with nothing spent.
  Update the how-to-play text and the prompt bar.
- **Quiet preview:** a thin outline only. When blocked, a thin coral outline and a small cross at the tip: no stripes, no
  hatching, in either look.
- **HUD overlap:** the burst line ("Joy burst [G]: READY - N dimmed ...") must not run into the spirit label, in either
  look.
- Refresh the checkpoint 5 reach shots. Spare spirit, the strain rings and the other effects stay as they are.

## Graphics checkpoint 5 follow-up build (2026-11-04)

One agent (`c74afdc`, merge `00f25df`). Gate (712 tests, 99.8%), determinism (0 lines differing) and baseline passed
through `tools/round_end.py`. The baseline first refused `border_centre.gd` (99.7% to 99.4%): the arm-cap guard for arms
that already use the whole loop had been reached only through the always-on preview. It now has its own test
(`8dd3f4e`). An earlier determinism pass showed 2 lines differing in `recorder.gd:521-522` (2 hits vs 1, under the
limit; likely the recorder's background save); the final pass had 0.

- **E:** holding E shows the zone preview, which follows the cursor; releasing E places the beacon, with the same refusals,
  notices and cost as before; right-click while holding cancels with nothing spent. With E up there is no preview (the
  "Stretching" travel still shows during a stretch). Both looks. The how-to-play panel went from 760 to 880 px wide to fit
  the longer Keys line.
- **Quiet preview:** outline only, no fill, in both looks (placeholder 0.2 m; limited 0.26 m coral, was 0.6 m). Limited
  is a thin coral outline and a small cross. The styled hatching, stripes and zone shader are gone. The normal preview keeps
  its small tip marker.
- **HUD:** the spirit label sits above its bar, and the burst line reads "READY - clears N dimmed", so they no longer
  overlap (tested at 1280x720 in both looks).
- **Tests changed:** preview tests now hold E first (`shaped_zone_test`, `reactions_test`, `shaping_tuning_test`,
  `looks_round20_pieces_test`, `looks_checkpoint5_test`); `gap_patch_test` checks the new burst text;
  `how_to_play_keys_test` knows right-click. New: `hold_e_test`, and a HUD overlap test. **Loosened:** nothing.

**Open:** the limited shot uses "inside the zone already", not a dimmed block. `checkpoint_shots` printed about 2000
"Too many instances using shader instance variables" lines on some styled runs; checkpoint 5 thought it had fixed this, so
it may still show in play and needs a look. Losing window focus while holding E may leave the preview showing until the
next E press.

## Checkpoint 5 follow-up playtest and snag round plan (2026-11-04)

Played `18a39a5` once in the styled look, recorded (`20261104-233132`, saved with its `godot.log` in
`recordings/playtests/cp5b/`): a win, 2 of 3 dawn lights (44 rescued, 73%; ground 17%; Garden at 39 s). 35 gaps (calm 6,
midnight 23, easing 6; the last styled game had 0 at midnight), no relapses, 2 wobbles both saved. 5 beacons, all reached
(zone 1729 sq m). 2 bursts (3 dimmed cleared), spare spirit made 38 gifts (1500 joy). First light ran from 135 s and
lifted 18 people.

**What the user said:** hold E to aim and release to place is good, keep it. The thin outline preview is quiet enough. The
busier midnight was exciting, keep it. They did not understand "the square that showed up": the first light front (a hard
square edge closing in from the plaza edge) has no on-screen explanation. Next: fix the open snags.

**Seen in the log and shots:** the game's log has 277 "Too many instances using shader instance variables" and 77
`instance_buffer_pos.has(p_instance)` errors, so the shader error happens in real play, not only in checkpoint runs. The
wobble edge pointer sits over the top-right HUD (targeting line and REC mark) when the wobble is up and to the right.

### Plan (three parts in parallel)

- **Part L, shader errors (Sonnet):** find which shaders use `instance uniform`, why the instance count overflows (and the
  `instance_buffer_pos` error, probably freeing or reusing instances), and fix the cause so a full styled game logs none.
  Raising the global shader buffer size is acceptable only alongside a reason it is the right size; add a test or a check
  that fails if the errors come back.
- **Part M, HUD snags (Haiku):** the wobble pointers keep clear of the HUD panels (top-right targeting/REC/landmarks,
  minimap, bottom bar), in both looks. Losing window focus while E is held cancels the aim (nothing spent). First light
  gets a short line when it starts ("First light: dawn is coming in from the edges", wording in the gloom terms), in both
  looks; its look otherwise stays.
- **Part N, context tooling (Sonnet):** `tools/source_map.py` writes `SOURCE_MAP.md` from the GDScript (per script: class,
  extends, signals, constants count, public functions with signature, line and the first comment line). The commit hook
  refuses a commit when the map is stale (like lint), with a one-line fix command. IDEAS.md gets a short "Current state"
  section at the top (mechanics, controls, open items, push status); resolved items and finished round history move to
  `IDEAS_RESOLVED.md`. CLAUDE.md, ARCHITECTURE.md and the brief-build-agent skill point agents to both.

## Snag round build (2026-11-05)

Three parts in parallel, merged in order N, M, L. Gate (all tests, coverage ratchet, timing), determinism and baseline
passed through `tools/round_end.py`. The first gate refused `wobble_alert.gd` (100% to 99.3%: the axis-aligned ray case of
the new pointer placement); it now has a test (`322abc5`).

- **Part L, shader errors (`86c9106`):** only `style_toon.gdshader` has instance uniforms (3), and each mesh using it
  reserves 16 vec4 of the global shader buffer, hidden or not. The default 65536 holds 4096 meshes; a styled level starts
  with 2803 and reaches about 4344 once each block has built its whimsical version, so the extra meshes got no slot (the
  277 errors) and the engine then logged its follow-on `instance_buffer_pos` errors (77). No leak (switching looks three
  times does not grow the count). `project.godot` now sets `buffer_size=262144` (16384 meshes, 4 MiB).
  `tests/shader_instances_test.gd` counts the worst case and fails if twice it would exceed capacity. The screenshot run
  went from 2078 errors to 0. The styled look is unchanged.
- **Part M, HUD snags (`762c28b`):** wobble pointer tips sit where the ray from the centre leaves a safe rectangle (the
  screen less the shown HUD panels, minimap and spirit cue), with the whole pointer inside it. Losing window focus while E
  is held cancels the aim with nothing spent. First light starts with a 4 s notice "First light: dawn is coming in from
  the edges", in both looks; its tint, band and motes are unchanged. Tests added in `wobble_alert_test`,
  `hold_e_test`, `first_light_test`.
- **Part N, context tooling (`45a2a48`):** `tools/source_map.py` writes `SOURCE_MAP.md` (every script's public functions
  with line numbers; tests listed with counts); the commit hook refuses a stale map. IDEAS.md went from 2068 to about 280
  lines with a Current state section on top; history and resolved items moved unchanged to `IDEAS_RESOLVED.md`. CLAUDE.md,
  ARCHITECTURE.md and the brief-build-agent and finish-round skills point to both.
- **Coordinator:** `tools/checkpoint/checkpoint_round24.gd` used the removed first light label; it now shows the notice
  (`ab2cef4`), and the unused `FIRST_LIGHT_TEXT_COLOUR` went.
- **Loosened:** nothing. Raising the shader buffer is a capacity setting with a test that guards it, not a test threshold.

## Snag round playtest and graphics checkpoint 6 plan (2026-11-07)

Played `c5e819b` once in the styled look, recorded (`20261107-055505`, saved with its `godot.log` in
`recordings/playtests/snag/`): a win, 2 of 3 dawn lights (40 rescued, 67%; ground 12%), much harder than the last game:
52 gaps (calm 6, midnight 29, easing 17), 17 wobbles (5 saved, 11 relapses), the Garden claimed at 48 s, lost at 133 s and
retaken at 171 s, 6 bursts, 1 patch, 3 beacons. First light ran from 135 s and lifted 20 people. **The game's log had 0
errors** (the last game had 354 shader instance errors), so the buffer fix holds in play.

**What the user said:** a good challenge, keep it. First light: make it a closing ring rather than a square. The styled
look looked fine apart from the coral edge triangles sitting over the landmarks panel and the key line. Next: more
graphics work. They like the overall style but there is too much dithering (keep a bit). Also: the player's jog barely
differs from the walk; the placeholder HUD text, target highlight and beacon marker in the styled look; and big centre
notices ("Someone lost their joy!") cover the play area.

### Plan: graphics checkpoint 6 (three parts in parallel)

- **Part O, first light ring (Sonnet):** the front is a circle closing on the border's centre (or the plaza centre if
  that is what the square used), starting where it covers the whole map and reaching the centre at dawn. "Passed" uses
  the round distance, so the lifting follows the ring. Both looks: the placeholder strips, the styled ground shader's
  `dawn_front`, `StyleFirstLight` motes, and the minimap. Same timing and lift rates; check the analyser's FIRST LIGHT
  numbers stay comparable.
- **Part P, styled HUD (Sonnet):** the coral edge triangles (and any other edge pointers) keep clear of the HUD panels,
  reusing `WobbleAlert.safe_rect`. Notices move off the play area: a slimmer banner under the Dusk to Dawn bar instead
  of the big centre panel, in both looks. The styled look gets its own target highlight, beacon marker and HUD text
  labels (rescued count, burst line, target line, targeting line, key line) in the existing styled UI language
  (`StyleUi`, parchment panels, pixel font), original art.
- **Part Q, dithering and jog (Haiku):** cut the styled dithering to roughly half its current strength (post shader,
  ground and glow stipple), keeping some texture. Make the player's run clearly different from the walk (faster stride,
  more lean and bob) in both looks.
- Afterwards the coordinator refreshes the checkpoint screenshots for the user.
