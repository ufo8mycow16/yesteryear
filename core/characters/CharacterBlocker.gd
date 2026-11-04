extends AnimatableBody3D
class_name CharacterBlocker
## REV 147 (CLAUDE.md item 21): every character is solid. CharacterKit puts one of these inside every
## figure it makes (named crew, stand-ins, background officers, Vulcans...), so nobody can walk
## through anybody, and characters added later get it without any per-scene code.
##
## - It lives on its own physics layer (CHARACTERS), not the world's layer 1, so the gameplay
##   camera's wall checks never bump into people; the player and walking NPCs include that layer
##   in what they collide with.
## - It's an AnimatableBody3D, so when a script walks the character (Spock heading back to the
##   group, Pell standing up) the body moves with them and nudges the player aside instead of
##   leaving the player standing inside them.
## - A figure that is the visible body of a CharacterBody3D (the player, Kirk/McCoy in Episode 1, a
##   follower) already has that body's capsule, so its blocker switches itself off.
## - Tight on purpose (Glen: properly solid, with a little leeway): a slim capsule, so crowds and
##   corridors stay walkable.
## - Background crew don't step aside; they stay put.
##
## A cutscene that needs people to pass through each other: CharacterBlocker.set_solid(figure, false),
## and true again afterwards.

## Physics layer 3. Layer 1 is the world, layer 2 the hotspots.
const LAYER := 4
const RADIUS := 0.27
const HEIGHT := 1.75
const GROUP := "character_blockers"

var _wanted_on := true


## Add the blocker to a figure (CharacterKit does this for every figure it makes).
static func attach(figure: Node3D) -> CharacterBlocker:
	if figure == null:
		return null
	var existing := of(figure)
	if existing != null:
		return existing
	var b := CharacterBlocker.new()
	b.name = "Blocker"
	figure.add_child(b)
	return b


## The blocker inside a figure, or null.
static func of(figure: Node) -> CharacterBlocker:
	if figure == null:
		return null
	for c in figure.get_children():
		if c is CharacterBlocker:
			return c
	return null


## Switch a figure's solidity on or off (for an authored moment that needs it off).
static func set_solid(figure: Node, on: bool) -> void:
	var b := of(figure)
	if b != null:
		b._wanted_on = on
		b._apply()


func _init() -> void:
	sync_to_physics = false        # follows the figure exactly, frame by frame
	collision_layer = LAYER
	collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "Capsule"
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	shape.shape = capsule
	shape.position.y = HEIGHT * 0.5
	add_child(shape)


func _enter_tree() -> void:
	add_to_group(GROUP)
	_apply()


## The figure this blocker belongs to.
func figure() -> Node3D:
	return get_parent() as Node3D


## Off when switched off, or when the figure is already some CharacterBody3D's body.
func is_active() -> bool:
	return collision_layer != 0


func _apply() -> void:
	var on := _wanted_on and not _inside_character_body()
	collision_layer = LAYER if on else 0
	var shape := get_node_or_null("Capsule") as CollisionShape3D
	if shape != null:
		shape.set_deferred("disabled", not on)


func _inside_character_body() -> bool:
	var p := get_parent()
	while p != null:
		if p is CharacterBody3D:
			return true
		p = p.get_parent()
	return false
