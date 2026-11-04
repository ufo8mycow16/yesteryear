class_name CrewWalker
extends Node
## REV 389 (Glen: "some scripted background crew members just strolling around the corridors, to give the
## impression of a working ship" - few of them (two-thirds of the crew are on shore leave), never in your way,
## nothing to click).
##
## Walks one figure back and forth along a route of world points at an unhurried pace, pausing a few seconds at
## each end (turned to the wall, as if checking a panel). The figure's own animator turns movement into its walk.
## Never blocks anyone: the figure is not solid, and if the played character is close ahead on the route it
## stops and waits until the way is clear.

const SPEED := 1.05             # metres a second (at the character's own size)
const TURN_SPEED := 4.0         # radians a second
const PAUSE := Vector2(2.5, 6.0)
const GIVE_WAY := 1.5           # metres: someone this close ahead - stop and wait
const WALL_LOOK := 2.2          # REV 392: at a route's end, look this far either side for a wall to face

var figure: Node3D = null
var route: Array = []           # world points
var scale_k := 1.0
var _i := 0
var _dir := 1
var _wait := 0.0
var _face := NAN                # REV 392: the way to face while paused (the nearer side wall), or none
var _look := ""                 # REV 401: what the head is held on while stopped: "", "wall", "you"
var _rng := RandomNumberGenerator.new()


static func make(room: Node3D, fig: Node3D, points: Array, k: float) -> CrewWalker:
	var w := CrewWalker.new()
	w.name = "CrewWalker"
	w.figure = fig
	w.route = points
	w.scale_k = k
	room.add_child(w)
	CharacterBlocker.set_solid(fig, false)
	if not points.is_empty():
		fig.global_position = points[0]
	w._rng.randomize()
	w._wait = w._rng.randf_range(0.0, 3.0)        # don't all set off together
	return w


func _process(delta: float) -> void:
	if figure == null or not is_instance_valid(figure) or route.size() < 2:
		return
	if _wait > 0.0:
		_wait -= delta
		if not is_nan(_face):
			var d := wrapf(_face - figure.rotation.y, -PI, PI)
			figure.rotation.y += clampf(d, -TURN_SPEED * 0.5 * delta, TURN_SPEED * 0.5 * delta)
			_hold_look("wall")
		return
	_face = NAN
	var target: Vector3 = route[_i + _dir] if _i + _dir >= 0 and _i + _dir < route.size() else route[_i]
	var to := target - figure.global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.05:
		_i += _dir
		if _i <= 0 or _i >= route.size() - 1:
			_dir = -_dir
			_wait = _rng.randf_range(PAUSE.x, PAUSE.y)
			_face = _wall_side()
		return
	var heading := to / dist
	if _someone_ahead(heading):
		_hold_look("you")
		return
	_hold_look("")
	var want := atan2(heading.x, heading.z)
	var cur := figure.rotation.y
	var dyaw := wrapf(want - cur, -PI, PI)
	figure.rotation.y = cur + clampf(dyaw, -TURN_SPEED * delta, TURN_SPEED * delta)
	if absf(dyaw) > 1.2:
		return       # turn round on the spot first
	var step := minf(SPEED * scale_k * delta, dist)
	figure.global_position += heading * step


## REV 401 (Glen: "it's only when they stop that they look down at the ground" - their standing pose has the
## head tipped down): stopped, the walker holds its head up on something - the panel on the wall it turned to
## (eye height, just in front), or you, when it has stopped to let you by. Walking again, the head is free.
func _hold_look(what: String) -> void:
	if what == _look and what != "wall":
		return
	var face := CharacterFace.face_of(figure)
	if face == null:
		return
	match what:
		"wall":
			if _look != "wall":
				var fwd := Vector3(sin(_face), 0.0, cos(_face))
				var eyes := face.focus_point("eyes")
				face.look_at_point(eyes + fwd * 0.6 * scale_k + Vector3.UP * 0.05 * scale_k)
		"you":
			var room := get_parent()
			var body: Node3D = room.get("active_body") if room != null else null
			var them := CharacterFace.face_of(body) if body != null else null
			if them == null and body != null:
				for c in body.get_children():
					them = CharacterFace.face_of(c)
					if them != null:
						break
			if them != null:
				face.look_at_node(them.focus_node())
			elif body != null:
				face.look_at_point(body.global_position + Vector3.UP * 1.65 * scale_k)
		_:
			face.clear_look()
	_look = what


## REV 392 (Glen: she "stopped, at a door, and then went back the other way" - it looked like she'd forgotten
## something): pausing at an end, the walker turns to the nearer side wall, as if checking a panel there.
func _wall_side() -> float:
	if route.size() < 2 or not figure.is_inside_tree():
		return NAN
	var along: Vector3 = (route[route.size() - 1] - route[0])
	along.y = 0.0
	if along.length() < 0.01:
		return NAN
	along = along.normalized()
	var side := Vector3(along.z, 0.0, -along.x)
	var space := figure.get_world_3d().direct_space_state
	var from := figure.global_position + Vector3.UP * 1.2 * scale_k
	var best := INF
	var best_dir := Vector3.ZERO
	for d in [side, -side]:
		var q := PhysicsRayQueryParameters3D.create(from, from + d * WALL_LOOK * scale_k)
		q.collision_mask = 1
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var dist := from.distance_to(hit["position"])
			if dist < best:
				best = dist
				best_dir = d
	if best_dir == Vector3.ZERO:
		return NAN
	return atan2(best_dir.x, best_dir.z)


func _someone_ahead(heading: Vector3) -> bool:
	var room := get_parent()
	var body: Node3D = room.get("active_body") if room != null else null
	if body == null or not is_instance_valid(body):
		return false
	var d := body.global_position - figure.global_position
	d.y = 0.0
	return d.length() < GIVE_WAY * scale_k and d.dot(heading) > 0.0
