# PositiveFPS — Game Ideas

**What to build next is on the GitHub board** "Positive game dev" (https://github.com/users/skarfacegc/projects/3):
headlines, targets (milestones such as "0.4 Walls and gates"), status and size. This file holds the detail; a `#N` on a
headline is its issue. Finished history and resolved issues live in `IDEAS_RESOLVED.md` (one line per round or target
at its top, plus the map from old round numbers to versions). This file keeps the current state, the standing ideas and
the current targets' plans. To find code use `SOURCE_MAP.md`
(`python tools/source_map.py`); for where things live and how to brief an agent use `ARCHITECTURE.md`.

## Current state (as of 2026-11-13, 0.4 Walls and gates done and released as v0.4.0)

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
  One surge a night (pass 3, `gloom_tide.gd`): a 40 s warning from t=25 s (fog gathers at the far end of one street,
  a minimap mark, the light cools, banners), then 50 s rolling down that street, peaking at midnight: it pushes the
  gate it meets (1.5) and that gate's neighbours at half; then an aftermath where arrivals ease.
- **Zone and line (0.4 pass 2):** the zone is a set of held grid cells (`scripts/zone.gd`); the line is its outline.
  Along a held block's face it is a **wall** (firm, needs nobody); across a street mouth or a square's open side it is a
  **gate**, the only place the gloom can push. Members stand only on gates (about one per 6 m since Loop tuning,
  2026-11-13; shared out when short). Dimmed people walk the streets to the nearest gate. The push below now happens per gate.
- **Border (physical push):** only visible things push: dimmed people leaning on the line from outside, and the surge.
  The line bends inward where pushed (the loop dents; members brace and lean) and springs back when relieved. Past
  `PUSH_BREAK_DEPTH` (2.4 m of dent) it breaks: a gap made by pushing. Pushers walk through and drain people and erode
  painted land inside until the break mends (when no dimmed person is within 5 m and a member near it has had joy since
  it opened, or after 25 s clear; `PUSH_MEND_NEEDS_JOY`). Joy weakens pushers; joy at bending members or a burst (G or Q)
  calms the spot. A member drained too far wobbles about five seconds before relapsing; a joy hit saves them. Relapses are
  gated (`RELAPSE_GATE_GAP`). Model and open questions: "Round 26 build: physical push" in `IDEAS_RESOLVED.md`.
- **Thin line and lost cells (pass 3):** a gate breaks at `PUSH_BREAK_DEPTH` x lerp(0.5, 1, members / need) x its
  defence multiplier, so a short-handed gate breaks at as little as half the dent. A gate broken for 12 s
  (`GATE_LOST_SECONDS`) loses the cell behind it and any cell that loss cuts off (never the start square): the line
  re-traces, members regroup, that cell's pips reset, nobody relapses; banner "The gloom took a block." and a grey pulse.
- **Defences (pass 3, F):** hold F, point at a gate (within 5 m), release; right-click cancels; the wheel cycles types.
  One per gate, 4 in all, each staffed by the nearest free member, who leaves the line. Claiming a landmark unlocks its
  type for the night: Bandstand (gate 1.5x stronger), Garden (cannot break), Gallery (its cells cannot be lost), Bell
  tower (a free burst when the gate is bent past half, 20 s cooldown). A defence whose gate closes is handed back.
- **Spirit:** 0 to 100, start 50; +10 a rescue (was 20 until 2026-11-13). At 0 the player goes dim (half speed, no fire, border loses heart). Spare
  spirit at a full meter pools and warms the most strained border member (`spirit_warmth.gd`).
- **Spirit actions:** take a block with E (pass 2c: the only way the zone grows): hold E and point at a cell next to
  the zone to preview its new gates and the people they need against the people free, release to take it, right-click
  cancels. Rescue pips: each rescue fills a pip on its cell; at 3 (`TAKE_RESCUES`) the cell is ready and E takes it free,
  any other cell next to the zone costs 25 spirit (`TAKE_SPIRIT_COST`). Refused only when spirit is short; people never
  refuse a take (a short line is shared out thinly). Takeable cells glow on the ground and the minimap (gold free, blue
  paid; pass 3: free is a filled cell tagged "Free", paid an outline tagged "25", each with pips "2/3"); the
  preview reads "+5 gates: 18 more people" or "covered by spare people"; a HUD line under the spirit meter says
  "People: 31 on the line, 23 short" (or "6 spare"); a taken cell pulses and the slim banner says what it cost. G or Q (30, 8 s cooldown) bursts: lifts dimmed
  people nearby, pushes back those on the border line, lets the line near the burst spring back, and mends every
  break within reach, holding that gate calm for 16 s (the cue says "G: mend").
- **Gate cues (pass 2c):** each gate shows members/need, red when short; a pushed gate glows coral from 20% of
  `PUSH_BREAK_DEPTH`, and past 50% an off-screen gate gets an edge pointer (`gate_marks.gd`). Embrace is removed.
- **Town grid (0.4 pass 2, spread out in 2c):** 5 by 5 cells, 12 m streets; the start square is 18 m (its row and
  column are 18 m wide, so the blocks beside it are 18 x 12), other cells 12 m, plaza 114 m (`scripts/town_grid.gd`). The
  start square needs 12 members. The middle cell is the start square, the four diagonal cells next to it are landmark squares, the other 20 are solid built blocks (for the
  player too). Posts are gone (walls replace them).
- **Landmarks:** Bandstand, Garden, Bell Tower and Gallery, on the diagonal squares, about 27 m from the start (the Gallery is
  placed and claimable only, no boost, no styled art yet). Holding one (3 s inside the border) boosts joy; the third dawn
  light needs 75% rescued and 2 landmarks.
- **First light:** over the last 45 s a square front moves in from the map edge; people it passes lift and stop draining.
- **Cues:** the bending line is the warning (ribbon colour and width follow the bend; members lean and struggle). Gap
  arrows point at an off-screen break; wobble edge pointers, minimap blips, landmark pointers and a cue panel beside the
  spirit meter (glows when G can be used). Prompts, notices and events (claims, losses, lost joy) are one slim banner
  under the night bar, one at a time, events first. Clean HUD (2026-11-13): the controls strip shows for 20 s (H
  again), landmark pointers are an arrow and initial, gate counts show only when short and bent or while E/F is held,
  the targeting line is in F3, and no target or mood line.
  Strain markers, strain rings and the border warning are gone.

**Controls.** WASD move, Shift run, mouse to point, hold E / release E take a block (right-click cancels), G or Q
burst, hold F / release F plant a defence (wheel picks the type), F2 targeting mode, mouse wheel zoom, F3 debug, F4 switch look, hold H show controls, R restart, M menu. Menu: Play (Enter, 1, click), Look.

**Look modes.** Placeholder (default, plain shapes, what the tests run) and styled (pixel-diorama 3D: toon, outline, ground
and post shaders, in a 640x360 SubViewport). F4 or the menu switches mid-game. Gameplay rounds touch the placeholder only;
the styled look changes only in graphics checkpoints (latest: checkpoint 7: living ground, street props, ambient life,
gloom mist, styled push and HUD, no direction line, dithering removed from the styled look, and the look chosen by context:
`--look=styled|placeholder`, exported builds start styled). Still placeholder in styled mode: the REC and F3 labels, and
(per the checkpoint 7 shots) the push fog's `tide_fog` and `tide_pointer` pieces; the styled HUD text uses the fallback
font, not a pixel font (#26). 0.3.1 (done 2026-11-08) changed the push fog to a storm cloud band, raised the
mist and the ground life, props and ambient life for play zoom, and strung bunting from posts; `tide_fog` is no longer a
placeholder, `tide_pointer` still is.

**Open items** (listed 2026-11-11; each one's issue id is on the board):
- Gap arrows now sit at the edge of the safe band, so a gap straight north shows its arrow part way down the screen. (#24)
- The player's jog barely differs from the walk in the styled look. (#27)
- Sound cues: not designed yet; first wanted for the surge warning (from #81, 2026-11-12). (#25)
- Parked (2026-11-07): members pop out of a deep dent and start dimming again, recoverable with a quick joy hit, as a
  step before a break. Investigate after 0.4 Walls and gates's push and pull. (#22)
- The gold inner ring (#38) was not raised in any 0.3.1 playtest; it stays in Backlog.
- The Gallery has no styled art (it uses the bandstand model); its dent-fade protection and defence unlock were built in 0.4 pass 3 and are judged in 0.5. (#16)

**Watch in the next playtest** (no issue: questions for the interview, not work):
- Checkpoint 6's notice banner under the night bar and the styled target ring have no full-frame screenshot yet.
- First light lifts fewer people now the front is round (it reaches the plaza edge about 13 s in); watch the FIRST LIGHT
  numbers (20 lifted in the last game).
- Whether one burst per 8 s keeps pace with arrivals every 9 s (bursts were barely used in the last recordings).
- Dawn lights are easy (60% rescued plus one landmark was enough in earlier rounds; now 75% and 2); watch in the next
  recording whether the third light is earned.
- Difficulty is tuned only by bot nights (knobs `TIDE_PUSH` 2.0, `PUSH_PER_PERSON`, `PUSH_BREAK_DEPTH`).
- Pass 2 (walls and gates): does the town now tell you where to look and what to do next? Is 25 spirit or 3 rescues the
  right price for a block? Do solid blocks and 12 m streets feel roomy or cramped? From the tests: two dimmed people
  together break a gate in about 25 to 30 s; one alone never does.
- Pass 3: does a short-handed gate read as thin (people further apart) and does it now need you? Does losing a cell
  feel fair? Is the surge's warning seen wherever you are, and is one surge enough tension? Are defences worth a member
  each? After the capture polish: can you tell free from paid, pips, and people free against needed at a glance?

**Recorder:** breaks are logged as `break_open` / `break_close`; `analyse_recording.py` reads the old `gap_open` / `gap_close` names too and renames them.

**Next:** **0.4 Walls and gates is done** (the user called it on 2026-11-13 after a styled playtest of `3c94c08`),
released as `v0.4.0`. Its milestone is closed, and its plan and passes are in `IDEAS_RESOLVED.md`. Release builds
start styled and never record: an exported build hides the menu's recording check box and ignores `--record`. The rest
of Lighter tests (#69, moving rule checks to unit tests) went back to Backlog with no target. The next target is **0.5
Why expand** (sketch below; #15 and #16 are In review there).

**Resolved items** are listed in `IDEAS_RESOLVED.md` ("Resolved since they were last listed").

**Performance.** Crowd separation uses a spatial grid and a cached index: `CrowdMovement.update_people` 3.0 to 0.75 ms per
frame, identical results. `Border.update` is 1.5 ms at 28 members (slot assignment 0.8, polygon 0.36, buildings 0.15,
push 0.07); not changed, since the cheap fixes would not keep the results identical.

**Push status.** `main` was pushed to `origin` with the `v0.4.0` release on 2026-11-13. The releases are `pre-alpha`,
`pre-alpha-2`, `v0.3.2` and `v0.4.0`. Nothing is pushed until the user asks.

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
- Visual progression: the town goes from desaturated to full colour as it is rebuilt; the placeholder look is plain, a richer style comes in look-focused targets. (largely built in 0.3 Living town)
- From the 0.3.1 playtests: butterfly styling (#46); the push and storm need more impact and more room to play around, to discuss (#47).
- **Recorder replay** (#62, M): every 2 s, log the position and stage of every person and member (and the gates), and
  have a Python tool draw a top-down replay with a time slider and a heatmap of where people bunch or stick, as one
  HTML page. It would have proved the 0.3.3 snag ("logs no member positions, so the cause is unproven"). Keep the
  file small (rounded positions, short keys).
- **Rename to Mirthwood** (#89, S; chosen 2026-11-11): "PositiveFPS" no longer fits a top-down territory game.
  Mirthwood came out of a naming talk (Rekindle and its variants were taken many times on Steam and itch.io).
  **Before building, review the change with the user again**: confirm the name still feels right, run a fresh
  Steam / itch.io / domain check, and agree the scope (player-facing title, window and exe name, README and docs, or
  also the repo, folder and code identifiers).

Wider world and level progression ideas: see `VISION.md`.

## 0.5 Why expand (sketch; from the design talk, 2026-11-11)

0.4 stays on the mechanics (walls, gates, pressure); this is the content for the next target. The 0.4 pass 3
playtest showed the problem: expanding costs about 5 gates and 20 people a cell and gives little back (16% ground barely
moves the dawn rating, landmarks give a joy boost and a defence type), so a compact zone is the sensible play and no
defence was worth a member. Goal: ground worth holding. Not a plan yet; plan it before building.

- **Residents (#83, M):** each built block shows what it is before it is taken. A house lets its residents out when
  taken, as wistful people who are easy to rescue; rescued, they join the line, so expanding answers "People short"
  instead of causing it.
- **Shops (#84, S):** a held shop (cafe, workshop) gives a small spirit trickle. Points toward the rebuilt-building
  unlocks in VISION (#28, #29).
- **Landmark powers (#85, M):** each landmark gives a strong power for the rest of the night: Bandstand, music joy
  reaches further; Garden, lost cells slowly grow back; Bell tower, half the burst cooldown; Gallery, painted ground
  pays spirit.
- **Spirit sinks:** spirit is weak now (only takes at 25 and bursts at 30; the pass 3 game averaged 87.5 spirit), so a
  trickle needs something to buy: **block upgrades (#86, M)**, spend on a held block (a house gives more people, a shop
  more spirit); **stronger joy (#87, S)**, spend for a short boost (wider, faster joy).
- **Defences (#15, L) and landmark unlocks (#16, S), moved here from 0.4 on 2026-11-11:** built in 0.4 pass 3 and
  still In review. Nobody planted one because there was nothing worth defending, so they are judged again once ground
  is worth holding. Played 2026-11-12: 2 planted, but it was not clear whether a defence helped; it needs
  visible feedback that it made a difference. Decide in the 0.5 plan how the defence unlocks (#16) sit beside Landmark powers (#85).
- **Rule stepping (#18, L), moved here from 0.4 on 2026-11-11:** tooling, not content; 0.5 adds long-night balance
  tests, which is where it pays. Its first slice of Lighter tests (#69) was built in 0.4; the rest is in Backlog.
- **Not now:** pressure that punishes staying small (unheld blocks dimming their residents into pushers, or rising
  take costs). The user wants rewards alone tried first.

## Codebase cleanup (2026-11-11 review)

Found by two read-only reviews of tests, code, docs and token cost on 2026-11-11. Cleanup passes A and B, Slowest
tests (#88) and the checkpoint scripts (#74) were done in 0.4 (see `IDEAS_RESOLVED.md`).

Still Backlog, as filler beside playtests: the rest of Lighter tests (#69; its first slice of setup trims was built
in 0.4, and moving rule checks to unit tests is left), History out of code (#67), Unused constants (#68), and
Styled-look tier (#72, which needs the user's call on the coverage rule first).

### Cleanup: History out of code (#67, L)
707 comments carry `Round N:` or `Checkpoint N:` tags; 92 constant names have history prefixes (`C7_`, `L31_`, `L32_`,
`CP7_`); test files are named by round, not purpose (`checkpoint7_test`, `looks_round19_test`, `looks_round20_*`,
`hud_checkpoint6_test`, `looks_checkpoint5_test`, `style_props_032_test`); some comments still describe removed
concepts (arms, reach, beacon). Git history keeps the history. Rename by purpose, strip the tags, update
`SOURCE_MAP.md`, `ARCHITECTURE.md` and `tools/checkpoint` sets that name them. One Haiku pass, mechanical.

### Cleanup: Unused constants (#68, XS)
11 config constants are never used (`REACT_PATCH_*`, `GLUM_SLUMP_SCALE`, `TOWN_BLOCK_HEIGHT`, `CUE_PLAYER_RANGE`,
`CUE_ALPHA`, `WOBBLE_ALERT_BADGE`, `BORDER_LANDMARK_COLOUR`, `C7_LAMP_LEAN`, `L31_LAMP_HALO`) and 8 are used only by
tests. Remove the dead ones and add a check to `lint.py` or `source_map.py`.

### Cleanup: Lighter tests (#69, L)
65 of 89 suites boot the full level; tests simulate about 22,700 frames and the weighted tests add up to about 17 min
serial, the slowest 20-43 s each (`reactions_test` arms, `stagger_test` nine seconds apart, `world_scale_test` local
gap). Many check rules that already live in pure code (`BorderShape`, `Zone`, `TownGrid`, `DawnRating`, the night
clock). Test the rule as a unit test and keep one level test per feature; step the clock instead of playing 2000+
frames for timing rules. No threshold or perf budget is loosened. Sonnet.

### Cleanup: Styled-look tier (#72, M)
25 suites switch to the styled look, and many of their tests pin art details (for example a bandstand luminance above
0.5), so art tweaks break tests and the 100% line-coverage ratchet pushes coverage-only tests. Put styled-look tests in
their own tier, run in look-focused targets and the full gate, and decide (user's call) whether `scripts/looks/style_*`
keeps the 100% floor.

### Walls and gates: Rule stepping, advance the game rules without the scene (#18; moved to 0.5 Why expand 2026-11-11)

Tests are frame-bound: the 2400-frame border test sets the suite's floor. Let people, gloom and border advance on a
fixed time step without the scene running, so the long scenario tests stop waiting on real frames. Rules and visuals are already split for the looks; this does the same for the simulation.
