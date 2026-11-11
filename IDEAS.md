# PositiveFPS — Game Ideas

**What to build next is on the GitHub board** "Positive game dev" (https://github.com/users/skarfacegc/projects/3):
headlines, targets (milestones such as "0.4 Walls and gates"), status and size. This file holds the detail; a `#N` on a
headline is its issue. Finished history and resolved issues live in `IDEAS_RESOLVED.md` (one line per round or target
at its top, plus the map from old round numbers to versions). This file keeps the current state, the standing ideas and
the current targets' plans. To find code use `SOURCE_MAP.md`
(`python tools/source_map.py`); for where things live and how to brief an agent use `ARCHITECTURE.md`.

## Current state (as of 2026-11-09, after 0.4 pass 2 Grid and Line)

**What the game is.** A gentle top-down territory game in Godot 4.7 (GDScript, strict typing). Dimmed people slowly take
over a plaza; the player rescues them with joy, and the rescued form a living border that holds the gloom back and paints
the land inside. One night per level, dusk to dawn (about 3 minutes); reaching dawn wins and is rated 1 to 3 dawn lights.
Tone: warm and gentle, joy shared and never a cure. Player-facing text uses the gloom terms (wistful, gloomy, dimmed),
never "dark people". Art is original, technique-level inspiration only.

**Mechanics as they stand (0.4 pass 2: walls and gates on a town grid).**
- **Joy and elements:** music, art and nature (a soft cycle: matched 2x, strong 1.5x, weak 1x). Pointing at a person fires
  automatically; a person needs enough joy to be rescued (grace, then the border). Moods: guarded (front-only joy),
  skittish (flees), glum (x3 when looking up), sheltered (umbrella shield, four hits).
- **Gloom:** unrescued people go wistful, gloomy, then dimmed. Dimmed people lean on the border and reach for the player.
  The night has phases: calm opening, rising, midnight (hardest, dimmed sinks staggered by `DIM_ARRIVAL_MIN_GAP`), easing.
  Two gloom tides a night (rising, midnight) are a visible wave of fog with figures that rolls in and shoves its side.
- **Zone and line (0.4 pass 2):** the zone is a set of held grid cells (`scripts/zone.gd`); the line is its outline.
  Along a held block's face it is a **wall** (firm, needs nobody); across a street mouth or a square's open side it is a
  **gate**, the only place the gloom can push. Members stand only on gates (about one per 3.7 m, shared out when
  short). Dimmed people walk the streets to the nearest gate. The push below now happens per gate.
- **Border (physical push):** only visible things push: dimmed people leaning on the line from outside, and a tide's wave.
  The line bends inward where pushed (the loop dents; members brace and lean) and springs back when relieved. Past
  `PUSH_BREAK_DEPTH` (2.4 m of dent) it breaks: a gap made by pushing. Pushers walk through and drain people and erode
  painted land inside until the break mends (when no dimmed person is within 5 m and a member near it has had joy since
  it opened, or after 25 s clear; `PUSH_MEND_NEEDS_JOY`). Joy weakens pushers; joy at bending members or a burst (G or Q)
  calms the spot. A member drained too far wobbles about five seconds before relapsing; a joy hit saves them. Relapses are
  gated (`RELAPSE_GATE_GAP`). Model and open questions: "Round 26 build" below.
- **Spirit:** 0 to 100, start 50; +20 a rescue. At 0 the player goes dim (half speed, no fire, border loses heart). Spare
  spirit at a full meter pools and warms the most strained border member (`spirit_warmth.gd`).
- **Spirit actions:** take a block (25, `TAKE_SPIRIT_COST`): hold E and point at a cell next to the zone to preview its
  new gates, release to take it, right-click cancels; refused when spirit or people are short. Rescue pips: each rescue
  fills a pip on its cell, and at 3 (`TAKE_RESCUES`) a cell next to the zone joins by itself. G or Q (30, 8 s cooldown) bursts: lifts dimmed people nearby, pushes
  back those on the border line and lets the line near the burst spring back. There is no patch action any more.
- **Town grid (0.4 pass 2):** 5 by 5 cells of 12 m with 10 m streets (`scripts/town_grid.gd`). The middle cell is the
  start square, the four diagonal cells next to it are landmark squares, the other 20 are solid built blocks (for the
  player too). Posts are gone (walls replace them).
- **Landmarks:** Bandstand, Garden, Bell Tower and Gallery, one at each street end, 26 to 32 m from the start (the Gallery is
  placed and claimable only, no boost, no styled art yet). Holding one (3 s inside the border) boosts joy; the third dawn
  light needs 75% rescued and 2 landmarks.
- **First light:** over the last 45 s a square front moves in from the map edge; people it passes lift and stop draining.
- **Cues:** the bending line is the warning (ribbon colour and width follow the bend; members lean and struggle). Gap
  arrows point at an off-screen break; wobble edge pointers, minimap blips, landmark pointers and a cue panel beside the
  spirit meter (glows when G can be used). Prompts and notices are one slim banner under the night bar, one at a time.
  Strain markers, strain rings and the border warning are gone.

**Controls.** WASD move, Shift run, mouse to point, hold E / release E take a block (right-click cancels), G or Q
burst, F2 targeting mode, mouse wheel zoom, F3 debug, F4 switch look, R restart, M menu. Menu: Play (Enter, 1, click), Look.

**Look modes.** Placeholder (default, plain shapes, what the tests run) and styled (pixel-diorama 3D: toon, outline, ground
and post shaders, in a 640x360 SubViewport). F4 or the menu switches mid-game. Gameplay rounds touch the placeholder only;
the styled look changes only in graphics checkpoints (latest: checkpoint 7: living ground, street props, ambient life,
gloom mist, styled push and HUD, no direction line, dithering removed from the styled look, and the look chosen by context:
`--look=styled|placeholder`, exported builds start styled). Still placeholder in styled mode: the REC and F3 labels, and
(per the checkpoint 7 shots) the push fog's `tide_fog` and `tide_pointer` pieces; the styled HUD text uses the fallback
font, not a pixel font (#26). 0.3.1 (done 2026-11-08) changed the push fog to a storm cloud band, raised the
mist and the ground life, props and ambient life for play zoom, and strung bunting from posts; `tide_fog` is no longer a
placeholder, `tide_pointer` still is.

**Open items** (each checked against the code on 2026-11-07):
- Gap arrows now sit at the edge of the safe band, so a gap straight north shows its arrow part way down the screen. (#24)
- The player's jog barely differs from the walk in the styled look. (#27)
- Sound cues: not designed yet. (#25)
- The town is dense for how it plays and the game does not flow yet. Decided 2026-11-09: the town becomes a grid the
  line follows (walls and gates, block by block); see the 0.4 plan. (#55, #56)
- Parked (2026-11-07): members pop out of a deep dent and start dimming again, recoverable with a quick joy hit, as a
  step before a break. Investigate after 0.4 Walls and gates's push and pull. (#22)
- The gold inner ring (#38) was not raised in any 0.3.1 playtest; it stays in Backlog.
- The Gallery has no styled art (it uses the bandstand model); its dent-fade protection and defence unlock are in 0.4. (#16)

**Watch in the next playtest** (no issue: questions for the interview, not work):
- Checkpoint 6's notice banner under the night bar and the styled target ring have no full-frame screenshot yet.
- First light lifts fewer people now the front is round (it reaches the plaza edge about 13 s in); watch the FIRST LIGHT
  numbers (20 lifted in the last game).
- Whether one burst per 8 s keeps pace with arrivals every 9 s (bursts were barely used in the last recordings).
- Dawn lights are easy (60% rescued plus one landmark was enough in earlier rounds; now 75% and 2); watch in the next
  recording whether the third light is earned.
- Difficulty is tuned only by bot nights (knobs `TIDE_PUSH` 2.0, `PUSH_PER_PERSON`, `PUSH_BREAK_DEPTH`).
- Whether Embrace gets noticed (it did not in the round 25 playtests).
- Pass 2 (walls and gates): does the town now tell you where to look and what to do next? Is 25 spirit or 3 rescues the
  right price for a block? Do solid blocks and 10 m streets feel roomy or cramped? From the tests: two dimmed people
  together break a gate in about 25 to 30 s; one alone never does.
- Auto-join by pips ignores whether there are people for the new gates (the plan said it should check); "enough
  people" for E counts all rescued, since members are capped at the slot count. Thin lines are #12 in pass 3.

**Recorder:** breaks are logged as `break_open` / `break_close` (#23); the analyser still reads the old `gap_*` names.

**Next:** 0.3.3 Town layout is done (2026-11-09, internal, no release; history in `IDEAS_RESOLVED.md`). Current target:
**0.4 Walls and gates**, passes 1 Reorg and 2 Grid and Line built (In review); pass 2 needs a playtest, then pass 3 (plan below, and on the board; reshaped 2026-11-09 as walls and gates on a town grid and renamed from "Tug of war"). 0.3.2 Prop styling was released as `v0.3.2` (2026-11-09).

**Resolved items** are listed in `IDEAS_RESOLVED.md` ("Resolved since they were last listed").

**Performance.** Crowd separation uses a spatial grid and a cached index: `CrowdMovement.update_people` 3.0 to 0.75 ms per
frame, identical results. `Border.update` is 1.5 ms at 28 members (slot assignment 0.8, polygon 0.36, buildings 0.15,
push 0.07); not changed, since the cheap fixes would not keep the results identical.

**Push status.** `origin/main` is `fc2a37c` (0.3 Living town and the board docs, pushed 2026-11-07); local `main` is
ahead by the 0.3.1 to 0.3.3 commits (not pushed). The last release is
`pre-alpha-2` (`da0dfb2`, round 26); 0.3 is internal, not released. Nothing is pushed until the user asks.

**Pointers.** `README.md` (player docs), `ARCHITECTURE.md` (script map, tools, gotchas, areas and files per system),
`SOURCE_MAP.md` (every script's public functions with line numbers, generated), `IDEAS_RESOLVED.md` (history),
`tools/COVERAGE_TOOL_NOTES.md`, `.claude/skills/` (brief-build-agent, finish-target, launch-playtest), `tools/board.py` (the board). Latest recordings
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

## Open ideas (unscheduled)
- Extra elements: food/cooking and play/sport (five elements also make a clean cycle); new elements could unlock via rebuilt buildings (bakery, playground) with new people of that affinity. (#28)
- Building to unlock mapping (music shop: guitar upgrades, garden centre: flower variants, cafe: healing item). (#29)
- Enemy tiers and bosses: light routine people as the bulk, grey normal, dark spreaders rarer and tougher; bosses such as a heavily gloomed figure with a big aura, in a dedicated later target. (#30)
- Visual progression: the town goes from desaturated to full colour as it is rebuilt; the placeholder look is plain, a richer style comes in look-focused targets. (#2, largely built in 0.3 Living town)
- From the 0.3.1 playtests: butterfly styling (#46); the push and storm need more impact and more room to play around, to discuss (#47).
- **Recorder replay** (#62, M): every 2 s, log the position and stage of every person and member (and the gates), and
  have a Python tool draw a top-down replay with a time slider and a heatmap of where people bunch or stick, as one
  HTML page. It would have proved the 0.3.3 snag ("logs no member positions, so the cause is unproven"). Keep the
  file small (rounded positions, short keys).

Wider world and level progression ideas: see `VISION.md`.

## 0.4 Walls and gates plan (2026-11-07; called "Tug of war" until 2026-11-09)

Planned as rounds 27 and 28 before the switch to targets. **Order** (confirmed by the user, 2026-11-09: code health
first, then the gameplay changes):
- **Pass 1, Reorg** (#3, #4): the code-health items. No gameplay change, so no playtest: the gate, the determinism
  check and the timings are the proof. (Quick wins were done in 0.3.3.)
- **Pass 2, Grid and Line** and **pass 3, Pressure and Defences:** Walls and gates on the reorganised layout (reshaped
  2026-11-09: the town becomes a grid and the line follows it).
- **Rule stepping** (#18) if there is room.

### Walls and gates: Reorg, code reorganisation (#3, #4)

**Pass 1 of 0.4.** One Sonnet agent; #4 builds on #3's files, so they are not split.

**Scope note (2026-11-09).** Pass 2 removes the round loop, the beacon, its arms and the reach guide, and posts. Reorg
moves their constants and set-up as they are, into files of their own (for example a beacon config and a round-loop
config), and spends no effort tidying them, so pass 2 can delete whole files.

**Why.** Of the last 150 commits, `config.gd` changed in 63 and `topdown_main.gd` in 54: almost every change, and most
merge conflicts between parallel parts, go through these two files. The tuning values are filed by round
("Round 25:", "Round 26:") across `config.gd` (599 lines) and `config_base.gd` (744 lines, about 680 constants in all),
so an agent tuning one system searches both.

**Changes** (one Sonnet worktree agent, no behaviour change):
1. **Config by system, not by round** (#3). Split `Config`/`ConfigBase` into one small config script per system (for example
   border, push, tide and night, people, projectiles, spirit, landmarks, HUD and cues, recorder), and update every
   reference. The round history stays in git and IDEAS_RESOLVED.md. Walls and gates then adds its values to
   its own systems' files.
2. **`topdown_main.gd` coordinates only** (#4). Move each system's set-up and per-frame work into that system's script, so
   `TopDownMain` builds the systems and calls them in order. New features should no longer need an edit there.
3. **Proof of no change:** the full gate and the determinism check give the same tests and lines hit as before;
   `coverage_baseline.json` gets the new file paths (never a lower total). Regenerate SOURCE_MAP.md and update
   ARCHITECTURE.md (script map, areas, tuning).

**Built (2026-11-09, merged `ffe5e44`; In review, no playtest).** `config_base.gd` is gone: the 783 constants are in
18 per-system scripts (`scripts/*_config.gd`, listed in ARCHITECTURE.md "Tuning"); `beacon_config.gd` and
`round_loop_config.gd` hold what pass 2 deletes. `config.gd` keeps the shared core and helpers. `topdown_main.gd` is
about 230 lines (was 860) and builds and calls ten new system scripts (`plaza`, `camera_rig`, `target_highlight`,
`level_hud`, `level_events`, `level_end`, `dim_gate`, `cover_update`, `dim_recovery`, `look_switch`). After the merge:
gate `--full` 875 tests in 279 s, determinism same 11178 lines, baseline total unchanged. Nothing loosened.

**Not in Reorg:** sub-folders for `scripts/` (border/, gloom/, people/, hud/, fx/). Coverage, the baseline and the
fast tier's map are keyed by file path, so it needs a remap tool first; low value for the risk.

### Walls and gates: Grid, Line and Defences (Grid #55, Line #56 and #10 to #14, Defences #15 and #16)

**Reshaped on 2026-11-09** after the 0.3.3 styled playtest and a design talk about #55. The 2026-11-07 version of this
section (free-form grab and pull on the round loop) is in git at `ea6432a`. Its interview decisions still stand and are
listed below; what changed is how each one is built.

**Discussion (2026-11-09).** The town layout is liked, but the game "feels cramped and doesn't flow" and "is not fun
yet". The user's answers: things were visually dense even before the layout, and it is hard to parse what is happening
and what a decision changed, apart from rescuing someone; there is no clear next goal and it is the same thing all
night; things get in the way. Wanted from the boundary: shape it, fortify it, fight at it, and use the town. On the
town's role the user liked both "anchors and gates" and "block by block" and asked for a hybrid.

**Diagnosis.** Mostly gameplay and readability, partly layout. The border is one round loop (about 180 m long by the
end of the last game) measured from a moving centre, and any metre of it can matter, so there is nowhere obvious to
look and nothing obvious to do next. The town only gets in the way: blocks are 4 m obstacles the loop wraps around.
Thinning the town would not fix that. The town has to give the line its shape.

**The model: walls and gates, block by block.**
- **The town is a grid of cells** with streets between them. A cell is a built block (houses, solid), or an open
  square (the start square in the middle and the four landmark squares).
- **The zone is the set of cells you hold**, plus the street pieces between two held cells. It starts as the start
  square once the first few people are rescued.
- **The line is the zone's outline.** Where it runs along the face of a held built block it is a **wall**: it holds
  firm, cannot dent and needs nobody. Where it crosses a street mouth, or runs along the open side of a held square, it
  is a **gate**: rescued people stand across it, and it is the only place the gloom can push.
- **Growth is block by block.** A cell next to the zone can be taken; it lights up and the line jumps to its far side.
- **The trade-off.** Taking a built block adds wall and usually two street mouths. Taking a square adds open sides,
  which cost more people. A cell the zone surrounds joins by itself, which closes gates. More gates than people to
  hold them is a thin line.
- **Loss is block by block too.** A gate left broken long enough loses the cell behind it.

**Decisions that stand (interview, 2026-11-07).** E shapes the line and costs spirit per use; rescues pull the line;
the beacon is replaced (its arms, preview and 50 spirit cost go); defences cost rescued people as staff, go on F, hold
the line and do not extend it; landmarks unlock defence types and none is available until the first capture; the night
gets one long telegraphed surge in place of the two tides.

**Why rebuild the line, not bend the round loop to fit** (code check, 2026-11-09). `border.gd` keeps a radius at 48
angles round a centre that drifts with the rescued (`_organic_polygon`), and `border_push.gd` keeps its dent at the
same 48 angles. That loop can only be star-shaped from its centre, a 10 m gate would be two or three samples wide, and
its upkeep (the size ease, the wrap round blocks, the map-edge seals, the arms and the pull-in in `border_centre.gd`)
is where the zone-control snags came from (#53). A zone made of cells needs none of that: the outline is traced
exactly, and each edge already knows whether it is a wall or a gate. About 2,600 lines across the five `border*.gd`
scripts are affected; 16 other scripts read the border, mostly its `polygon`, `members` and `push`, and that surface
is kept so they change little.

**Changes** (values marked "default" are the coordinator's calls; the playtest can overrule them).
1. **Town grid** (#55). Replaces the two-street plan of 0.3.3 on the same 100 m plaza.
   - Default: 5 by 5 cells, 12 m cells and 10 m streets. The middle cell is the start square; four cells are landmark
     squares; the other 20 are built blocks, each a tight group of houses filling its cell.
   - Default: the landmark squares are the four diagonal cells next to the start square (about 31 m away, as now).
   - Built blocks are solid for everyone, so the player, the people and the gloom all move on streets and squares.
     Streets stay clear down the middle: lamps, benches and planters stand against the block faces.
   - Unrescued people stand on the streets and squares; each belongs to the nearest cell.
   - The grid has loops everywhere, so no more out and back through the middle.
   - A new `scripts/town_grid.gd` holds the plan (cells, kinds, rectangles, neighbours, street pieces);
     `TownLayout` and `TopDownMain.BLOCK_POSITIONS` read from it.
2. **The line follows the grid** (#56). The zone is a set of held cells; the line is its outline, split into wall edges
   and gate edges.
   - Members stand only on gates, spread across each one at `BORDER_TARGET_SPACING`; everyone else stands inside.
   - The round 26 push is kept but lives on gates: dimmed people lean on a gate, it bends inward, it breaks past
     `PUSH_BREAK_DEPTH`, and it mends by the same rules. Joy at bending members and the burst calm a gate as now.
   - Dimmed people head for the nearest gate along the streets.
   - Gone: the round loop and its drifting centre, the size ease, the wrap round blocks, the map-edge seals, posts and
     post worth (#54: walls replace them), and with (3) the beacon, its arms and the reach guide.
   - Kept for the scripts that read the border: `polygon` (now the traced outline, with extra points across each gate
     so a dent shows), `members`, `segment_gap`, `cover_at`, `line_blocks`, `clip_move` and `push.dent` per point.
3. **Take a block (E), replacing the beacon** (#10). Hold E and point at a cell next to the zone: a preview shows the
   new line, the gates it opens and closes, and whether you have the people for it. Release to take it, paying
   `TAKE_SPIRIT_COST` (default 25); right-click cancels. Refused, with the slim banner, when spirit is short or the new
   gates need more members than you have.
4. **Rescues pull the line** (#11). Each cell next to the zone shows pips. Rescuing someone who belongs to it fills a
   pip; at `TAKE_RESCUES` (default 3) the cell joins without E, if you have the people for its gates. Where you rescue
   is where you grow.
5. **A stretched line is thin** (#12). Each gate needs members for its width (a 10 m street mouth about 3, an open
   square side about 4). When the zone has fewer members than its gates need, the gates share them and a short-handed
   gate dents and breaks sooner (`THIN_LINE_*`). It must read in the placeholder look as people standing further
   apart, not as a meter.
6. **Land follows the line** (#13). A gate broken for `GATE_LOST_SECONDS` (default 12) loses the cell behind it: the
   cell goes grey, the line jumps back and its members regroup. Nobody relapses just because a cell is lost. The start
   square is never lost this way.
7. **One long telegraphed surge** (#14), replacing the two tides. Warning (default about 40 s): a fog bank gathers at
   the far end of one street, shown on screen and on the minimap, and the light cools. Surge (default about 50 s): it
   rolls down that street and pushes the gate it meets, and at half strength the gates either side. Aftermath: the fog
   thins and arrivals ease. The warning must reach the player wherever they are (in 0.3.1 neither tide was seen).
8. **Defences (F), planted at gates** (#15). Hold F and point at a gate, release to plant; one per gate, `DEFENCE_MAX`
   4 in all. The nearest free member staffs it. One type per landmark:
   - Bandstand (music): pushers at this gate are weakened.
   - Garden (nature): this gate bends but cannot break.
   - Gallery (art): the cells either side of this gate cannot be lost.
   - Bell tower: when this gate is pressed hard the bell rings and calms it (a small free burst, with a cooldown).
   A defence whose gate closes (its street is now inside the zone) is handed back and its staff rejoin the line.
9. **Landmarks unlock defences** (#16). A landmark is claimed by holding its square for 3 s, as now, and unlocks its
   defence type for the rest of the night. The third dawn light still needs 75% rescued and 2 landmarks.

**Pass 2 built (2026-11-09; merged `5fc6d93` Grid and Line, then Take a block; In review).** Sonnet built the grid,
the zone and the gate line (#55, #56) and removed the round loop, posts, the beacon and its reach guide (14 test files,
about 107 tests, removed with them; 7 rewritten; `zone_test`, `border_gates_test` new). Haiku built take a block and
rescue pips (#10, #11; `take_block.gd`, `rescue_pips.gd`, `take_block_test`). After the merge: gate 793 tests in 191 s,
determinism passed, baseline updated. Nothing loosened. Not done: there is no bot-night tool, so no tuning by bot
nights; the checkpoint screenshot scripts still reference removed border internals (#57).

**Pass 2b, Styled grid (#58, #57; 2026-11-10).** At the start of the pass 2 playtest the user asked to see the grid
styled before judging it. A look-focused pass, so the styled look and checkpoint shots may change. One Sonnet agent:
fix the checkpoint screenshot scripts (#57); style the grid town's built blocks (tight groups of houses filling each
cell, in the existing pixel-diorama style), walls versus gates on the line, the take-a-block preview and the rescue
pips, and the minimap; new checkpoint shots of the grid. Original art only. The placeholder look and the rules do not
change. Then the playtest restarts styled.
**Built (2026-11-10, merged `9e17e9b`, `6cb4600`; In review).** #57: `checkpoint_shots.gd` runs again (forced-gap and
sealed-edge shots dropped; the round 19/20/24 and checkpoint 7 sets parse but still build the old ring scenario). #58:
built cells are five small houses each (`style_houses.gd`); walls are a hedge with small lamps (`style_hedge.gd`), the
ribbon now marks gates only and sits above the mist (it was hidden under it); leaf-green walls on the minimap; styled take
preview and rescue pips (`style_take.gd`). Shots: `design/renders/v0.4-grid/` (`checkpoint_shots.py --set grid`). An
unused kiosk option was removed from `style_buildings.gd`. Gate 801 tests, determinism passed, baseline updated, nothing
loosened. Left: the take preview's glow plane is faint.

**Pass 2 playtest (2026-11-11; placeholder `20261110-064011` on 29c24da, styled `20261111-082446` on 2dc55ac).** Both
nights won with 3 dawn lights (58 and 53 rescued, 3 landmarks each). Breaks: 0 and 2 (both at midnight). Spirit sat at
100 most of both nights (means 98 and 94), so 25 spirit per block cost nothing. The zone grew to 6 and 8 of 25 cells,
mostly by rescue pips. The recorder does not log takes yet (cells and gates are in the samples).
- **Readability: partly.** The people needed to extend were unintuitive; the grid grew by itself as well as on E and it
  was hard to tell which did what ("not bad, just hard to parse"); hard to see which gate is in trouble and why the line
  changed.
- **E barely used**: pips did the growing. The user wants E to matter more.
- **Space:** the start square is very cramped; overall decent, spread out a little.
- **Styled grid (#58): works**, accepted.

**Pass 2c, Grid fixes (#55, #56, #10, #11; planned 2026-11-11).** One Sonnet agent. Builds after Recorder catch-up
(#59 to #61, below): remove the recorder's `auto_join` emit with auto-join, set `take`'s `free` for a pip-ready take.
1. **E only, pips show readiness** (#10, #11). Cells never join by themselves. Rescues still fill a cell's pips; a cell
   with full pips (`TAKE_RESCUES` 3) is ready, and taking it with E is free; any other cell next to the zone costs
   `TAKE_SPIRIT_COST` (25). Every change to the line is one the player made.
2. **People count on the gate and the preview** (#10, #56). Each gate shows its members against its need (for example
   "3/4"), red when short; the take preview shows the people the new gates need against the free people you have. Must
   read in both looks.
3. **Which gate is in trouble** (#56). A gate being pushed reads from across the screen (its line pulses or shifts colour
   with the dent), and one past half `PUSH_BREAK_DEPTH` gets an edge pointer when off screen (extend the gap arrows).
4. **Why the line changed** (#56). A short pulse on a cell when it is taken (and later when lost), with the slim banner.
5. **Spread out a little** (#55). Start square 18 m (other cells 12 m), streets 12 m. Grow the plaza to fit and keep the
   landmark squares on the diagonals; check spawns and first light still reach the town.
Playtest questions: is E now the way you grow, and is the price a choice? Does the count make the people cost clear?
Can you see which gate is in trouble?

**What stays as it is.** Joy, elements and moods; the gloom's phases and arrivals; the burst; spirit and spirit warmth;
wobble and relapse; first light; the dawn rating; the cue panel and the slim banner; both looks.

**Passes.** Pass 1 is Reorg (#3, #4), above. Then:
- **Pass 2, Grid and Line** (#55, #56, #10, #11): the smallest playable version of the idea. One Sonnet agent, since
  the grid and the line depend on each other. The two tides keep running, aimed at gates, until pass 3.
  Playtest question: does the town now tell you where to look and what to do next?
- **Pass 3, Pressure and Defences** (#12, #13, #14, #15, #16): two Sonnet worktree agents, **Pressure** (thin line,
  lost cells, the surge) and **Defences** (defences and unlocks, against a small per-gate interface: a strength
  multiplier, a "cannot break" flag and a "cannot be lost" flag). The coordinator merges Pressure first.
- Tune passes 2 and 3 with bot nights so a compact zone holds and an over-reached one loses cells.

**Constraints.** Placeholder look only: the styled look keeps working where it can (blocks, ribbon, minimap), and the
styled grid town is a later look-focused target. Border tests written for the round loop, the beacon and posts are
rewritten for the grid or removed; list every one in the report. Never loosen a threshold or a `test_perf_*` budget.
Rules change, so run the determinism check at the end of each pass. Player-facing text uses the gloom terms. README.md
is updated, since the controls change (E take a block, F defence).

**Playtest questions.** Do walls and gates make the line easy to read at a glance? Is the next block a clear goal, and
is taking it a real decision? Do solid blocks and 10 m streets feel roomy or cramped? Is 25 spirit, or three rescues,
the right price for a block? Does a thin line read as thin without a meter? Is one surge enough tension for the night?

**Open for the user** (defaults above are used unless overruled).
- Built blocks solid for the player too, or only for the gloom? Solid is simpler and makes the streets matter;
  walk-through keeps more room to move.
- 25 cells with 20 built blocks, or a smaller 3 by 3 town with wider cells?
- This also answers #47 (more room to play around the push): the gates are that room. Close #47 once pass 2 is played?

### Walls and gates: Recorder catch-up (#59, #60, #61)

**Planned 2026-11-11; builds before Pass 2c Grid fixes** (user's call, 2026-11-11), on today's rules: auto-join is
still logged (`auto_join`) and `take` carries a `free` field that is false until 2c. **2c's agent** removes the
`auto_join` emit with auto-join, sets `free` for a pip-ready take, and keeps the other recorder events firing. The recorder (round 18) has turned impressions into numbers
(round 18's "flat" game, the twirl's removal, `--compare`), but it has not followed 0.4: the per-second sample has
only totals (cells, gates, wall and gate length), there are no events for takes, pips or a single gate, and
the analyser still prints sections for removed mechanics. 2c's playtest questions (is E the way you grow, is the price
a choice, which gate is in trouble) need these numbers, so this pass goes **before the 2c playtest**.

**One Haiku agent** (tooling, three small items in the same two files; not split). Files: `scripts/recorder.gd`,
`scripts/recorder_config.gd`, `scripts/controls.gd` (the key), the emitting call sites, `tools/analyse_recording.py`,
the recorder tests. The recorder still only listens: no game state changes, no random numbers, no per-frame file I/O.

- **0.4 events and analyser (#59, S).** New events, each with the cell, gate count before and after, spirit and
  rescued count where they apply:
  - `take` (by E, with `free` true when the cell's pips were full, the spirit paid, and the people the new gates need
    against the free people) and `take_refused` with the reason (spirit short, people short, not next to the zone,
    cancelled);
  - `pip` (a rescue fills a pip: cell, pips now), `cell_ready` (a cell's pips just filled) and `auto_join` (the cell,
    gates it adds, members available; gone after 2c), so the analyser can show how long a ready cell waited before it
    was taken, and how the zone grew before 2c;
  - per gate: `gate_break` (gate id, seconds under push, pushers) and `gate_hold` (a push that ended without a break).
  - Sample gains `pips_total`, `ready_cells` and `members_short` (gate slots with nobody on them).
  - Analyser: a **BLOCKS** section (takes free vs paid, refusals by reason, spirit at each take, time between
    takes, ready cells and how long they waited, auto-joins, takes and auto-joins with too few people) and a **GATES** section (breaks and holds, seconds to break, pushers per
    break, breaks per minute by phase). Remove the dead SHAPED ZONE section (stretches, grows, shrinks) and anything
    else that reads events no longer emitted; keep old recordings readable (missing events = empty section).
  - `--compare` gets columns for takes (free / paid), refusals, ready-cell wait and gate breaks.
- **Mark this moment (#60, XS).** A key (default **F8**; F2 to F4 are taken, F is kept for defences) logs a `mark`
  event and takes a screenshot at once; the HUD flashes "Marked" briefly next to REC, only while recording. The
  analyser lists marks with the time, phase, and what happened 10 s either side (events by type). Not in the
  player's controls list; the how-to-play text mentions it only under the Record option.
- **Screenshots on key events (#61, XS).** Besides the 18 s timer, take a shot on the first break of each phase, each
  take, a mark, player dim, and the end of the game; at most one per 3 s
  (`RECORD_EVENT_SHOT_MIN_GAP`). The shot's file name carries the event type; the `screenshot` event names its cause.
  The analyser prints the shot file beside each listed event.

**Gate.** Recorder and analyser tests (`tools/run_tests.py` for the recorder suites) and lint, then the full gate via
`python tools/round_end.py`. The recorder touches no rules, but it is in the determinism list, so run the determinism
check. Coverage must not drop. Then the 2c playtest runs with this recorder.

**Built (2026-11-11, `3d75d85`; In review).** One Haiku agent. Events `take` (`free` false until 2c), `take_refused`,
`pip`, `cell_ready`, `auto_join`, `gate_break`, `gate_hold`, `mark`; the sample gains `pips_total`, `ready_cells` and
`members_short`; signals were added only in `take_block.gd` and `rescue_pips.gd`. F8 marks a moment (shot at once,
"Marked" beside REC). Shots on events, at most one per 3 s (marks always). The analyser has BLOCKS, GATES and MARKS
sections and new `--compare` columns; it dropped SHAPED ZONE, SPIRIT BEACONS and PATCH EFFECT (events no longer sent).
Gate, determinism and baseline passed; nothing loosened. Limits: `pushers` on gate events is the border-wide count, not
per gate; the break shot follows `break_open`, not `gate_break`; a take aimed at no cell is logged as `not_next`.

**Open for the user.** F8 for the mark key (or another)? Should a mark also ask for a one-word note? (Default: no,
the interview fills it in.)

### Walls and gates: Rule stepping, advance the game rules without the scene (#18; after Line and Defences merge, or the next target)

Tests are frame-bound: the 2400-frame border test sets the suite's floor. Let people, gloom and border advance on a
fixed time step without the scene running, so the long scenario tests stop waiting on real frames. Rules and visuals are already split for the looks; this does the same for the simulation.
