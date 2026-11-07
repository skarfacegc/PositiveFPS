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
- **Gloom:** unrescued people go wistful, gloomy, then dimmed. Dimmed people lean on the border and reach for the player.
  The night has phases: calm opening, rising, midnight (hardest, dimmed sinks staggered by `DIM_ARRIVAL_MIN_GAP`), easing.
  Two gloom tides a night (rising, midnight) are a visible wave of fog with figures that rolls in and shoves one side.
- **Border (physical push, round 26):** rescued people form a loop. Only visible things push it: dimmed people leaning on
  it and the tide's wave. The line bends inward where it is pushed (loop and members move, members brace and lean) and
  springs back when relieved; past `PUSH_BREAK_DEPTH` it snaps (a break; gaps from too few people still exist). Pushers walk
  through a break and dim what is inside until it mends. Joy at a pusher weakens its push; joy at a bending member (or a
  burst) calms the spot. A member drained too far wobbles about five seconds before relapsing; a joy hit saves them.
  Relapses are gated (`RELAPSE_GATE_GAP`). Details and the open questions: "Round 26 build" below.
- **Spirit:** 0 to 100, start 50; +20 a rescue. At 0 the player goes dim (half speed, no fire, border loses heart). Spare
  spirit at a full meter pools and warms the most strained border member (`spirit_warmth.gd`).
- **Spirit actions:** beacon (50): hold E to aim a zone preview, release to place, right-click cancels; the zone stretches
  toward it and the arm stays, limited by headcount. (The F patch was removed in round 26.)
  G or Q (30, 8 s cooldown) bursts: lifts dimmed people nearby, pushes back those on the border line and lets the line
  near the burst spring back.
- **Landmarks:** Bandstand, Garden (about 14 m from the start), Bell Tower. Holding one (3 s inside the border) boosts
  joy; the third dawn light needs 75% rescued and 2 landmarks.
- **First light:** over the last 45 s a square front moves in from the map edge; people it passes lift and stop draining.
- **Cues:** the bending line is the warning (ribbon colour and width follow the bend; members lean and struggle); gap
  arrows point at an off-screen break, wobble edge pointers and minimap blips, landmark pointers, a cue panel beside the
  spirit meter (glows when G can be used). Prompts and notices are one slim banner under the night bar, one at a time.

**Controls.** WASD move, Shift run, mouse to point, hold E / release E beacon (right-click cancels), G or Q
burst, F2 targeting mode, mouse wheel zoom, F3 debug, F4 switch look, R restart, M menu. Menu: Play (Enter, 1, click), Look.

**Look modes.** Placeholder (default, plain shapes, what the tests run) and styled (pixel-diorama 3D: toon, outline, ground
and post shaders, in a 640x360 SubViewport). F4 or the menu switches mid-game. Gameplay rounds touch the placeholder only;
the styled look changes only in graphics checkpoints (latest: checkpoint 6: first light ring, styled HUD text and target
ring, notices as slim banners under the night bar, half the dithering, a real jog). Still placeholder in styled mode: the
Dusk to Dawn bar, the spirit label, and the REC and F3 labels; the styled HUD text uses the fallback font, not a pixel font.

**Open items** (each checked against the code on 2026-11-07):
- Checkpoint 6 needs a playtest look: the notice banner under the night bar and the styled target ring are covered by
  geometry tests but have no full-frame screenshot.
- First light lifts fewer people now the front is round (it reaches the plaza edge about 13 s in); watch the FIRST LIGHT
  numbers (20 lifted in the last game).
- Gap arrows (like the wobble pointers) now sit at the edge of the safe band, so a gap straight north shows its arrow part
  way down the screen.
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
- Wider-world and progression ideas (`VISION.md`) are not scheduled.

**Resolved items** are listed in `IDEAS_RESOLVED.md` ("Resolved since they were last listed").

**Push status.** `origin/main` is `4d8ea8d`; rounds 23 onward are unpushed (local main is ahead). Rounds are not pushed
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


## Round 25 plan: border control (2026-11-07)

**Why.** The user wants border control to be the mechanic to dig into. Today it has one verb (stretch toward a point) and
one reason (get landmarks and ground inside). This round adds a reason to reach out (Embrace) and a reason to pull in
(gloom tides), so every beacon is a choice. The user also finds the border edge visually chaotic under pressure: too
many per-person effects stacked on the same few metres while dimmed bodies overlap the members. Ideas kept for later:
Brace (pull a section in two deep), Gate, arrange the ranks (elements by side), lanterns and posts, hearths, stragglers,
smothering gloom sources, carry the light, pinch into two loops.

**Interview answers.** Embrace: rescue outright; about 8 s a stage; a little extra strain on the nearest members; warm
glow and a fill ring. Tides: drain that side harder (no dimmed wave); two a night, rising and midnight; about 15 s
warning on the minimap and one on-screen edge pointer; no element yet. Edge cleanup: all four suggestions, in both looks
(the user asked for it as graphics work); all three parts in parallel.

### Plan (three parts in parallel)

- **Part R, edge cleanup (Sonnet), both looks:** the border is drawn as one continuous ribbon through its members, gold
  when healthy, amber when strained, coral and thin near breaking; a gap is a real break in it. This replaces the
  per-person strain rings, light columns and breach rings. Pushes show as inward dents in the ribbon, deeper for harder
  pushes. One marker per trouble spot (priority gap > wobble > strain > warm gift), at most 4 on screen, gaps shorter than
  half a second never shown. Dimmed people outside the border are drawn at lower contrast (or a soft vignette outside).
  Patch, burst and gift effects are brief and replace rather than stack; no tall light columns.
- **Part S, Embrace (Sonnet):** an unrescued gloomy or dimmed person inside the border loop lifts one stage about every
  8 s (dimmed, gloomy, wistful) and is rescued at the end (joins the border like any rescue). While someone is embraced the
  nearest border members drain a little faster. Cue: a warm glow and a ring filling toward the next stage (placeholder
  look; styled in a later graphics checkpoint). Recorder events and an EMBRACE line in `analyse_recording.py`.
- **Part T, gloom tides (Haiku):** two tides a night, one in the rising phase and one at midnight, each from a side picked
  from the seed. About 15 s before it hits: a fog edge on the minimap and one on-screen edge pointer (inside
  `HudSafeArea`). While it passes, border members facing that side lose joy faster. A short, thick side should hold; a
  long thin arm there should wobble. No dimmed wave, no element. Placeholder visuals for the fog. Recorder events and a
  TIDES line in `analyse_recording.py`.

**Playtest questions:** does reaching out to embrace feel worth it; is the tide warning readable and the hit fair; can
you now read what is happening at the edge when it is pushed?

## Round 25 build (2026-11-07)

Three parts in parallel, merged S (Embrace, `75ed049`), T (tides, `4bb7613`), R (edge cleanup, `ba7af84`); conflicts in
`config.gd`, `recorder.gd`, `topdown_main.gd`, `analyse_recording.py` and `SOURCE_MAP.md`, all kept both sides.
- **Embrace** (`embrace.gd`, `looks/embrace_cue.gd`): inside the loop a person gathers 1 s/s; every 8 s a stage lifts,
  wistful is rescued through the normal path. Outside, progress fades at 0.25 s/s. The 3 nearest members lose 8 joy/s per
  embraced person. A relapsed person is skipped for 20 s (stops a relapse-and-re-embrace spirit farm). Placeholder glow
  and filling ring in both looks.
- **Gloom tides** (`gloom_tide.gd`, `tide_pointer.gd`): two a night from the level seed (rising 0.30-0.42, midnight
  0.50-0.60), 15 s warning (minimap fog arcs, grey edge pointer, notice), 12 s passing, facing members (90 degree sector)
  drain 2x. Multiplier on normal drain only. Off under tests unless `Config.tides_override = 1`.
- **Edge cleanup** (`edge_ribbon.gd`, `edge_strip.gd`, `edge_markers.gd`, `edge_marker_fx.gd`, `edge_dim.gd`, shader
  `style_ribbon`): one ribbon through the members, dents for pressers, at most 4 markers by priority, faded dimmed
  outside, short non-stacking effects; strain rings, patch posts, light columns, breach rings, the styled wobble ring and
  the warm disc removed; `style_beam` and `style_haze` deleted.
- **Tooling:** the coverage instrumenter broke on inner classes (`class Stop:`), so every suite loading them failed under
  coverage; inner-class lines now probe through `CovProbe.counts(...)` (`e269e2a`). `round_end`'s worker used
  DETACHED_PROCESS, so every child opened a console window; now CREATE_NO_WINDOW, and run_tests/godot_run too
  (`9fbb8f1`). Coverage tests for `intro.gd`, `border_look_styled.gd` and `minimap.gd` (`6209e59`). Agents still started
  background polling loops despite the brief; the brief now says so explicitly.
- **Loosened:** nothing. The parts' changed tests asserted visuals that are gone (listed in the agents' reports).

## Round 25 playtest and round 26 plan (2026-11-07)

Played `9fbb8f1` twice, placeholder then styled (`20261107-103701`, `20261107-104010`, in `recordings/playtests/round25/`):
two wins, 52 and 48 rescued, 2 of 3 dawn lights each (people 87% and 80%, but only 1 landmark held). Much calmer than the
last game: 27 and 28 gaps (52 before), 0 wobbles and 0 relapses (17 and 11 before). Tides came from the south at 72 s
and the north at 97 s in both games (same seed); no wobbles, 9 gaps during the north one. Embrace began 9 and 5 times,
lifted 2 and 6 stages, rescued 1 and 3 (16 and 21 s). First light lifted 9 and 12 (20 with the square).

**What the user said:** the edge is better but still busy: markers and rings, and text and prompts (e.g. "A gap! Help the
faltering one (!) to close it." over the spirit bar). They did not notice Embrace or the tides. Too easy now.

### Plan (two parts in parallel) — superseded by the replay below

- **Part U, edge declutter 2 (Sonnet), both looks:** fewer and quieter markers and rings: the ribbon already shows strain,
  so strain gets no marker of its own (only gaps and wobbles get markers, at most 3), markers smaller and calmer; check the
  player's and target rings do not stack on border spots. Text and prompts: help prompts and notices go to the slim banner
  slot under the night bar (not over the spirit bar), shorter wording, one at a time. Stay out of tide visuals.
- **Part V, tides you notice (Sonnet), both looks:** tides bite: a base drain on facing members while the tide passes, even
  where nobody presses, sized so a long thin arm on that side wobbles and a short thick side holds. Stronger visual: a fog
  wall visibly rolling in on screen from that side, and the ribbon and members on that side tinted grey while it passes.
- Embrace unchanged this round (the user did not choose a change); watch whether it gets noticed once the edge is quieter.

## Round 25 replay and revised round 26 plan (2026-11-07)

Replayed the same build (`2c32b30`, no game changes since `9fbb8f1`), placeholder look (`20261107-135118`, in
`recordings/playtests/round25/`): win, 55 rescued, 3 of 3 dawn lights (people 92%, ground 26%, 2 landmarks held). 55 gaps
(27 and 28 before), 43 of them at midnight; the north tide at 97 s opened 27 (9 before), but they closed fast (median
2.1 s). 1 wobble, 1 relapse. No patches, 3 bursts. 5 of 5 beacons reached. Embrace began 5 times, 3 rescues (13.3 s).
Strict quiet time 9.5%.

**What the user said:** still too easy. Noticed neither the tides nor Embrace. Gaps and pressure do not read: the ambient
pressure and the pressure from individual dimmed people blur together. Wants only pressure, pushing in, until the line
gives and lets dimmed people inside, with a more physical look. The F patch does not parse; remove it for now.

### Revised plan: physical push (one Sonnet agent; the pieces depend on each other)

Replaces Parts U and V above. Both looks get the mechanics; visuals in the placeholder look (styled only at a checkpoint).

- **Only visible things push.** Dimmed people leaning on the border, and tides as a visible wave of gloom (fog with
  figures in it) rolling in and shoving one side. Remove the invisible ambient strain on members with nobody near them.
- **The line bends inward** where pushed (members are shoved back, the loop dents) and springs back when relieved.
  Members visibly brace (lean and plant), struggling more as the push grows. Not chosen: members spreading apart.
- **Break.** Past a dent-depth limit the line snaps at that spot. The pushers spill through and dim the painted land and
  people inside until the hole is mended. "Gap" is no longer a separate idea: a gap is a break made by pushing.
- **Fighting back:** joy at the pushers weakens their push (and can still rescue them); joy at bending members makes them
  push back out; burst (G/Q) shoves the pushers away and lets the line spring back. **Remove the F patch** (key, spirit
  action, cue panel entry, prompts, docs).
- **Cues:** the bending line is the warning, so strain markers and rings go; keep at most a pointer for an off-screen
  break. Help prompts and notices go to the slim banner under the night bar, shorter, one at a time.
- **Difficulty:** the push model should make the game harder than now (the user finds it too easy); midnight and tides
  are where the line should really bend and sometimes break.
- Embrace unchanged; watch whether it gets noticed.
- **Requirement: faster crowd movement.** Profiling (2026-11-07, test-speed work) found `CrowdMovement.update_people`
  the largest per-frame cost when people wander (3.6 ms of 6.5 ms per headless frame): `_separation` checks every
  person against every other and calls `people.find(p)` each time. While the push model rewrites this area, replace
  that with a spatial grid (or similar) and a cached index. Results must stay the same for the same inputs (the
  determinism check depends on it): add a test comparing old and new separation on a fixed crowd, and report the
  per-frame time before and after. Also profile `Border.update` (2 to 3 ms per frame with 20 to 30 members) once
  the push model is in, and report what dominates (fix it only if it is simple and keeps results the same).
- **Requirement: clear the coverage baseline.** The baseline has refused since round 25: total line coverage would
  fall from 99.8% to 99.6% because round 25's new scripts entered below 100% (`edge_dim` 90.9%, `embrace` 93.5%,
  `gloom_tide` 94.3%, `edge_ribbon` 97.4%, `edge_marker_fx` 97.9%, `embrace_cue` 98.0%). Add tests for whichever of
  these survive the push rewrite, so the round end's baseline update passes without `--allow-decrease`.
- **Test shape:** the gap, patch, feedback and edge suites get rewritten here anyway; write the new ones as small,
  focused tests (short scenarios, one behaviour each) rather than whole-night scenarios, so the commit hook's fast tier
  can skip them for unrelated changes.
- Open questions for the build agent to report, not decide alone: how a break is mended (rescue the spillers, joy the
  broken ends, or both) and whether the recorder/analyser keep "gap" event names or move to "break".

## Round 26 build: physical push (2026-11-07)

Built as the revised plan above. Scripts: `border_push.gd` (new), `burst_cue.gd`/`burst_fx.gd` (the old `gap_patch.gd`/`patch_fx.gd`
without the patch), `gloom_tide.gd` (wave and figures), `border.gd`/`border_slots.gd` (dent in the loop, breaks as gaps),
`person.gd` (`push_mult`, `joy_hits`, `brace`), `intro.gd`/`prompt_bar.gd` (banner only). Gone: the F patch, `edge_markers.gd`,
`edge_marker_fx.gd`, `border_warning.gd`, the strain rings and minimap strain rings, the tide's drain, the faltering step-back
and benching. Constants: `scripts/config.gd` "Round 26: physical push" and the tide block.

- **Model:** force per angle sample = pushers (each `PUSH_PER_PERSON` x night strength x their push strength, spread as a bell,
  more from a tired member) + the tide wave. Dent follows force at most `PUSH_GIVE_SPEED` m/s deeper and `PUSH_SPRING_SPEED`
  back; the dent is applied to the loop after the size factor. Past `PUSH_BREAK_DEPTH` (2.4 m) the line snaps (3 samples wide).
- **Mending (default, easy to switch):** a break mends when no dimmed person is within `PUSH_MEND_CLEAR` and a member near it
  has had joy since it opened (`PUSH_MEND_NEEDS_JOY`), or by itself after `PUSH_MEND_AUTO` s clear. On mending the dent is
  halved. That is "joy the ends and rescue/lift the spillers". Open question (a) for the user: joy the ends only, rescue the
  spillers only, or both.
- **Event names:** the recorder keeps `gap_open` / `gap_close` (a break shows as a gap); `gap_patched` no longer occurs (the
  analyser still reads old files). Open question (b): move to `break_*`?
- **Difficulty numbers** (scratch whole-night runs, 30 rescued on a ring, seed fixed): nobody helping: the rising tide (80 s)
  and the midnight tide (102 s) each break the line, 5 breaks in the night, the border loses all but 2 people by 140 s. A
  generous bot (joy at the nearest pusher 3 times a second and at braced members) holds: the rising tide bends the line to
  96% of the limit, 1 break at midnight open 0.3 s. A human plays between the two. Tuning knobs: `TIDE_PUSH` (2.0),
  `PUSH_PER_PERSON`, `PUSH_DENT_PER_FORCE`, `PUSH_BREAK_DEPTH`.
- **Speed:** crowd `update_people` 3.0 ms to 0.75 ms per frame (grid). `Border.update` is 1.5 ms with 28 members: slot
  assignment 0.8 ms (order the people round the loop 0.35, find slot points 0.15, outermost picks 0.12), the loop 0.36 ms,
  building share 0.15 ms, the push 0.07 ms. Not changed (the cheap fixes would not keep the results bit-identical).
- **Not done / for a look:** no styled-look change (the styled people do not lean; the tide fog and figures are placeholder
  only); README.md still describes the F patch (not touched this round).
