# PositiveFPS — Game Ideas

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

## First proof of concept (POC)
Goal: find out whether reading cues, picking the right element and helping as many people as possible before the clock runs out is fun.

- **Engine:** Godot 4 (GDScript)
- **Controls:** standard FPS conventions: WASD move, mouse look, Shift run, 1/2/3 + mouse wheel to switch element, left click to use. Later additions follow convention too (e.g. G for grenade-style item).
- **Firing:** hitscan for all three elements; same behaviour, different colour and multiplier
- **People:** stationary, ~20 in one small plaza with a few blocks for routing
- **Cues:** placeholder colour marker per person (music / art / nature)
- **Rescue:** joy meter fills when hit; full → person turns from grey to colour and does a little bounce
- **Matchups:** soft cycle, matched 2× / strong 1.5× / weak 1×
- **Timer:** fixed 2 minutes
- **End screen:** buildings unlocked, based on rescue-count thresholds
- **Out of scope:** real rebuilding, grey boundary push/pull, art style, bosses, player health, extra elements, multiplayer

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

## POC round 2 (after first playtest)
Playtest 1 feedback: movement and cues good; rescues too fast; not enough push-back; right/wrong element choice not visible enough.
- **Slower rescues:** joy per shot reduced.
- **Distance falloff:** joy is strongest within ~4 m and drops to 25% by ~22 m, so you have to move.
- **Joy fades:** partly-helped people drain back to grey if you stop helping them.
- **Gloom levels:** people start at different shades of grey and get darker over time, faster the further they are from a colour zone (rescued people create colour zones). Darker people need more joy.
- **Darkness spreads:** very dark people darken those nearby and drain joy from rescued people. Rescued people can relapse and need re-joying. Final count = people still happy when the timer ends.
- **Floating joy numbers:** Borderlands-style numbers; better matches look bigger, brighter, outlined and bouncy; weak matches look small, grey and droopy.

## POC round 3 (after second playtest)
Playtest 2 feedback: some tension now; time-to-joy a bit too long; lower-tier numbers not visible enough; colour zones not understood; darkening too subtle (it was continuous); relapses noticed only after the fact, with no warning.
- **Rescues ~25% faster.**
- **Lower-tier numbers more visible** (bigger, outlined); top tier unchanged.
- **Three stepped grey levels** (light / grey / dark) with a visible moment on each step; only dark people spread darkness, and they give off dark wisps.
- **Painted ground:** the floor turns colourful around rescued people and fades back to grey when they relapse (replaces the circles).
- **Relapse warning + alert:** rescued people flicker, wobble and show "!" as they lose joy; a relapse has a dark burst and an on-screen alert.
- **Later:** richer, less plain visual style (current look is placeholder).

## POC round 4 (after third playtest)
Playtest 3 feedback: first-person aiming makes it feel like an "element selector challenge"; maybe top-down would suit it better (Deep Rock Galactic: Survivor / Vampire Survivors style), where aiming is mostly automatic and the game is about movement and element choice. Beams feel sterile; projectiles (notes, paint, flowers) would feel better (visual only for now; hits are still instant). Mix of loadout and element switching, but don't go deep on loadout yet; get the core loop healthier first.
- **Top-down mode** added alongside first person (menu to pick), to compare directly.
- **Auto-aim + auto-fire:** targets the person nearest your mouse (or nearest you); you choose position and element.
- **Joy burst (G/Q):** cooldown ability that gives everyone nearby a best-match hit. A second verb; first step toward a loadout.
- **Bigger moving crowd:** 60 people in a larger plaza; people wander, dark people drift toward colourful areas.
- **Projectile visuals:** music notes, paint blobs (leave splats), flowers.

## POC round 5 (after fourth playtest)
Playtest 4 feedback (top-down): too hard to get someone joyful. Too slow, and the fire went somewhere other than where
the player was looking. Moving and switching element on the same hand was awkward. First person vs top-down is still
too early to tell. A gamepad is wanted eventually; no device to test with yet.
- **Auto-chosen element (top-down):** every shot uses the target's element, so it is always a best match. No more
  switching; the ring under the player shows the target's colour.
- **Click-to-lock targeting, switchable with F2:** click a person to lock on (a warm ring marks them). Modes: lock-on
  (default), hover-sticky (the person under the mouse, then sticky) and auto (rescued-and-about-to-relapse first, then
  the darkest, then the nearest). The lock drops on rescue or when you walk away.
- **2x faster rescues:** each top-down shot gives twice the joy.
- **Lightly physics-based projectiles, with per-element behaviour:** notes home in on their target; paint is lobbed
  onto the target's spot and splashes people nearby; flowers drift in gently and bloom where they land, giving joy to
  everyone standing in the patch for a few seconds. Projectiles are stopped by walls, and they can miss.
- **Gamepad-ready input:** all gameplay goes through InputMap actions (no raw keys), and `controls.gd` lists the action
  each future gamepad button would take. No bindings yet.
- **Deterministic tests:** one seed for all gameplay randomness, and test runs use a fixed timestep, so coverage no
  longer changes between runs.

## POC round 6 (after fifth playtest)
Playtest 5 feedback: too much clustering of dark people; drain and relapse too fast; time-to-joy still a bit high for
ordinary people (wants about 1.5x faster); projectile types hard to tell apart (wants them bigger, with trails); targeting
modes not compared yet; enemy tiers and bosses deferred to a later dedicated round.
- **Less clustering (top-down):** dark people drift more slowly (0.8 m/s, was 1.3) and stop 2.5 m from the rescued
  person. Everyone steers away from neighbours within 2.2 m. At most two dark people drift toward one rescued person;
  the rest pick the next-nearest rescued person with a free slot, or wander.
- **Slower drain and relapse (top-down):** darkness drains rescued joy at half rate. A rescued person has 4 s of grace
  before they can be drained, shown by a soft warm halo that fades as the grace runs out. First person is unchanged.
- **About 1.5x faster rescues (top-down):** each shot gives 135 joy (was 90). Bloom and splash rates are unchanged.
  Measured: a light person 3 m away is rescued by locked fire in 47 frames, down from 72.
- **Readable projectiles (top-down):** shots are drawn 1.5x bigger, and each element leaves its own trail. Notes leave a
  wavy dusty-blue ribbon. Paint drips rose and terracotta drops that land as small splats. Flowers shed sage and pink
  petals that drift down and fade. Each projectile leaves at most 12 trail pieces.
- **Not changed:** the three targeting modes (still to be compared in a playtest), the first-person rules.
- **Next:** round 7 is a Godot style test built from the style pillars above (pixel-diorama rendering, earthy joy
  palette, the cold-to-warm transformation).

## POC round 7 (after sixth playtest)
Playtest 6 feedback: push-back still too strong; joy should be contagious (enough to lighten people to light grey and
stop their degradation when they stand inside enough cover); cover should protect more in the middle and less at the
edges; darkness should only creep in at the edges; ground transitions should be slower than people; time-to-joy still a
bit slow; projectile types still not distinct enough; the grace halo was not noticed; targeting modes not tried yet
(lock-on stays the default).
- **Graded cover:** each person's cover is the average paint weight of the ground within 3 m. Protection is 0 at the
  edge of painted ground (cover 0.35) and 1 well inside (cover 0.85). Paint is now a weight from 0 to 1 per tile.
- **Joy contagion:** with cover of 0.6 or more, grey people lose gloom at 0.034 per second times their protection, so
  they lighten to light grey in about 10 s per level. Contagion never adds joy or rescues anyone.
- **Edge-only darkness:** dark spreading and drain on rescued people are scaled by (1 - protection). Gloom growth is
  scaled the same way. The old zone heal is not used in top-down. Partial joy does not fade deep inside painted ground.
- **Slower ground (top-down):** paint spreads in at 0.05 per update and fades back at 0.012, so territory takes a few
  seconds to paint in and lingers after a relapse.
- **Less push-back and faster rescues:** drain multiplier 0.5 to 0.4. Joy per shot 135 to 170 (Nature).
- **Distinct projectiles:** fire rate per element (music 2x, nature 1x, art 0.5x) with joy per shot scaled inversely,
  so each element gives the same joy per second. Music is smaller and quicker, with a wavy ribbon trail and a dusty-blue
  ring pulse on landing. Art is a bigger, slower, higher blob with heavier drips and a bigger splat. Nature flowers bob
  and burst petals on impact.
- **Visible grace cue:** a warm pulsing ring on the ground under a rescued person, plus a soft glow on the body. Both
  fade over the last second of grace.
- **F3 debug overlay** (top-down): cover and protection above each person, and a hint on the HUD. Off by default.
- **Next:** round 8 is the style pass that brings `design/style_test` into the game (pixel-diorama rendering, earthy joy
  palette, the cold-to-warm transformation).
- **Open question (found while building round 7):** a rescued person stands in the middle of the paint they made, so
  their protection reaches 1 about four seconds after the rescue (the same time as the grace period). In the live game
  darkness then almost never drains a rescued person, so relapses by drain are close to gone in top-down. Options to
  decide next round: measure cover without the person's own paint, paint a ring rather than a disc, or accept durable
  territory and let relapses come only from edges that players leave open.

## POC round 8 (after seventh playtest)
Playtest 7 feedback: relapse isn't strong enough at the edges (no sense of risking ground); rescue speed good; projectiles
distinct, but paint is a bit large (reads as an area weapon); nature could have more defined edges; overall scale feels
off, and a closer camera would help; grace ring visible; the F3 overlay was not seen in real play; hover felt best for
targeting.
- **Decision (resolves the round 7 open question): own paint doesn't protect you.** A rescued person's cover counts only
  paint from other rescued people. So a lone rescued person is protected by nothing, and a dark neighbour can drain and
  relapse them. Of the three options (measure cover without the person's own paint, paint a ring rather than a disc, or
  accept durable territory), this is the first; the disc stays. Each tile keeps the strongest paint and the strongest
  from anyone else, and a rescued person's cover uses the lower of the current paint and the others' paint.
- **Darkness erodes paint at the edge:** each dark person takes 0.25 weight a second off the edge tiles within 2 m. A tile
  is interior (immune) only when it and its neighbours are at least 0.9 painted. Eroded tiles cannot regrow for 3 s.
  The edge moves inward while a dark person stays within that 2 m reach.
- **Weakest-point pursuit:** a dark person chases the rescued person with the lowest protection within 25 m (ties go to
  the nearer one). With nobody in reach it drifts to the nearest territory edge (and erodes there).
- **Smaller paint, crisper blooms:** paint is 1.3x (was 2.0x), the splat is 0.6 m (was 1.0 m), and the splash radius is
  1.1 m (was 1.6 m). The splash is shown as a brief ring at exactly its radius. A bloom has a thin darker sage outline
  at exactly its radius, and the whole patch fades together.
- **Closer camera:** 18 m above and 10 m behind the player (was 24 and 12). The 11 m range ring fits on screen at
  1280x720 (a test checks it). 15 m and 8 m were tried first, but then the near edge of the ring fell off the bottom of
  the screen. Labels use scale 1.9 (was 2.5) so they stay about the same size on screen.
- **Hover is the default** targeting mode. F2 still cycles through the others.
- **F3 overlay fixed:** the labels were about 0.5 m tall in the world, about 9 px on screen from the top-down camera. They
  are now sized in metres (about 19 px) with a bigger `[F3] debug` line. A regression test goes menu, key 2, F3.
- **Open for round 9:** does the inward erosion feel right, or should the dark person's 2 m reach be smaller?
- **Next:** round 9 is the style pass that brings `design/style_test` into the game (pixel-diorama rendering, earthy joy
  palette, the cold-to-warm transformation).

## Direction change: the living border (2026-10-24, after playing round 8)
The ground control is the unique part and a promising core loop, so the game focuses there. Rescuing people stays, but its
purpose is now to capture ground.
- **First person is dropped.** Top-down evolves into the territory game.
- **The living border:** rescued people organise themselves into a border around a centre. The centre forms on its own
  from wherever your first rescued people gather; there's no pre-placed heart. The border expands as you rescue more people.
- **Shape:** organic, pushed outward where you work, wrapping around buildings and obstacles.
- **Border people:** hold back darkness (dark people can't cross an intact stretch; they press against it) and fill gaps
  (when one relapses, neighbours shuffle along to close the hole).
- **Inside the border:** the land is gradually beautified, ground and buildings alike.
- **Tension:**
  - **Overextension:** a bigger area means a longer border, so the same people stand further apart. Thin stretches leak
    darkness. Every expansion is a risk.
  - **Dusk to dawn** replaces the plain timer: the light fades toward night (grey grows stronger), and the level ends at
    dawn. Grey waves were considered but not chosen for now.
- **Win:** each area has a landmark building. Enclose it with the border and hold it to win; the level is lost if the
  border collapses.
- **Prototype:** build a few border variants with a picker to compare (the user asked for options to try).

## Round 9 build: the living border

Built on the 2026-10-24 direction change. First person is retired (step 1). Top-down is the territory game (step 2). The
menu picks one of three border shapes, so they can be compared in play.

- **Three variants:** A circle (a ring sized from the rescued count), B organic push (recommended: each rescue pushes the
  border out at its angle, and it wraps around blocks), C paint edge (the border follows the paint the rescued people
  spread).
- **Shared rules, all variants:** the centre is the rescued centroid. Border members stand evenly spaced on the loop, the
  rest stand inside. A stretch over 3.5 m is a gap. Dark people outside press against solid stretches and drain the
  nearest member. Inside the loop the ground fills in slowly and blocks are beautified after 3 s. Cover is depth inside
  the loop.
- **Dusk to dawn:** 240 s, with grey strength up to 1.75 at midnight. The light goes from warm dusk to dim blue to soft
  dawn. The level ends at dawn, or earlier: the landmark held for 10 s wins, and the border falling loses.
- **Tuning:** all values are in `scripts/config.gd` under the Round 9 block (`BORDER_` and `NIGHT_`).

**Playtest 9: what to compare**
- Which variant feels best (A, B or C), and why. B is recommended, but this is the question.
- Does overextension (gaps) create good tension? Gaps only really appear in the paint edge variant and when the border is
  thin. In the circle and organic variants the perimeter is kept near the people count times the spacing, so a bigger
  border does not leave gaps by itself. Watch whether that feels too safe.
- Is dusk to dawn better than the timer? Does the night pace feel right, and does midnight feel like pressure?
- Is the landmark goal clear? Do players know it is the block with the beacon, and what holding it means?
- Does the border read as a border (the gold line, the flicker on gaps, members walking to their places)?

**Known rough spots (to check in play)**
- Paint edge can make a tiny border while the paint is still spreading (the centroid of the rescued may sit between
  painted patches). A small border can also leave members on the line with no room inside.
- Organic wrapping can jump the loop out past a block, so a border can briefly bulge into a corridor.
- The end screen counts beautified buildings and the painted share at the end, not the peak.


## Round 10 plan (after playing round 9, 2026-10-24)
Playtest 9 feedback: the living border is good and just needs balance; it was too hard to grow the control zone. Green
circles (most likely nature blooms) were distracting, especially with all the other floor detail.

**Variants decided:** Organic push (variant B) is the one. Circle and Paint edge are retired in round 10 (menu becomes a
simple Play). They remain in git history at commit `0e9d19b` (scripts/border.gd, tests/border_variant_test.gd); bring
one back if Organic push proves hard to tune.

**A. Make growing easier (suggestions 2 + 3)**
- More ground per rescue: border spacing per person 2.2 m to about 3.0 m, and a bigger outward push where you rescue
  (organic variant).
- Captured buildings become **border posts**: a beautified building on the border line holds that stretch on its own,
  worth several people, so growth accelerates as you capture buildings.
- Calm opening: almost no grey pressure for the first quarter of the night, then a build toward midnight.
- An intact border slowly pushes dark people back instead of being drained; drain only happens at gaps.
- The joy burst used near the border shoves the line outward a little.
- Overextension stays the risk: wider spacing means gaps appear sooner if people relapse.

**B. Calm the floor (visual hierarchy)**
- Audit every floor overlay (painted tiles, splats, drip dots, splash rings, music ring pulses, blooms, grace rings,
  target highlight, border line and gaps) and rank them. Border and gaps first, then the target and threats, then
  everything else.
- Blooms become subtle: no hard outline, low alpha, a few petals, quick fade. Splats and drip dots get smaller and fade
  faster; impact rings get fainter. Cap the number of floor effects alive at once.
- Add an F3 debug readout that counts live floor effects by type, so the next "what was that?" is answerable.

**C. Readability from the locked art style** (design/style_test/REVIEW_NOTES.md, placeholder visuals until the style
pass)
- Closer camera (orthographic, about the locked size 14.5).
- Circular minimap, top-left: warm and grey ground, buildings, border, gaps, dark people, landmark, player.
- Off-screen gap arrows on the screen edge.
- Bigger, more readable people and a distinct player marker.
- Gaps pulse softly (coral, 1.2 s, eased) instead of a hard flicker.

**D. Tooling**
- The pre-commit hook skips the test gate for commits that only touch design/.

**Open questions for the playtest:** Is the calm opening long enough? Do border posts
make buildings feel worth capturing?

**After round 10:** the full style pass (port design/style_test into the game).

## Round 10 build

Built from the round 10 plan. Only the organic push border is kept (Circle and Paint edge are in history at `0e9d19b`).
Commits: retire variants `6803067`, easier growth `703bbf2`, calmer floor and readability `d13b7db`, hook `6677f50`,
docs and baseline (this round's last commit).

**What was built**
- **Menu:** one Play button (Enter, key 1 or click). Hint line names the keys.
- **Growing easier:** spacing 3.0 m (was 2.2), rescue push 2.4 m (was 1.6). Beautified blocks on the line, and the
  landmark once beautified, are **posts**: each holds three members' worth of perimeter (the loop needs three fewer
  people) and the segments beside it are never gaps. Posts also pull the centre like three people. The night is calm for
  the first 25% (strength 0.2), then eases (smoothstep) into the old curve, peaking at midnight. An intact line pushes
  dark people back at 0.6 m/s and drains nobody; only gaps drain. The joy burst within 4 m of the line shoves it out
  toward you by about 1.5 m.
- **Calmer floor:** blooms have no outline, fill alpha 0.25, 4 flowers of 4 petals, fade over the last 40% of life.
  Splats radius x0.7 (0.42 m) and fade 0.8 s. Drip dots x0.6 and fade 0.8 s. Music ring and splash ring alpha halved.
  Floor effects are capped at `TD_MAX_FLOOR_EFFECTS` = 40: the oldest priority-3 effect goes first. The inventory and
  priorities are in `config.gd`. F3 shows the live counts.
- **Readability (placeholders, per REVIEW_NOTES):** orthographic camera, size 14.5, pitch 41 degrees, look point 2.4 m
  north of the player. Circular minimap top-left at 20% of the screen width. Off-screen gap arrows on the screen edge,
  kept clear of the minimap. People drawn 1.5x (collision unchanged). Saffron player with a warm double ring and glow.
  Gaps glow coral with a 1.2 s cosine pulse, never a hard line.
- **Hook:** design/ and Markdown-only commits skip the lint and test gate. Rules are in `tools/hook_paths.sh`, dry-run by
  `tools/test_hook_paths.sh` (13 fake path lists).

**Final tuning values** (all in `scripts/config.gd`)
- `BORDER_TARGET_SPACING` 3.0, `BORDER_PUSH` 2.4, `BORDER_POST_REACH` 2.0, `BORDER_POST_WORTH` 3, `BORDER_PUSHBACK_SPEED`
  0.6, `BORDER_SHOVE_RANGE` 4.0, `BORDER_SHOVE_AMOUNT` 1.5, `BORDER_GAP_PULSE_SECONDS` 1.2.
- `NIGHT_CALM_FRACTION` 0.25, `NIGHT_CALM_STRENGTH` 0.2.
- `TD_CAMERA_ORTHO_SIZE` 14.5, `TD_CAMERA_PITCH_DEG` 41, `TD_CAMERA_DISTANCE` 20, `TD_CAMERA_LOOK_OFFSET` (0, 0, -2.4).
- `TD_MAX_FLOOR_EFFECTS` 40, `TD_MINIMAP_WIDTH_FRACTION` 0.2, `PERSON_VISUAL_SCALE` 1.5.

**TD_AUTO_RANGE outcome: 8.6 m (was 11).** With the look point 2.4 m north, the far side of the auto ring sits
(r + 2.4) m from the look point. Projected at sin 41 degrees, that must fit the 7.25 m half-height of a 14.5 m view,
which gives r at most 8.65. The camera test checks 16 points around the full ring on a 1280x720 screen. The range is
now the reach of a shot, so targets walking away from it lose the lock sooner.

**Deviations from the plan, and why**
- **A bug fix in the organic push (commit `6803067`).** A rescue measured its push from the person's own spot before
  any centre existed, so the first rescues, and any made in the same frame, pushed toward angle 0. The loop then drifted
  east at full speed. Pushes are now queued and applied from the centre. This was found while the variant tests failed.
- **Posts pull the centre.** Without it the loop slid away from a landmark that no member stood beside (found by the
  landmark test).
- **"Fade 1.5 to 0.8 s" for splats:** the config had 2.5 s for paint splats and 1.5 s for splat dots. Both are now 0.8 s.
- **"At most 4 petals":** read as 4 flowers of 4 petals each (16 petals, down from 35).
- **Shove:** the bump is divided by the size factor, so it shows as about 1.5 m on the line. Normalisation trims the rest
  of the loop a little, so the measured bulge is within 0.8 to 1.8 m.

**Tests added:** floor cap and priority (input-driven F3 through the menu), camera, minimap model, off-screen arrows,
gap pulse, player colour, people scale, posts, anchored gaps, push-back, shove (by G key), the spacing settle, and the
calm-opening night curve. The Round 10 border tests are in `tests/border_growth_test.gd`.

**Playtest questions**
- Is growth now easy enough? Does the calm opening feel long enough (a quarter of the night)?
- Do border posts make buildings feel worth capturing?
- Is the floor calm enough, and are the minimap and arrows enough to manage gaps?
- Does the 8.6 m auto range feel too short now that targets walk away from it?

**Rough spots to watch in play:** a three-person loop is lopsided and can still wander a little while it settles; the
burst shove shrinks the rest of a loop slightly; a post's slots can be shifted by its neighbours, leaving a rare empty slot
(a gap beside it).

## Round 10 playtest and draft round 11 plan (2026-10-24)
Feedback: the best round yet. Wants a little more zoomed out and a little faster (player and enemy movement, overall
pace). Turning fully dark is a little fast; light grey to grey feels good. Growth is now too easy. Border posts and the
calmer floor landed. The calm opening went unnoticed (keep as is). Minimap and arrows were unclear: gaps weren't obvious
on the minimap and the edge arrows went unnoticed.

Draft round 11 (to be re-evaluated after the build-speed tooling round):
- Pace: player movement about +15%, dark and grey people a bit faster; night 4 → about 3 minutes.
- Darkening: grey → dark slower; light grey → grey unchanged.
- Camera: about 15% further out; auto-fire range back to about 10 m.
- Risk back: border spacing 3.0 → about 2.6 m; intact push-back weaker, and a small drain even when intact.
- Gaps: much clearer gap markers on the minimap; bigger, more noticeable pulsing edge arrows.
- Unchanged: calm opening, border posts, floor effects.

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

## Style pass approach: switchable looks (decision, 2026-10-24)
Replaces the plan to port design/style_test into the game as a permanent replacement. The goal is to feel the game
with the locked style periodically without paying its upkeep cost on every gameplay round.

**Where the cost is:** the locked style is almost all code (toon, ground, glow, haze and post shaders, plus scene
scripts), not heavy asset files, so load and test times barely change. The cost is upkeep: every new gameplay thing
would need a styled look before a round could finish, agents would read and change more visual code each round, and
visual bugs would mix with gameplay bugs in playtests.

**The approach**
1. **Split rules from looks.** Each object's script keeps its rules (for example `person.gd`: movement, rescue,
   relapse). A separate visual piece reads that state and draws it. Today each script builds its own placeholder
   shapes, so this is a one-off refactor.
2. **Two looks:** placeholder (today's shapes) and styled (the shaders and models from design/style_test, per
   REVIEW_NOTES.md).
3. **Fallback:** in styled mode, anything without a styled look uses its placeholder. Gameplay rounds never have to
   update the styled look.
4. **Switch:** a menu toggle, plus a key (for example F4) to flip looks mid-game. Tests use the placeholder by default,
   plus one check that styled mode loads and runs. Optionally, F3 counts what is still placeholder.

**Round rhythm**
- Gameplay rounds add placeholder visuals only, at today's speed.
- Every few rounds, a **style round** gives new things their styled look, followed by a playtest in styled mode. Time
  these before playtests where the look matters.

**Setup cost:** one round: split the visuals out, then port the locked style for the main things on screen (ground,
buildings, people, player, border, minimap). This is the already-planned style pass, made switchable.

**Watch for:** the two looks drifting apart in readability (a gap that is obvious as a placeholder may be subtle when
styled). Keep style rounds regular, and check readability of gaps, threats and the player in both modes.

## Round 11 build (tuning)
Built from the round 10 feedback above. Values changed in `scripts/config.gd`; the rules are in `gloom_sim.gd` (darkening)
and `border.gd` (intact drain). Unchanged: calm opening, border posts, floor effects, minimap and arrows.

Final values (round 10 in brackets):
- Walk `TD_MOVE_SPEED` 6.9 (6.0); run `TD_RUN_SPEED` 10.9 (9.5), about +15%.
- Wandering and dark drift `TD_WANDER_SPEED` and `TD_DARK_DRIFT_SPEED` 0.92 (0.8), about +15%.
- Night `NIGHT_LENGTH` 180 s (240). The calm opening is still a quarter of the night (now 45 s), the curve is unchanged.
- Darkening: `GLOOM_DARK_STEP_MULT` 0.65 on growth at grey only (grey to dark about 35% slower). Light grey to grey is
  unchanged. Spread and contagion are unchanged.
- Camera `TD_CAMERA_ORTHO_SIZE` 16.7 (14.5), about 15% further out. Distance and pitch are unchanged.
- `TD_AUTO_RANGE` 10.0 (8.6). A ring 11 m out no longer fits the 1280x720 view (the test checks both).
- `TD_UI_SCALE` 2.2 (1.9), so labels keep their size on screen with the wider view (1.9 x 16.7 / 14.5 is 2.19, rounded).
  F3 label sizes are in metres and are unchanged.
- Border `BORDER_TARGET_SPACING` 2.6 (3.0). Gaps are still over `BORDER_MAX_GAP` 3.5 m.
- `BORDER_PUSHBACK_SPEED` 0.35 (0.6).
- New `BORDER_INTACT_DRAIN_FRACTION` 0.25: dark people pressing an intact stretch drain the nearest member at a quarter
  of the gap rate (gaps keep the full rate, 24 joy per second at strength 1).

Playtest questions for round 11:
- Pace: does the walk and run feel right now, and do the grey and dark people feel fast enough to be a threat, not a
  nuisance?
- Darkening: does grey to dark feel slower, while light grey to grey still feels good?
- Zoom and range: is the wider view still easy to read? Is 10 m the right range (does auto feel too eager now)?
  Are the labels still readable?
- Growth risk: is it risky enough again? Does a lone press on the intact line feel like a threat, or does it still feel
  harmless?
- Night: does 3 minutes feel like the right length for the calm opening and the midnight push?

## Round 11 playtest and round 12 plan (2026-10-24)
Feedback: super close, but missing something. The capture side is decent; the "combat" loop is too simple (move
around and point at things). Pace feels right. Zoom, 10 m auto range and labels are good. The 3-minute night feels
right. Growth is still too safe. Grey-level changes (light grey, grey, dark) go unnoticed; they should be more
pronounced. (Whether grey to dark feels slower wasn't noticed either way.)

Three combat ideas were discussed: (1) read the person, (2) elements combine on the ground, (3) dance with the dark.
Chosen: **1 and 3 together, plus going dim**, as one version. Idea 2 is kept for later; it fits element unlocks in the
progression tree.

**A. Read the person (idea 1)**
- Grey people get readable moods, all three in the first try:
  - **Guarded:** turns away from the player; joy lands only from the front or side.
  - **Skittish:** backs off if the player runs at them; approach at a walk.
  - **Glum:** slumps, with short look-up moments; shots in that moment count three times.
- **Sheltering:** joy doesn't land on a grey person while a dark person stands close. Deal with the dark person first or
  draw them away.
- The auto-element and hover targeting stay.

**B. Dance with the dark (idea 3)**
- Dark people reach for the player with a clear wind-up. A grab drains **spirit**, and fire slows as spirit drops.
- **Twirl:** a short dash with a cooldown. Twirling through a grab at the last moment gives a small joy burst.
- **Spirit is a spendable resource:** rescues fill it, and the joy burst (G) costs it. The user likes collecting a
  spendable resource and wants to expand it later (future: more things to spend it on).

**C. Going dim (instead of dying)**
- At zero spirit the player goes **dim**: half walk speed, no joy, colour drains toward grey. The twirl still works.
- Dark people **ignore a dim player** and go back to pressing the border.
- **Recovery:** inside a captured area, faster the deeper inside the border you are. Before any border exists, stand
  near the landmark to recover.
- While the player is dim, the border loses ground **x1.5** faster (the troupe loses heart). The border visibly dims or
  flickers so the cause is clear.

**D. Growth risk: pressure at the edges**
- Dark people gather more at the far edge of the border, so the newest ground is the riskiest. Spacing and intact
  drain numbers are unchanged for now; retune after playing with going dim.

**E. Noticeable grey-level changes**
- A short gloomy puff or ripple when someone sinks a stage, and a warm one when they lift (not cold: see "Gloom terminology").
- A brief blip on the minimap when someone turns dark.
- A sound cue is wanted for each transition, but is not designed yet. It waits for a general discussion about sound
  cues (to do, not now).

**Deferred:** checking balance with one starting element waits for the level goals and progression work (every
element is still available until then).

**Build note:** round 12 should start from the switchable-looks work if that lands first; new things get placeholder
visuals only. Round 12 is large; consider splitting it (for example C + B first, then A, D and E).

## Graphics checkpoint 1
**Built:** the one-time setup of switchable looks from the "Style pass approach" section. Rules and looks are split
(`scripts/looks/`), the locked style is ported as the styled look, and F4 / the menu "Look" button flip between them.

**How to switch:** menu button "Look: Placeholder / Styled" (remembered for the session), or F4 in game (rebuilds the
visuals in place; game state is untouched). F3 shows the current look and how many objects still use placeholder.
Screenshots of both looks at the same moment: `python tools/checkpoint_shots.py` (results in
`design/renders/checkpoint_01/`, with `NOTES.md`).

**Styled:** pixel pipeline (640x360, toon + dither, outlines, long warm shadows), cobble ground from the paint weights,
industrial/whimsical buildings and landmark, grey/joyful/dark people, the player, border haze + motes + coral gap glow,
the round parchment minimap, landmark hold ring.
**Still placeholder:** projectiles, blooms, burst/grace rings, target highlight, HUD text and arrows, labels and joy numbers.

**Cadence rule:** gameplay rounds add placeholder visuals only. Run a style round every few gameplay rounds, and before any
playtest where the look matters: give whatever F3 lists as placeholder its styled look, run the checkpoint tool, look at
the PNGs (can you spot the player, the gaps, dark people, the landmark?), then playtest in styled mode.

**Found while building:** the current border rules open every stretch of a loop at once (spacing over `BORDER_MAX_GAP`),
so a single gap on a healthy loop never happens by itself; the screenshot scenario marks two stretches by hand. A
gameplay decision for later (should gaps be per stretch?).

## Gloom terminology (decision, 2026-10-24)
Move the words away from "dark = bad". This is about terminology; the visuals may still get darker as gloom deepens.
The theme is **gloom** in general, not cold or frost.

- **The force:** gloom. Use "gloom spreads", not "darkness spreads".
- **The three stages** (were light grey, grey, dark): **wistful, gloomy, dimmed**. "Glum" stays the name of the mood
  from round 12 idea A, not a stage.
- **People:** "dimmed people", not "dark people". The same for players' docs, playtest questions, the HUD and the
  minimap legend.
- **The player's out-of-spirit state is dim on purpose:** the gloom touches the player the same way it touches people,
  with the same word and a matching look.
- **Applies to:** new docs and plans from now on, player-facing text in the game, and the round 12 plan. Older sections
  above stay as written (history). Code names such as `dark` and `TD_DARK_DRIFT_SPEED` can be renamed in a later build
  round when convenient; not urgent. The locked art note "hunched gloomy dark people" in design/style_test/REVIEW_NOTES.md
  reads as "hunched gloomy dimmed people" from now on.

## Round 12a build
Built from the round 12 plan: item **C (going dim)** and item **B (dance with the gloom)**, with the spirit resource that
joins them. Items A, D and E (moods, edge pressure, noticeable grey levels) wait for round 12b. Player-facing text uses
the new terms (gloom; wistful, gloomy, dimmed; "dimmed people"); code names such as `dark_*` and `is_dark()` are unchanged.

**What was built**
- **Spirit** (`TopDownPlayer.spirit`, 0..100; the player starts with 50, a choice the plan did not specify): +20 per rescue,
  the joy burst costs 30 and is unavailable (HUD: "needs 30 spirit") without it. Joy fire rate is full at 50% spirit or
  more and falls linearly to 40% of the rate just above 0. A HUD bar and label sit above the burst indicator.
- **Going dim** at spirit 0: walk speed x0.5, no joy fire, no burst, body colour lerps to grey (placeholder look; the
  styled player is not tinted yet: rough spot). Dimmed people ignore a dim player (they go back to chasing the weakest
  rescued person or the edge). Recovery is **only while dim**, only inside the border, at 10/s x (0.3 + 0.7 x depth
  protection); before any border exists, within 6 m of the landmark at the full rate. Dim ends at spirit 30. While dim the
  border loses ground x1.5: drain of members by pressing and by GloomSim, paint erosion and paint fade; the border line
  (placeholder: alpha pulse; styled: haze and motes drop out in the dark half of the flicker) flickers.
- **Dance with the gloom** (`scripts/grabs.gd`): a dimmed person who notices a non-dim player within 7 m walks toward
  them. Within 2.0 m they start a 0.7 s wind-up (lean back, red ring growing at their feet toward the player: drawn by the
  person look from `Person.grab_frac`), then a 0.15 s lunge of up to 1.0 m toward where the player stood. If the player is
  within 1.3 m of the grabber when the lunge ends, 25 spirit is drained. 2.5 s cooldown per person.
- **Twirl** (Space, new `twirl` action): 3.0 m in 0.2 s in the move direction (facing direction when standing still),
  1.5 s cooldown, usable while dim, no grabs land while it runs. **Perfect twirl:** a twirl that began within 0.25 s before
  the lunge ended, from a spot within 1.3 m of the grabber, avoids the grab and sets off a free joy burst (radius 2.5 m,
  half of the burst joy, no spirit cost, no border shove) and an alert. A twirl out of reach early just avoids it.
- **Checkpoint fixes:** the styled minimap shades warm as soon as a tile has paint (it waited for half paint, so slowly
  filling ground looked unclaimed); dimmed people get a bigger, denser smoke pool and twice the soot motes in the styled
  look, and a soft dark disc on the ground in the placeholder look.
- New things are placeholder-look only (grab ring, dimmed disc): the ring registers itself in F3 in styled mode.

**Tuning values** (all in `config.gd`, "Round 12a"): `SPIRIT_MAX 100`, `SPIRIT_START 50`, `SPIRIT_PER_RESCUE 20`,
`BURST_SPIRIT_COST 30`, `SPIRIT_FULL_FIRE_FRACTION 0.5`, `SPIRIT_MIN_FIRE_FRACTION 0.4`, `DIM_MOVE_MULT 0.5`,
`DIM_RECOVER_RATE 10` (base 0.3, depth 0.7), `LANDMARK_RECOVER_RADIUS 6`, `DIM_EXIT_SPIRIT 30`, `DIM_LOSS_MULT 1.5`,
`GRAB_NOTICE_RANGE 7`, `GRAB_RANGE 2.0`, `GRAB_HIT_RANGE 1.3`, `GRAB_WINDUP 0.7`, `GRAB_LUNGE_TIME 0.15`,
`GRAB_LUNGE_DISTANCE 1.0`, `GRAB_COOLDOWN 2.5`, `GRAB_SPIRIT_DRAIN 25`, `TWIRL_DISTANCE 3.0`, `TWIRL_TIME 0.2`,
`TWIRL_COOLDOWN 1.5`, `TWIRL_PERFECT_WINDOW 0.25`, `TWIRL_BURST_RADIUS 2.5`, `TWIRL_BURST_JOY_FRACTION 0.5`.

**Judgement calls to check**
- The plan said the hit check happens "at the end" of the wind-up; with a start range of 2.0 and a hit range of 1.3 a
  standing player could never be hit, so the lunge was made to close the gap (up to 1.0 m) and the check is at its end.
- Spirit only recovers while dim. A non-dim player's spirit comes only from rescues. If that feels too stingy, add a
  slow passive recovery inside the border.
- Spending the burst down to exactly 0 spirit makes the player go dim (a 30 spirit burst from 30). This is probably
  harsh; the alternative is to forbid a burst that would leave 0.
- Dimmed people now walk toward a non-dim player, which changes the feel of standing in the open. They are still held at
  the border line like everything else.

**Playtest questions**
- Is the spirit/dim tension good: do rescues feel like they refill something worth protecting?
- Do the grabs feel fair with the wind-up (ring, lean, 0.7 s)? Is 25 spirit the right price, 1.3 m the right reach?
- Is the twirl satisfying (distance, cooldown, the perfect window)? Does a perfect twirl feel worth aiming for?
- Does going dim feel like a meaningful cost (half speed, no joy, the border flickering and losing heart), and is the
  recovery (inside the border, deeper is faster) clear and fair? Is the landmark fallback before a border findable?
- Is the dimmed aura enough to pick dimmed people out from gloomy people at a glance?

**Rough spots:** the styled player does not tint when dim; the styled smoke pool is dark on a dark night and reads
mostly through the soot motes; the HUD spirit bar uses the default progress bar look; no sound cues yet.

