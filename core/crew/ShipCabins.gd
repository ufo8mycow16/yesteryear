class_name ShipCabins
extends RefCounted
## REV 812 - who sleeps where (Glen, 3 Nov: crew assigned to the cabins, a nameplate with the room number on every
## cabin; docs/systems/cabins.md "Decisions").
##
## The cabins themselves are FIXED - data/ship/cabins.json, read off Franz Joseph's plans (REV 809). Who is in them is
## worked out per playthrough from the crew roster (CrewRoster), the whole ship at once so nobody is double-booked.
## It is built from the roster's own seed, which is saved with the game - so a playthrough always gets the same
## roommates, and a new game gets new ones, without anything extra in the save.
##
## The rules agreed with Glen:
##  - rank picks the deck: officers (lieutenant junior grade and up) Deck 5, by seniority; the rest of them and the
##    ensigns in the secondary hull (Decks 17-19); enlisted on Decks 6 and 7 (+ the secondary hull's last beds).
##    Deck 4 is the DIPLOMATIC QUARTERS - kept for guests, nobody from the crew.
##  - Deck 7's crew cabins are for people who WORK on Deck 7 (security, engineering, sickbay, the transporter rooms),
##    each pair in the free cabin nearest their work; the quad (bunks) goes to four engineers.
##  - roommates share a department, same sex where the numbers allow.
##  - story people with a crew post (Kyle, Giotto, Leslie, Ross, the Fizzbin engineers...) are placed like anyone
##    else; the canon senior officers (Kirk, Spock, McCoy, Scotty, Sulu, Uhura, Chekov...) keep the old Deck 5 cabins.
##  - voice lines never say a shuffled crewman's cabin number (it changes per playthrough).

const CABINS_JSON := "res://data/ship/cabins.json"

const OFFICER_RANKS := ["captain", "commander", "lt_commander", "lieutenant", "lieutenant_jg"]
const SENIORITY := {"captain": 0, "commander": 1, "lt_commander": 2, "lieutenant": 3, "lieutenant_jg": 4, "ensign": 5}
## Deck 7 work places (new Deck 7, deck metres x, z) - a crew pair gets the free cabin nearest its own.
const DECK7_WORK := {
	"security": [Vector2(22.2, 26.3)],
	"engineering": [Vector2(46.5, 0.0), Vector2(48.6, 16.5), Vector2(48.6, -16.5)],
	"sickbay": [Vector2(17.3, 2.9)],
	"transporter": [Vector2(-8.3, 25.7), Vector2(-8.3, -25.7)],
}
const SECONDARY_HULL := ["17", "18", "19"]

static var _seed := -1
static var _decks: Dictionary = {}          # deck -> [cabin dicts from cabins.json]
static var _in: Dictionary = {}             # cabin number -> Array[String] person ids
static var _of: Dictionary = {}             # person id -> cabin number


## Everyone in cabin `number` (e.g. "7F-215"), in a stable order. Empty = nobody (spare berths, Deck 4's suites).
static func occupants(number: String) -> Array:
	_ensure()
	return _in.get(number, [])


## The cabin a person sleeps in ("" if none - the canon senior officers, guests).
static func cabin_of(person_id: String) -> String:
	_ensure()
	return String(_of.get(person_id, ""))


## A nameplate's two plaques: [names (one line per occupant, "RANK SURNAME"), the number].
static func plate_text(number: String) -> Array:
	var names := PackedStringArray()
	for pid in occupants(number):
		names.append(CrewRoster.display_name(String(pid)).to_upper())
	return ["\n".join(names), number]


## Every cabin on a deck from the fixed list ("7" -> its 55 cabins).
static func cabins_on(deck: String) -> Array:
	_load()
	return _decks.get(deck, [])


# ---------------------------------------------------------------------------------------------------------------------

static func _load() -> void:
	if not _decks.is_empty() or not FileAccess.file_exists(CABINS_JSON):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(CABINS_JSON))
	if d is Dictionary:
		var decks: Dictionary = (d as Dictionary).get("decks", {})
		for k in decks:
			_decks[String(k)] = (decks[k] as Dictionary).get("cabins", [])


static func _ensure() -> void:
	var s := CrewRoster.crew_seed()
	if s == _seed and not _in.is_empty():
		return
	_seed = s
	_load()
	_assign()


static func _h(id: String) -> int:
	return CrewRoster._h(id + "cabin", _seed)


static func _rank_of(pid: String) -> String:
	return String(CrewRoster.post_of(pid).get("rank", "specialist"))


static func _sex_of(pid: String) -> String:
	return String(CrewRoster.person(pid).get("sex", "male"))


## Where a person works, as a Deck 7 work place key ("" = not on Deck 7).
static func _deck7_work(pid: String) -> String:
	var post := CrewRoster.post_of(pid)
	var loc := String(post.get("location", ""))
	var dep := String(post.get("department", ""))
	if loc == "transporter" or loc == "transporter_room" or dep == "transporter":
		return "transporter"
	if loc == "sickbay":
		return "sickbay"
	if loc == "security":
		return "security"
	if loc == "engineering" or (loc == "deck7" and dep == "engineering"):
		return "engineering"
	return ""


static func _department(pid: String) -> String:
	var w := _deck7_work(pid)
	return w if w != "" else String(CrewRoster.post_of(pid).get("department", "support"))


static func _assign() -> void:
	_in.clear()
	_of.clear()
	# everyone with a crew post: the roster + story people who hold crew posts
	var people: Array = []
	for pid in CrewRoster.roster():
		people.append(String(pid))
	for pid in CrewRoster.STORY_PEOPLE:
		people.append(String(pid))
	people.sort_custom(func(a, b) -> bool: return _h(String(a)) < _h(String(b)))

	var officers: Array = []
	var juniors: Array = []                   # ensigns + officers Deck 5 can't take
	var enlisted: Array = []
	for pid in people:
		var r := _rank_of(String(pid))
		if r in OFFICER_RANKS:
			officers.append(pid)
		elif r == "ensign":
			juniors.append(pid)
		else:
			enlisted.append(pid)
	officers.sort_custom(func(a, b) -> bool:
		var ra: int = SENIORITY.get(_rank_of(String(a)), 9)
		var rb: int = SENIORITY.get(_rank_of(String(b)), 9)
		return ra < rb if ra != rb else _h(String(a)) < _h(String(b)))

	# Deck 5: the senior officers first, singles before doubles
	var d5: Array = cabins_on("5").duplicate()
	d5.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["berths"]) < int(b["berths"]) if int(a["berths"]) != int(b["berths"]) else String(a["number"]) < String(b["number"]))
	var left := _fill_rooms(d5, _pairs(officers))
	juniors = left + juniors

	# Deck 7: people who work there, near their work
	var d7_people: Array = []
	var rest: Array = []
	for pid in enlisted:
		if _deck7_work(String(pid)) != "":
			d7_people.append(pid)
		else:
			rest.append(pid)
	rest.append_array(_fill_deck7(d7_people))

	# Deck 6, then the secondary hull (juniors first there - officers' country)
	var d6: Array = cabins_on("6").duplicate()
	var over := _fill_rooms(d6, _pairs(rest))
	var hull: Array = []
	for dk in SECONDARY_HULL:
		hull.append_array(cabins_on(dk))
	_fill_rooms(hull, _pairs(juniors) + _pairs(over))


## People in rooms of two: same department and sex where possible, then same department, then anyone.
static func _pairs(list: Array) -> Array:
	var groups := {}
	for pid in list:
		var k := "%s|%s" % [_department(String(pid)), _sex_of(String(pid))]
		if not groups.has(k):
			groups[k] = []
		(groups[k] as Array).append(pid)
	var out: Array = []
	var odd_by_dep := {}
	var keys := groups.keys()
	keys.sort()
	for k in keys:
		var g: Array = groups[k]
		var i := 0
		while i + 1 < g.size():
			out.append([g[i], g[i + 1]])
			i += 2
		if i < g.size():
			var dep := String(k).split("|")[0]
			if not odd_by_dep.has(dep):
				odd_by_dep[dep] = []
			(odd_by_dep[dep] as Array).append(g[i])
	var spare: Array = []
	for dep in odd_by_dep:
		var g: Array = odd_by_dep[dep]
		var i := 0
		while i + 1 < g.size():
			out.append([g[i], g[i + 1]])
			i += 2
		if i < g.size():
			spare.append(g[i])
	var i := 0
	while i < spare.size():
		out.append(spare.slice(i, i + 2))
		i += 2
	return out


## Fill rooms in order with groups (singles take a group's first person, the other goes on to the next room).
## Returns everyone who didn't fit.
static func _fill_rooms(rooms: Array, groups: Array) -> Array:
	var queue: Array = []
	for g in groups:
		queue.append_array(g)
	var q := 0
	for c in rooms:
		var n := int((c as Dictionary).get("berths", 2))
		var who: Array = []
		while who.size() < n and q < queue.size():
			who.append(queue[q])
			q += 1
		_put(String(c["number"]), who)
	return queue.slice(q)


static func _put(number: String, who: Array) -> void:
	if who.is_empty():
		return
	_in[number] = who
	for pid in who:
		_of[String(pid)] = number


## Deck 7: the quad to four engineers, then each pair (in seed order) the free cabin nearest its work. Returns the
## people left over (Deck 7 has 112 berths; far more people work there).
static func _fill_deck7(list: Array) -> Array:
	var free: Array = cabins_on("7").duplicate()
	var by_dep := {}
	for pid in list:
		var w := _deck7_work(String(pid))
		if not by_dep.has(w):
			by_dep[w] = []
		(by_dep[w] as Array).append(pid)
	var placed := {}
	# the quad
	for c in free:
		if int(c["berths"]) >= 4:
			var eng: Array = by_dep.get("engineering", [])
			var crew: Array = eng.slice(0, int(c["berths"]))
			_put(String(c["number"]), crew)
			for p in crew:
				placed[p] = true
			free.erase(c)
			break
	var rest: Array = []
	for p in list:
		if not placed.has(p):
			rest.append(p)
	var pairs := _pairs(rest)
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return _h(String(a[0]) + "d7") < _h(String(b[0]) + "d7"))
	var left: Array = []
	for pr in pairs:
		if free.is_empty():
			left.append_array(pr)
			continue
		var work: Array = DECK7_WORK.get(_deck7_work(String(pr[0])), [Vector2.ZERO])
		var best := -1
		var best_d := INF
		for i in free.size():
			var cc: Array = (free[i] as Dictionary)["centre"]
			var p := Vector2(float(cc[0]), float(cc[1]))
			for w in work:
				var d := p.distance_to(w as Vector2)
				if d < best_d:
					best_d = d
					best = i
		_put(String((free[best] as Dictionary)["number"]), pr)
		free.remove_at(best)
	return left
