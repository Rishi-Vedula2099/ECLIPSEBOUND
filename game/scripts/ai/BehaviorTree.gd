# BehaviorTree.gd
# Modular Behavior Tree framework providing Sequences, Selectors, Conditions, and Action nodes.
class_name BehaviorTree
extends RefCounted

enum Status {
	SUCCESS,
	FAILURE,
	RUNNING
}

var root_node = null
var blackboard: Dictionary = {}
var actor: Node = null

func _init(host_actor: Node = null, root = null) -> void:
	actor = host_actor
	root_node = root

func tick() -> Status:
	if not root_node:
		return Status.FAILURE
	return root_node.tick(actor, blackboard)

class BTNode extends RefCounted:
	var node_name: String = "BTNode"

	func tick(_p_actor: Node, _p_blackboard: Dictionary) -> Status:
		return Status.SUCCESS

# --- Composite: Sequence ---
class SequenceNode extends BTNode:
	var children: Array = []
	var current_child_idx: int = 0

	func _init(nname: String = "Sequence") -> void:
		node_name = nname

	func add_child(child) -> SequenceNode:
		children.append(child)
		return self

	func tick(p_actor: Node, p_blackboard: Dictionary) -> Status:
		while current_child_idx < children.size():
			var s = children[current_child_idx].tick(p_actor, p_blackboard)
			if s == Status.RUNNING:
				return Status.RUNNING
			elif s == Status.FAILURE:
				current_child_idx = 0
				return Status.FAILURE
			current_child_idx += 1
		
		current_child_idx = 0
		return Status.SUCCESS

# --- Composite: Selector ---
class SelectorNode extends BTNode:
	var children: Array = []
	var current_child_idx: int = 0

	func _init(nname: String = "Selector") -> void:
		node_name = nname

	func add_child(child) -> SelectorNode:
		children.append(child)
		return self

	func tick(p_actor: Node, p_blackboard: Dictionary) -> Status:
		while current_child_idx < children.size():
			var s = children[current_child_idx].tick(p_actor, p_blackboard)
			if s == Status.RUNNING:
				return Status.RUNNING
			elif s == Status.SUCCESS:
				current_child_idx = 0
				return Status.SUCCESS
			current_child_idx += 1
		
		current_child_idx = 0
		return Status.FAILURE

# --- Leaf: Condition ---
class ConditionNode extends BTNode:
	var condition_fn: Callable

	func _init(nname: String, fn: Callable) -> void:
		node_name = nname
		condition_fn = fn

	func tick(p_actor: Node, p_blackboard: Dictionary) -> Status:
		if condition_fn.is_valid() and condition_fn.call(p_actor, p_blackboard):
			return Status.SUCCESS
		return Status.FAILURE

# --- Leaf: Action Task ---
class ActionNode extends BTNode:
	var action_fn: Callable

	func _init(nname: String, fn: Callable) -> void:
		node_name = nname
		action_fn = fn

	func tick(p_actor: Node, p_blackboard: Dictionary) -> Status:
		if action_fn.is_valid():
			var res = action_fn.call(p_actor, p_blackboard)
			if res is Status:
				return res
			return Status.SUCCESS if bool(res) else Status.FAILURE
		return Status.FAILURE
