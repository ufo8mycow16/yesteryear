extends Control
class_name CircularMinimapFrame
## Circular minimap frame — thin gold outer ring + darker inner bezel,
## replacing the old square PanelContainer frame per the art direction's
## "final minimap should be circular... no giant rectangular modern minimap
## card." Content stays explicitly placeholder (a flat tint, no real map
## geometry) until real level data exists; only the frame treatment and the
## static player-heading marker are meant to be final here.
##
## Custom _draw() rather than a StyleBoxFlat because StyleBoxFlat can't
## produce a true circle/ring — this is the standard Godot approach for a
## round instrument face.

const RING_COLOR := Color(0.831, 0.686, 0.216)
const BEZEL_COLOR := Color(0.02, 0.02, 0.028, 0.95)
const PLACEHOLDER_COLOR := Color(0.1, 0.4, 0.3, 0.6)
const MARKER_COLOR := Color(0.92, 0.92, 0.9)
const RING_WIDTH := 2.0
const BEZEL_INSET := 3.0


## How quickly the marker eases toward the player's real heading (higher =
## snappier). Exponential smoothing, so it never visibly snaps.
const HEADING_SMOOTHING := 10.0
## Extremely subtle dark halo behind the ring so the circle carries similar
## visual weight to the WHO card / function bank without a square backing.
const BACKING_COLOR := Color(0.0, 0.0, 0.0, 0.16)
const BACKING_RINGS := 3
const BACKING_STEP := 3.0

var _player: Node3D
var _heading: float = 0.0

## Real map picture, supplied by the current scene (any node in the group
## "minimap_source" with a get_minimap_data() method). Drawn north-up, centred on
## the player. Without one the frame falls back to the flat placeholder tint.
var _map_texture: Texture2D
var _map_origin := Vector2.ZERO        # world (x, z) of the picture's top-left corner
var _map_px_per_metre: float = 16.0
var _view_metres: float = 26.0         # how many metres across the circle shows
var _labels: Array = []                # REV 804: room names from the room ([world x,z, text, size])
var _map_id := ""                      # REV 804: whose notes to show (MapNotes)
## REV 29: mouse-wheel zoom, only while the pointer is over the minimap. Kept across rooms and maps.
const ZOOM_MIN_METRES := 10.0
const ZOOM_MAX_METRES := 70.0
const ZOOM_STEP := 1.15
static var saved_view_metres: float = -1.0
static var modal_open: bool = false   # the full map screen sets this; the wheel is left alone while it is up
var _last_player_xz := Vector2(1e9, 1e9)
const CIRCLE_POINTS := 72
var _stale_timer: float = 0.0


func _process(delta: float) -> void:
	# REV 772: who you're playing can change (TAB, a story hand-over) - follow whoever it is now, every frame
	var now := PlayerController.current(get_tree())
	if now != _player:
		_player = now
		_last_player_xz = Vector2(1e9, 1e9)
	if _player == null or not is_instance_valid(_player):
		return
	if _map_texture == null:
		_try_load_map()
	else:
		# Big rooms: the scene may need to draw a fresh picture once the player walks off the old one.
		_stale_timer -= delta
		if _stale_timer <= 0.0:
			_stale_timer = 0.5
			var src := get_tree().get_first_node_in_group("minimap_source")
			if src != null and src.has_method("minimap_stale") and src.minimap_stale():
				_map_texture = null
				_try_load_map()
	if _map_texture != null and GameSettings.objective_marker:
		queue_redraw()      # REV 741: the objective marker pulses
	if _map_texture != null:
		var xz := Vector2(_player.global_position.x, _player.global_position.z)
		if xz.distance_squared_to(_last_player_xz) > 0.0004:
			_last_player_xz = xz
			queue_redraw()
	# The player model faces +Z at yaw 0, but the map is north-up with -Z at
	# the top and the marker's rest pose points up, so the screen rotation
	# is PI minus the yaw.
	var target := PI - _player.rotation.y
	var next := lerp_angle(_heading, target, 1.0 - exp(-HEADING_SMOOTHING * delta))
	if absf(angle_difference(next, _heading)) > 0.0005:
		_heading = next
		queue_redraw()


func _input(event: InputEvent) -> void:
	if modal_open or not is_visible_in_tree():
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_WHEEL_UP and mb.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	var local := get_global_transform().affine_inverse() * mb.global_position
	var radius: float = minf(size.x, size.y) / 2.0
	if local.distance_to(size / 2.0) > radius:
		return   # not over the minimap: leave the wheel to whatever else wants it
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_view_metres = maxf(_view_metres / ZOOM_STEP, ZOOM_MIN_METRES)   # zoom in: fewer metres across
	else:
		_view_metres = minf(_view_metres * ZOOM_STEP, ZOOM_MAX_METRES)
	saved_view_metres = _view_metres
	queue_redraw()
	get_viewport().set_input_as_handled()


## Asks the current scene for its map picture (once it exists).
func _try_load_map() -> void:
	var source := get_tree().get_first_node_in_group("minimap_source")
	if source == null or not source.has_method("get_minimap_data"):
		return
	var data: Dictionary = source.get_minimap_data()
	var tex: Texture2D = data.get("texture")
	if tex == null:
		return
	_map_texture = tex
	_map_origin = data.get("origin", Vector2.ZERO)
	_map_px_per_metre = float(data.get("px_per_metre", 16.0))
	_view_metres = float(data.get("view_metres", 26.0))
	_labels = data.get("labels", [])
	_map_id = MapNotes.map_id(data) if data.has("map_id") else ""
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = min(size.x, size.y) / 2.0

	for i in range(BACKING_RINGS, 0, -1):
		draw_circle(center, radius + BACKING_STEP * i, BACKING_COLOR)

	draw_circle(center, radius, BEZEL_COLOR)
	draw_arc(center, radius - RING_WIDTH / 2.0, 0, TAU, 64, RING_COLOR, RING_WIDTH, true)

	var inner_radius := radius - BEZEL_INSET
	# REV 120: not before the frame has a real size (a zero-size circle can't be drawn and spammed
	# "triangulation failed" errors), and only while the player still exists
	if inner_radius < 2.0:
		return
	if _map_texture != null and is_instance_valid(_player):
		draw_circle(center, inner_radius, BEZEL_COLOR)
		_draw_map(center, inner_radius)
	else:
		draw_circle(center, inner_radius, PLACEHOLDER_COLOR)

	# North tick stays fixed (map is north-up); only the player marker turns.
	var tick_outer := center + Vector2(0, -inner_radius)
	var tick_inner := center + Vector2(0, -inner_radius + 5)
	draw_line(tick_outer, tick_inner, RING_COLOR, 1.5)

	var marker_size := 5.0
	var pts := PackedVector2Array([
		Vector2(0, -marker_size),
		Vector2(-marker_size * 0.6, marker_size * 0.6),
		Vector2(marker_size * 0.6, marker_size * 0.6),
	])
	if not is_finite(_heading):
		return
	var xf := Transform2D(_heading, center)
	draw_colored_polygon(xf * pts, MARKER_COLOR)
	_draw_objective(center, inner_radius)


## REV 741 (item 6): the objective marker - inside the circle where it is, or an arrow on the rim toward it.
func _draw_objective(center: Vector2, inner_radius: float) -> void:
	if _map_texture == null or not is_instance_valid(_player):
		return
	var t := ObjectiveMarker.target(get_tree())
	if t.is_empty():
		return
	var w: Vector3 = t["pos"]
	var off := Vector2(w.x - _player.global_position.x, w.z - _player.global_position.z)
	var px := off / (_view_metres * 0.5) * inner_radius
	if px.length() <= inner_radius - 9.0:
		ObjectiveMarker.draw(self, center + px, bool(t["lift"]), 0.8)
	elif px.length() > 0.001:
		ObjectiveMarker.draw_edge_arrow(self, center, inner_radius, px.normalized(), bool(t["lift"]))


## The map picture, cut to a circle: a round polygon whose texture coordinates
## point at the part of the picture around the player (north-up, so world -Z is
## up the screen).
func _draw_map(center: Vector2, inner_radius: float) -> void:
	var tex_size := Vector2(_map_texture.get_width(), _map_texture.get_height())
	var player_xz := Vector2(_player.global_position.x, _player.global_position.z)
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in CIRCLE_POINTS:
		var a := TAU * float(i) / float(CIRCLE_POINTS)
		var unit := Vector2(cos(a), sin(a))
		points.append(center + unit * inner_radius)
		var world := player_xz + unit * (_view_metres * 0.5)
		var px := (world - _map_origin) * _map_px_per_metre
		uvs.append(px / tex_size)
	draw_colored_polygon(points, Color.WHITE, uvs, _map_texture)
	# REV 804: room names and the player's notes, as text at a fixed size
	var to_px := inner_radius / (_view_metres * 0.5)
	var small := 10 if _view_metres <= 40.0 else 9
	for l in _labels:
		if _view_metres > 45.0 and int(l[2]) < 12:
			continue          # zoomed well out: only the big names
		var at: Vector2 = center + ((l[0] as Vector2) - player_xz) * to_px
		if at.distance_to(center) < inner_radius - 10.0:
			MapNotes.draw_text(self, at, String(l[1]), small, MapNotes.LABEL_COLOUR)
	if not _map_id.is_empty():
		for n in MapNotes.notes(_map_id):
			var at: Vector2 = center + ((n["pos"] as Vector2) - player_xz) * to_px
			if at.distance_to(center) < inner_radius - 6.0:
				MapNotes.draw_note(self, at, String(n["text"]), small, at.distance_to(center) < inner_radius - 40.0)
