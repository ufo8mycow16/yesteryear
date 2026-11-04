extends Control
class_name PortraitFrame
## Reusable rounded character-portrait frame (Glen, Oct 2026): image, then
## a thin dark gap, then a colored border ring — gold for the active/main
## character, blue for other party members, all rounded rather than the
## HUD chrome's "very lightly clipped" corners elsewhere.
##
## Built as three nested rounded layers rather than one do-everything
## shader:
##   outer PanelContainer — StyleBoxFlat filled with border_color, rounded.
##     Its own rounded corners ARE the border ring; nothing paints "on
##     top" of it; the layers inside just don't cover all of it.
##   gap PanelContainer    — StyleBoxFlat filled near-black, rounded,
##     inset from the outer by border_width. The ring of outer color left
##     showing around it is the border.
##   TextureRect (portrait) — inset from the gap by gap_width. StyleBoxFlat
##     can round a flat fill like the two layers above, but it can't clip a
##     CHILD control to that rounded shape — Godot's Control clipping is
##     axis-aligned-rect only — so the actual photographic image needs its
##     own corner mask, done with rounded_corners.gdshader. The dark gap
##     layer behind shows through at the image's masked-away corners,
##     which is what reads as the gap ring.
##
## No portrait art yet for a given character is a non-event: setup() with
## texture == null just renders the two border layers with nothing inside,
## the same "degrade, don't break" pattern UITheme uses for missing fonts.

const GAP_COLOR := Color(0.02, 0.02, 0.028, 1.0)
const SHADER_PATH := "res://assets/shaders/rounded_corners.gdshader"

static var _rounded_shader: Shader

var _texture_rect: TextureRect
var _shader_material: ShaderMaterial


## frame_size is the OUTER size, border ring included. corner_radius/
## border_width/gap_width are all in pixels, measured on the outer frame.
## crop (0-1) keeps that fraction of the square source, so a smaller value
## zooms in on the face; crop_focus_y (0 = top, 1 = bottom) picks where the
## kept window sits vertically — faces live in the upper part of a portrait.
func setup(texture: Texture2D, frame_size: Vector2, border_color: Color, corner_radius: float = 14.0, border_width: float = 3.0, gap_width: float = 2.0, crop: float = 1.0, crop_focus_y: float = 0.5) -> void:
	custom_minimum_size = frame_size
	size = frame_size

	var outer := PanelContainer.new()
	outer.name = "BorderRing"
	outer.custom_minimum_size = frame_size
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = border_color
	outer_style.set_corner_radius_all(int(corner_radius))
	outer_style.set_content_margin_all(border_width)
	outer.add_theme_stylebox_override("panel", outer_style)
	add_child(outer)

	var gap := PanelContainer.new()
	gap.name = "Gap"
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap_style := StyleBoxFlat.new()
	gap_style.bg_color = GAP_COLOR
	gap_style.set_corner_radius_all(maxi(int(corner_radius - border_width), 0))
	gap_style.set_content_margin_all(gap_width)
	gap.add_theme_stylebox_override("panel", gap_style)
	outer.add_child(gap)

	_texture_rect = TextureRect.new()
	_texture_rect.name = "Portrait"
	_texture_rect.texture = texture
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture_rect.clip_contents = true
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = _get_rounded_shader()
	var inner_radius: float = maxf(corner_radius - border_width - gap_width, 0.0)
	_shader_material.set_shader_parameter("corner_radius", inner_radius)
	_shader_material.set_shader_parameter("crop", clampf(crop, 0.3, 1.0))
	_shader_material.set_shader_parameter("crop_focus_y", clampf(crop_focus_y, 0.0, 1.0))
	_texture_rect.material = _shader_material
	gap.add_child(_texture_rect)

	# The mask is computed from rect_size, so a wrong value hides the whole
	# image (a zero size masks every pixel away — that's what left only the
	# dark gap showing inside the ring when this relied on a single
	# deferred read that could run before container layout had finished).
	# Seed it with the size we know it will end up at, then keep it exact
	# via the TextureRect's own resized signal.
	var inset := (border_width + gap_width) * 2.0
	_shader_material.set_shader_parameter("rect_size", Vector2(maxf(frame_size.x - inset, 1.0), maxf(frame_size.y - inset, 1.0)))
	_texture_rect.resized.connect(_apply_rect_size_uniform)


func _apply_rect_size_uniform() -> void:
	if _shader_material != null and _texture_rect != null and _texture_rect.size.x > 0.0 and _texture_rect.size.y > 0.0:
		_shader_material.set_shader_parameter("rect_size", _texture_rect.size)


static func _get_rounded_shader() -> Shader:
	if _rounded_shader == null:
		_rounded_shader = load(SHADER_PATH)
	return _rounded_shader
