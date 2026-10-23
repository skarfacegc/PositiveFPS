# Style test (pixel-diorama rendering)

A separate, nested Godot project that produced the renders in `design/renders/*.png`. It tries the pixel-diorama
look from `IDEAS.md` (style pillars): low-resolution 3D rendered at 480x270, crisp upscaling, soft toon shading,
outlines, ordered dithering and a warm, late-afternoon light. It has its own `project.godot` and is not part of the
game. The main project does not run or import it.

## Re-rendering

Run `run.sh` in this folder (bash, Godot 4.7.2 console executable from the WinGet install path). It starts the
style test, renders the sample scenes and saves PNG files.

- **It overwrites `design/renders/`.** The output path is hard-coded in `main.gd` (`OUT`). Commit or copy the
  existing renders first if you want to keep them.
- A GUI window titled "PositiveFPS - RENDERING STYLE SAMPLES" opens briefly (`run.sh` uses a 90 second timeout)
  and closes by itself when the renders are saved.
- The `.godot/` folder it creates is not committed (git ignores it).
