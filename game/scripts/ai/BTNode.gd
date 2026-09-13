# BTNode.gd
# Base node for the ECLIPSEBOUND hierarchical Behavior Tree framework.
class_name BTNode
extends RefCounted

enum Status {
	SUCCESS,
	FAILURE,
	RUNNING
}

var node_name: String = "BTNode"

func tick(_actor: Node, _blackboard: Dictionary) -> Status:
	return Status.SUCCESS
