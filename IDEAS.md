# PositiveFPS — Game Ideas

**What to build next is on the GitHub board** "Positive game dev" (https://github.com/users/skarfacegc/projects/3):
headlines, targets (milestones such as "0.4 Tug of war"), status and size. This file holds the detail; a `#N` on a
headline is its issue. Finished history and resolved issues live in `IDEAS_RESOLVED.md` (one line per round or target
at its top, plus the map from old round numbers to versions). This file keeps the current state, the standing ideas and
the current targets' plans. To find code use `SOURCE_MAP.md`
(`python tools/source_map.py`); for where things live and how to brief an agent use `ARCHITECTURE.md`.

## Current state (as of 2026-11-09, after 0.3.3 Town layout)

**What the game is.** A gentle top-down territory game in Godot 4.7 (GDScript, strict typing). Dimmed people slowly take
over a plaza; the player rescues them with joy, and the rescued form a living border that holds the gloom back and paints
the land inside. One night per level, dusk to dawn (about 3 minutes); reaching dawn wins and is rated 1 to 3 dawn lights.
Tone: warm and gentle, joy shared and never a cure. Player-facing text uses the gloom terms (wistful, gloomy, dimmed),
never "dark people". Art is original, technique-level inspiration only.

**Mechanics as they stand (round 26, physical push).**
- **Joy and elements:** music, art and nature (a soft cycle: matched 2x, strong 1.5x, weak 1x). Pointing at a person fires
  automatically; a person needs enough joy to be rescued (grace, then the border). Moods: guarded (front-only joy),
  skittish (flees), glum (x3 when looking up), sheltered (umbrella shield, four hits).
- **Gloom:** unrescued people go wistful, gloomy, then dimmed. Dimmed people lean on the border and reach for the player.
  The night has phases: calm opening, rising, midnight (hardest, dimmed sinks staggered by `DIM_ARRIVAL_MIN_GAP`), easing.
  Two gloom tides a night (rising, midnight) are a visible wave of fog with figures that rolls in and shoves its side.
- **Border (physical push):** only visible things push: dimmed people leaning on the line from outside, and a tide's wave.
  The line bends inward where pushed (the loop dents; members brace and lean) and springs back when relieved. Past
  `PUSH_BREAK_DEPTH` (2.4 m of dent) it breaks: a gap made by pushing. Pushers walk through and drain people and erode
  painted land inside until the break mends (when no dimmed person is within 5 m and a member near it has had joy since
  it opened, or after 25 s clear; `PUSH_MEND_NEEDS_JOY`). Joy weakens pushers; joy at bending members or a burst (G or Q)
  calms the spot. A member drained too far wobbles about five seconds before relapsing; a joy hit saves them. Relapses are
  gated (`RELAPSE_GATE_GAP`). Model and open questions: "Round 26 build" below.
- **Spirit:** 0 to 100, start 50; +20 a rescue. At 0 the player goes dim (half speed, no fire, border loses heart). Spare
  spirit at a full meter pools and warms the most strained border member (`spirit_warmth.gd`).
- **Spirit actions:** beacon (50): hold E to aim a zone preview, release to place, right-click cancels; the zone stretches
  toward it and the arm stays, limited by headcount. G or Q (30, 8 s cooldown) bursts: lifts dimmed people nearby, pushes
  back those on the border line and lets the line near the burst spring back. There is no patch action any more.
- **Town (0.3.3):** 20 blocks in rows along a main street (z=0) and a cross street (x=0), 10 m wide, meeting at the start
  (`scripts/town_layout.gd`). Lamps on the kerbs, stalls on the start square, a bench and planter in front of each block.
  Border members and rescued people steer around block footprints, and a post (a block on the border) holds one slot.
- **Landmarks:** Bandstand, Garden, Bell Tower and Gallery, one at each street end, 26 to 32 m from the start (the Gallery is
  placed and claimable only, no boost, no styled art yet). Holding one (3 s inside the border) boosts joy; the third dawn
  light needs 75% rescued and 2 landmarks.
- **First light:** over the last 45 s a square front moves in from the map edge; people it passes lift and stop draining.
- **Cues:** the bending line is the warning (ribbon colour and width follow the bend; members lean and struggle). Gap
  arrows point at an off-screen break; wobble edge pointers, minimap blips, landmark pointers and a cue panel beside the
  spirit meter (glows when G can be used). Prompts and notices are one slim banner under the night bar, one at a time.
  Strain markers, strain rings and the border warning are gone.

**Controls.** WASD move, Shift run, mouse to point, hold E / release E beacon (right-click cancels), G or Q
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
- The town is a little dense for how it plays: thin the layout or retune the gameplay (a decision first). (#55)
- Parked (2026-11-07): members pop out of a deep dent and start dimming again, recoverable with a quick joy hit, as a
  step before a break. Investigate after 0.4 Tug of war's push and pull. (#22)
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
- Until 0.4 replaces the beacon: the second arm is much shorter than the first (7.3 m against 34.2 m at 24 people), and
  the limited preview checkpoint shot uses "inside the zone already", not a dimmed block.

**Recorder:** breaks are logged as `break_open` / `break_close` (#23); the analyser still reads the old `gap_*` names.

**Next:** 0.3.3 Town layout is done (2026-11-09, internal, no release; history in `IDEAS_RESOLVED.md`). Next target:
**0.4 Tug of war** (plan below, and on the board). 0.3.2 Prop styling was released as `v0.3.2` (2026-11-09).

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

Wider world and level progression ideas: see `VISION.md`.

## 0.4 Tug of war plan (2026-11-07)

Planned as rounds 27 and 28 before the switch to targets; the content is unchanged. **Order:** first pass **Reorg**
and **Quick wins** together (no gameplay change, so no playtest: the gate, the determinism check and the timings are
the proof), then **Line** and **Defences** on the reorganised layout, then **Rule stepping** if there is room.

### Tug of war: Reorg, code reorganisation (#3, #4)

Two parts at once in their own worktrees: **Reorg** (Sonnet) and **Quick wins** (Haiku, tools and skills only, so no
overlap).

**Why.** Of the last 150 commits, `config.gd` changed in 63 and `topdown_main.gd` in 54: almost every change, and most
merge conflicts between parallel parts, go through these two files. The tuning values are filed by round
("Round 25:", "Round 26:") across `config.gd` (599 lines) and `config_base.gd` (744 lines, about 680 constants in all),
so an agent tuning one system searches both.

**Changes** (one Sonnet worktree agent, no behaviour change):
1. **Config by system, not by round** (#3). Split `Config`/`ConfigBase` into one small config script per system (for example
   border, push, tide and night, people, projectiles, spirit, landmarks, HUD and cues, recorder), and update every
   reference. The round history stays in git and IDEAS_RESOLVED.md. Line and Defences then add their values to
   their own systems' files.
2. **`topdown_main.gd` coordinates only** (#4). Move each system's set-up and per-frame work into that system's script, so
   `TopDownMain` builds the systems and calls them in order. New features should no longer need an edit there.
3. **Proof of no change:** the full gate and the determinism check give the same tests and lines hit as before;
   `coverage_baseline.json` gets the new file paths (never a lower total). Regenerate SOURCE_MAP.md and update
   ARCHITECTURE.md (script map, areas, tuning).

**Not in Reorg:** sub-folders for `scripts/` (border/, gloom/, people/, hud/, fx/). Coverage, the baseline and the
fast tier's map are keyed by file path, so it needs a remap tool first; low value for the risk.

### Tug of war: Quick wins, build speed and upkeep (#5 to #9)

Moved to 0.3.3 Town layout (2026-11-09); the text stays here.

1. **Stop Godot importing tool output** (#5). `.godot/` is 1.4 GB: Godot imports every gdUnit4 report under `reports/` (267
   folders, one logo per report page; 15,395 paths in `reports/determinism-2` alone). `run_tests.py`'s freshness check
   already skips these folders (`IMPORT_IGNORED_DIRS`), but Godot itself does not. Have the tools put a `.gdignore` in
   each `IMPORT_IGNORED_DIRS` folder that holds no game assets (at least `reports/` and `coverage/`; check `design/`,
   `recordings/` and `dist-builds/` are never loaded by the game first), keep only the last few report folders, then
   clear `.godot/imported` once and reimport. Expect a much smaller cache, a faster `--import` (about 38 s today), and
   faster coverage and determinism copies, which start from the repo's import cache. Record before and after in
   `tools/BUILD_TIMINGS.md`.
2. **Worktree agents start with the import cache** (#6) (only once 1 has shrunk it): list the needed parts of `.godot/`
   in a `.worktreeinclude`, so a new agent worktree skips its first full import. Measure the copy against the import.
3. **SOURCE_MAP.md never blocks a commit** (#7). Have `lint.py --fix` regenerate it (the hook still checks it), and say so
   in the `brief-build-agent` skill, so agents stop losing a commit attempt to a stale map.
4. **IDEAS.md stays short** (#8). The `finish-target` skill moves the finished build and plan sections to IDEAS_RESOLVED.md
   (the round 26 build section is still here).
5. **Coordinator, by hand** (#9): now that checkpoint 7 has merged, run `python tools/cleanup_worktrees.py` (three old scratchpad
   copies and `agent-afd5…` are stale), and suggest `/fewer-permission-prompts` to the user to allowlist the common
   tool commands.

### Tug of war: push and pull (Line #10 to #14, Defences #15 to #17)

**Order.** Build after Reorg and Quick wins are merged. Checkpoint 7 part A removed the beacon's reach guide and
part D brought the round 26 push into the styled look; this keeps the styled push working where it can, and its new
visuals are placeholder only, as usual.

**Discussion (no new playtest; design talk after the checkpoint 7 playtest).** The core loop is *build your zone,
reinforce and protect it, reach for goals with it*. Shooting is the means to that end. The border should be a visible tug
of war: the player pulls it outward, the gloom pushes it in. E "kinda works" but growth doesn't push against anything,
so the beacon is replaced. Buildings and landmarks should be denser.

**Decisions (interview).**
- Shaping: **grab and pull (E)** and **rescues pull the line**. Defences do not pull the line out (tent pegs not
  picked); they hold it.
- The beacon is **replaced** (its arms, preview and 50 spirit cost go). Spirit stays for bursts and warmth.
- Grab and pull costs **spirit per pull**, on top of the thin-line weakness.
- Defences cost **rescued people as staff**, go on **F, inside near the edge**, and **landmarks unlock types**, with
  **none available until the first capture**.
- The night gets **one long telegraphed surge** in place of the two tides.
- Parked for later: people popping out of a deep dent and dimming again (see the open items).

**Changes** (values marked "default" are the coordinator's calls; the playtest can overrule them).
1. **Grab and pull (E), replacing the beacon** (#10). Hold E: the stretch of border nearest the cursor is grabbed. Drag
   outward and a preview shows the new shape (a smooth bulge, wider the further you pull). Release to set it, paying
   `PULL_SPIRIT_COST` (default 25); right-click cancels; not enough spirit shows the slim banner. The pulled shape
   becomes the line's rest shape: members walk out to fill it, and it holds there until pressed in. Reach is capped by
   headcount (see 3). Default: outward only for now.
2. **Rescues pull the line** (#11). A person rescued outside the zone joins the border at the point nearest where they stood
   and pulls that stretch's rest shape out toward them by `RESCUE_PULL_SHARE` of the distance (default 0.5, capped by
   headcount). Where you rescue is where you grow. Rescues inside the zone add headcount as now.
3. **The line is a balance of forces; tight or stretched** (#12; land follows the line #13).
   - Each angle sample has a rest position (from pulls and rescues) and a pressure (pushers and the surge, as round 26).
     The line sits between them and springs back to its rest shape, not further, when relieved. Default: no automatic
     outward drift.
   - Strength per metre falls as the same people cover a longer line: member spacing widens, and dent resistance and
     break depth scale down with it (`THIN_LINE_*`). A compact zone holds; a long reach is a thin, risky line. The
     thinness must read in the placeholder look (wider member spacing, a thinner ribbon), not as a meter or alarm.
   - **Land follows the line:** ground under a dent fades toward grey while the dent holds and recolours when the line
     springs back. Ground left outside after a deep press is lost to the gloom as it is today outside the border.
4. **Defences (F)** (#15). Hold F to aim on painted ground inside the zone near the edge, release to plant; right-click
   cancels. With more than one type unlocked, the mouse wheel cycles the type while F is held (it zooms otherwise).
   The nearest free border member walks over and staffs it (they leave the line, so the line thins). A defence
   strengthens the stretch of border nearest it. One type per landmark:
   - Bandstand (music): pushers within its reach are weakened, so that stretch dents less.
   - Garden (nature): the nearby line resists denting and cannot break there.
   - Gallery (art): painted ground near it cannot be worn away, and the dent's grey fade (3) skips it.
   - Bell tower: when the nearby line is pressed hard, the bell rings and calms that stretch (a small free burst, with
     a cooldown).
   A defence left outside the line goes quiet (no effect) and its staff drains like any member until the line takes it
   back. Defaults: `DEFENCE_MAX` 4 in total; any rescued person can staff any type (no element matching).
5. **Landmarks unlock defences (#16); denser layout (#17, moved to 0.3.3 Town layout on 2026-11-09).**
   - Capturing a landmark (held 3 s, as now) unlocks its defence type for the rest of the night; nothing is unlocked
     at the start. The unlock shows in the slim banner and the cue panel.
   - Add a fourth landmark, the **Gallery** (art), and move the Bandstand and Bell tower closer: today they are about
     49 m and 45 m from the start (the Garden about 14 m). Default: all four within about 18 to 32 m of the start, on
     different sides, so reaching one takes a pull or two, not a trek.
   - More ordinary buildings, closer together (default about 1.5x as many), keeping paths for people and the player.
   - The third dawn light still needs 75% rescued and 2 landmarks (of four now); watch it in the playtest.
6. **One long telegraphed surge** (#14), replacing the rising and midnight tides:
   - **Warning** (default about 40 s before the peak): a fog bank gathers on one or two sides, visible on screen and
     on the minimap, and the light cools. That is the window to pull, plant and staff.
   - **Surge** (default about 50 s): a long, heavy push from the side shown, using round 26's wave and pushers.
   - **Aftermath:** the fog thins and arrivals ease, leaving time to repair and reach for the next landmark.
   - Tune with bot nights so a compact zone with a defence holds and an over-stretched one bends or breaks.
   - The warning must reach the player wherever they are: in the 0.3.1 playtest neither tide was seen, because both
     came from the far side and the off-screen cue was only the placeholder `tide_pointer`.

**Constraints.** Placeholder look only. Tests for the removed beacon may be removed or rewritten for the pull; list them
in the report. Never loosen a threshold or a `test_perf_*` budget. Rules change, so run the determinism check at the end.
Player-facing text uses the gloom terms. README.md is updated, since the controls change (E pull, F defence).

**Build split** (two Sonnet worktree agents, each adding its values to the per-system config files Reorg creates;
a new system gets its own file):
- **Line:** changes 1, 2, 3 and 6, the line and the surge (`border.gd`, `border_push.gd`, the beacon scripts, the night
  cycle). It adds one hook for defences: a per-angle strength multiplier and a "no break here" flag that
  `border_push.gd` reads through a small interface.
- **Defences:** changes 4 and 5, defences, unlocks and layout (new `scripts/defences.gd` and its placeholder look, landmarks,
  the level layout, cue panel text). It provides that interface and tests against a stub until Line merges.
- The coordinator merges Line first, then Defences, and resolves the shared config files, README.md and the controls text.

**Playtest questions.** Does pulling feel like pulling against something? Is 25 spirit per pull a real decision? Does a
thin line read as thin without a meter? Are defences planted during the warning, and is one surge enough tension for the
night? Are four closer landmarks the right density?

### Tug of war: Rule stepping, advance the game rules without the scene (#18; after Line and Defences merge, or the next target)

Tests are frame-bound: the 2400-frame border test sets the suite's floor. Let people, gloom and border advance on a
fixed time step without the scene running, so the long scenario tests stop waiting on real frames. Rules and visuals are already split for the looks; this does the same for the simulation.
