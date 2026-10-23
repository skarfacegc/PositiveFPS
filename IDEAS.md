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
- **Pressure is time, not enemies:** each mission gives you a limited time to help as many people as possible. Your rescue count at the end sets how much of the town you can restore. A gentler kind of shooter.

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
