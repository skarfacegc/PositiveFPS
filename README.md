# PositiveFPS — proof of concept

A gentle first-person "shooter" where instead of hurting people, you spread joy.
Twenty grey people are standing in a plaza. Shoot them with the right element to
fill their joy meter, and they turn colourful and bounce. You have two minutes.

## How to run

1. Open Godot 4.7.
2. Click **Import** and pick the `project.godot` file in this folder.
3. Press **F5** (or the Play button) to run the game.

## Modes

The game opens a menu. Pick a mode:

- **1 = First person** (the original): aim with the mouse and fire beams.
- **2 = Top-down** (new): a bigger plaza seen from above. You move and choose the element; joy fires automatically at the nearest person (or the one under your mouse).

Press **M** at any time to go back to the menu.

## Controls

First person:

- **WASD** move
- **Mouse** look around
- **Shift** run
- **Space** jump
- **Left click** spread joy (hold to keep firing)
- **1 / 2 / 3** or **mouse wheel** switch element (Music, Art, Nature)
- **Esc** free the mouse
- **R** restart
- **M** back to menu

Top-down:

- **WASD** move, **Shift** run
- **Mouse** aim (joy fires automatically)
- **1 / 2 / 3** or **mouse wheel** switch element
- **G** or **Q** joy burst (short cooldown; boosts everyone nearby)
- **R** restart, **M** back to menu

## Tuning

All the numbers live in `scripts/config.gd`. Change them there and run the game
again to see how it feels. Each one has a short comment explaining what it does.

## How the matchups work

Elements form a soft cycle:

- Music is strong against Art
- Art is strong against Nature
- Nature is strong against Music

Using the element that matches a person's marker gives double joy (2x).
Using an element that is strong against them gives 1.5x. Anything else gives 1x.
