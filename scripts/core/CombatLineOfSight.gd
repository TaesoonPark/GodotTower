extends RefCounted
class_name CombatLineOfSight

static func has_ranged_line_of_sight(tree: SceneTree, from_pos: Vector2, to_pos: Vector2) -> bool:
	if tree == null:
		return true
	for node in tree.get_nodes_in_group("blocking_structures"):
		if not _is_los_blocker(node):
			continue
		var structure: Node2D = node as Node2D
		var footprint: Vector2 = structure.get_meta("footprint_size") if structure.has_meta("footprint_size") else Vector2(40.0, 40.0)
		var rect := Rect2(structure.global_position - footprint * 0.5, footprint)
		if rect.has_point(from_pos) or rect.has_point(to_pos):
			continue
		if _segment_intersects_rect(from_pos, to_pos, rect):
			return false
	return true

static func _is_los_blocker(node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not (node is Node2D):
		return false
	if node.is_queued_for_deletion() or not node.is_inside_tree():
		return false
	if node.has_meta("blocks_ranged_line_of_sight"):
		return bool(node.get_meta("blocks_ranged_line_of_sight"))
	return bool(node.get_meta("blocks_movement")) and not bool(node.get_meta("passable_for_friendly"))

static func _segment_intersects_rect(from_pos: Vector2, to_pos: Vector2, rect: Rect2) -> bool:
	var p0: Vector2 = rect.position
	var p1: Vector2 = rect.position + Vector2(rect.size.x, 0.0)
	var p2: Vector2 = rect.position + rect.size
	var p3: Vector2 = rect.position + Vector2(0.0, rect.size.y)
	return Geometry2D.segment_intersects_segment(from_pos, to_pos, p0, p1) != null \
		or Geometry2D.segment_intersects_segment(from_pos, to_pos, p1, p2) != null \
		or Geometry2D.segment_intersects_segment(from_pos, to_pos, p2, p3) != null \
		or Geometry2D.segment_intersects_segment(from_pos, to_pos, p3, p0) != null
