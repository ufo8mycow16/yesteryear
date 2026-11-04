extends RefCounted
class_name Approach
## REV 147 (CLAUDE.md items 22 and 29): where the player stands to do something, and walking there.
## One system for both:
##
##  - USING something (item 29): clicking a console, the intercom, a door... from a reasonable
##    distance walks the player to a sensible spot in front of it, turns them to face it, and only
##    then does it happen. Nobody operates a console from metres away, and nobody has to shuffle
##    onto an invisible exact spot. A hotspot can name its own spot (Hotspot.approach_point, e.g. the
##    intercom, so McCoy has room to raise his arm); otherwise one is worked out from the hotspot's
##    box. If the player is already within reach, they just turn to face it.
##  - TALKING (items 22 and 29): conversations start with the two people a comfortable distance
##    apart, about 1.2-1.5 m (TALK_MIN / TALK_IDEAL, times the character's size). If the player is
##    too close or too far, the PLAYER's character moves - whoever they're playing - never the other
##    person, who may be standing on a planned mark. Everyone else nearby is kept clear of too.
##
## Every spot is checked before anyone moves: the player's own capsule must fit there (no walls,
## props or people), there must be floor under it at the same level, and the straight walk there
## must be clear. If no spot works, nobody moves and the action goes ahead from where they are.

const TALK_MIN := 0.85         # metres (for a normal-sized adult; scaled by the player's size). REV 235 (Glen): was 1.2
const TALK_IDEAL := 1.0        # REV 235 (Glen: at 1.35-1.5 m a close-up looked like someone talking to no one): was 1.35
const TALK_FAR := 1.4          # walking up to talk: further than this, step in to TALK_IDEAL (REV 235: was 1.9)
const PERSONAL_SPACE := 0.9    # from anyone else in the room
const REACH := 0.75            # within this of an object's edge: close enough to use it
const STAND_OFF := 0.6         # how far from an object's edge to stand when walking up to it
## Directions tried around the person being spoken to, nearest to where the player already is first.
const TALK_ANGLES := [0.0, 25.0, -25.0, 50.0, -50.0, 75.0, -75.0, 100.0, -100.0, 135.0, -135.0, 180.0]
const USE_ANGLES := [0.0, 30.0, -30.0, 60.0, -60.0]


# ---- talking --------------------------------------------------------------------------------

## Where the player should stand to talk to `partner` (a figure). mode "approach": the player
## clicked TALK - fix too close AND too far. mode "stage": a conversation is starting - only fix
## too close (or crowding someone else). Returns {} when the player should stay where they are.
static func talk_spot(player: PlayerController, partner: Node3D, mode: String = "approach") -> Dictionary:
	if player == null or partner == null or not player.is_inside_tree():
		return {}
	var k := _size(player)
	var me := player.global_position
	var them := partner.global_position
	var flat := Vector3(me.x - them.x, 0.0, me.z - them.z)
	var d := flat.length()
	var crowded := _crowding(player, me, partner) < PERSONAL_SPACE * k
	var too_close := d < TALK_MIN * k
	var too_far := mode == "approach" and d > TALK_FAR * k
	if not too_close and not too_far and not crowded:
		return {}
	var base := flat.normalized() if d > 0.05 else _facing(partner)
	for a in TALK_ANGLES:
		var dir := base.rotated(Vector3.UP, deg_to_rad(float(a)))
		var spot := _on_floor(player, them + dir * TALK_IDEAL * k)
		if spot == Vector3.INF:
			continue
		if _crowding(player, spot, partner) < PERSONAL_SPACE * k:
			continue
		if not fits(player, spot) or not path_clear(player, spot):
			continue
		return {"pos": spot, "face": them}
	return {}


## The figure a hotspot stands for, if it's a person: one inside it (Kirk, Spock, Pell...), else the
## nearest character to it (Episode 1's partner spot follows the other player body).
static func figure_for(hotspot: Node3D) -> Node3D:
	if hotspot == null:
		return null
	for n in hotspot.find_children("*", "Node3D", true, false):
		if n.has_meta("speaker_id") or CharacterBlocker.of(n) != null:
			return n as Node3D
	var best: Node3D = null
	var best_d := 1.2
	for f in _people(hotspot):
		var d := Vector2(f.global_position.x - hotspot.global_position.x, f.global_position.z - hotspot.global_position.z).length()
		if d < best_d:
			best_d = d
			best = f
	return best


# ---- using things -----------------------------------------------------------------------------

## Where the player should stand to use `hotspot`, or {} to use it from where they are.
static func use_spot(player: PlayerController, hotspot: Hotspot) -> Dictionary:
	if player == null or hotspot == null or not player.is_inside_tree():
		return {}
	var k := _size(player)
	var me := player.global_position
	# an authored spot (Hotspot.approach_point, in the hotspot's own space)
	if hotspot.has_approach_point():
		var face := hotspot.global_transform * hotspot.approach_face
		var mark := _on_floor(player, hotspot.global_transform * hotspot.approach_point)
		if mark == Vector3.INF:
			return {}
		if Vector2(mark.x - me.x, mark.z - me.z).length() < 0.15 * k:
			return {"pos": me, "face": face}
		if fits(player, mark) and path_clear(player, mark):
			return {"pos": mark, "face": face}
		return {"pos": me, "face": face}
	# worked out from the hotspot's box: the nearest point of its footprint
	var edge := _nearest_edge(hotspot, me)
	if edge == Vector3.INF:
		return {}
	var gap := Vector2(me.x - edge.x, me.z - edge.z)
	var face_point := Vector3(edge.x, hotspot.global_position.y, edge.z)
	if gap.length() <= REACH * k:
		# already within reach (or inside a big area like the lane): just face it
		return {"pos": me, "face": face_point} if gap.length() > 0.05 else {}
	var out := Vector3(gap.x, 0.0, gap.y).normalized()
	for a in USE_ANGLES:
		var dir := out.rotated(Vector3.UP, deg_to_rad(float(a)))
		var spot := _on_floor(player, edge + dir * STAND_OFF * k)
		if spot == Vector3.INF:
			continue
		if fits(player, spot) and path_clear(player, spot):
			return {"pos": spot, "face": face_point}
	return {"pos": me, "face": face_point}


# ---- checks -----------------------------------------------------------------------------------

## The player's capsule fits at `spot` (feet position): nothing solid there - walls, props, people.
static func fits(player: PlayerController, spot: Vector3) -> bool:
	var shape_node := _capsule_of(player)
	if shape_node == null:
		return true
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape_node.shape
	var xf := shape_node.global_transform
	xf.origin = spot + (shape_node.global_position - player.global_position) + Vector3.UP * 0.08 * _size(player)
	q.transform = xf
	q.collision_mask = player.collision_mask
	q.exclude = [player.get_rid()]
	q.collide_with_areas = false
	return space.intersect_shape(q, 1).is_empty()


## The straight walk from where the player is to `spot` is clear.
static func path_clear(player: PlayerController, spot: Vector3) -> bool:
	var from := player.global_transform
	from.origin += Vector3.UP * 0.12 * _size(player)       # lifted a little so the floor doesn't count
	var motion := spot - player.global_position
	motion.y = 0.0
	if motion.length() < 0.02:
		return true
	return not player.test_move(from, motion, null, 0.001)


## `spot` dropped onto the floor below/above it at about the player's level; INF if there's none.
static func _on_floor(player: PlayerController, spot: Vector3) -> Vector3:
	var k := _size(player)
	var space := player.get_world_3d().direct_space_state
	var top := Vector3(spot.x, player.global_position.y + 0.9 * k, spot.z)
	var q := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * (0.9 * k + player.max_step_height + 0.3))
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
		return Vector3.INF
	var y: float = (hit["position"] as Vector3).y
	if absf(y - player.global_position.y) > player.max_step_height:
		return Vector3.INF
	return Vector3(spot.x, y, spot.z)


## How close the nearest other person (not the player, not `partner`) is to `spot`.
static func _crowding(player: PlayerController, spot: Vector3, partner: Node3D) -> float:
	var best := INF
	for f in _people(player):
		if f == partner or player.is_ancestor_of(f) or f == player:
			continue
		if partner != null and (partner.is_ancestor_of(f) or f.is_ancestor_of(partner)):
			continue
		var d := Vector2(f.global_position.x - spot.x, f.global_position.z - spot.z).length()
		best = minf(best, d)
	return best


## Everyone standing in the scene: solid figures, plus the other player bodies (Episode 1).
static func _people(from: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for b in from.get_tree().get_nodes_in_group(CharacterBlocker.GROUP):
		var blk := b as CharacterBlocker
		if blk != null and blk.is_active() and blk.figure() != null and blk.figure().is_visible_in_tree():
			out.append(blk.figure())
	for p in from.get_tree().get_nodes_in_group("player"):
		if p is Node3D and (p as Node3D).is_visible_in_tree():
			out.append(p as Node3D)
	return out


static func _nearest_edge(hotspot: Hotspot, from: Vector3) -> Vector3:
	var box: BoxShape3D = null
	var shape_node: CollisionShape3D = null
	for c in hotspot.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			shape_node = c
			box = (c as CollisionShape3D).shape
			break
	if box == null:
		return hotspot.global_position
	var local := shape_node.global_transform.affine_inverse() * from
	var h := box.size * 0.5
	var p := Vector3(clampf(local.x, -h.x, h.x), 0.0, clampf(local.z, -h.z, h.z))
	var g := shape_node.global_transform * p
	return Vector3(g.x, from.y, g.z)


static func _capsule_of(player: Node) -> CollisionShape3D:
	for c in player.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
			return c
	return null


static func _size(player: PlayerController) -> float:
	return maxf(player.body_scale, 0.1)


static func _facing(fig: Node3D) -> Vector3:
	var f := fig.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.BACK
