extends Control
class_name RememberDelta
## REV 528 (Glen + Tiffany's review, 27 Oct): a remembered choice is marked by a small Starfleet delta that glints
## in the top-left corner for a moment, with a soft chime - no words. It replaces Telltale's "ULLUS WILL REMEMBER
## THAT." card, which read as "inspired by another game". Players who notice get a hint; players who don't still get
## the payoff later. Drawn as vector shapes (crisp at any resolution, no image file).
##
##   RememberDelta.flash(some_canvas_layer_or_control)

const SIZE := Vector2(40.0, 60.0)      # the shape's own units; drawn at DRAW_SCALE
const DRAW_SCALE := 0.62
const CORNER := Vector2(26.0, 46.0)    # where the old card sat

var _outer := PackedVector2Array()
var _star := PackedVector2Array()


static func flash(parent: Node) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var d := RememberDelta.new()
	d.position = CORNER
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)
	d._play()


func _init() -> void:
	size = SIZE * DRAW_SCALE
	pivot_offset = size * 0.5
	_outer = _arrowhead()
	_star = PackedVector2Array([
		Vector2(20, 11), Vector2(22, 25), Vector2(28.5, 27), Vector2(22, 29), Vector2(23.5, 37),
		Vector2(20, 31.5), Vector2(16.5, 37), Vector2(18, 29), Vector2(11.5, 27), Vector2(18, 25)])
	for i in _star.size():
		_star[i] = _star[i] * DRAW_SCALE


## The TOS arrowhead: two gently bowed sides from the tip, and the concave sweep along the bottom.
func _arrowhead() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var tip := Vector2(20, 0)
	var bl := Vector2(0, 60)
	var br := Vector2(40, 60)
	for i in 13:     # right side: tip -> bottom right
		pts.append(_quad(tip, Vector2(35, 24), br, i / 12.0))
	for i in range(1, 13):     # bottom: right -> left, curving up into the middle
		pts.append(_quad(br, Vector2(20, 34), bl, i / 12.0))
	for i in range(1, 12):     # left side: bottom left -> tip
		pts.append(_quad(bl, Vector2(5, 24), tip, i / 12.0))
	for i in pts.size():
		pts[i] = pts[i] * DRAW_SCALE
	return pts


static func _quad(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(c, t).lerp(c.lerp(b, t), t)


func _draw() -> void:
	draw_colored_polygon(_outer, UITheme.GOLD)
	var ring := _outer.duplicate()
	ring.append(_outer[0])
	draw_polyline(ring, Color(0.05, 0.05, 0.06, 0.95), 2.0, true)
	draw_colored_polygon(_star, Color(0.06, 0.06, 0.07))


func _play() -> void:
	modulate = Color(1, 1, 1, 0)
	scale = Vector2.ONE * 0.6
	SfxManager.ui("confirm", -10.0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, UITheme.dur(0.2))
	t.tween_property(self, "scale", Vector2.ONE, UITheme.dur(0.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.set_parallel(false)
	# the glint: a quick brightening, like light catching the badge
	t.tween_property(self, "modulate", Color(1.7, 1.7, 1.5, 1.0), UITheme.dur(0.12))
	t.tween_property(self, "modulate", Color(1, 1, 1, 1), UITheme.dur(0.3))
	t.tween_interval(1.1)
	t.tween_property(self, "modulate:a", 0.0, UITheme.dur(0.6))
	t.tween_callback(queue_free)
