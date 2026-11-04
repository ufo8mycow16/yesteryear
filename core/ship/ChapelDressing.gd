class_name ChapelDressing
extends RefCounted
## REV 705 (Glen, 30 Oct: "deck 7 is supposed to have a chapel. In the original, it was a redress of the briefing room"
## - his still from "Balance of Terror", docs/reference/chapel_balance_of_terror.png). The briefing room is copied behind
## the ISOLATION ROOM door (tools/rebuild_deck7.sh step 6, emptied of its table and chairs); this furnishes it as the
## ship's chapel: low black padded benches on chrome legs in rows facing the front, a red runner up the aisle, a pale
## raised platform with the tall angled lectern, and Glen's altar backdrop (assets/signs/chapel_backdrop.png, a glowing
## WALL_PICTURES panel over the old viewer screen on the front wall - ModelRoom.WALL_PICTURES). ModelRoom.build_shared
## calls build() for aedeck7.glb.
##
## The room (map units): inner walls x -270..55, y 1474..1700 (the window bay beyond to y 1778); the door in the south
## wall at x -38..10; the FRONT is the west wall (x -270), where the viewer was (y 1527..1643).

const FRONT_X := -270.0
const AISLE_Y := 1585.0
## the platform across the front, the lectern on it, the runner up the aisle
## REV 707 (Glen: "bring the step and the podium out, i can't fit spock in between it"): platform 1.5 m deep (was 1.05),
## the lectern 1.3 m off the front wall, the bench rows 40 apart (was 45) so the back row still clears the door
const PLATFORM := [-270.0, -206.0, 1512.0, 1658.0]       # x0, x1, y0, y1 (map units)
const PLATFORM_H := 0.14                                  # metres
const LECTERN := Vector2(-216.0, AISLE_Y - 42.0)   # REV 707 (Glen's first look: it hid the candles) - off to one side, as in the episode
const RUNNER := [-206.0, 30.0, 1564.0, 1606.0]
## benches: rows at these x (their front edge), each side of the aisle (y ranges)
const ROWS := [-186.0, -146.0, -106.0, -66.0]
const SIDES := [[1612.0, 1690.0], [1482.0, 1558.0]]
const SEAT_H := 0.42
const SEAT_DEPTH := 0.40

var room: Node3D
var u := 0.024
var root: Node3D
var _mats := {}


static func build(r: Node3D) -> void:
	var d := ChapelDressing.new()
	d.room = r
	d.u = float(r.get("QS")) * float((r.get("cfg") as Dictionary)["scale"])
	d.root = Node3D.new()
	d.root.name = "ChapelDressing"
	r.add_child(d.root)
	var o: Vector3 = r.call("q", 0.0, 0.0, 0.0)
	d.root.transform = Transform3D(Basis(Vector3.UP, float(r.get("_model_yaw"))), o)
	d._furnish()


## A map point (x, y) at a height (metres above the deck) in the dressing's own frame.
func _p(x: float, y: float, h: float) -> Vector3:
	return Vector3(x * u, h, -y * u)


func _mat(col: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var k := "%s|%.2f|%.2f" % [col.to_html(), rough, metal]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	_mats[k] = m
	return m


## A box at a centre (metres, the dressing frame), solid if asked - people walk round it.
func _box(pos: Vector3, size: Vector3, m: Material, solid := false, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		body.rotation = rot
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		body.add_child(mi)
		root.add_child(body)
	else:
		mi.position = pos
		mi.rotation = rot
		root.add_child(mi)
	return mi


func _furnish() -> void:
	var pale := _mat(Color(0.80, 0.81, 0.83), 0.45)
	var edge := _mat(Color(0.90, 0.91, 0.93), 0.35)
	var black := _mat(Color(0.05, 0.05, 0.06), 0.28)
	var chrome := _mat(Color(0.82, 0.83, 0.86), 0.18, 1.0)
	var red := _mat(Color(0.55, 0.06, 0.05), 0.9)
	# the platform across the front, with a lighter lip
	var px0: float = PLATFORM[0]
	var px1: float = PLATFORM[1]
	var py0: float = PLATFORM[2]
	var py1: float = PLATFORM[3]
	var pc := _p((px0 + px1) * 0.5, (py0 + py1) * 0.5, PLATFORM_H * 0.5)
	_box(pc, Vector3((px1 - px0) * u, PLATFORM_H, (py1 - py0) * u), pale, true)
	_box(_p(px1, (py0 + py1) * 0.5, PLATFORM_H - 0.012), Vector3(0.05, 0.024, (py1 - py0) * u), edge)
	# the red runner up the aisle, from the platform's foot to the door end
	var rx0: float = RUNNER[0]
	var rx1: float = RUNNER[1]
	var ry0: float = RUNNER[2]
	var ry1: float = RUNNER[3]
	_box(_p((rx0 + rx1) * 0.5, (ry0 + ry1) * 0.5, 0.006), Vector3((rx1 - rx0) * u, 0.012, (ry1 - ry0) * u), red)
	_lectern(pale, edge)
	for x in ROWS:
		for side in SIDES:
			_bench(float(x), float(side[0]), float(side[1]), black, chrome)


## The tall angled lectern (the still: a pale tapered slab leaning back, a sloping top board facing the congregation).
func _lectern(pale: Material, edge: Material) -> void:
	var base := _p(LECTERN.x, LECTERN.y, PLATFORM_H)
	_box(base + Vector3(0.0, 0.02, 0.0), Vector3(0.40, 0.04, 0.46), edge, true)
	# the slab: 1.05 m tall, leaning back (away from the congregation, towards the front wall) by 12 degrees
	var lean := deg_to_rad(12.0)
	var h := 1.05
	var slab := base + Vector3(-sin(lean) * h * 0.5, 0.04 + cos(lean) * h * 0.5, 0.0)
	_box(slab, Vector3(0.10, h, 0.42), pale, true, Vector3(0.0, 0.0, lean))
	# the reading board, sloping down towards the congregation
	var top := base + Vector3(-sin(lean) * h + 0.10, 0.04 + cos(lean) * h, 0.0)
	_box(top, Vector3(0.34, 0.03, 0.52), edge, false, Vector3(0.0, 0.0, deg_to_rad(-22.0)))


## One bench: a low black padded seat on two chrome legs, its sitters facing the front (-x).
func _bench(front_x: float, y0: float, y1: float, black: Material, chrome: Material) -> void:
	var blen := (y1 - y0) * u
	var c := _p(front_x, (y0 + y1) * 0.5, 0.0) + Vector3(SEAT_DEPTH * 0.5, 0.0, 0.0)
	_box(c + Vector3(0.0, SEAT_H - 0.05, 0.0), Vector3(SEAT_DEPTH, 0.10, blen), black, true)
	for e in [-1.0, 1.0]:
		var lz: float = e * (blen * 0.5 - 0.22)
		_box(c + Vector3(0.0, (SEAT_H - 0.10) * 0.5, lz), Vector3(0.30, SEAT_H - 0.10, 0.05), chrome)
		_box(c + Vector3(0.0, 0.01, lz), Vector3(0.36, 0.02, 0.10), chrome)
