class_name RecorderConfig
extends RefCounted

# The gameplay recorder (scripts/recorder.gd).

# Round 18: the gameplay recorder (scripts/recorder.gd). Off by default; the menu or `-- --record` turns it on.
# A sample line every RECORD_SAMPLE_SECONDS; gaps, shields and the like are polled every RECORD_POLL_SECONDS; the
# buffer is written out every RECORD_FLUSH_SECONDS; a screenshot (downscaled to RECORD_SHOT_WIDTH) every
# RECORD_SHOT_SECONDS; a dimmed person within RECORD_PRESS_RADIUS of the person they pursue counts as pressing.
const RECORD_SAMPLE_SECONDS := 1.0
const RECORD_POLL_SECONDS := 0.1
const RECORD_FLUSH_SECONDS := 3.0
const RECORD_SHOT_SECONDS := 18.0
const RECORD_SHOT_WIDTH := 960
const RECORD_PRESS_RADIUS := 3.0

# Walls and gates: Recorder catch-up (#59, #60, #61). A gate counts as pushed while a point of it is dented past
# RECORD_PUSH_DENT metres (checked each poll); a shot taken because of an event (take, break, mark...) is at least
# RECORD_EVENT_SHOT_MIN_GAP seconds after the last one; the HUD's "Marked" flash lasts MARK_FLASH_SECONDS.
const RECORD_PUSH_DENT := 0.2
const RECORD_EVENT_SHOT_MIN_GAP := 3.0
const MARK_FLASH_SECONDS := 1.5
