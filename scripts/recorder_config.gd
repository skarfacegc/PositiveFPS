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
