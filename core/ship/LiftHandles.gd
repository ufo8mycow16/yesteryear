extends RefCounted
class_name LiftHandles
## LiftHandles — where the turbolift control levers (the "sc_handle" pieces) are in the
## Enterprise map (enterprise3_full.glb). Each entry is one lift: its centre (Quake x, y)
## and its handles (Quake x, y, z). A room that uses the map puts a "Control Lever"
## hotspot on each handle of the lift it has (ModelRoom.add_lift_handles).

const ENTERPRISE3 := [
	[Vector2(-456, 483), [Vector3(-507, 509, 1747), Vector3(-403, 509, 1747), Vector3(-436, 458, 1747), Vector3(-476, 458, 1747)]],
	# REV 744 (Glen's bug list item 1): Deck 6's four cars are REAL TOS cars - Deck 7's car copied in at 95%
	# (tools/rebuild_deck6.sh, COPY_lift_*), each with its own six handles
	[Vector2(1103, 1659), [Vector3(1151, 1634, 1487), Vector3(1077, 1611, 1487), Vector3(1129, 1611, 1487), Vector3(1128, 1707, 1487), Vector3(1150, 1686, 1487), Vector3(1074, 1707, 1487)]],
	[Vector2(1103, 323), [Vector3(1151, 298, 1487), Vector3(1077, 275, 1487), Vector3(1129, 275, 1487), Vector3(1128, 371, 1487), Vector3(1150, 350, 1487), Vector3(1074, 371, 1487)]],
	[Vector2(872, 980), [Vector3(920, 955, 1487), Vector3(846, 932, 1487), Vector3(898, 932, 1487), Vector3(897, 1028, 1487), Vector3(920, 1007, 1487), Vector3(844, 1028, 1487)]],
	[Vector2(716, 1808), [Vector3(741, 1856, 1487), Vector3(764, 1782, 1487), Vector3(764, 1834, 1487), Vector3(668, 1833, 1487), Vector3(689, 1856, 1487), Vector3(668, 1780, 1487)]],
	[Vector2(141, 320), [Vector3(166, 339, 1747), Vector3(166, 299, 1747), Vector3(116, 268, 1747), Vector3(116, 372, 1747)]],
	[Vector2(140, 1768), [Vector3(164, 1676, 1747), Vector3(164, 1635, 1747), Vector3(117, 1605, 1747), Vector3(117, 1709, 1747), Vector3(164, 1899, 1747), Vector3(164, 1859, 1747), Vector3(116, 1829, 1747), Vector3(116, 1933, 1747)]],
	[Vector2(-200, 2509), [Vector3(-252, 2485, 1747), Vector3(-148, 2485, 1747), Vector3(-221, 2533, 1747), Vector3(-181, 2534, 1747)]],
	[Vector2(2839, -1322), [Vector3(2787, -1347, 1395), Vector3(2891, -1347, 1395), Vector3(2819, -1298, 1395), Vector3(2858, -1298, 1395)]],
	[Vector2(1454, -1376), [Vector3(1479, -1356, 1344), Vector3(1479, -1396, 1344), Vector3(1429, -1428, 1344), Vector3(1429, -1324, 1344)]],
	[Vector2(-5, -1378), [Vector3(20, -1430, 1344), Vector3(20, -1326, 1344), Vector3(-30, -1358, 1344), Vector3(-30, -1398, 1344)]],
	[Vector2(400, 1022), [Vector3(348, 997, 1937), Vector3(452, 997, 1937), Vector3(379, 1046, 1937), Vector3(419, 1046, 1937)]],
]


## Lifts of the Act 1 Enterprise maps (aedeck1 ... ent1), found from the maps own handle props.
## Same layout as above, keyed by map name.
const MAPS := {
	# The bowling alley map: six cars on three levels. The one on the lane level is at (2595, -307).
	"wreckdeck": [
		[Vector2(2500, -37), [Vector3(2533, -11, 185), Vector3(2532, -64, 185), Vector3(2458, 12, 185), Vector3(2510, 11, 185), Vector3(2510, -86, 185), Vector3(2457, -85, 185)]],
		[Vector2(1484, -37), [Vector3(1474, 12, 185), Vector3(1526, 12, 185), Vector3(1526, -86, 185), Vector3(1451, -63, 185), Vector3(1452, -10, 185), Vector3(1473, -85, 185)]],
		[Vector2(1249, -2), [Vector3(1239, 47, 41), Vector3(1291, 47, 41), Vector3(1291, -51, 41), Vector3(1216, -28, 41), Vector3(1217, 25, 41), Vector3(1238, -50, 41)]],
		[Vector2(2584, -116), [Vector3(2558, -83, 41), Vector3(2611, -84, 41), Vector3(2535, -158, 41), Vector3(2536, -106, 41), Vector3(2633, -106, 41), Vector3(2633, -158, 41)]],
		[Vector2(2595, -307), [Vector3(2569, -274, -103), Vector3(2621, -275, -103), Vector3(2547, -350, -103), Vector3(2547, -296, -103), Vector3(2644, -297, -103), Vector3(2643, -350, -103)]],
		[Vector2(2479, 348), [Vector3(2430, 338, 41), Vector3(2431, 391, 41), Vector3(2528, 390, 41), Vector3(2527, 337, 41), Vector3(2505, 315, 41), Vector3(2453, 316, 41)]],
	],
	"wreckdeck_up": [
		[Vector2(2500, -37), [Vector3(2533, -11, 185), Vector3(2532, -64, 185), Vector3(2458, 12, 185), Vector3(2510, 11, 185), Vector3(2510, -86, 185), Vector3(2457, -85, 185)]],
		[Vector2(1484, -37), [Vector3(1474, 12, 185), Vector3(1526, 12, 185), Vector3(1526, -86, 185), Vector3(1451, -63, 185), Vector3(1452, -10, 185), Vector3(1473, -85, 185)]],
		[Vector2(1249, -2), [Vector3(1239, 47, 41), Vector3(1291, 47, 41), Vector3(1291, -51, 41), Vector3(1216, -28, 41), Vector3(1217, 25, 41), Vector3(1238, -50, 41)]],
		[Vector2(2584, -116), [Vector3(2558, -83, 41), Vector3(2611, -84, 41), Vector3(2535, -158, 41), Vector3(2536, -106, 41), Vector3(2633, -106, 41), Vector3(2633, -158, 41)]],
		[Vector2(2479, 348), [Vector3(2430, 338, 41), Vector3(2431, 391, 41), Vector3(2528, 390, 41), Vector3(2527, 337, 41), Vector3(2505, 315, 41), Vector3(2453, 316, 41)]],
	],
	"wreckdeck_down": [
		[Vector2(2595, -307), [Vector3(2569, -274, -103), Vector3(2621, -275, -103), Vector3(2547, -350, -103), Vector3(2547, -296, -103), Vector3(2644, -297, -103), Vector3(2643, -350, -103)]],
	],
	"aedeck1": [
		[Vector2(2766, -1974), [Vector3(2818, -1986, 142), Vector3(2794, -1961, 142), Vector3(2739, -1962, 142), Vector3(2715, -1987, 142)]],
		[Vector2(2855, -1327), [Vector3(2805, -1372, 291), Vector3(2906, -1316, 291), Vector3(2882, -1292, 291), Vector3(2827, -1293, 291), Vector3(2803, -1318, 291), Vector3(2906, -1370, 291)]],
	],
	"aedeck5_6": [
		# REV 685 (Glen: "let's not cheap out, and let's use a real turbolift please" - the empty alcove off Deck 5's
		# middle corridor): a COPY of Deck 5's round car by the lounge (377, 1584), turned to open east (--rot -90),
		# car x 115-245, y 2143-2257 (COPY_alcove_lift in aedeck5_6.glb; the alcove's own walls erased first); its six
		# real handles moved with it; the flat front with red doors = CAR_FRONTS. How: docs/systems/copying-turbolifts.md
		[Vector2(172, 2200), [Vector3(216, 2151, 312), Vector3(216, 2250, 312), Vector3(161, 2150, 312), Vector3(161, 2251, 312), Vector3(138, 2227, 312), Vector3(139, 2172, 312)]],
		[Vector2(646, 2366), [Vector3(596, 2321, 177), Vector3(619, 2401, 177), Vector3(595, 2376, 177), Vector3(697, 2377, 177), Vector3(697, 2323, 177), Vector3(672, 2401, 177)]],
		[Vector2(377, 1584), [Vector3(406, 1550, 312), Vector3(351, 1549, 312), Vector3(326, 1573, 312), Vector3(428, 1574, 312), Vector3(326, 1627, 312), Vector3(427, 1629, 312)]],
		[Vector2(400, 943), [Vector3(427, 909, 312), Vector3(374, 909, 312), Vector3(350, 931, 312), Vector3(451, 934, 312), Vector3(349, 987, 312), Vector3(450, 989, 312)]],
		[Vector2(648, 694), [Vector3(597, 737, 177), Vector3(597, 683, 177), Vector3(622, 659, 177), Vector3(676, 660, 177), Vector3(699, 684, 177), Vector3(698, 739, 177)]],
		[Vector2(-1154, 578), [Vector3(-1205, 565, 142), Vector3(-1181, 590, 142), Vector3(-1126, 591, 142), Vector3(-1102, 566, 142)]],
	],
	"aedeck7": [
		[Vector2(375, 1755), [Vector3(401, 1790, 41), Vector3(426, 1712, 41), Vector3(426, 1766, 41), Vector3(324, 1765, 41), Vector3(347, 1789, 41), Vector3(324, 1709, 41)]],
		[Vector2(-989, 1115), [Vector3(-1023, 1141, 41), Vector3(-1022, 1087, 41), Vector3(-944, 1065, 41), Vector3(-944, 1167, 41), Vector3(-1001, 1166, 41), Vector3(-998, 1065, 41)]],
		[Vector2(558, -773), [Vector3(609, -784, 142), Vector3(586, -761, 142), Vector3(531, -762, 142), Vector3(508, -785, 142)]],
		# REV 695 (Glen): the car beside engineering moved from the corridor end (426, -292) into the space west of the
		# corridor - tools/rebuild_deck7.sh copies it there turned round (COPY_eng_lift), its handles with it
		[Vector2(-4, -417), [Vector3(-39, -444, 41), Vector3(-39, -391, 41), Vector3(-15, -366, 41), Vector3(-14, -468, 41), Vector3(41, -467, 41), Vector3(39, -366, 41)]],
		[Vector2(1054, 934), [Vector3(1080, 968, 41), Vector3(1106, 891, 41), Vector3(1106, 945, 41), Vector3(1003, 943, 41), Vector3(1028, 969, 41), Vector3(1004, 888, 41)]],
	],
	"aedeck8": [
		[Vector2(558, -773), [Vector3(508, -785, 142), Vector3(531, -762, 142), Vector3(586, -761, 142), Vector3(609, -784, 142)]],
		[Vector2(324, -395), [Vector3(280, -438, 566), Vector3(279, -386, 566), Vector3(299, -362, 566), Vector3(348, -361, 566), Vector3(368, -385, 566), Vector3(369, -436, 566)]],
		[Vector2(2657, 729), [Vector3(2606, 739, 185), Vector3(2606, 684, 185), Vector3(2629, 763, 185), Vector3(2708, 740, 185), Vector3(2708, 685, 185), Vector3(2684, 763, 185)]],
		[Vector2(2657, -722), [Vector3(2606, -678, 185), Vector3(2606, -733, 185), Vector3(2630, -756, 185), Vector3(2708, -677, 185), Vector3(2708, -732, 185), Vector3(2685, -756, 185)]],
		# REV 622 (Glen): the alcove under the round turbolift hole beside Auxiliary Control (upper level, floor 528) -
		# the map built the car (walls, the ring in its ceiling) but no levers; ADDED_LEVERS draws them.
		# REV 626 (Glen): a COPY of the hangar lift car (2657, -722) now stands here (tools/copy_glb_region.py, COPY_aux_lift
		# in aedeck8.glb + _extra) - its six real handles, moved by the copy's offset (-1577, +794, +384).
		[Vector2(1080, 72), [Vector3(1029, 116, 569), Vector3(1029, 61, 569), Vector3(1053, 38, 569), Vector3(1131, 117, 569), Vector3(1131, 62, 569), Vector3(1108, 38, 569)]],
		# REV 623: TURBO LIFT 7, right behind it - the map's car had no floor and no levers. REV 650 (Glen: "it's
		# untextured, and I think it needs to come forward a bit"): that bare car is gone - a COPY of the hangar car
		# (2657, -722), turned to open east, stands with its doorway on TL7's door (x 1069-1182, y -97..17; COPY_tl7_lift
		# in aedeck8.glb + _extra, tools/copy_glb_region.py --rot) - its six real handles, turned and moved with it.
		[Vector2(1125, -40), [Vector3(1153, 11, 569), Vector3(1098, 11, 569), Vector3(1075, -13, 569), Vector3(1154, -91, 569), Vector3(1099, -91, 569), Vector3(1075, -68, 569)]],
		# REV 673 (Glen: the lift at the end of the little corridor west of Auxiliary Control "is facing the wrong way" -
		# its door frame stood against the corridor's blank end wall, nothing behind it - "proper lift, yes please"): a
		# COPY of the hangar car (2657, -722) turned to open south, behind the end wall (car x 16-130, y 267-380, floor
		# 508 - the corridor's own floor; COPY_end_lift in aedeck8.glb + _extra); the wall's doorway cut out (x 42-104,
		# tools/split_glb_square.py --y-wall --drop), the old frame posts erased; the front + red doors = CAR_FRONTS.
		[Vector2(73, 324), [Vector3(124, 296, 549), Vector3(124, 351, 549), Vector3(100, 374, 549), Vector3(22, 295, 549), Vector3(22, 350, 549), Vector3(45, 374, 549)]],
	],
	"ent1": [
		[Vector2(1886, 2121), [Vector3(1841, 2171, 1546), Vector3(1841, 2071, 1546), Vector3(1896, 2172, 1546), Vector3(1897, 2070, 1546), Vector3(1921, 2095, 1546), Vector3(1921, 2148, 1546)]],
		[Vector2(414, 2185), [Vector3(368, 2235, 1546), Vector3(369, 2135, 1546), Vector3(424, 2236, 1546), Vector3(425, 2134, 1546), Vector3(449, 2159, 1546), Vector3(449, 2212, 1546)]],
		[Vector2(406, 2569), [Vector3(361, 2619, 1546), Vector3(361, 2519, 1546), Vector3(416, 2620, 1546), Vector3(417, 2518, 1546), Vector3(441, 2543, 1546), Vector3(441, 2596, 1546)]],
		[Vector2(686, -1247), [Vector3(637, -1292, 291), Vector3(737, -1292, 291), Vector3(635, -1238, 291), Vector3(737, -1235, 291), Vector3(712, -1211, 291), Vector3(659, -1213, 291)]],
		[Vector2(2855, -1327), [Vector3(2805, -1372, 291), Vector3(2905, -1372, 291), Vector3(2803, -1318, 291), Vector3(2906, -1317, 291), Vector3(2880, -1291, 291), Vector3(2829, -1292, 291)]],
	],
}


## REV 622: levers the map itself doesn't have (lifts added to MAPS by hand) - ModelRoom.add_lift_handles draws a
## lever at each: [handle (map x, y, z), the way to the wall it hangs on (map x, y)].
const ADDED_LEVERS := {
	# (REV 650: Turbo Lift 7's two drawn levers retired - its copied car has the real ones)
}

## REV 623: floors the map leaves out of a lift car - [min corner (map x, y), max corner (map x, y), floor height
## (map z)] - ModelRoom.add_lift_handles lays a solid deck plate there (Turbo Lift 7 opened onto a drop - Glen).
const ADDED_FLOORS := {
	"aedeck8": [[Vector2(1047, -97), Vector2(1184, 15), 528.0]],
}


## REV 624 (Glen: "There needs to be an actual turbo lift here"): lift cars the map only half-built - three bare
## walls and a doorway, no car. ModelRoom._add_drawn_cars lines the car with the turbolift wall picture, gives it a
## ceiling with a light, and hangs a pair of red sliding doors in the doorway (MapDoors - they open as you walk up).
## [inside min corner (map x, y), inside max corner (map x, y), floor (map z), ceiling (map z), doorway from (map x, y),
##  doorway to (map x, y), door top (map z), the map's own ceiling over the doorway (map z - the lintel fills up to
##  it)] - the doorway runs along the car's front wall, through its middle.
const ADDED_CARS := {
	# Deck 15, Auxiliary Control level: the car under the round ceiling hatch. Inside x 1024-1136, y 33-110; the
	# doorway between the map's two wall stubs (x 1042-1118, stubs y 110-118) opens north into the corridor.
	# (REV 624's drawn car for Deck 15's alcove is retired - REV 626 copied a real car there; see CAR_FRONTS)
}

## REV 626: the corridor face of a copied lift car whose front is rounded (Deck 15's): a flat wall across the corridor
## end with the car's doorway in it, red sliding doors in the doorway, and a lintel up to the ceiling. [wall from map x,
## wall to map x, wall face (map y), floor (map z), ceiling (map z), doorway from map x, doorway to map x, door top
## (map z)]. ModelRoom._add_drawn_cars builds it.
const CAR_FRONTS := {
	"aedeck8": [[1024.0, 1136.0, 143.0, 528.0, 648.0, 1049.0, 1111.0, 616.0],
		[12.0, 134.0, 265.5, 508.0, 630.0, 42.0, 104.0, 600.0]],   # REV 673: the end-of-corridor lift (73, 324)
	# REV 685: a 9th value "y" = the front runs along map y at a fixed x: [from y, to y, wall face (map x), floor,
	# ceiling, doorway from y, doorway to y, door top, "y"] - Deck 5's alcove lift (doorway y 2176-2224 at x 246)
	"aedeck5_6": [[2140.0, 2260.0, 246.0, 272.0, 392.0, 2176.0, 2224.0, 352.0, "y"]],
}


## Which way each ordinary turbolift car opens (a unit direction on the map, from the car's centre to its
## doors). ModelRoom closes the car with walls everywhere except there. Same lift centres as MAPS above.
const DOORS := {
	"wreckdeck_up": [[Vector2(2500, -37), Vector2(-1, 0)], [Vector2(1484, -37), Vector2(1, 0)], [Vector2(1249, -2), Vector2(1, 0)], [Vector2(2584, -116), Vector2(0, -1)], [Vector2(2479, 348), Vector2(0, 1)]],
	"wreckdeck_down": [[Vector2(2595, -307), Vector2(0, -1)]],
	"wreckdeck": [[Vector2(2500, -37), Vector2(-1, 0)], [Vector2(1484, -37), Vector2(1, 0)], [Vector2(1249, -2), Vector2(1, 0)], [Vector2(2584, -116), Vector2(0, -1)], [Vector2(2595, -307), Vector2(0, -1)], [Vector2(2479, 348), Vector2(0, 1)]],
	"enterprise3": [[Vector2(-456, 483), Vector2(0, 1)], [Vector2(1103, 1659), Vector2(-1, 0)], [Vector2(1103, 323), Vector2(-1, 0)], [Vector2(872, 980), Vector2(-1, 0)], [Vector2(716, 1808), Vector2(0, -1)], [Vector2(141, 320), Vector2(-1, 0)], [Vector2(141, 1657), Vector2(-1, 0)], [Vector2(141, 1880), Vector2(-1, 0)], [Vector2(-200, 2509), Vector2(0, -1)], [Vector2(2839, -1322), Vector2(0, -1)], [Vector2(1454, -1376), Vector2(-1, 0)], [Vector2(-5, -1378), Vector2(1, 0)], [Vector2(400, 1022), Vector2(0, -1)]],
	"aedeck1": [[Vector2(2766, -1974), Vector2(0, -1)], [Vector2(2855, -1327), Vector2(0, -1)]],
	"aedeck5_6": [[Vector2(172, 2200), Vector2(1, 0)], [Vector2(646, 2366), Vector2(0, -1)], [Vector2(377, 1584), Vector2(0, 1)], [Vector2(400, 943), Vector2(0, 1)], [Vector2(648, 694), Vector2(0, 1)], [Vector2(-1154, 578), Vector2(0, -1)]],
	"aedeck7": [[Vector2(375, 1755), Vector2(0, -1)], [Vector2(-989, 1115), Vector2(1, 0)], [Vector2(558, -773), Vector2(0, -1)], [Vector2(-4, -417), Vector2(1, 0)], [Vector2(1054, 934), Vector2(0, -1)]],
	"aedeck8": [[Vector2(558, -773), Vector2(0, -1)], [Vector2(2657, 729), Vector2(0, -1)], [Vector2(2657, -722), Vector2(0, 1)]],
	"ent1": [[Vector2(1886, 2121), Vector2(-1, 0)], [Vector2(414, 2185), Vector2(-1, 0)], [Vector2(406, 2569), Vector2(-1, 0)], [Vector2(686, -1247), Vector2(0, -1)], [Vector2(2855, -1327), Vector2(0, -1)]],
}

## REV 701: Deck 5's alcove car (172, 2200) back to 16380 (its real walls are all there now - the _extra.glb panels
## were copied too; REV 689's 61455 had filled sectors 4-11 with drawn walls to hide the gaps).
## REV 29: which parts of each car the map already has real walls for (measured from the map geometry).
## [lift centre, bit mask of the 16 wall sectors that already have wall (sector i spans angle 22.5*i degrees,
## measured from +x towards +y on the map), whether the car has its own ceiling]. ModelRoom only fills the gaps.
const RING := {
	"aedeck1": [[Vector2(2766, -1974), 50151, true], [Vector2(2855, -1327), 59391, true]],   # REV 366: + sectors 10 and 13 (the map has those walls; the gap test missed them and two panels stood inside the bridge car)
	"aedeck5_6": [[Vector2(172, 2200), 16380, true], [Vector2(646, 2366), 50175, true], [Vector2(377, 1584), 65475, true], [Vector2(400, 943), 65475, true], [Vector2(648, 694), 65475, true], [Vector2(-1154, 578), 50151, true]],
	"aedeck7": [[Vector2(375, 1755), 50175, true], [Vector2(-989, 1115), 16380, true], [Vector2(558, -773), 50087, true], [Vector2(-4, -417), 16380, true], [Vector2(1054, 934), 50175, true]],
	"aedeck8": [[Vector2(558, -773), 50087, true], [Vector2(2657, 729), 50175, true], [Vector2(2657, -722), 65475, true]],
	"ent1": [[Vector2(1886, 2121), 64575, true], [Vector2(414, 2185), 64575, true], [Vector2(406, 2569), 64575, true], [Vector2(686, -1247), 50175, true], [Vector2(2855, -1327), 50175, true]],
	"enterprise3": [[Vector2(-456, 483), 65475, true], [Vector2(1103, 1659), 64575, true], [Vector2(1103, 323), 64575, true], [Vector2(872, 980), 64575, true], [Vector2(716, 1808), 50175, true], [Vector2(141, 320), 64575, true], [Vector2(141, 1657), 64575, true], [Vector2(141, 1880), 64575, true], [Vector2(-200, 2509), 32, false], [Vector2(2839, -1322), 50175, false], [Vector2(1454, -1376), 64575, true], [Vector2(-5, -1378), 16380, true], [Vector2(400, 1022), 8224, false]],
}


## [mask, has_roof] for the lift at (x, y); null if unknown.
static func ring_info(x: float, y: float, map_key: String = "") -> Variant:
	var key := map_key if map_key != "" else "enterprise3"
	if not RING.has(key):
		return null
	for entry in RING[key]:
		if (entry[0] as Vector2).distance_to(Vector2(x, y)) < 30.0:
			return [int(entry[1]), bool(entry[2])]
	return null


## The way the doors of the lift at (x, y) face, as a unit vector on the map, or (0, 0) if unknown.
static func door_dir(x: float, y: float, map_key: String = "") -> Vector2:
	var key := map_key if map_key != "" else "enterprise3"
	if not DOORS.has(key):
		return Vector2.ZERO
	for entry in DOORS[key]:
		if (entry[0] as Vector2).distance_to(Vector2(x, y)) < 30.0:
			return entry[1]
	return Vector2.ZERO


## The handles of every lift in a map (one Array of Vector3 per lift).
static func all_handles(map_key: String = "") -> Array:
	var out: Array = []
	var lifts: Array = MAPS[map_key] if MAPS.has(map_key) else ENTERPRISE3
	for lift in lifts:
		out.append(lift[1])
	return out


## The handles of the lift nearest to a point (Quake x, y), as an Array of Vector3.
static func near(x: float, y: float, map_key: String = "") -> Array:
	var best: Array = []
	var best_d := INF
	var lifts: Array = MAPS[map_key] if MAPS.has(map_key) else ENTERPRISE3
	for lift in lifts:
		var c: Vector2 = lift[0]
		var d := c.distance_to(Vector2(x, y))
		if d < best_d:
			best_d = d
			best = lift[1]
	return best
