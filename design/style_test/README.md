# Style test (pixel-diorama rendering)

A separate, nested Godot project that produced the renders in `design/renders/*.png`. It tries the pixel-diorama
look from `IDEAS.md` (style pillars): low-resolution 3D rendered at 640x360 (upscaled 3x with nearest filtering to 1920x1080), soft toon shading,
outlines, ordered dithering and a warm, late-afternoon light. It has its own `project.godot` and is not part of the
game. The main project does not run or import it.

## Re-rendering

Run `run.sh` in this folder (bash, Godot 4.7.2 console executable from the WinGet install path). It first runs a
headless `--import` (needed so the `StyleScene` and `MiniMap` class names are known), then starts the style test,
renders the sample scenes and saves PNG files: `topdown_joy_000/050/100`, `closeup_transformation`, `people_lineup`,
`comparison_smooth_vs_pixel` and `contact_sheet`. See `REVIEW_NOTES.md` for what changed after each art review.

- **It overwrites `design/renders/`.** The output path is hard-coded in `main.gd` (`OUT`). Commit or copy the
  existing renders first if you want to keep them.
- A GUI window titled "PositiveFPS - RENDERING STYLE SAMPLES" opens briefly (`run.sh` uses a 170 second timeout)
  and closes by itself when the renders are saved.
- The `.godot/` folder it creates is not committed (git ignores it).
