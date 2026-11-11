class_name TownConfig
extends RefCounted

# The town layout: the grid of cells and streets, lamps, stalls and the landmark squares.

# Walls and gates: Grid (0.4, #55). The town is TOWN_GRID_CELLS by TOWN_GRID_CELLS cells of TOWN_CELL_SIZE metres with
# streets of TOWN_STREET_WIDTH metres between them, filling the plaza (see Grid fixes below for the spread-out sizes).
# The middle cell is the start square; the four cells next to it on the diagonals are the landmark squares, in
# LandmarkConfig.LANDMARK_NAMES order; the other twenty are built blocks, solid for everyone.
const TOWN_GRID_CELLS := 5
const TOWN_CELL_SIZE := 12.0  # Metres: one cell, a block or a square.
const TOWN_STREET_WIDTH := 12.0  # Metres between two cells (Grid fixes: was 10).
const TOWN_BLOCK_HEIGHT := 3.0  # Metres: a built block's height (a tight group of houses filling its cell).
const TOWN_LANDMARK_CELLS: Array[Vector2i] = [Vector2i(3, 1), Vector2i(1, 1), Vector2i(3, 3), Vector2i(1, 3)]

# Props: lamps stand against the block faces, in the kerb strip, one per face of each street piece; benches and
# planters stand against the face of a block that looks toward the start; stalls stand on the start square.
const TOWN_KERB_OFFSET := 5.4  # Metres from a street's centre line: lamps stand this far out, beside the block faces.
const TOWN_STALL_OFFSET := 5.5  # The four stalls on the start square stand at (+-5.5, +-5.5) from the start.
const TOWN_BENCH_OFFSET := 7.0  # A block's bench stands this far in front of its centre (against its face).
const TOWN_PLANTER_OFFSET := Vector2(6.9, 3.6)  # A block's planter: forward, then sideways.

# Walls and gates: Grid fixes (#55). Spread out: the start square is TOWN_START_SIZE metres, so its column and its row
# are that wide where they cross it (the blocks there are 18 x 12), and the streets are 12 m. The town is
# 4 x 12 + 18 + 4 x 12 = 114 m across (Config.TD_PLAZA_SIZE). The landmark squares stay on the diagonals, 27 m out.
const TOWN_START_SIZE := 18.0  # Metres: the start square's side (the other cells are TOWN_CELL_SIZE).
