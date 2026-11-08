# PositiveFPS — Game Ideas

Finished round history and resolved issues live in `IDEAS_RESOLVED.md` (one line per round at its top). This file keeps
the current state, the standing ideas and backlog, and the latest rounds. To find code use `SOURCE_MAP.md`
(`python tools/source_map.py`); for where things live and how to brief an agent use `ARCHITECTURE.md`.

## Current state (as of 2026-11-07, after round 26: physical push)

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
the styled look changes only in graphics checkpoints (latest: checkpoint 6: first light ring, styled HUD text and target
ring, notices as slim banners under the night bar, half the dithering, a real jog). Still placeholder in styled mode: the
Dusk to Dawn bar, the spirit label, the REC and F3 labels, and the push's lean, fog and figures; the styled HUD text uses
the fallback font, not a pixel font.

**Open items** (each checked against the code on 2026-11-07):
- Checkpoint 6 needs a playtest look: the notice banner under the night bar and the styled target ring are covered by
  geometry tests but have no full-frame screenshot.
- First light lifts fewer people now the front is round (it reaches the plaza edge about 13 s in); watch the FIRST LIGHT
  numbers (20 lifted in the last game).
- Gap arrows now sit at the edge of the safe band, so a gap straight north shows its arrow part way down the screen.
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
- README.md still describes the F patch (update at the next graphics checkpoint or on request).
- Unused: `Person.React.PATCH` is never set by gameplay (only tests set it); `config_base.gd` `GAP_HEAL_DELAY` and
  `MEMBER_FALTER_STEP_BACK` are read nowhere. Remove them or give them a use.
- Difficulty is tuned only by bot nights (knobs `TIDE_PUSH` 2.0, `PUSH_PER_PERSON`, `PUSH_BREAK_DEPTH`), so it needs a
  playtest.
- The styled look has no lean, fog or figures yet (placeholder only).
- Open question: should the recorder rename `gap_open` / `gap_close` to `break_*`?
- Whether Embrace gets noticed (it did not in the round 25 playtests).
- Wider-world and progression ideas (`VISION.md`) are not scheduled.

**Resolved items** are listed in `IDEAS_RESOLVED.md` ("Resolved since they were last listed").

**Performance.** Crowd separation uses a spatial grid and a cached index: `CrowdMovement.update_people` 3.0 to 0.75 ms per
frame, identical results. `Border.update` is 1.5 ms at 28 members (slot assignment 0.8, polygon 0.36, buildings 0.15,
push 0.07); not changed, since the cheap fixes would not keep the results identical.

**Push status.** `origin/main` is `da0dfb2` (round 26, pushed 2026-11-07, released as `pre-alpha-2`). Rounds are not pushed
until the user asks.

**Pointers.** `README.md` (player docs), `ARCHITECTURE.md` (script map, tools, gotchas, areas and files per system),
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

## Open ideas (unscheduled)
- Extra elements: food/cooking and play/sport (five elements also make a clean cycle); new elements could unlock via rebuilt buildings (bakery, playground) with new people of that affinity.
- Building to unlock mapping (music shop: guitar upgrades, garden centre: flower variants, cafe: healing item).
- Enemy tiers and bosses: light routine people as the bulk, grey normal, dark spreaders rarer and tougher; bosses such as a heavily gloomed figure with a big aura, in a dedicated later round.
- Visual progression: the town goes from desaturated to full colour as it is rebuilt; the placeholder look is plain, a richer style comes in graphics checkpoints.
- Wider world and level progression ideas: see `VISION.md`.

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

## Graphics checkpoint 7 plan (2026-11-07)

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
