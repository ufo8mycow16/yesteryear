extends Node3D
class_name HotspotHalo
## Reusable "this is interactable" indicator — a small number of tiny,
## crisp emissive points scattered near a hotspot, twinkling asynchronously
## at a low ambient intensity, boosted (still subtle) while that hotspot is
## the one currently targeted, and hidden entirely while a HUD modal panel
## has interaction suspended. Attached automatically to every hotspot by
## Hotspot._enter_tree() — nothing here is Prologue-specific, and no
## concrete hotspot script needs to know this exists.
##
## Deliberately NOT: an outline shader, a loot-style glow, a particle
## fountain, or a sparkle explosion. REV 137: each point is a little four-
## pointed star (long thin cross rays, short diagonal ones, a soft bright
## core; drawn once in code — no art asset needed), additive-blended, with
## its own random phase and period so the stars drift in and out of
## brightness independently. Each one swells as it brightens and flickers
## quickly at its peak, which is what reads as "twinkling" instead of
## "blinking". Brighter and a little bigger than the old soft dots so they
## are easy to spot, but still only a handful per hotspot.

# ---- GLOBAL TUNING (all hotspots share these; retune here once the real
# bowling-alley environment is imported) ---------------------------------
const STAR_COUNT := 6
const STAR_SIZE := 0.1            # world units, across the rays
const INTENSITY := 1.0            # global brightness multiplier
const BASE_ALPHA := 0.55          # idle peak alpha (before INTENSITY)
const TARGETED_MULTIPLIER := 2.0  # peak boost while this hotspot is targeted (capped at fully bright); REV 160: 1.7 -> 2.0
## REV 160 (item 19): the moment it becomes the target, the stars swell a little brighter and settle.
const FOCUS_SWELL := 0.5
const FOCUS_SWELL_SECONDS := 0.35
const MIN_PERIOD := 1.3           # seconds per star lifetime (twinkle cycle)
const MAX_PERIOD := 2.4
const FLICKER_HZ := 6.0           # the quick shimmer at a star's brightest
const STAR_COLOR := Color(1.0, 0.9, 0.62)

## Hold the "highlight_hotspots" key (H, or the gamepad's Back button) and every
## interactable object in the room shows a bright ring and its name, even
## through walls. The twinkling stars above stay the quiet, always-on hint.
const MARKER_SIZE := 0.34
const MARKER_COLOR := Color(1.0, 0.86, 0.4)
const LABEL_PIXEL_SIZE := 0.0009

static var _star_texture: ImageTexture
static var _ring_texture: ImageTexture


class _Star:
	var node: MeshInstance3D
	var cycle: int = 0
	var material: StandardMaterial3D
	var phase: float = 0.0
	var period: float = 2.0
	var flicker: float = 0.0
	var size: float = 1.0


var _stars: Array[_Star] = []
var _time: float = 0.0
var _targeted: bool = false
var _swell := 0.0
var _suppressed: bool = false
var _suppress_modal: bool = false
var _suppress_convo: bool = false
var _suppress_cutscene: bool = false
var _center_offset := Vector3(0, 0.4, 0)
var _radius := 0.3
var _marker: Node3D
var _marker_ring: MeshInstance3D
var _marker_material: StandardMaterial3D
var _marker_label: Label3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	var owner_hotspot := get_parent()
	if owner_hotspot is Hotspot:
		_center_offset = owner_hotspot.halo_center_offset
		_radius = owner_hotspot.halo_radius

	for i in range(STAR_COUNT):
		var star := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(STAR_SIZE, STAR_SIZE)
		star.mesh = quad

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
		mat.disable_receive_shadows = true
		mat.albedo_texture = _get_star_texture()
		mat.albedo_color = Color(STAR_COLOR.r, STAR_COLOR.g, STAR_COLOR.b, 0.0)
		star.material_override = mat

		star.position = _random_star_position()
		add_child(star)

		var record := _Star.new()
		record.node = star
		record.cycle = -1
		record.material = mat
		record.phase = randf_range(0.0, TAU)
		record.period = randf_range(MIN_PERIOD, MAX_PERIOD)
		record.flicker = randf_range(0.0, TAU)
		record.size = randf_range(0.7, 1.15)
		_stars.append(record)

	_build_marker(owner_hotspot)

	# Pick up whatever the suspension state already is (e.g. a hotspot
	# that enters the tree while a modal happens to already be open)
	# rather than always starting visible for one frame.
	_suppress_modal = InteractionManager.is_modal_suspended()
	_refresh_suppression()

	InteractionManager.focus_changed.connect(_on_focus_changed)
	InteractionManager.modal_suspended_changed.connect(_on_modal_changed)
	InteractionManager.lock_changed.connect(_on_lock_changed)
	InteractionManager.verb_used.connect(_on_verb_used)
	# Hotspot indicators also step aside while a conversation is running.
	DialogueManager.conversation_started.connect(_on_conversation_started)
	DialogueManager.conversation_ended.connect(_on_conversation_ended)


func _process(delta: float) -> void:
	if _suppressed:
		return
	_time += delta
	_update_marker()
	_swell = maxf(_swell - delta / FOCUS_SWELL_SECONDS, 0.0)
	var peak := minf(BASE_ALPHA * INTENSITY * (TARGETED_MULTIPLIER if _targeted else 1.0) * (1.0 + FOCUS_SWELL * _swell * _swell), 1.0)
	for record in _stars:
		var t: float = _time / record.period + record.phase / TAU
		# New twinkle cycle = new spot, so stars appear/vanish at varied
		# places rather than sitting in a constant ring. The move happens
		# at the cycle boundary, where the star is at its dimmest.
		var cycle := int(floor(t))
		if cycle != record.cycle:
			record.cycle = cycle
			record.node.position = _random_star_position()
			record.size = randf_range(0.7, 1.15)
		var wave := (1.0 - cos(fposmod(t, 1.0) * TAU)) * 0.5
		wave = wave * wave * (3.0 - 2.0 * wave)          # a sharper rise and fall: a glint, not a glow
		var shimmer := 1.0 - 0.3 * wave * (0.5 + 0.5 * sin(_time * FLICKER_HZ * TAU + record.flicker))
		var alpha: float = peak * wave * shimmer
		var grow: float = record.size * (0.45 + 0.55 * wave)
		record.node.scale = Vector3(grow, grow, grow)
		var c: Color = record.material.albedo_color
		record.material.albedo_color = Color(c.r, c.g, c.b, alpha)


## REV 103: a gold ring that expands and fades from the thing you just used. It lives beside the
## halo (not inside it), so it still shows when the interaction immediately hides the halo for a scene.
const PING_SECONDS := 0.5


func _on_verb_used(hotspot: Hotspot, _verb: String) -> void:
	if hotspot == null or hotspot != get_parent() or not is_inside_tree():
		return
	var ring := MeshInstance3D.new()
	ring.name = "UsePing"
	var quad := QuadMesh.new()
	quad.size = Vector2(MARKER_SIZE, MARKER_SIZE)
	ring.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.albedo_texture = _get_ring_texture()
	var colour: Color = GameSettings.marker_color()
	mat.albedo_color = Color(colour.r, colour.g, colour.b, 0.9)
	mat.render_priority = 100
	ring.material_override = mat
	hotspot.add_child(ring)
	ring.position = _center_offset
	var tw := ring.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "scale", Vector3(2.6, 2.6, 1.0), PING_SECONDS)
	tw.tween_property(mat, "albedo_color:a", 0.0, PING_SECONDS)
	tw.chain().tween_callback(ring.queue_free)


func _on_focus_changed(hotspot: Hotspot) -> void:
	var now := hotspot != null and hotspot == get_parent()
	if now and not _targeted:
		_swell = 1.0
	_targeted = now


func _on_modal_changed(v: bool) -> void:
	_suppress_modal = v
	_refresh_suppression()


func _on_lock_changed(v: bool) -> void:
	_suppress_cutscene = v
	_refresh_suppression()


func _on_conversation_started(_dialogue) -> void:
	_suppress_convo = true
	_refresh_suppression()


func _on_conversation_ended(_dialogue_id) -> void:
	_suppress_convo = false
	_refresh_suppression()


func _random_star_position() -> Vector3:
	return _center_offset + Vector3(
		randf_range(-_radius, _radius),
		randf_range(-_radius * 0.6, _radius * 0.6),
		randf_range(-_radius, _radius)
	)


func _refresh_suppression() -> void:
	_apply_suppressed(_suppress_modal or _suppress_convo or _suppress_cutscene)


func _apply_suppressed(suspended: bool) -> void:
	_suppressed = suspended
	visible = not suspended
	if suspended:
		# Snap straight to dark rather than leaving whatever mid-twinkle
		# alpha each star happened to be at — nothing to catch the eye for
		# the one frame before `visible` takes effect.
		for record in _stars:
			var c: Color = record.material.albedo_color
			record.material.albedo_color = Color(c.r, c.g, c.b, 0.0)


## A four-pointed twinkle star, drawn once in code: long thin rays up/down/left/right, shorter fainter
## diagonal ones, and a soft round core.
static func _get_star_texture() -> ImageTexture:
	if _star_texture == null:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := (size - 1) / 2.0
		var half := size / 2.0
		for y in size:
			for x in size:
				var dx := (x - c) / half
				var dy := (y - c) / half
				var r := sqrt(dx * dx + dy * dy)
				var core := exp(-r * r / 0.012)
				var glow := 0.35 * exp(-r * r / 0.06)
				# the cross: thin across, fading toward the tips
				var ray_h := exp(-dy * dy / 0.0009) * maxf(1.0 - absf(dx), 0.0)
				var ray_v := exp(-dx * dx / 0.0009) * maxf(1.0 - absf(dy), 0.0)
				# the diagonals: half as long, fainter
				var u := (dx + dy) * 0.7071
				var v := (dx - dy) * 0.7071
				var ray_d1 := exp(-v * v / 0.0006) * maxf(1.0 - absf(u) * 2.0, 0.0) * 0.45
				var ray_d2 := exp(-u * u / 0.0006) * maxf(1.0 - absf(v) * 2.0, 0.0) * 0.45
				var a := core + glow + pow(ray_h, 1.5) + pow(ray_v, 1.5) + ray_d1 + ray_d2
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
		img.generate_mipmaps()
		_star_texture = ImageTexture.create_from_image(img)
	return _star_texture


# ---- highlight marker (hold the highlight key) -----------------------------

func _build_marker(owner_hotspot: Node) -> void:
	_marker = Node3D.new()
	_marker.name = "HighlightMarker"
	_marker.position = _center_offset
	_marker.visible = false
	add_child(_marker)

	_marker_material = StandardMaterial3D.new()
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_marker_material.no_depth_test = true
	_marker_material.disable_receive_shadows = true
	_marker_material.albedo_texture = _get_ring_texture()
	_marker_material.albedo_color = MARKER_COLOR
	_marker_material.render_priority = 100

	_marker_ring = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(MARKER_SIZE, MARKER_SIZE)
	_marker_ring.mesh = quad
	_marker_ring.material_override = _marker_material
	_marker.add_child(_marker_ring)

	_marker_label = Label3D.new()
	_marker_label.text = _label_text(owner_hotspot)
	_marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker_label.no_depth_test = true
	_marker_label.fixed_size = true
	_marker_label.pixel_size = LABEL_PIXEL_SIZE
	_marker_label.font_size = 28
	_marker_label.outline_size = 10
	_marker_label.modulate = MARKER_COLOR
	_marker_label.outline_modulate = Color(0, 0, 0, 0.85)
	_marker_label.render_priority = 101
	_marker_label.outline_render_priority = 100
	_marker_label.position = Vector3(0, MARKER_SIZE * 0.75, 0)
	_marker.add_child(_marker_label)


func _label_text(owner_hotspot: Node) -> String:
	if owner_hotspot is Hotspot:
		var name_text: String = String(owner_hotspot.display_name)
		if name_text == "":
			name_text = String(owner_hotspot.hotspot_id).replace("_", " ").capitalize()
		return name_text.to_upper()
	return ""


func _update_marker() -> void:
	if _marker == null:
		return
	var on := InputMap.has_action("highlight_hotspots") and Input.is_action_pressed("highlight_hotspots")
	_marker.visible = on
	if on:
		var colour: Color = GameSettings.marker_color()
		var pulse := 0.75 + 0.25 * sin(_time * 6.0)
		_marker_material.albedo_color = Color(colour.r, colour.g, colour.b, pulse)
		_marker_label.modulate = colour
		var grow := 1.0 + 0.12 * sin(_time * 6.0)
		_marker_ring.scale = Vector3(grow, grow, 1.0)


## A ring with a dot in the middle, drawn once in code (no art asset).
static func _get_ring_texture() -> ImageTexture:
	if _ring_texture == null:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := (size - 1) / 2.0
		for y in size:
			for x in size:
				var d := Vector2(x - c, y - c).length() / (size / 2.0)
				var a := 0.0
				if d > 0.72 and d < 0.92:
					a = 1.0 - absf(d - 0.82) / 0.10
				elif d < 0.16:
					a = 1.0 - d / 0.16
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
		_ring_texture = ImageTexture.create_from_image(img)
	return _ring_texture
