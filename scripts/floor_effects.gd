class_name FloorEffects
extends RefCounted

# The floor overlay registry (round 10). Every transient floor effect (sound rings, paint splats, splash rings, petal
# bursts, blooms and trail pieces) joins the group GROUP with its kind and priority (see the inventory in config.gd).
# The live count is capped at Config.TD_MAX_FLOOR_EFFECTS: when a new effect would go over the cap, the oldest effect
# of the lowest priority (the highest number, so priority 3 before anything else) is freed first.

const GROUP := "floor_effect"
const KIND_META := "floor_kind"
const PRIORITY_META := "floor_priority"
const SEQ_META := "floor_seq"

# Counts every effect added, so "oldest" is well defined even within one frame.
static var _seq: int = 0


# Adds `node` to `parent` at `at` as a floor effect of `kind` and `priority`, then enforces the cap.
static func add(parent: Node, node: Node3D, kind: String, priority: int, at: Vector3) -> void:
	node.add_to_group(GROUP)
	node.set_meta(KIND_META, kind)
	node.set_meta(PRIORITY_META, priority)
	_seq += 1
	node.set_meta(SEQ_META, _seq)
	parent.add_child(node)
	node.global_position = at
	enforce_cap(parent.get_tree())


# The effects alive in `tree` (freed-at-end-of-frame effects do not count).
static func live(tree: SceneTree) -> Array[Node]:
	var out: Array[Node] = []
	for node: Node in tree.get_nodes_in_group(GROUP):
		if not node.is_queued_for_deletion():
			out.append(node)
	return out


# Frees the oldest effect of the lowest priority until no more than TD_MAX_FLOOR_EFFECTS are alive.
static func enforce_cap(tree: SceneTree) -> void:
	var nodes := live(tree)
	while nodes.size() > Config.TD_MAX_FLOOR_EFFECTS:
		var victim := _pick_victim(nodes)
		victim.queue_free()
		nodes.erase(victim)


# The live effect to free: the highest priority number, and among those the smallest sequence number (the oldest).
static func _pick_victim(nodes: Array[Node]) -> Node:
	var victim: Node = nodes[0]
	for node: Node in nodes:
		var pr: int = node.get_meta(PRIORITY_META)
		var v_pr: int = victim.get_meta(PRIORITY_META)
		var seq: int = node.get_meta(SEQ_META)
		var v_seq: int = victim.get_meta(SEQ_META)
		if pr > v_pr or (pr == v_pr and seq < v_seq):
			victim = node
	return victim


# How many live effects there are of each kind, as a Dictionary of kind -> count.
static func counts_by_kind(tree: SceneTree) -> Dictionary:
	var out: Dictionary = {}
	for node: Node in live(tree):
		var kind: String = node.get_meta(KIND_META)
		out[kind] = out.get(kind, 0) + 1
	return out


# The line the F3 readout shows: the total against the cap, then the count per kind (kinds sorted by name).
static func summary(tree: SceneTree) -> String:
	var counts := counts_by_kind(tree)
	var kinds: Array = counts.keys()
	kinds.sort()
	var parts: Array[String] = []
	for kind: Variant in kinds:
		var n: int = counts[kind]
		parts.append("%s %d" % [str(kind), n])
	var detail := "none" if parts.is_empty() else ", ".join(parts)
	return "floor fx %d/%d: %s" % [live(tree).size(), Config.TD_MAX_FLOOR_EFFECTS, detail]
