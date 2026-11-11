# PositiveFPS — Game Ideas

**What to build next is on the GitHub board** "Positive game dev" (https://github.com/users/skarfacegc/projects/3):
headlines, targets (milestones such as "0.4 Walls and gates"), status and size. This file holds the detail; a `#N` on a
headline is its issue. Finished history and resolved issues live in `IDEAS_RESOLVED.md` (one line per round or target
at its top, plus the map from old round numbers to versions). This file keeps the current state, the standing ideas and
the current targets' plans. To find code use `SOURCE_MAP.md`
(`python tools/source_map.py`); for where things live and how to brief an agent use `ARCHITECTURE.md`.

## Current state (as of 2026-11-11, after 0.4 pass 3 Pressure and Defences)

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
  **gate**, the only place the gloom can push. Members stand only on gates (about one per 3.7 m, shared out when
  short). Dimmed people walk the streets to the nearest gate. The push below now happens per gate.
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
- **Spirit:** 0 to 100, start 50; +20 a rescue. At 0 the player goes dim (half speed, no fire, border loses heart). Spare
  spirit at a full meter pools and warms the most strained border member (`spirit_warmth.gd`).
- **Spirit actions:** take a block with E (pass 2c: the only way the zone grows): hold E and point at a cell next to
  the zone to preview its new gates and the people they need against the people free, release to take it, right-click
  cancels. Rescue pips: each rescue fills a pip on its cell; at 3 (`TAKE_RESCUES`) the cell is ready and E takes it free,
  any other cell next to the zone costs 25 spirit (`TAKE_SPIRIT_COST`). Refused only when spirit is short; people never
  refuse a take (a short line is shared out thinly). Takeable cells glow on the ground and the minimap (gold free, blue
  paid; pass 3: free is a filled cell tagged "Free", paid an outline tagged "25", each with pips "2/3"); the
  preview reads "+5 gates: 18 more people" or "covered by spare people"; a HUD line under the spirit meter says
  "People: 31 on the line, 23 short" (or "6 spare"); a taken cell pulses and the slim banner says what it cost. G or Q (30, 8 s cooldown) bursts: lifts dimmed
  people nearby, pushes back those on the border line and lets the line near the burst spring back.
- **Gate cues (pass 2c):** each gate shows members/need, red when short; a pushed gate glows coral from 20% of
  `PUSH_BREAK_DEPTH`, and past 50% an off-screen gate gets an edge pointer (`gate_marks.gd`). Embrace is removed.
- **Town grid (0.4 pass 2, spread out in 2c):** 5 by 5 cells, 12 m streets; the start square is 18 m (its row and
  column are 18 m wide, so the blocks beside it are 18 x 12), other cells 12 m, plaza 114 m (`scripts/town_grid.gd`). The
  start square needs 20 members. The middle cell is the start square, the four diagonal cells next to it are landmark squares, the other 20 are solid built blocks (for the
  player too). Posts are gone (walls replace them).
- **Landmarks:** Bandstand, Garden, Bell Tower and Gallery, on the diagonal squares, about 27 m from the start (the Gallery is
  placed and claimable only, no boost, no styled art yet). Holding one (3 s inside the border) boosts joy; the third dawn
  light needs 75% rescued and 2 landmarks.
- **First light:** over the last 45 s a square front moves in from the map edge; people it passes lift and stop draining.
- **Cues:** the bending line is the warning (ribbon colour and width follow the bend; members lean and struggle). Gap
  arrows point at an off-screen break; wobble edge pointers, minimap blips, landmark pointers and a cue panel beside the
  spirit meter (glows when G can be used). Prompts and notices are one slim banner under the night bar, one at a time.
  Strain markers, strain rings and the border warning are gone.

**Controls.** WASD move, Shift run, mouse to point, hold E / release E take a block (right-click cancels), G or Q
burst, hold F / release F plant a defence (wheel picks the type), F2 targeting mode, mouse wheel zoom, F3 debug, F4 switch look, R restart, M menu. Menu: Play (Enter, 1, click), Look.

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
- Sound cues: not designed yet. (#25)
- The town is dense for how it plays and the game does not flow yet. Decided 2026-11-09: the town becomes a grid the
  line follows (walls and gates, block by block); see the 0.4 plan. (#55, #56)
- Parked (2026-11-07): members pop out of a deep dent and start dimming again, recoverable with a quick joy hit, as a
  step before a break. Investigate after 0.4 Walls and gates's push and pull. (#22)
- The gold inner ring (#38) was not raised in any 0.3.1 playtest; it stays in Backlog.
- The checkpoint screenshot scripts (`tools/checkpoint`) still use the town coordinates from before pass 2c. (#74)
- The Gallery has no styled art (it uses the bandstand model); its dent-fade protection and defence unlock are in 0.4. (#16)

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
  each? After the capture polish (#75): can you tell free from paid, pips, and people free against needed at a glance?

**Recorder:** breaks are logged as `break_open` / `break_close` (#23); `analyse_recording.py` reads the old `gap_open` / `gap_close` names too and renames them.

**Next:** 0.3.3 Town layout is done (2026-11-09, internal, no release; history in `IDEAS_RESOLVED.md`). Current target:
**0.4 Walls and gates**, passes 1 Reorg, 2 Grid and Line and 2c Grid fixes built (2c played and accepted 2026-11-11), then pass 3 Pressure and Defences (built 2026-11-11, In review, needs a playtest) (plan below, and on the board; reshaped 2026-11-09 as walls and gates on a town grid and renamed from "Tug of war"). 0.3.2 Prop styling was released as `v0.3.2` (2026-11-09).

**Resolved items** are listed in `IDEAS_RESOLVED.md` ("Resolved since they were last listed").

**Performance.** Crowd separation uses a spatial grid and a cached index: `CrowdMovement.update_people` 3.0 to 0.75 ms per
frame, identical results. `Border.update` is 1.5 ms at 28 members (slot assignment 0.8, polygon 0.36, buildings 0.15,
push 0.07); not changed, since the cheap fixes would not keep the results identical.

**Push status.** `origin/main` is `3d52b58` (0.3.2 Prop styling playtest 5 docs); local `main` is 57 commits ahead
(as of 2026-11-11, not pushed: the 0.3.3 and 0.4 commits). The last release is
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

## 0.5 Why expand (sketch; from the #82 design talk, 2026-11-11)

0.4 stays on the mechanics (walls, gates, pressure, defences); this is the content for the next target. The 0.4 pass 3
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
- **Not now:** pressure that punishes staying small (unheld blocks dimming their residents into pushers, or rising
  take costs). The user wants rewards alone tried first.

## Codebase cleanup (2026-11-11 review)

Found by two read-only reviews of tests, code, docs and token cost (the second, later on 2026-11-11, added #76 to
#80). **Targeted at 0.4 Walls and gates on 2026-11-11, in this order** (after pass 3, which is being built; the
tools and docs passes touch no gameplay files, so they can also run while the user plays):
1. **Cleanup pass A, quick wins** (one Haiku pass): Test timings (#76), Test weights (#63), Stale state (#77),
   Playtest skill (#78), Search noise (#64), Housekeeping (#65).
2. **Cleanup pass B, agent docs** (one pass): Coordinator rules (#79), Agent tool notes (#80), Trim docs (#71).
3. **Lighter tests** (#69, Sonnet), once pass A has refreshed the timings. Rule stepping (#18) serves the same goal:
   decide then whether it comes first.

Still Backlog, as filler beside playtests: Permissions (#66), History out of code (#67), Unused constants (#68),
Styled-look tier (#72, needs the user's call on the coverage rule first), the checkpoint scripts (#74).

### Cleanup: Test timings (#76, S)
`.git/positivefps-test-times.json`, which `run_tests.py` plans from, was last written on 2026-11-09: it holds 15
deleted suites and nothing for 8 live ones (`take_block_test`, `zone_test`, `border_gates_test`, `gate_marks_test`,
`border_misc_test`, `style_grid_test`, `recorder_blocks_test`, `recorder_shots_test`). An untimed test counts as 0.5 s,
so all of them land in the "under 5 s" fast tier on every commit and the parallel plan cannot balance them. Only a
full plain run writes the file, and a pass ends with coverage runs. Save the times from every full run (plain or
instrumented, scaled if needed), drop entries for tests that are gone, and cover it in `tools/test_run_tests.py`.
Do it together with Test weights (#63).

### Cleanup: Stale state (#77, XS)
"Current state" above has facts that are no longer true: `origin/main` is `3d52b58`, not `fc2a37c`, and local main
is 47 commits ahead; it points to a "Round 26 build" section "below" that has moved to `IDEAS_RESOLVED.md`; "Watch
in the next playtest" says 10 m streets (they are 12 m, and `README.md` line 68 says 10 m too); the Recorder line
says the analyser still reads the old `gap_*` names, but `analyse_recording.py` already maps them; the open items
say "checked 2026-11-07". Correct each against the code.

### Cleanup: Playtest skill (#78, XS)
`.claude/skills/launch-playtest/SKILL.md` step 5 tells the coordinator to quote a "PATCH EFFECT" section and to
summarise "beacons", and calls the sections "round 23 sections"; patches and beacons are gone. Rewrite step 5 from
what `tools/analyse_recording.py` prints now (its sections for takes, pips, gates and breaks).

### Cleanup: Coordinator rules (#79, S)
`CLAUDE.md` is 8 KB and every build agent loads it, but about 70% (the board, the target loop, keeping targets
cheap, parallel builds) is for the coordinating session only. Keep "Rules for every agent", the targets and
versions summary and the pointers in `CLAUDE.md`; move the rest to a coordinator skill or doc that only the main
session loads, and remove what the three skills repeat. No rule is dropped or weakened.

### Cleanup: Agent tool notes (#80, XS)
The brief template sends every agent to ARCHITECTURE.md's "Quality gate and tools", about 30 dense lines, most of
them about `round_end.py`, the board, the dashboard, `perf_compare.py` and cache internals. Split it into a short
agent part (own suites, `--check-files`, lint, `godot_run.py`, the source map) and a coordinator part, and stop the
template restating the `CLAUDE.md` rules it already tells agents to read. Do it with Coordinator rules (#79).

### Cleanup: Test weights (#63, XS)
`tools/test_weights.json` has 203 entries for tests that no longer exist (15 whole suites, such as `beacon_test`) and
no entry for 233 of the 801 live tests, which then count as 0.5 s. The fast tier ("under 5 s") and the parallel
scheduling both use these numbers, so a slow new level test can slip into every commit's hook. Run
`run_tests.py --update-weights`, make the update drop entries for tests that are gone, and have the gate or
`board.py scan` warn when more than about 10% of tests have no weight.

### Cleanup: Search noise (#64, S)
About 126 MB of `design/` (renders, mockups, `gap_pulse.html` at 1.6 MB) is tracked and makes up most of the 60 MB
pack; it, `addons/gdUnit4` (508 files) and `IDEAS_RESOLVED.md` (220 KB) show up in broad Grep/Glob searches. Add a root
`.ignore` (ripgrep skips it; direct reads still work) for `design/`, `addons/` and `IDEAS_RESOLVED.md`. Decide whether
the renders move out of git (LFS, or untracked with a note).

### Cleanup: Housekeeping (#65, XS)
Five agent worktrees in `.claude/worktrees` (one locked), three playtest worktrees in old scratchpads and 117 MB in
`.scratch/`. Run `tools/cleanup_worktrees.py`, prune `.scratch`.

### Cleanup: Permissions (#66, XS)
`.claude/settings.json` allows about 14 commands; `run_tests.py`, `gate.py`, `source_map.py` and read-only git commands
are missing, so they prompt (a round trip each, and a stall for background agents). Build the list with the
`fewer-permission-prompts` skill.

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

### Cleanup: Trim docs (#71, S)
The 0.4 plan is 23 KB of IDEAS.md's 40 KB; move the finished passes to IDEAS_RESOLVED.md and keep what is open. The
border paragraph in ARCHITECTURE.md "Areas" is about 2 KB on one line: split it into short bullets. Merge memory notes
that repeat CLAUDE.md (coordinator work, `consolidate-memory`).

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

## 0.4 Walls and gates plan (2026-11-07; called "Tug of war" until 2026-11-09)

Planned as rounds 27 and 28 before the switch to targets. **Order** (confirmed by the user, 2026-11-09: code health
first, then the gameplay changes):
- **Pass 1, Reorg** (#3, #4): the code-health items. No gameplay change, so no playtest: the gate, the determinism
  check and the timings are the proof. (Quick wins were done in 0.3.3.)
- **Pass 2, Grid and Line** and **pass 3, Pressure and Defences:** Walls and gates on the reorganised layout (reshaped
  2026-11-09: the town becomes a grid and the line follows it).
- **Cleanup passes A and B, then Lighter tests** (added 2026-11-11; #76, #63, #77, #78, #64, #65, then #79, #80,
  #71, then #69): after pass 3; order and detail in "Codebase cleanup" above.
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

**Pass 2c, Grid fixes (#55, #56, #10, #11, #73; planned 2026-11-11, updated after the playtest the same day).** One Sonnet agent. Builds after Recorder catch-up
(#59 to #61, now in IDEAS_RESOLVED.md): remove the recorder's `auto_join` emit with auto-join, set `take`'s `free` for a pip-ready take.
1. **E only, pips show readiness** (#10, #11). Cells never join by themselves. Rescues still fill a cell's pips; a cell
   with full pips (`TAKE_RESCUES` 3) is ready, and taking it with E is free; any other cell next to the zone costs
   `TAKE_SPIRIT_COST` (25). Every change to the line is one the player made.
2. **People count on the gate and the preview** (#10, #56). Each gate shows its members against its need (for example
   "3/4"), red when short; the take preview shows the people the new gates need against the free people you have. Must
   read in both looks. **People no longer lock a take** (user, 2026-11-11 playtest): a cell next to the zone can always
   be taken, and a short line is shared out thinly as today (pass 3's thin line, #12, makes thin gates weaker). The
   count is a warning, not a refusal; drop the `people_short` refusal.
2a. **Mark takeable cells** (#10; user, 2026-11-11 playtest). Cells you can take right now glow on the ground and on the
   minimap before E is pressed: one look for a free (pips full) cell, another for a 25-spirit cell. Placeholder look
   only. The recorder splits `not_next` into `not_next` and `already_held`.
3. **Which gate is in trouble** (#56). A gate being pushed reads from across the screen (its line pulses or shifts colour
   with the dent), and one past half `PUSH_BREAK_DEPTH` gets an edge pointer when off screen (extend the gap arrows).
4. **Why the line changed** (#56). A short pulse on a cell when it is taken (and later when lost), with the slim banner.
5. **Spread out a little** (#55). Start square 18 m (other cells 12 m), streets 12 m. Grow the plaza to fit and keep the
   landmark squares on the diagonals; check spawns and first light still reach the town.
6. **Remove Embrace** (#73; user, 2026-11-11 playtest: never noticed in round 25 or this game, 6 begun, 1 rescue).
   Delete the system, its config, tests, recorder events and analyser section, and its how-to-play and README lines.
Playtest questions: is E now the way you grow, and is the price a choice? Does the count make the people cost clear?
Can you see which gate is in trouble? Can you tell which cells you can take before pressing E?

**Built (2026-11-11, `4bbb7ce`, merged `ad6070e`; In review).** One Sonnet agent. All seven items as above. New
`scripts/gate_marks.gd` (people labels, push glow, edge pointers via the gap arrows); the take preview says "Free" or
"25 spirit"; `FIRST_LIGHT_START_RADIUS` 71 to 81 and `C7_LINE_MAX_DIST` 22 to 27.5 to fit the bigger town. Bug fixed on
the way: `Border.update` pushed against the old polygon after a re-trace (would have broken pass 3's lost cells).
Embrace removed (`embrace_test` and `tools/test_analyse_embrace.py` gone; `take_block_test` and `recorder_blocks_test`
rewritten for the new rules; layout numbers moved in 17 other suites, thresholds unchanged). Marks, labels and glow are
plain quads and Label3D in both looks (no styled art). Gate passed (824 tests), determinism passed; the coverage
ratchet needed new border and recorder tests after Embrace's tests went (`dc23152`: `border_misc_test`,
`recorder_shots_test`; then gate, determinism and baseline passed). Nothing loosened. Not done: the checkpoint
screenshot scripts in `tools/checkpoint` still use the old coordinates (#74).

**Played 2026-11-11 (`8d14eae`); accepted, Done** (#10, #11, #55, #56, #73). Seed 42, placeholder, win, 3 of 3 dawn
lights (92% rescued, all 4 landmarks). Against the recorder playtest the same morning: takes 1 to 7 (2 free, 5 paid),
refusals 23 to 2 (1 `not_next`, 1 `already_held`). Spirit still never limited a take (mean 96 after 125 spent); the 2
free cells waited 61 s on median (max 112 s) before they were taken. Every take was short of people (the last: 85
needed, 54 free) with no penalty; 4 breaks, 0 relapses, 0 wobbles, 1 burst.
- Capture: "mostly clear, needs polish": free vs paid glow, the people-count wording and a cell's pips were hard to
  read; "wasn't clear how many folks were free to expand and how many more were needed" (#75 in pass 3).
- The user expanded while gates read 3/5 and assumed spare people float and fill later gates, which is how it works
  (members fill gates up to their need; the rest stand inside as inner and move to new gates; short, everyone is shared
  out). Say it on screen (#75).
- Price: 25 spirit and 3 pips stay (user's call), to be judged again once pass 3 makes over-reaching cost something.
- Gate cues: "I could tell where pushes were happening, but they weren't anything I had to deal with": pressure is the
  gap, which pass 3 is for.

**What stays as it is.** Joy, elements and moods; the gloom's phases and arrivals; the burst; spirit and spirit warmth;
wobble and relapse; first light; the dawn rating; the cue panel and the slim banner; both looks.

**Passes.** Pass 1 is Reorg (#3, #4), above. Then:
- **Pass 2, Grid and Line** (#55, #56, #10, #11): the smallest playable version of the idea. One Sonnet agent, since
  the grid and the line depend on each other. The two tides keep running, aimed at gates, until pass 3.
  Playtest question: does the town now tell you where to look and what to do next?
- **Pass 3, Pressure and Defences** (#12, #13, #14, #15, #16, #75; plan below): two Sonnet worktree agents, **Pressure** (thin line,
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

### Walls and gates: Pass 3 plan, Pressure, Defences and capture polish (#12, #13, #14, #15, #16, #75; planned 2026-11-11)

**Why now.** Two pass 2 games were easy wins (3 of 3 lights, 0 relapses, 4 breaks each), the line ran 30 people short
with no penalty, and the user saw pushes that "weren't anything I had to deal with". Items 5 to 9 of the Grid, Line and
Defences plan above are the design; this section is how pass 3 builds them, with the defaults to use.

**Two Sonnet worktree agents, merged Pressure first.** Both start from local main (base check in the brief).
- **Pressure** (#12, #13, #14). Files: `border_slots.gd`, `border_push.gd`, `border.gd`, `zone.gd`, `gloom_tide.gd`
  (becomes the surge), `night_cycle.gd`, `push_config.gd` / `border_config.gd` / `night_config.gd` (block "Walls and
  gates: Pressure"), the minimap warning, the recorder events (`cell_lost`, `surge_warn`, `surge_start`, `surge_end`;
  the analyser's TIDES section becomes SURGE and BLOCKS gains lost cells).
  - Thin line (#12): a gate's strength follows its fill (members / need): the break depth is
    `PUSH_BREAK_DEPTH * lerp(THIN_LINE_MIN_STRENGTH 0.5, 1, fill)`, and its members stand evenly along it so a thin gate
    shows wide spacing. Nothing else reads it (no meter).
  - Lost cells (#13): a gate broken for `GATE_LOST_SECONDS` 12 loses the held cell behind it (the start square never);
    the line re-traces, members regroup, that cell's pips reset to 0, a cell the loss cuts off from the start square is
    lost with it. Nobody relapses from a loss. Banner: "The gloom took a block." with the cell pulse in grey.
  - One surge (#14) replaces the two tides: warning 40 s (fog gathers at the far end of one street, a minimap mark, the
    light cools, a banner that reaches the player anywhere), surge 50 s down that street pushing the gate it meets at
    full strength and the gates either side at half, then an aftermath where arrivals ease. Timed to peak at midnight.
  - Interface for Defences (agreed up front, both agents code to it): per gate `strength_mult` (default 1),
    `cannot_break` and `cannot_lose` flags, set through `Border.set_gate_modifiers(g, {...})` and cleared on re-trace
    by gate id.
- **Defences and capture polish** (#15, #16, #75). Files: new `defences.gd` + `defence_config.gd`, `controls.gd` (F),
  `landmarks.gd` (unlocks), `take_block.gd`, `gate_marks.gd`, `minimap.gd`, `hud.gd`/prompt bar, menu how-to-play,
  README controls.
  - Defences (#15, #16) as in items 8 and 9 above: hold F, point at a gate, release; one per gate, `DEFENCE_MAX` 4;
    staffed by the nearest free member (who leaves the line); a type is unlocked by claiming its landmark: Bandstand
    weakens pushers (`strength_mult` 1.5), Garden `cannot_break`, Gallery `cannot_lose` (both cells beside it), Bell tower
    rings a free burst at the gate when it is pressed past half the break depth (cooldown 20 s). A defence whose gate
    closes is handed back. Placeholder look: a simple post shape per type with its landmark's colour.
  - Capture polish (#75, user's notes): free and paid differ in shape as well as colour (free: a filled cell with a
    "Free" tag; paid: an outline with "25"); pips are larger and show on every cell next to the zone as "2/3"; one HUD
    line under the spirit meter says the people plainly, for example "People: 31 on the line, 23 short" or "People: 54
    on the line, 6 spare"; the take preview says "+5 gates: 18 more people" (or "covered by spare people"). Gate labels
    keep members/need. Words reviewed for the gloom terms.
- After the merge: bot nights do not exist yet, so the coordinator checks the balance with two scripted level runs (a
  compact zone and an over-reached one) in the tests: the compact one must keep its cells through the surge, the
  over-reached one must lose at least one. If either fails, report the numbers; do not tune thresholds to pass.

**Gate.** Each agent: its own suites and lint, `--check-files` on its scripts; the coordinator runs `round_end.py`
(rules change: determinism runs). Never loosen a threshold or a `test_perf_*` budget.

**Playtest questions.** Does a thin gate read as thin and does it need you now? Does losing a block feel fair and
recoverable? Did you see the surge coming from wherever you were, and is one enough? Are defences worth a member and a
choice between types? Can you tell free from paid and how many people you have to spare?

**Built (2026-11-11; Pressure `a335b99`, Defences and polish `ec144fc`, merged `65b4fe6` and `996ae97`; In review).**
Two Sonnet worktree agents in parallel. Pressure: thin line (`Border.break_depth`, `gate_fill`), lost cells
(`Zone.cell_behind`, `cells_behind`, `cells_lost` signal, `lost_pulse.gd`), one surge in `gloom_tide.gd` (warn 25 s,
push 65 to 115 s, aftermath 30 s; 16 seeded streets that meet a gate), recorder `cell_lost` and `surge_*`, analyser
SURGE. Defences: `defences.gd`, `defence_config.gd`, F and the wheel, landmark unlocks, recorder `defence_*` and
`bell_ring`, analyser DEFENCES; capture polish (#75) as planned; the how-to-play panel widened to 1120 px (2 px spare).
Merge: both built the gate-modifier block; Pressure's kept (Defences sends full modifier sets, so it fits), with
Defences' filter that keeps staffed people off the line. Menu text now names the surge. Balance tests
(`pressure_balance_test`, seed 42, one street): the compact zone holds (deepest dent 2.23 against 2.40, about a 7%
margin), the over-reached zone (12 of 40 people) loses one cell after a 12 s break. Gate and determinism passed; the
coverage ratchet needed more recorder and defence tests (commit after the merge). Nothing loosened. `border.gd` is
976 lines against the 1000 cap. Tide tests became surge tests (`gloom_tide_test`, `gloom_tide_edges_test`,
`border_push_test`, `checkpoint7_test`, `edge_cleanup_test`); `edge_ribbon_test` and `gate_marks_test` adjusted for
staffed gates.

**Open for the user** (defaults used unless overruled): `GATE_LOST_SECONDS` 12; surge 40 s warning and 50 s push; four
defences in all; defences cost a member each, no spirit (all used as built). Close #47 (room to play around the push) now that gates and
streets give that room?

**Played (2026-11-11, `6af7799`, recording `20261111-165927`).** "A really good round. The direction is solid, needs
refinement." Win 3/3 dawn lights, 45 rescued (2c: 55), 2 relapses (2c: 0), strict quiet 15.1% (2c: 7.8%). 7 takes
(3 free, 4 paid, 100 spirit), 2 refusals (not next). The surge came down the south street at 65 s, broke gate 8 and took
2 cells at 96 s (the Bell tower lost the same second); 3 breaks and 8 holds in all. No defence planted (one F refused,
no gate in range). Answers:
- Lost cells: fair, but the surge warning was missed. Wants a sound cue and a much bigger fog visual (#81).
- Defences: no reason to plant one; capturing ground was already going well. The wider theme is **why expand, what is
  there**: the boosts are thin. To explore in a design conversation first, covering cells that give things, landmarks
  that matter more, and pressure that punishes staying small (#82; talked through 2026-11-11, see "0.5 Why expand").
- Capture cues: mostly clear, needs polish (no detail given). #75 accepted (Done).
- #12 to #16 stay In review: they work, refine in the next pass and play again.

### Walls and gates: Rule stepping, advance the game rules without the scene (#18; after Line and Defences merge, or the next target)

Tests are frame-bound: the 2400-frame border test sets the suite's floor. Let people, gloom and border advance on a
fixed time step without the scene running, so the long scenario tests stop waiting on real frames. Rules and visuals are already split for the looks; this does the same for the simulation.
