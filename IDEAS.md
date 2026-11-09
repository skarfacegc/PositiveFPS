# PositiveFPS — Game Ideas

**What to build next is on the GitHub board** "Positive game dev" (https://github.com/users/skarfacegc/projects/3):
headlines, targets (milestones such as "0.4 Tug of war"), status and size. This file holds the detail; a `#N` on a
headline is its issue. Finished history and resolved issues live in `IDEAS_RESOLVED.md` (one line per round or target
at its top, plus the map from old round numbers to versions). This file keeps the current state, the standing ideas and
the current targets' plans. To find code use `SOURCE_MAP.md`
(`python tools/source_map.py`); for where things live and how to brief an agent use `ARCHITECTURE.md`.

## Current state (as of 2026-11-08, after round 26, graphics checkpoint 7 and 0.3.1 Living town fixes)

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
- **Landmarks:** Bandstand, Garden (about 14 m from the start), Bell Tower. Holding one (3 s inside the border) boosts
  joy; the third dawn light needs 75% rescued and 2 landmarks.
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
- The minimap redraw spike (8 ms per redraw; tests turn the automatic redraw off). (#21)
- The player's jog barely differs from the walk in the styled look. (#27)
- Sound cues: not designed yet. (#25)
- The agent dashboard may show a finished agent as running (not rechecked). (#20)
- Unused: `Person.React.PATCH` is never set by gameplay (only tests set it); `config_base.gd` `GAP_HEAL_DELAY` and
  `MEMBER_FALTER_STEP_BACK` are read nowhere. Remove them or give them a use. (#19)
- Open question: should the recorder rename `gap_open` / `gap_close` to `break_*`? (#23)
- Parked (2026-11-07): members pop out of a deep dent and start dimming again, recoverable with a quick joy hit, as a
  step before a break. Investigate after 0.4 Tug of war's push and pull. (#22)
- 0.3.2 Prop styling (done and released as v0.3.2; plan, built and playtest notes below):
  lamp styling (#49), bench styling (#50), bunting wires above the player (#42). The gold inner ring (#38) was not raised in any 0.3.1 playtest; it stays in Backlog.

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

**Next:** 0.3.2 Prop styling (#42, #49, #50) is done and released as `v0.3.2` (2026-11-09). Next target:
**0.3.3 Town layout** (Ready, plan below): town layout (#52), the orange plank (#51), the denser layout and Gallery
(#17), tooling (#5 to #9, #20, #23) and code health (#19, #21). Then 0.4 Tug of war (plan below, and on the board).
0.3 Living town is done (2026-11-07) and 0.3.1 Living town fixes is done (2026-11-08, playtest 4 below), both internal
only: no release.

**Resolved items** are listed in `IDEAS_RESOLVED.md` ("Resolved since they were last listed").

**Performance.** Crowd separation uses a spatial grid and a cached index: `CrowdMovement.update_people` 3.0 to 0.75 ms per
frame, identical results. `Border.update` is 1.5 ms at 28 members (slot assignment 0.8, polygon 0.36, buildings 0.15,
push 0.07); not changed, since the cheap fixes would not keep the results identical.

**Push status.** `origin/main` is `fc2a37c` (0.3 Living town and the board docs, pushed 2026-11-07); local `main` is
ahead by the 0.3.1 commits (not pushed). The last release is
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

## Round 26 build (2026-11-07)

Physical push, built by one Sonnet agent as planned. `border_push.gd` (new) owns the push: a dent per angle sample, breaks,
mending, calm and the tide's wave. `burst_cue.gd` and `burst_fx.gd` replace `gap_patch.gd` and `patch_fx.gd`. Removed: the
F patch, `edge_markers.gd`, `edge_marker_fx.gd`, `border_warning.gd`, strain rings, the tide's drain, the faltering
step-back and benching. Prompts and notices go to the banner under the night bar. Crowd separation uses a spatial grid.

Open-question defaults (for the playtest to settle):
- Mending: a break mends when no dimmed person is within 5 m and a member near it has had joy since it opened, or after
  25 s clear. That is "joy the ends, lift the spillers". Alternatives: joy the ends only, or rescue the spillers only.
- Recorder: keeps `gap_open` and `gap_close`; `gap_patched` no longer fires. Renaming to `break_*` is still open.

Coverage: commit `68e0cbf` restores `style_dawn` coverage (the idle styled cue panel draws as a quiet tag). Nothing loosened.

## 0.3 Living town plan (graphics checkpoint 7, 2026-11-07) (#2)

**Playtest (release build `da0dfb2`, styled look).** The environment needs more going on to drive home the beautification;
the buildings' industrial-to-whimsical swap alone is not enough. Three dislikes: the straight red-and-white line from the
zone centre showing the growth direction (the zone border shown while E is held is enough), the rings round people at the
start of the game (not needed), and the dithering (still too much after checkpoint 6 halved it).

**Decisions (interview).** All four environment ideas go in, plus the styled catch-up. Dithering is removed entirely.
The look depends on the work: placeholder for gameplay rounds, styled for graphics checkpoints, and releases always styled.

**Changes.**
1. Cleanup (both looks where the piece is shared):
   - Remove the stretch direction line from the centre to the tip (`reach_guide.gd`, `style_reach.gd`), with its tip disc
     and dashed line. Keep the zone preview while E is held and the finish pulse.
   - Remove the rings round people at the start. Identify them from a checkpoint shot of the calm opening first; if they
     carry any meaning later in the game, report instead of removing.
   - Remove all dithering from the styled look: shadow bands, glow halos, ground edges, sand ridges, the ribbon's halo and
     the reach pieces. Use smooth toon bands and soft alpha falloff instead. Keep the low resolution and the outlines.
2. Living ground (`style_ground.gdshader`, `ground_look_styled.gd`): inside the painted ground, grass tufts, wildflowers
   and moss in the cobble cracks, and puddles that catch warm light. Outside, cracked grey slabs, litter and dead leaves.
   The change follows the paint weight, so it sweeps outward as the zone grows and recedes if ground is lost.
3. Street props: lamp posts, benches, planters, market stalls, bunting and washing lines between buildings. In gloom they
   are dark, broken or bare; inside the zone the lamps glow warm, bunting unfurls and planters bloom (driven by the same
   paint weight or the nearest building's `beautified`). Props are scenery only: no collision, no effect on spawns or
   the rules.
4. Ambient life: butterflies by day and fireflies by night drifting inside the zone, birds landing on beautified rooftops,
   and rescued people idling there with small actions (sitting on benches, waving, tending flower boxes) when the rules
   leave them standing. Visual only: idling must not move a person's rule position.
5. Gloom atmosphere: low drifting mist and a cold, desaturated tint over the ground outside the zone, clearing inside it.
   The sky warms as night turns to dawn, and distant rooftops on the skyline light up as each landmark is restored.
6. Styled catch-up: the round 26 push (pushers' lean, the fog at a pushed stretch, the figures) in the styled look, and the
   styled Dusk to Dawn bar and spirit label.
7. Look by context:
   - A `--look=styled|placeholder` user argument picks the starting look. Exported builds (`OS.has_feature("template")`)
     start styled; F4 still switches. Tests keep running in the placeholder look.
   - `launch-playtest` passes `--look=placeholder` for gameplay rounds and `--look=styled` for graphics checkpoints.
   - The release build recipe (dist-builds memory) needs no flag, since exports start styled.

**Constraints.** Rules untouched: no scenery or ambient piece reads or writes the simulation, so determinism holds.
Performance: props and ambient life use MultiMesh or GPU particles; the `test_perf_*` budgets are not loosened, so
report if they don't fit. New checkpoint shots (`tools/checkpoint_shots.py`) for the calm opening, mid-night inside and
outside the zone, a push, and dawn, saved in `design/renders/checkpoint_07/`. README updated at the end (this is a
checkpoint), including the removed F patch.

**Build split** (four parallel worktree agents, each with its own config block "Checkpoint 7: <part>"; each removes the
dithering in the files it owns, so none waits on another):
- Part A (Sonnet): change 1 except the ground and ribbon dithering, and change 7. Owns `reach_guide.gd`, `style_reach.gd`,
  the people and toon shaders, `style_glow`, the start-look code and the `launch-playtest` skill.
- Part B (Sonnet): changes 2 and 5, plus the ground's dithering. Owns `style_ground.gdshader`, `ground_look_styled.gd`
  and the sky and view pipeline.
- Part C (Sonnet): changes 3 and 4. Owns new `scripts/looks/style_props.gd` and `style_ambient.gd`, plus one hook each in
  the scene.
- Part D (Haiku): change 6, plus the ribbon's dithering. Owns `border_look_styled.gd`, the ribbon shader and
  `style_hud*.gd`.
- Merge order D, A, C, B; then one `round_end.py` with the determinism check; then one Haiku pass for the checkpoint
  shots, README, ARCHITECTURE's Looks section and a styled playtest copy.

## 0.3 Living town built (graphics checkpoint 7, 2026-11-07) (#2)

Merged on `main` (cef18a1 part A, 4aebfe0 part C, ebf6c84 part B, and part D). Gate, determinism and baseline passed.
- **Part A (cleanup and look by context):** the stretch direction line and its tip are gone (the zone preview while E is
  held and the finish pulse stay); dithering removed from the reach pieces, glow halos and shadow bands;
  `--look=styled|placeholder` and the exported-build default. The rings round people at the start were not removed
  (see open item b).
- **Part B (living ground and atmosphere):** `style_ground.gdshader` and `ground_look_styled.gd` (grass, flowers, moss,
  puddles inside the paint, cracked slabs, litter outside; follows the paint weight), `style_atmosphere.gd` with
  `shaders/style_mist.gdshader` (mist, cold tint outside the zone, warming sky, skyline lights per landmark).
- **Part C (props and ambient life):** `style_props.gd` (lamps, benches, planters, stalls, bunting, washing lines) and
  `style_ambient.gd` (butterflies, fireflies, birds on beautified roofs, idling rescued people). Visual only.
- **Part D (styled catch-up):** the styled push (`style_push.gd`: pixel fog banks, figures), the styled Dusk to Dawn bar and
  spirit label, the ribbon's dithering and the HUD dithering.

Shots: `design/renders/checkpoint_07/` (`python tools/checkpoint_shots.py --set checkpoint7`): calm_opening,
midnight_inside_zone, midnight_outside_zone, push_in_progress, push_closeup and dawn, each in both looks, plus
contact_sheet.png and contact_sheet_compare.png.

Open items:
- (a) Dithering leftovers: the shared `bayer4()` helper and the `dither_amt` set in `ground_look_styled.gd` are no-ops or
  unused; the spirit meter fill head in `style_hud.gd` `_fill` still dithers; about 20 comments and test names still say
  "dithered"; `BEACON_GUIDE_PATH_COLOUR` and `BEACON_GUIDE_CAPPED_COLOUR` in the config are unused.
- (b) The "rings round people at the start": Part A found the only rings in the styled opening are the player's ground
  marker (a gold inner ring, plus an outer ring whose colour shows the target's element, `style_people.gd` about lines
  276-303). The outer ring means something later in the game, so nothing was removed. Needs the user to confirm whether
  the decorative inner gold ring is what they meant.
- (c) `tools/checkpoint/checkpoint_round24.gd` is broken: it references `main.gap_patch`, which the removed F patch took
  with it, so `--set round24` does not load. The checkpoint 7 set does not extend it.
- (d) The mist, skyline, props and ambient life were never viewed in a screenshot by the part agents. From the new
  shots: props are visible (a planter and a bench at the calm opening, lit stalls and bunting in the zone). Ambient life
  shows as fireflies inside the zone at mid-night. The mist is hard to pick out at mid-night outside the zone and needs a
  stronger or differently placed look. The styled look reports `tide_fog` and `tide_pointer` falling back to placeholder,
  and the push closeup shows dark round blobs that may be those placeholder pieces. Tune strength, colour and placement
  from these shots.

## 0.3.1 Living town fixes (2026-11-07) (#37, #39, #40, #41, #42, #43)

**Playtest (copy `9fa1b4e`, styled, recording 20261107-233106).** Win, 180 s, seed 42, 48 of 60 rescued, 2 of 3 dawn
lights (people 80%, ground 23%, 1 landmark: Garden at 50 s). 13 gaps (median open 4.9 s), 7 relapses from 10 wobbles,
2 tides (72 s south, 97 s north). 5 bursts lifted 1 dimmed in total. Embrace now used: 15 begun, 7 rescues. First light
lifted 13.
- Push fog reads as a grey block: `StylePush.build_fog` builds 9 opaque pale boxes (2.2 m tall) across 90% of the side.
- In the captured zone only the puddles read at play zoom (19.5); grass, flowers, moss, props and ambient life went
  unnoticed (too small, sparse or low in contrast).
- Bare bunting and washing lines between grey buildings read as lines on the ground the player walks over.
- Dithering is fine now, except the spirit meter's chequered tip. The start rings were not raised again: #38 is treated
  as settled unless the 0.3.1 playtest raises it (it stays in Backlog until then).

**Changes.**
1. Tidy (#37, #39):
   - Spirit meter fill head (`style_hud.gd` `_fill`): smooth or solid, no chequer.
   - Remove `bayer4()` from `shaders/style_common.gdshaderinc` (leave `design/style_test/` alone), the `dither_amt` set
     in `ground_look_styled.gd` (line 57) and `CP7_GROUND_LIGHT_DITHER`; the tests that assert `dither_amt == 0.0`
     (`looks_checkpoint6_test.gd:51`, `looks_checkpoint7_ground_test.gd:57`) assert the parameter is gone instead.
   - Remove the unused `BEACON_GUIDE_PATH_COLOUR` and `BEACON_GUIDE_CAPPED_COLOUR` (`config.gd` 34 to 35).
   - Reword comments and test names that still say "dithered" (scripts/, shaders/, tests/ only).
   - `tools/checkpoint/checkpoint_round24.gd`: drop the patch shots (the `main.gap_patch` calls near lines 129 to 170)
     so `--set round24` loads again. Check it loads; don't regenerate or commit old renders.
2. Storm cloud push fog and mist (#40): `StylePush.build_fog` becomes a low, churning storm cloud band with darker cores
   and a soft alpha edge (no dither), only as long as the stretch being pushed; figures half-hidden inside. Raise the
   mist (`CP7_MIST_*`) until it reads outside the zone at mid-night. Find why the styled look still notes `tide_fog` as a
   placeholder (`gloom_tide.gd:330`) and fix it if the storm cloud covers it. `tide_pointer` stays as it is: 0.4 (#14)
   replaces the two tides.
3. Reads at play zoom (#41): scale, density and contrast of the ground life (`CP7_GROUND_LIFE`, `style_ground.gdshader`),
   the props (`style_props.gd`) and ambient life (`style_ambient.gd`), judged from full-frame shots at zoom 19.5.
   `test_perf_*` budgets are not loosened.
4. Wires (#42): no bare lines in gloom; inside the zone, bunting is strung at roof height from visible posts
   (`style_props.gd` `layout_lines`, `_draw_line`).
5. Splash screen (#43): `boot_splash/show_image=false` in `project.godot` (made in the working tree, not yet played or
   committed). Optionally set `boot_splash/bg_color` to match the menu.

**Constraints.** Look only: nothing reads or writes the rules. Placeholder look untouched. New constants go in a
"0.3.1 Living town fixes" config block. Shots: add a play-zoom view to the checkpoint 7 set (calm opening, mid-night inside,
mid-night outside, push) and save the final set in `design/renders/v0.3.1/`. No README change.

**Build (token-lean: two agents in a row on `main`, no worktrees, one full gate).**
- **Tidy (Haiku, XS+XS):** change 1. Targeted suites and lint only, then commits. Goes first: it touches comments in
  files the look agent edits, so running in a row avoids a merge.
- **Look (Sonnet, S+M+XS):** changes 2 to 4, after Tidy commits. Screenshot budget: styled look only while tuning, the
  four play-zoom shots per round (read the contact sheet, not each frame), at most three rounds; the full both-looks set
  once at the end. Targeted suites and lint, then commits.
- **Coordinator (fresh Sonnet session, `finish-target`):** one `python tools/round_end.py` (with determinism, since
  tests/ changes), the docs, board items to In review, a styled playtest copy.
- Why not parallel: both parts touch `config.gd`, the style scripts and tests; worktrees start without the import cache
  (#6); a merge costs the coordinator. Running in a row costs only wall-clock.

## 0.3.1 Living town fixes built (2026-11-08) (#37, #39, #40, #41, #42, #43)

Three commits on `main`, in a row, no worktrees. All look-only: nothing reads or writes the rules.
- **Tidy (`5b0c493`, Haiku; #37, #39).** Spirit meter fill head is smooth (no chequer). `bayer4()`, the `dither_amt` set
  and `CP7_GROUND_LIGHT_DITHER` are gone, and the two tests now assert the parameter is gone. The unused
  `BEACON_GUIDE_PATH_COLOUR` and `BEACON_GUIDE_CAPPED_COLOUR` are removed. Comments and test names no longer say
  "dithered". The round 24 shot set loads again (patch shots dropped).
- **Look (`4a96cd8`, Sonnet; #40, #41, #42).** `StylePush.build_fog` is a low churning storm cloud band (new
  `shaders/style_cloud.gdshader`, darker cores, soft alpha edge) sized to the stretch being pushed, figures half hidden
  inside; `gloom_tide.gd` no longer notes `tide_fog` as a placeholder. Mist raised (`CP7_MIST_*`). Ground life, props
  and ambient life scaled up and given more contrast for zoom 19.5. Bunting is strung at roof height from visible posts
  and bare lines are gone in gloom. New play-zoom views in the checkpoint 7 set.
- **Fix pass (`db0ab21`, Sonnet; #40, #41, #42).** Mist seams removed (integer-hash value noise, `CP7_MIST_STRENGTH`
  0.4), bolder storm cloud, a `play_props_bunting` view, props scaled x1.8.
- **Splash (`5da1fd0`; #43).** `boot_splash/show_image=false` in `project.godot`.
- **Gate (2026-11-08).** `gate.py --full`: 839 tests, line coverage 99.9%, baseline OK. Determinism: both runs hit the
  same lines. Baseline updated. Nothing loosened.

**Open notes for the playtest.**
- Lamps and benches are still small next to the stalls.
- The tuning sheet of round 2 was checked by eye, but the final full-set renders in `design/renders/v0.3.1/` were not
  viewed one by one by the agent: look at them in the playtest.
- `tide_pointer` is still a placeholder piece in the styled look; 0.4 (#14) replaces the tides.
- #38 (start rings) stays in Backlog until this playtest says otherwise.

## 0.3.1 Living town fixes, playtest 2 (2026-11-08) (#44, #45)

**Playtest (copy `ed510f4`, styled, recording 20261108-062326).** Win, 180 s, 46 of 60 rescued, 2 of 3 dawn lights,
2 tides (72 s south, 97 s north), 0 relapses, 0 bursts. #37, #39 to #43 stay In review until the user accepts them.
- Butterflies hurt performance; the user wants fewer but larger ones.
- The ground looked strange: `shot_0004` and `shot_0002` show hard straight vertical edges in the painted ground, with
  puddles and grass cut into rectangles (at about x=265 and x=390 in `shot_0004`). Likely chunk or tile seams in
  `style_ground.gdshader` or `ground_look_styled.gd`, possibly from `db0ab21`'s noise rework. Not confirmed.
- Neither tide was seen: the player was on the far side both times, and the placeholder `tide_pointer` was the only cue.
  No 0.3.1 work: noted on 0.4's surge (#14), which must be seen wherever the player is.
- North is up the screen (-z).

**Changes.**
1. Butterflies (#44): `C7_BUTTERFLIES` 28 down to about 8 to 10, each larger (`L31_AMBIENT_SCALE` or a butterfly-only
   scale), and less per-frame work in `StyleAmbient.step` (each flyer redraws two wing boxes and calls
   `paint_weight_at` every frame: cache or throttle that). Measure ambient on and off with `perf_compare` before and
   after. `test_perf_*` budgets are not loosened.
2. Ground seams (#45): reproduce in a play-zoom shot inside the zone, find the cause, fix it so paint, puddles and
   grass flow across without straight edges. No dithering.

**Build.** One Sonnet agent on `main` (look and perf, same area), screenshot budget as before (styled play-zoom shots,
one contact sheet per round, at most three rounds), re-render `design/renders/v0.3.1/`. Then a fresh Sonnet session
runs `finish-target`.

## 0.3.1 Living town fixes, playtest 2 built (2026-11-08) (#44, #45)

One commit on `main` (`04d86e6`, Sonnet, Refs #44 #45), after the plan (`ef84ed5`). Look and perf only; nothing reads or
writes the rules.
- **Butterflies (#44).** 9 butterflies (was 28) at `L31_BUTTERFLY_SCALE` 4.2, a butterfly-only scale. Paint lookups
  are cached and rechecked every `L31_AMBIENT_RECHECK` 0.4 s, not every frame. One ambient step went from about
  0.49 ms to about 0.37 ms. New test `test_perf_the_ambient_step_with_a_full_zone_is_cheap` (budget 0.6 ms).
- **Ground seams (#45).** Cause: the float fract hash `hash21` and `vnoise` in `shaders/style_ground.gdshader` stepped
  at lattice lines on the GPU, giving straight vertical edges. All ground noise now uses the integer hash. New
  assertions in `looks_checkpoint7_ground_test.gd` and `style_scenery_test.gd`.
- `design/renders/v0.3.1/` was re-rendered; the coordinator checked the play shots and saw no seams.
- **Gate (2026-11-08).** `gate.py --full`: 843 tests, line coverage 99.9%, baseline OK. Determinism: both runs hit the
  same lines. Baseline updated. Nothing loosened.

**Open notes.**
- The butterflies were checked only by tests: no shot shows them (there is no daytime play view). Watch them in the
  playtest: size, count and whether they read.
- The ground fix was judged from the re-rendered play shots, not played: look for seams in the playtest.
- Lamps and benches are still small next to the stalls; `tide_pointer` is still a placeholder (0.4 #14); #38 stays in
  Backlog.

## 0.3.1 Living town fixes, playtest 3 (2026-11-08) (#46, #47; #48 targeted)

**Recording (copy `e53988c`, styled, 20261108-085302).** Win, 180 s, seed 42, 48 of 60 rescued, 2 of 3 dawn lights
(people 80%, ground 24%, 1 landmark). Quiet time 2.8% strict / 21.8% relaxed. 12 gaps (median open 2.8 s, max 10.1 s),
3 relapses, 3 bursts. 2 tides (72 s south: 4 gaps; 97 s north: 2 gaps), 0 wobbles or relapses from them. 2 beacons
(+94 sq m). Embrace: 8 begun, 4 rescues (mean 18.0 s). First light finished.

**Feedback.**
- Butterflies: size and count are good (#44 accepted). Their styling needs work: future item (#46, Backlog).
- Ground: looked better, no seams noticed (#45 accepted).
- Storm cloud: better and more obvious (#40 accepted). The push needs more impact and more ability to play around it:
  future discussion (#47, Backlog; ties in with 0.4's surge, #14).
- Props: not many noticed at play zoom. Ground life and ambient life from #41 are accepted; props split out as #48,
  targeted in 0.3.1.
- Splash screen: gone (#43 accepted).

**Props (#48), plan.** Props are laid out from the building blocks (`StyleProps.layout_props`), so most sit at the plaza
edge, away from where the player spends the night; lamps and benches are also small next to the stalls
(`L31_PROP_SCALE` 1.8, `L31_PROP_LIFT` 0.55).
1. Count where props land in a normal night (how many are on screen at zoom 19.5 around the player's usual path) before
   changing anything, and say what the cause is: placement, size or contrast.
2. Spread more props into the open plaza and along the routes the zone grows into (still scenery only: no collision,
   no effect on spawns or the rules), and make lamps and benches bigger and warmer so they read beside the stalls.
3. Check in play-zoom shots at calm opening and mid-night inside the zone (styled only, at most three rounds), then
   re-render `design/renders/v0.3.1/`. `test_perf_*` budgets are not loosened.
Build: one Sonnet agent on `main`, then the finish step in the existing finish session.

## 0.3.1 Living town fixes, playtest 3 built (2026-11-08) (#48)

One commit on `main` (`ff76b8e`, Sonnet, Refs #48), after the docs commit `46ee7bd`. Look only; nothing reads or writes
the rules. Props are scenery only.
- **Cause.** Before the change there were 0 props in the play-zoom frame in a normal night: every prop stood at a
  block 25 m or more out. The cause was placement, not size or contrast.
- **Placement.** New `StyleProps.layout_plaza` puts about 50 lamps, benches and planters on a deterministic 12 m
  lattice in the open plaza.
- **Size.** Lamps are 1.35x bigger and benches 1.4x bigger (new constants in `config.gd`).
- **Bug fixed.** Soft balls (lamp glow, planter flowers, stall goods, fireflies) were painted over by the post-process
  quad. They now draw at `L31_SOFT_PRIORITY`. Fireflies therefore also show as soft glows now: a visible change.
- New suite `tests/style_props_plaza_test.gd`. `design/renders/v0.3.1/` re-rendered. The ambient perf test held at
  0.36 ms.
- **Gate (2026-11-08).** `gate.py --full`: 849 tests, line coverage 99.9%, baseline OK. Determinism: both runs hit the
  same lines. Baseline updated. Nothing loosened.

**Open notes for the playtest.**
- The lamp halos are large pale discs: check they don't look like holes or blobs.
- Fireflies now show as soft glows (they were invisible before): check that they read well at night.
- The calm opening has a bright orange bench near the start: check it isn't distracting.
- #37, #39 and #42 are still In review until the user accepts them.

## 0.3.1 Living town fixes, playtest 4 (2026-11-08) (#37, #39, #42, #48; #49, #50 new)

Played `0846a4c` in the styled look (recording `20261108-120438` in the playtest copy): a win in 3:00, 41 of 60
rescued, 2 of 3 dawn lights (people 68%, ground 16%, 1 landmark), 16 gaps (none in the easing phase), 11 relapses,
4 bursts, 2 beacons.
- Props (#48 accepted, Done): lamps and benches are visible at play zoom now. Their styling doesn't fit well: lamps
  (#49) and benches (#50), both in 0.3.2.
- Fireflies as soft glows: awesome, keep them.
- #37 and #39 accepted (Done).
- Wires (#42) not accepted: the player is still taller than the wires. Moved to 0.3.2.
- 0.3.1 Living town fixes is done (2026-11-08), internal only: milestone closed, no tag.

## 0.3.2 Prop styling plan (2026-11-08) (#42, #49, #50)

A look-focused target: styled look only, nothing reads or writes the rules. Look direction agreed with the user on
2026-11-08. Today a lamp is a thin post, a ball and a big pale disc (`StyleProps._draw_lamp`), and a bench is a plank,
a back and two legs (`_draw_bench`); both only change colour as they bloom. Both now change shape too (style pillar:
props transform, not just colour), keeping the existing `bloom` (0 grey, 1 warm) and the 0.3.1 sizes and placement.
- **Lamps (#49).** In gloom: a stiff iron gas lamp with a caged glass head. As it blooms, vines curl up the post (with
  a few small leaves or flowers near full bloom) and the glass glows amber.
  - **Light.** Replace the big pale disc with a soft cone of light from the head down to a pool on the ground, plus
    a small glow at the head. The light is cool (pale blue-white) on the gloom side and a warm, cheery amber on the
    light side, following `bloom`. It is stronger at night; by day it is faint or off.
  - The cone and pool are soft unlit shapes drawn at `L31_SOFT_PRIORITY`, so the post-process quad doesn't paint over
    them. They must not hide people or gaps.
- **Benches (#50).** In gloom: a riveted grey metal bench. As it blooms: wooden slats, curled iron ends and a small
  cushion or blanket in the earthy joy palette. No single bright colour stands out in the calm opening (the orange
  bench near the start). The same shading and outline as the buildings.
- **Wires (#42).** Bunting wires and their posts sit above the player's head height everywhere, so the player never
  looks taller than them at play zoom.
- Planters and market stalls are not restyled in 0.3.2 (the user's call); restyle them later if they clash.
- Shots: styled play-zoom shots only (`checkpoint_shots.py --set checkpoint7 --play-only`), one contact sheet per
  round, at most three rounds; save the final set in `design/renders/v0.3.2/`. Check the lamps both in gloom and inside
  the zone at night. The ambient and props perf tests hold; `test_perf_*` budgets are not loosened.

Build: one Sonnet agent on `main` (about 400k tokens for all three; the cone of light may need a new soft-shape layer),
then the finish step in a fresh Sonnet session.

## 0.3.2 Prop styling built (2026-11-08) (#42, #49, #50)

One commit on `main` (`7216aa4`, Sonnet, Refs #42, #49, #50), after the docs commit `75e5c9d`. Look only; nothing reads
or writes the rules. New constants are in the "0.3.2 Prop styling" block of `config.gd`; new suite
`tests/style_props_032_test.gd`; final play-zoom shots in `design/renders/v0.3.2/`.
- **Lamps (#49).** A stiff iron gas lamp with a caged glass globe. Vines, leaves and a few flowers grow up the post with
  bloom. The big pale disc is gone: a soft cone (new MultiMesh layer, `shaders/style_lamp_cone.gdshader`) runs down to a
  pool on the ground (`shaders/style_lamp_light.gdshader`), plus a small glow at the head. The light is cool blue-white
  in gloom and warm amber in bloom, strong at night and faint by day; all alphas stay below 0.35.
- **Benches (#50).** Riveted grey metal in gloom (slats packed solid). In bloom: wooden slats, iron arms and curls, and
  a cushion and blanket in dusty blue, terracotta or sage. No bright bench colour in the calm opening.
- **Wires (#42).** The styled player measures about 3.1 m (in a test). Posts are now 5.3 m, sag 1.0 / 0.4, and reach
  full height at unfurl 0.4; the lowest drawn point is 3.46 m, above player height plus 0.3 m.
- **Gate (2026-11-08).** `round_end.py`: `gate.py --full` 860 tests, line coverage 99.9%, baseline OK (427 s);
  determinism: both runs hit exactly the same lines (290 s); baseline updated. Nothing loosened.

**Open notes for the playtest.**
- The vines on the lamp posts are small and dark at play zoom; the build agent brightened them but didn't re-check.
- The bright orange plank near the start in the calm opening is a stall or planter, not a bench. Restyling it is out of
  scope for 0.3.2: ask the user.
- The benches don't match the buildings' shading and outline beyond the toon boxes.
- Check the cool lamp light in the gloom, the warm light inside the zone, and the bunting above the player.
- #42, #49 and #50 were In review until the playtest below.

## 0.3.2 Prop styling, playtest 5 (2026-11-08) (#42, #49, #50)

Played `1fb5a53` in the styled look (recording `20261108-235246` in the playtest copy): a win in 3:00 (seed 42, 60
people), 40 rescued, 1 first light finished (20 lifted), 12 gaps, 5 relapses, 2 bursts, 3 beacons, 1 landmark (Garden).
- Wires (#42): look good. Accepted, Done.
- Benches (#50): acceptable. Accepted, Done. (The shading and outline still differ from the buildings; not pursued.)
- Lamps (#49): good. Accepted, Done.
- The bright orange plank near the start is a stall or planter: yes, restyle it (#51, Backlog, XS).
- Town layout: the props are good but haphazardly placed, and it doesn't look like a town. Place props, stalls and
  buildings in an organised arrangement (#52, Backlog, M). Needs a design talk first (streets, rows, squares?).
- Released as `v0.3.2` (2026-11-09) on GitHub: asset `PositiveFPS-3d52b58.7z`. Milestone 0.3.2 closed.

## 0.3.3 Town layout plan (2026-11-09) (#52, #51, #17, #5, #6, #7, #8, #9, #19, #20, #21, #23)

Targeted 2026-11-09 with the user (Ready, milestone "0.3.3 Town layout"). The town layout is the centre; the small tooling
and code-health items ride along in the same pass (batch small items; most are Haiku-sized).
- **Town layout** (#52, L, with #51 XS): the design below. **#17** (M) moved here from 0.4 Tug of war: the denser town
  layout and the fourth landmark (Gallery) with the landmarks pulled in to 18 to 32 m of the start (see the 0.4 plan,
  "Landmarks unlock defences; denser layout"). In 0.3.3 the Gallery is placed and claimable only; its dent-fade
  protection and the defence unlocks stay in 0.4, which needs the dents and defences.
- **Tooling** (from the 0.4 "Quick wins", unchanged text there): #5 and #6 (S), #7, #8, #9 (XS); plus #20 (agent dashboard
  shows finished agents as running) and #23 (recorder `gap_*` to `break_*`: a decision first) (XS each).
- **Code health:** #19 (remove unused code, XS) and #21 (minimap redraw spike, S).
- Order: the tooling and code-health items first (no look change), then the layout, which needs shots and a bot-night
  check. One Sonnet agent for the layout; one Haiku pass for the small items; parts in separate worktrees if run together.

### Town layout design (#52, #51)

Design talk after the v0.3.2 release. Today the ten buildings (`TopDownMain.BLOCK_POSITIONS`) are hand-placed at scattered
spots, and the plaza props sit on an even lattice (`StyleProps.layout_plaza`) unrelated to them: items are good but
read as scattered. Decisions (interview, 2026-11-09):
- **Shape: streets and rows.** A main street plus cross streets; buildings line them and face the street.
- **Buildings: more and denser,** about 16 to 24 blocks (the 0.4 plan already wants buildings and landmarks denser).
- **Props follow the streets:** lamps at regular spacing along the kerbs, benches and planters beside buildings or at a
  small square, stalls on the square. This replaces the plaza lattice.
- **Scope: look and placement only,** no new rules. Building positions are shared by gameplay (rescues, landmarks,
  boosts, `_near_block`), so moving them still needs the full gate, a bot-night check of the difficulty, and the
  landmarks kept reachable.
- Open for the plan: street plan sketch (shots first, as for a look-focused target), how the border and the start
  plaza sit on the streets, the orange stall or planter restyle (#51) rides along.
- Size: L (was M). Built in 0.3.3, before 0.4 Tug of war, since both touch where buildings stand.

## 0.3.3 Town layout, playtest 1 and fix plan (2026-11-09) (#53; #52, #51, #17, #5 to #8, #19 to #21 In review)

Played commit 760d19c (165 s, quit, 38 rescued, zone 870 sq m, three landmarks claimed, Bell tower lost once). The user
liked the buildings, but **zone control is glitchy because of them**: on watching the replay, people were bunched in the
middle of the zone, the border snagged, and people got stuck. It happens as the zone grows. Nothing accepted yet; all
0.3.3 items stay In review. The recording shows 13 to 31 people gloomy throughout and 9 gaps opened by the second tide
with only 5 members on that side; it logs no member positions, so the cause is unproven. Task #23 (recorder gap_* to
break_*) is back at Ready, undecided.

### Fix plan: Zone control around buildings (#53, M)

Probable cause: the 20 blocks of the street grid sit inside the growing zone and in the way of members walking to the
border's rest shape (and of rescued people walking in), so they bunch against block faces and corners. One Sonnet agent,
sequential:
1. **Reproduce first.** In a bot run (as the bot-night check in .scratch/botnight.gd) log member and rescued-person
   positions and speeds against the blocks; find where people stall (block corners, the 10 m streets, gaps between
   rows) and why the border rest shape and member spacing misplace them. Confirm before changing anything; put the
   finding in the commit message.
2. **Fix the cause found.** Likely options, cheapest first: members and rescued people steer around blocks (slide along
   faces, or target a point on the street side) instead of pushing into them; border sample positions that fall inside
   a block are moved to the nearest street edge; rest-shape pulls ignore the block footprints. Keep it to behaviour
   near blocks: no new rules, placeholder look only.
3. **Prove it.** A test that puts members and a rescued person behind a block and asserts they reach their targets in
   a set time; a bot-run comparison before and after (members used per rescued count back near the old 28, no one stuck
   more than a few seconds); `gate.py --full` and the determinism check (it touches the simulation).
4. Not in this fix: moving or removing blocks (the layout is liked), the Gallery art, the defences.

Then replay the same pass for the user's playtest 2.

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
