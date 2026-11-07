class_name EdgeMarkers
extends RefCounted

# Round 25 (edge cleanup): ONE marker per trouble spot on the border. The troubles are open gaps, wobbling people,
# strained members and warm gifts (spare spirit), in that order of priority. Neighbouring troubles on the same stretch
# merge into the stronger one, a gap that has been open less than EDGE_GAP_MIN_AGE never gets a marker (it is probably
# a blink that closes by itself), and at most EDGE_MARKER_MAX markers are shown, worst first. Pure rules for the
# look: nothing here changes the game.

# Higher is worse.
enum Kind { GIFT, STRAIN, WOBBLE, GAP }


# One trouble spot: its kind, where, how bad (0..1) and how many troubles merged into it.
class Marker:
	var kind: int = Kind.GIFT
	var pos := Vector3.ZERO
	var severity: float = 0.0
	var count: int = 1

	func _init(kind_in: int, pos_in: Vector3, severity_in: float) -> void:
		kind = kind_in
		pos = pos_in
		severity = severity_in


# The troubles right now: gaps (open at least EDGE_GAP_MIN_AGE), wobblers, strained members (the `warnings` of
# GapPatch, from EDGE_STRAIN_MARK_MIN up) and members being warmed. Unsorted.
static func collect(border: Border, people: Array[Person], warnings: Array[Dictionary]) -> Array[Marker]:
	var out: Array[Marker] = []
	var mids: Array[Vector3] = []
	if border.active:
		mids = border.gap_midpoints_cached()
	var urgencies := border.gap_urgencies()
	for i: int in range(mini(mids.size(), urgencies.size())):
		# The urgency is the gap's age over GAP_URGENCY_SECONDS, which is far past the minimum, so this is exact.
		if urgencies[i] * Config.GAP_URGENCY_SECONDS >= Config.EDGE_GAP_MIN_AGE:
			out.append(Marker.new(Kind.GAP, mids[i], urgencies[i]))
	for p: Person in people:
		if not p.is_rescued:
			continue
		if p.wobbling:
			out.append(Marker.new(Kind.WOBBLE, p.position, p.wobble_progress()))
		elif p.react_kind == Person.React.WARM and p.react_progress() >= 0.0:
			out.append(Marker.new(Kind.GIFT, p.position, 1.0 - p.react_progress()))
	for w: Dictionary in warnings:
		var u: float = w["urgency"]
		var who: Person = w.get("person")
		if u < Config.EDGE_STRAIN_MARK_MIN or (who != null and who.wobbling):
			continue
		var at: Vector3 = w["pos"]
		out.append(Marker.new(Kind.STRAIN, at, u))
	return out


# The markers to show from `troubles`: worst first (gap, wobble, strain, gift; then the more severe), a trouble within
# EDGE_MARKER_MERGE of a marker already chosen joins it (it adds to its count; it never changes the winner), and at most
# EDGE_MARKER_MAX come back.
static func pick(troubles: Array[Marker]) -> Array[Marker]:
	var sorted := troubles.duplicate()
	sorted.sort_custom(_worse)
	var out: Array[Marker] = []
	for t: Marker in sorted:
		var merged := false
		for m: Marker in out:
			if Vector2(t.pos.x - m.pos.x, t.pos.z - m.pos.z).length() <= Config.EDGE_MARKER_MERGE:
				m.count += t.count
				merged = true
				break
		if merged or out.size() >= Config.EDGE_MARKER_MAX:
			continue
		var copy := Marker.new(t.kind, t.pos, t.severity)
		copy.count = t.count
		out.append(copy)
	return out


# The markers for the level right now.
static func choose(border: Border, people: Array[Person], warnings: Array[Dictionary]) -> Array[Marker]:
	return pick(collect(border, people, warnings))


# How big a marker's ring is (m): by kind, a little more for every trouble merged into it.
static func radius_of(m: Marker) -> float:
	var base := Config.EDGE_MARKER_RADIUS_GIFT
	match m.kind:
		Kind.GAP:
			base = Config.EDGE_MARKER_RADIUS_GAP
		Kind.WOBBLE:
			base = Config.EDGE_MARKER_RADIUS_WOBBLE
		Kind.STRAIN:
			base = Config.EDGE_MARKER_RADIUS_STRAIN
	return base * (1.0 + 0.12 * float(mini(m.count - 1, 3)))


static func colour_of(m: Marker) -> Color:
	match m.kind:
		Kind.GAP:
			return Config.EDGE_MARKER_COLOUR_GAP
		Kind.WOBBLE:
			return Config.EDGE_MARKER_COLOUR_WOBBLE
		Kind.STRAIN:
			return Config.EDGE_MARKER_COLOUR_STRAIN
	return Config.EDGE_MARKER_COLOUR_GIFT


static func _worse(a: Marker, b: Marker) -> bool:
	if a.kind != b.kind:
		return a.kind > b.kind
	return a.severity > b.severity
