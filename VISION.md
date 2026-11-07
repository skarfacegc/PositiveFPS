# PositiveFPS — Vision (unscheduled ideas)

These are long-term ideas, not scheduled; moved out of IDEAS.md on 2026-11-07.

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
