extends Node
class_name WorldIndexService

signal pathing_world_changed

var _group_cache: Dictionary = {}
var _group_cache_dirty: Dictionary = {}
var _hot_groups: Array[StringName] = []

func setup(hot_groups: Array) -> void:
	_hot_groups.clear()
	for group_name_any in hot_groups:
		var group_name: StringName = StringName(group_name_any)
		_hot_groups.append(group_name)
		_group_cache_dirty[group_name] = true
	_connect_tree_signals()

func _ready() -> void:
	_connect_tree_signals()

func mark_group_dirty(group_name: StringName) -> void:
	_group_cache_dirty[group_name] = true

func mark_all_dirty() -> void:
	for group_name_any in _group_cache_dirty.keys():
		_group_cache_dirty[StringName(group_name_any)] = true

func mark_node_groups_dirty(node: Node) -> void:
	if node == null:
		return
	for group_name_any in _group_cache_dirty.keys():
		var group_name: StringName = StringName(group_name_any)
		if node.is_in_group(group_name):
			_group_cache_dirty[group_name] = true

func get_nodes_cached(group_name: StringName) -> Array:
	if not is_inside_tree():
		return []
	if bool(_group_cache_dirty.get(group_name, true)):
		var tree: SceneTree = get_tree()
		_group_cache[group_name] = tree.get_nodes_in_group(group_name)
		_group_cache_dirty[group_name] = false
	return _group_cache.get(group_name, [])

func _connect_tree_signals() -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	var added_callable: Callable = Callable(self, "_on_tree_node_added")
	if not tree.is_connected("node_added", added_callable):
		tree.connect("node_added", added_callable)
	var removed_callable: Callable = Callable(self, "_on_tree_node_removed")
	if not tree.is_connected("node_removed", removed_callable):
		tree.connect("node_removed", removed_callable)

func _on_tree_node_added(node: Node) -> void:
	_handle_tree_node_changed(node)

func _on_tree_node_removed(node: Node) -> void:
	_handle_tree_node_changed(node)

func _handle_tree_node_changed(node: Node) -> void:
	mark_node_groups_dirty(node)
	if node == null:
		return
	if node.is_in_group("blocking_structures") or node.is_in_group("build_sites") or node.is_in_group("structures"):
		pathing_world_changed.emit()
