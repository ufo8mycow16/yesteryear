extends Node
## NameTags (REV 112): each character's name floating above their head, in Microgramma Bold, with a
## small triangle pointing down at them - so you can tell who's who on a busy set.
##
## The rules (agreed with Glen):
##  * Names fade out with distance from you, so a crowded room isn't a wall of text.
##  * The person you're aiming at is highlighted: brighter, a little larger, solid triangle.
##  * Hidden in letterboxed conversations, scripted scenes, photo mode, menus and the pause menu.
##  * Each name is in that character's subtitle colour (Kirk gold, Spock blue, McCoy teal...), or
##    gold when SPEAKER COLOURS is off.
##  * Settings > Accessibility > CHARACTER NAMES: ALWAYS / NEARBY ONLY / OFF.
##  * Kept off the screen edges, hidden behind walls, and never stacked on top of each other.
##  * No name over the character you're playing.
##
## Who is a character: anything in the "speakers" group (CharacterKit figures and real models).
## Their name comes from the hotspot they belong to (its display_name), the body that carries them
## (a PlayerController named "Kirk"), a "display_name" meta, or their speaker id.

const NEAR_FULL := 5.5        # metres (x room scale): full strength up to here...
const NEAR_GONE := 8.5        # ...gone by here (NEARBY ONLY)
const FAR_FULL := 13.0        # the same for ALWAYS
const FAR_GONE := 17.0
const EDGE := 16.0            # px kept clear of the screen edges
const ABOVE_HEAD := 0.12      # metres between the top of the head and the triangle (x scale)
const FADE_SPEED := 8.0       # how quickly names fade in/out

var _layer: CanvasLayer
var _canvas: Control
var _alpha := {}              # instance id -> shown alpha (smoothed)
var _top := {}                # instance id -> height of the head above the figure's origin (local)
var _tags: Array = []         # this frame's tags to draw


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = -1         # over the 3D scene, under the HUD and every menu
	add_child(_layer)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_tags)
	_layer.add_child(_canvas)


func _process(delta: float) -> void:
	_tags.clear()
	var mode: int = GameSettings.name_tags
	var cam := get_viewport().get_camera_3d()
	var show_any := mode != 2 and cam != null and _allowed()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var from: Vector3 = player.global_position if player != null else (cam.global_position if cam != null else Vector3.ZERO)
	# (the focused hotspot can already be freed when a room changes - check before using it)
	var raw_focus = InteractionManager.get_focus()
	var focus: Node3D = raw_focus as Node3D if is_instance_valid(raw_focus) else null
	var seen := {}
	if cam != null:
		for f in get_tree().get_nodes_in_group("speakers"):
			var fig := f as Node3D
			if fig == null or not fig.is_inside_tree():
				continue
			var id := fig.get_instance_id()
			seen[id] = true
			var want := 0.0
			var tag := {}
			if show_any and _counts(fig, player):
				tag = _measure(fig, cam, from, mode, focus)
				want = float(tag.get("alpha", 0.0))
			var a: float = move_toward(float(_alpha.get(id, 0.0)), want, delta * FADE_SPEED)
			_alpha[id] = a
			if a > 0.01 and not tag.is_empty():
				tag["alpha"] = a
				_tags.append(tag)
	for id in _alpha.keys():
		if not seen.has(id):
			_alpha.erase(id)
			_top.erase(id)
	_place()
	_canvas.queue_redraw()


## Only while you're walking around a room yourself.
func _allowed() -> bool:
	if get_tree().paused or PhotoMode.active or ConversationPresenter.letterboxed:
		return false
	if InteractionManager.is_locked() or InteractionManager.is_modal_suspended():
		return false
	var hud := get_tree().get_first_node_in_group("hud")
	return hud != null and hud.is_visible_in_tree()


## A character that gets a tag: visible, not the one you're playing, not a model inside another
## tagged figure (a real model can sit inside a CharacterKit wrapper).
func _counts(fig: Node3D, player: Node3D) -> bool:
	if not fig.is_visible_in_tree():
		return false
	if player != null and (player == fig or player.is_ancestor_of(fig)):
		return false
	var p := fig.get_parent()
	while p != null:
		if p.is_in_group("speakers"):
			return false
		p = p.get_parent()
	return true


func _measure(fig: Node3D, cam: Camera3D, from: Vector3, mode: int, focus: Node3D) -> Dictionary:
	var room_scale := _scale_of(fig)
	# REV 132: above the head where it really is (sitting, kneeling), not where it would be standing
	var head := CharacterKit.crown_world(fig) + Vector3.UP * ABOVE_HEAD * room_scale
	if cam.is_position_behind(head):
		return {}
	var full := (NEAR_FULL if mode == 1 else FAR_FULL) * room_scale
	var gone := (NEAR_GONE if mode == 1 else FAR_GONE) * room_scale
	var dist := Vector2(head.x - from.x, head.z - from.z).length()
	var alpha := 1.0 - clampf((dist - full) / maxf(gone - full, 0.01), 0.0, 1.0)
	if alpha <= 0.0:
		return {}
	if _blocked(cam.global_position, head, fig):
		return {}
	var holder := _holder(fig)
	var focused: bool = focus != null and (focus == holder or (focus.global_position * Vector3(1, 0, 1)).distance_to(fig.global_position * Vector3(1, 0, 1)) < 0.6 * room_scale)
	var who := _name_of(fig, holder)
	if who == "":
		return {}
	return {"pos": cam.unproject_position(head), "name": who, "focused": focused,
		"alpha": alpha * (1.0 if focused else 0.78), "dist": cam.global_position.distance_to(head),
		"colour": GameSettings.speaker_colour(who, UITheme.GOLD)}


## Is a wall (or anything solid that isn't them) between the camera and their head?
func _blocked(eye: Vector3, head: Vector3, fig: Node3D) -> bool:
	var space := fig.get_world_3d().direct_space_state
	if space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, head)
	var skip: Array[RID] = []
	var owner_node := _holder(fig)
	for n in [fig, owner_node]:
		if n is CollisionObject3D:
			skip.append((n as CollisionObject3D).get_rid())
		if n != null:
			for c in (n as Node).find_children("*", "CollisionObject3D", true, false):
				skip.append((c as CollisionObject3D).get_rid())
	var player := get_tree().get_first_node_in_group("player")
	if player is CollisionObject3D:
		skip.append((player as CollisionObject3D).get_rid())
	for b in get_tree().get_nodes_in_group("see_through"):     # REV 605: force fields don't hide people
		if b is CollisionObject3D:
			skip.append((b as CollisionObject3D).get_rid())
	q.exclude = skip
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and eye.distance_to(hit["position"]) < eye.distance_to(head) - 0.15


## The hotspot or body a figure belongs to (for its name and focus), else the figure itself.
static func _holder(fig: Node3D) -> Node3D:
	var p := fig.get_parent()
	while p != null:
		if p is Hotspot or p is PlayerController:
			return p as Node3D
		if p == fig.get_tree().current_scene:
			break
		p = p.get_parent()
	return fig


static func _name_of(fig: Node3D, holder: Node3D) -> String:
	if fig.has_meta("display_name"):
		return String(fig.get_meta("display_name"))
	if holder is Hotspot and String((holder as Hotspot).display_name) != "":
		return String((holder as Hotspot).display_name)
	if holder is PlayerController:
		# REV 642 (Glen: "CAPTAIN KIRK" over Chapel in Episode 2): the body is named after its SLOT ("Kirk" / "McCoy");
		# who is in that slot is the room's to say (EpisodeRoom.lead_people - Episode 2 puts Chapel / Spock there).
		var slot := String(holder.name).to_lower()
		var scene := holder.get_tree().current_scene if holder.is_inside_tree() else null
		if scene != null and scene.has_method("lead"):
			var who := String(scene.call("lead", slot))
			if who != "":
				return GameNames.character(who, who.capitalize())
		return GameNames.character(String(holder.name), String(holder.name))
	var id := String(fig.get_meta("speaker_id", ""))
	if id == "":
		return ""
	return GameNames.character(id)


## Height of the top of the head above the figure's origin, in its own space (measured once from
## its meshes; a real model's face gives a better answer when it has one).
func _head_top(fig: Node3D) -> float:
	var id := fig.get_instance_id()
	if _top.has(id):
		return float(_top[id])
	var top := 1.8
	var face := CharacterFace.face_of(fig)
	if face != null and face.ready_to_use:
		var eyes := fig.global_transform.affine_inverse() * face.focus_point("eyes")
		top = eyes.y + 0.14
	else:
		top = CharacterKit.head_top_local(fig)
	_top[id] = top
	return top


static func _scale_of(fig: Node3D) -> float:
	return maxf(fig.global_transform.basis.get_scale().y, 0.01)


## Lay this frame's tags out: sizes, clamped to the screen, nearer ones first, and any that would
## overlap a nearer one nudged up above it.
func _place() -> void:
	var vp := _canvas.get_viewport_rect().size
	var font: Font = UITheme.font_bold
	if font == null:
		font = ThemeDB.fallback_font
	var base := clampi(int(round(15.0 * vp.y / 720.0)), 12, 30)
	_tags.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))
	var placed: Array[Rect2] = []
	for t in _tags:
		var size := base + (2 if bool(t["focused"]) else 0)
		var text := CinematicDialogueUI.format_speaker(String(t["name"]))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var h := font.get_height(size)
		var tri := maxf(5.0, size * 0.38)
		var p: Vector2 = t["pos"]
		var rect := Rect2(p.x - w * 0.5, p.y - tri - 3.0 - h, w, h)
		for _i in 4:
			var clash := false
			for r in placed:
				if r.grow(2.0).intersects(rect):
					rect.position.y = r.position.y - h - 4.0
					clash = true
			if not clash:
				break
		rect.position.x = clampf(rect.position.x, EDGE, vp.x - EDGE - w)
		rect.position.y = clampf(rect.position.y, EDGE, vp.y - EDGE - h)
		placed.append(rect)
		t["rect"] = rect
		t["text"] = text
		t["size"] = size
		t["tri"] = tri
		t["font"] = font


func _draw_tags() -> void:
	for t in _tags:
		if not t.has("rect"):
			continue
		var rect: Rect2 = t["rect"]
		var a: float = t["alpha"]
		var col: Color = t["colour"]
		var font: Font = t["font"]
		var size: int = t["size"]
		var base_line := rect.position + Vector2(0.0, font.get_ascent(size))
		_canvas.draw_string_outline(font, base_line, String(t["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.75 * a))
		_canvas.draw_string(font, base_line, String(t["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col.r, col.g, col.b, a))
		# the little triangle, pointing down at them (centred under the name, or at the person if
		# the name had to be moved)
		var tri: float = t["tri"]
		var p: Vector2 = t["pos"]
		if not p.is_finite() or not rect.position.is_finite():
			continue
		var cx := clampf(p.x, rect.position.x + tri, rect.end.x - tri)
		var top_y := rect.end.y + 2.0
		var pts := PackedVector2Array([Vector2(cx - tri, top_y), Vector2(cx + tri, top_y), Vector2(cx, top_y + tri * 0.9)])
		var ta := a * (1.0 if bool(t["focused"]) else 0.6)
		_canvas.draw_colored_polygon(pts, Color(col.r, col.g, col.b, ta))
		_canvas.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0, 0.5 * ta), 1.0, true)
