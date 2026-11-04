extends Node
## REV 160 (CLAUDE.md item 13): people notice McCoy. When the player character walks past someone,
## or comes up to talk to them, they now and then glance at him - a brief turn of the eyes and head
## (the face rig clamps how far), then back to what they were doing. Never in conversations or
## cutscenes, never while something else (dialogue, a scripted look) has them looking somewhere -
## those always win - and never everyone at once: one glance starts at a time, a short gap between
## glances, and each person has a cooldown so nobody stares.

const RANGE := 3.4              # metres (the character's own scale) - how close he has to come
const CHECK_EVERY := 0.25       # seconds between looks round
const CHANCE_PASSING := 0.22    # per check, someone he walks past
const CHANCE_APPROACH := 0.7    # per check, the person he has targeted to talk to / use
const GLANCE_SECONDS := Vector2(0.9, 1.7)
const COOLDOWN_SECONDS := Vector2(8.0, 16.0)
const GAP_SECONDS := 1.3        # between any two glances starting
const MAX_AT_ONCE := 2
const MOVING_SPEED := 0.4       # m/s - standing still next to someone isn't "passing"

var _check := 0.0
var _now := 0.0
var _last_start := -100.0
var _next_ok := {}      # figure -> time it may glance again
var _active := {}       # figure -> [face, end time, the player's figure]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()


func _process(delta: float) -> void:
	_now += delta
	_update_active()
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK_EVERY
	if ConversationPresenter.letterboxed or InteractionManager.is_locked() or DialogueManager.is_busy():
		_end_all()
		return
	if _active.size() >= MAX_AT_ONCE or _now - _last_start < GAP_SECONDS:
		return
	for k in _next_ok.keys():
		if not is_instance_valid(k):
			_next_ok.erase(k)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var me := _figure_of(player)
	if me == null:
		return
	var speed := 0.0
	if player is CharacterBody3D:
		var v := (player as CharacterBody3D).velocity
		speed = Vector2(v.x, v.z).length()
	var focus: Node = InteractionManager.get_focus() if InteractionManager.has_method("get_focus") else null
	var scale := maxf(player.global_transform.basis.get_scale().y, 0.01)
	var candidates: Array = []
	for f in get_tree().get_nodes_in_group("speakers"):
		var fig := f as Node3D
		if fig == null or fig == me or player.is_ancestor_of(fig) or not fig.is_visible_in_tree() or _active.has(fig):
			continue
		if _now < float(_next_ok.get(fig, 0.0)):
			continue
		var face := CharacterFace.face_of(fig)
		if face == null or face.is_looking():
			continue
		var d := Vector2(fig.global_position.x - player.global_position.x, fig.global_position.z - player.global_position.z).length() / scale
		if d > RANGE:
			continue
		var approached := focus != null and (focus == fig or (focus as Node).is_ancestor_of(fig))
		if not approached and speed < MOVING_SPEED:
			continue
		candidates.append([fig, face, approached])
	if candidates.is_empty():
		return
	var pick: Array = candidates[_rng.randi_range(0, candidates.size() - 1)]
	if _rng.randf() > (CHANCE_APPROACH if bool(pick[2]) else CHANCE_PASSING):
		return
	var fig: Node3D = pick[0]
	var face: CharacterFace = pick[1]
	# REV 214 (Glen: Kirk and Spock spend a lot of time looking at the floor): the glance used to aim
	# at McCoy's body node, whose origin is at his FEET. Meet his eyes instead.
	var my_face := CharacterFace.face_of(me)
	var look_at: Node3D = my_face.focus_node() if my_face != null else me
	face.look_at_node(look_at)
	_active[fig] = [face, _now + _rng.randf_range(GLANCE_SECONDS.x, GLANCE_SECONDS.y), look_at]
	_last_start = _now
	_next_ok[fig] = _now + _rng.randf_range(COOLDOWN_SECONDS.x, COOLDOWN_SECONDS.y)


## The figure (the thing with a face) that belongs to the player's body.
func _figure_of(player: Node) -> Node3D:
	for c in player.get_children():
		if c.is_in_group("speakers"):
			return c as Node3D
	for c in player.get_children():
		if c is Node3D and CharacterFace.face_of(c) != null:
			return c as Node3D
	return null


func _update_active() -> void:
	for fig in _active.keys():
		var e: Array = _active[fig]
		# a figure (or its face) freed by a room change: just forget it (never assign a freed one)
		if not is_instance_valid(fig) or not is_instance_valid(e[0]) or not is_instance_valid(e[2]):
			_active.erase(fig)
			continue
		var face: CharacterFace = e[0]
		# something else took over their look (dialogue, a cutscene): leave it alone
		if face.look_target() != e[2]:
			_active.erase(fig)
			continue
		if _now >= float(e[1]):
			face.clear_look()
			_active.erase(fig)


func _end_all() -> void:
	for fig in _active.keys():
		var e: Array = _active[fig]
		if is_instance_valid(fig) and is_instance_valid(e[0]) and is_instance_valid(e[2]) \
				and (e[0] as CharacterFace).look_target() == e[2]:
			(e[0] as CharacterFace).clear_look()
	_active.clear()
