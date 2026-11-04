extends Node3D
## The Guardian of Forever.
##
## The ring model has no texture layout of its own (it came from a 3D-print
## kit), so the stone is wrapped on from all sides with a triplanar material.
## The doorway is centred on this node's origin, with its floor at ground level,
## so placing this node is placing the doorway. The player walks through along Z.

@export var stone_material: Material

func _ready() -> void:
	if stone_material == null:
		return
	for node in find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = stone_material
