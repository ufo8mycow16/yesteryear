extends RefCounted
class_name ObjectiveMarker
## REV 741 (Glen's bug list 31 Oct, item 6): "a glowing icon on the maps, showing you where to go" - a pulsing
## marker on the minimap and the M map at the current objective. Only once the game has given the goal (the
## room's partner stage - EpisodeRoom.objective_target); when the place is on another deck or in another room, it
## points at the nearest turbolift instead. Switched off by the map's "Show Map Objective Marker" checkbox
## (GameSettings.objective_marker).

const GOLD := Color(1.0, 0.78, 0.22)
const LIFT := Color(0.45, 0.85, 1.0)


## {} or {"pos": Vector3 (world), "lift": bool}.
static func target(tree: SceneTree) -> Dictionary:
	if tree == null or not GameSettings.objective_marker:
		return {}
	var room := tree.current_scene
	if room == null or not room.has_method("objective_target"):
		return {}
	var t: Variant = room.call("objective_target")
	if t is Vector3:
		return {"pos": t, "lift": false}
	if t is String and String(t) == "lift":
		var player := PlayerController.current(tree)
		var lift := nearest_lift(room, player.global_position if player != null else Vector3.ZERO)
		if lift != Vector3.INF:
			return {"pos": lift, "lift": true}
	return {}


## The nearest turbolift lever in the room (every map's levers are "Control Lever" hotspots - ModelRoom).
static func nearest_lift(room: Node, from: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for n in room.find_children("*", "Area3D", true, false):
		var dn: Variant = n.get("display_name")
		if dn == null or String(dn) != "Control Lever" or not (n as Node3D).is_visible_in_tree():
			continue
		var p := (n as Node3D).global_position
		var d := p.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = p
	return best


## Pulse 0..1 (still when Reduced Motion is on).
static func pulse() -> float:
	if GameSettings.reduced_motion:
		return 0.5
	return 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)


## Draws the marker at `at` on any CanvasItem: a soft glow, a ring that breathes, a diamond (a lift: a double
## chevron "up/down" instead of the diamond).
static func draw(ci: CanvasItem, at: Vector2, lift: bool, scale: float = 1.0) -> void:
	var col := LIFT if lift else GOLD
	var k := pulse()
	ci.draw_circle(at, (11.0 + 5.0 * k) * scale, Color(col, 0.18 + 0.12 * k))
	ci.draw_arc(at, (8.0 + 6.0 * k) * scale, 0.0, TAU, 28, Color(col, 0.9 - 0.5 * k), 1.6 * scale, true)
	if lift:
		for dy in [-3.5, 3.5]:
			var dir := -1.0 if dy < 0.0 else 1.0
			ci.draw_polyline(PackedVector2Array([at + Vector2(-4.0, dy - dir * 2.0) * scale, at + Vector2(0.0, dy + dir * 2.0) * scale,
				at + Vector2(4.0, dy - dir * 2.0) * scale]), Color(1, 1, 1, 0.95), 1.8 * scale, true)
	else:
		var d := PackedVector2Array([at + Vector2(0, -5) * scale, at + Vector2(5, 0) * scale, at + Vector2(0, 5) * scale, at + Vector2(-5, 0) * scale])
		ci.draw_colored_polygon(d, col)
		d.append(d[0])
		ci.draw_polyline(d, Color(0.1, 0.07, 0.0), 1.0, true)


## An arrow on the rim pointing at a marker that is off the edge of a round map.
static func draw_edge_arrow(ci: CanvasItem, centre: Vector2, radius: float, dir: Vector2, lift: bool) -> void:
	var col := LIFT if lift else GOLD
	var k := pulse()
	var tip := centre + dir * (radius - 2.0)
	var side := Vector2(-dir.y, dir.x)
	var base := tip - dir * 9.0
	ci.draw_colored_polygon(PackedVector2Array([tip, base + side * 5.5, base - side * 5.5]), Color(col, 0.65 + 0.35 * k))
