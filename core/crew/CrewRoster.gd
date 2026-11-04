class_name CrewRoster
extends RefCounted
## REV 180: the Enterprise's 430-person complement, from Glen and Tiffany's CSVs (data/crew/, brief:
## data/crew/CLAUDE_CREW_IMPLEMENTATION_BRIEF.md). This is DATA only - nobody is built until a room asks
## for people (CrewRoster.people_for), and then only the few that room shows.
##
## Per playthrough: a crew seed is rolled once at New Game and kept in the save (WorldState
## "crew/seed"). From the seed and the permanent post/person ids (never row order):
##   - every non-canon post gets a qualified candidate: same career field (from the job title first),
##     same experience band, or - documented fallback - someone MORE experienced (never a different
##     career). Canon posts (Kirk, Spock x2, McCoy...) are reserved for the named characters.
##   - one extra relief member makes 430 distinct people (Spock holds two posts). REV 293: they get the
##     supplemental assignment RELIEF-001 (the brief), not a 431st row in crew_posts.csv.
##   - about two thirds go on shore leave on Vulcan; essential posts are kept aboard first.
##   - of those aboard, some are on watch at their post, the rest off duty in communal areas, so the
##     same person is never at their post AND in the rec room.
## New Game = a different crew; the same save = the same crew.

const POSTS_CSV := "res://data/crew/crew_posts.csv"
const PEOPLE_CSV := "res://data/crew/crew_people.csv"
const KEY_SEED := "crew/seed"
const KEY_LEAVE := "crew/leave/"        # + person_id: story override, true = on leave / false = aboard
const ABOARD_TARGET := 143              # about a third of 430
const ON_WATCH_SHARE := 0.55            # of those aboard (not essential), how many are at their post
## REV 293: the relief / floating crew member's assignment id (the brief: "RELIEF-001", kept out of
## crew_posts.csv). It is worked out from the saved crew seed like everything else, so the same save
## always has the same relief person.
const RELIEF_ID := "RELIEF-001"
## Rank the relief member holds, from their experience band (same bands as RANK_BAND).
const RELIEF_RANK := {"junior": "crewman", "mid": "lieutenant_jg", "senior": "lt_commander"}

## Career field of a post: the job title decides first (the brief: transporter and ordnance posts
## sit in other departments), then the department.
const TITLE_CAREER := {
	"Transporter Specialist": "transporter",
	"Ordnance Specialist": "ordnance",
	"Ordnance Officer": "ordnance",
	"Operations Yeoman": "support",
	"Command Yeoman": "command",
	"Science Yeoman": "science",
}
const RANK_BAND := {
	"specialist": "junior", "ensign": "junior", "yeoman": "junior", "petty_officer": "junior", "crewman": "junior",
	"lieutenant_jg": "mid", "lieutenant": "mid",
	"lt_commander": "senior", "commander": "senior", "captain": "senior",
}
const BAND_LEVEL := {"junior": 0, "mid": 1, "senior": 2}
## Rank shown before the surname (CLAUDE.md: rank + surname, never surname alone).
const RANK_TITLE := {
	"specialist": "Crewman", "ensign": "Ensign", "yeoman": "Yeoman", "petty_officer": "Petty Officer",
	"crewman": "Crewman", "lieutenant_jg": "Lieutenant", "lieutenant": "Lieutenant",
	"lt_commander": "Lieutenant Commander", "commander": "Commander", "captain": "Captain",
}

## REV 182: named story characters who use the crew bodies (CrewLooks.make(id)) but are not in the
## crew CSVs, so the roster never puts them on another post or in a crowd. Same columns as the CSVs,
## plus their post. Their face is worked out and pinned like anyone else's.
const STORY_PEOPLE := {
	# REV 856 (SHIKAHR_SCRIPT.md): Lieutenant Kevin Riley (TOS: The Naked Time, The Conscience of the King), on shore
	# leave in Shi'Kahr with a holo-camera. Irish, dark-haired; engineering's red since Conscience of the King.
	"riley": {
		"person_id": "riley", "first_name": "Kevin", "surname": "Riley", "sex": "male", "heritage": "european",
		"species": "human", "career_field": "operations", "rank_band": "junior", "notes": "Shore leave in Shi'Kahr. Sings when nervous.",
		"hair": "alistair_swept_0", "hair_tint": [0.30, 0.22, 0.16],
		"post": {"post_id": "STORY-RILEY", "division": "operations", "shirt_colour": "red", "department": "engineering",
			"rank": "lieutenant", "job_title": "Engineering Officer", "location": "engineering", "essential": "no", "canon": "riley"},
	},
	"pell": {
		"person_id": "pell", "first_name": "", "surname": "Pell", "sex": "male", "heritage": "european",
		"species": "human", "career_field": "support", "rank_band": "junior", "notes": "Prologue: rec deck steward",
		"post": {"post_id": "STORY-PELL", "division": "operations", "shirt_colour": "red", "department": "ship_services",
			"rank": "yeoman", "job_title": "Recreation Deck Steward", "location": "rec_deck", "essential": "no", "canon": ""},
	},
	# REV 227: the transporter chief (Episode 1 opening) until Glen's Daz Kyle arrives.
	"kyle": {
		"person_id": "kyle", "first_name": "", "surname": "Kyle", "sex": "male", "heritage": "european",
		"species": "human", "career_field": "operations", "rank_band": "mid", "notes": "Transporter chief",
		"post": {"post_id": "STORY-KYLE", "division": "operations", "shirt_colour": "red", "department": "transporter",
			"rank": "lieutenant", "job_title": "Transporter Chief", "location": "transporter_room", "essential": "yes", "canon": ""},
		# REV 673 (Glen's picture: his crown showed through - the kit's McCoy hair): sandy, swept
		# back (Glen's Kyle: "sandy swept-back hair")
		"hair": "alistair_swept_0", "hair_tint": [0.95, 0.82, 0.62],
	},
	# REV 511 (Episode 2, EPISODE2_SCRIPT.md): Lieutenant Commander Giotto, chief of security (TOS: The Devil in
	# the Dark) - the 2.06 escort and the 2.08 lead - and the two engineers who are always playing Fizzbin.
	"giotto": {
		"person_id": "giotto", "first_name": "", "surname": "Giotto", "sex": "male", "heritage": "european",
		"species": "human", "career_field": "security", "rank_band": "senior", "notes": "Chief of security. Was at Janus VI. Distrusts everyone equally.",
		# REV 610 (Glen: his rolled hair was one of the kit's broken, dotty styles): dark, swept back, like Barry Russo's
		"hair": "alistair_swept_0", "hair_tint": [0.35, 0.33, 0.32],
		"post": {"post_id": "STORY-GIOTTO", "division": "operations", "shirt_colour": "red", "department": "security",
			"rank": "lt_commander", "job_title": "Chief of Security", "location": "security", "essential": "yes", "canon": "giotto"},
	},
	# REV 717 (Glen: "remove ALL copies of that block man, and swap them for real crew"): Dr. M'Benga (TOS: A Private Little
	# War) in Episode 1's streets was the box stand-in.
	"mbenga": {
		"person_id": "mbenga", "first_name": "Joseph", "surname": "M'Benga", "sex": "male", "heritage": "african",
		"species": "human", "career_field": "medical", "rank_band": "mid", "notes": "Doctor; interned in a Vulcan hospital",
		"post": {"post_id": "STORY-MBENGA", "division": "sciences", "shirt_colour": "blue", "department": "medical",
			"rank": "lieutenant", "job_title": "Physician", "location": "sickbay", "essential": "no", "canon": "mbenga"},
	},
	"engineer_1": {
		"person_id": "engineer_1", "first_name": "", "surname": "", "sex": "male", "heritage": "european",
		"species": "human", "career_field": "engineering", "rank_band": "junior", "notes": "Episode 2: Fizzbin, on a long break",
		"post": {"post_id": "STORY-ENG1", "division": "operations", "shirt_colour": "red", "department": "engineering",
			"rank": "specialist", "job_title": "Engineer", "location": "deck7", "essential": "no", "canon": ""},
	},
	"engineer_2": {
		"person_id": "engineer_2", "first_name": "", "surname": "", "sex": "male", "heritage": "african",
		"species": "human", "career_field": "engineering", "rank_band": "junior", "notes": "Episode 2: Fizzbin, two jacks",
		"post": {"post_id": "STORY-ENG2", "division": "operations", "shirt_colour": "red", "department": "engineering",
			"rank": "specialist", "job_title": "Engineer", "location": "deck7", "essential": "no", "canon": ""},
	},
	# REV 593 (Episode 3, EPISODE3_SCRIPT.md - cast approved by Glen 27 Oct): the jumpy Romulan-spotter (any body
	# but Spock's - Glen), his partner Ross, Scotty's man in Engineering (TOS canon), and the mess hall crewman
	# who completely missed the hijacking.
	"leslie": {
		"person_id": "leslie", "first_name": "", "surname": "Leslie", "sex": "male", "heritage": "european",
		"species": "human", "career_field": "security", "rank_band": "mid", "notes": "Episode 3: sees Romulans everywhere. A coat. A tribble. Chekov.",
		# REV 741 (Glen's bug list item 35: "patchy black with scalp showing" - he drew one of the kit's dotty styles):
		# pinned to the kit's solid swept style, mid brown (Giotto wears it dark, Kyle sandy)
		"hair": "alistair_swept_0", "hair_tint": [0.55, 0.40, 0.27],
		"post": {"post_id": "STORY-LESLIE", "division": "operations", "shirt_colour": "red", "department": "security",
			"rank": "lieutenant", "job_title": "Security Officer", "location": "security", "essential": "no", "canon": "leslie"},
	},
	"ross": {
		"person_id": "ross", "first_name": "", "surname": "Ross", "sex": "male", "heritage": "african",
		"species": "human", "career_field": "security", "rank_band": "junior", "notes": "Episode 3: hasn't blinked since breakfast.",
		"post": {"post_id": "STORY-ROSS", "division": "operations", "shirt_colour": "red", "department": "security",
			"rank": "ensign", "job_title": "Security Officer", "location": "security", "essential": "no", "canon": ""},
	},
	"desalle": {
		"person_id": "desalle", "first_name": "Vincent", "surname": "DeSalle", "sex": "male", "heritage": "european",
		"species": "human", "career_field": "engineering", "rank_band": "mid", "notes": "Assistant chief engineer (TOS). Has stopped touching things.",
		"post": {"post_id": "STORY-DESALLE", "division": "operations", "shirt_colour": "red", "department": "engineering",
			"rank": "lieutenant", "job_title": "Assistant Chief Engineer", "location": "engineering", "essential": "yes", "canon": "desalle"},
	},
	"mess_crewman": {
		"person_id": "mess_crewman", "first_name": "", "surname": "Barrows", "sex": "male", "heritage": "european",
		"species": "human", "career_field": "support", "rank_band": "junior", "notes": "Episode 3: eating lunch. Has no idea.",
		"post": {"post_id": "STORY-MESS", "division": "operations", "shirt_colour": "gold", "department": "ship_services",
			"rank": "specialist", "job_title": "Crewman", "location": "off_duty", "essential": "no", "canon": ""},
	},
	# REV 592 (Episode 3 handover): Lieutenant Mira Romaine (TOS: The Lights of Zetar) - Episode 2's unnamed
	# Enterprise computer specialist (the datapad), named in Episode 3's computer core. Red dress, as in TOS.
	"romaine": {
		"person_id": "romaine", "first_name": "Mira", "surname": "Romaine", "sex": "female", "heritage": "european",
		"species": "human", "career_field": "operations", "rank_band": "mid", "notes": "Computer specialist. Knows Mister Scott - a history nobody explains.",
		"post": {"post_id": "STORY-ROMAINE", "division": "operations", "shirt_colour": "red", "department": "computers",
			"rank": "lieutenant", "job_title": "Computer Specialist", "location": "general", "essential": "yes", "canon": "romaine"},
	},
	# REV 280: Nurse Chapel (Episode 2) - her face is a fixed recipe, CrewLooks.FIXED_LOOKS["chapel"].
	"chapel": {
		"person_id": "chapel", "first_name": "Christine", "surname": "Chapel", "sex": "female", "heritage": "european",
		"species": "human", "career_field": "medical", "rank_band": "mid", "notes": "Head nurse. Was a civilian on exchange with the Stanford-Moorehouse epigenetic programme; resigned it and took a commission (Glen)",
		"post": {"post_id": "STORY-CHAPEL", "division": "sciences", "shirt_colour": "blue", "department": "medical",
			"rank": "lieutenant", "job_title": "Head Nurse", "location": "sickbay", "essential": "yes", "canon": "chapel"},
	},
}

static var _cache_seed := -1
static var _posts: Array = []            # Dictionaries, CSV columns
static var _people: Dictionary = {}      # person_id -> Dictionary (CSV columns)
static var _crew: Dictionary = {}        # person_id -> {"post": post dict (REV 293: RELIEF-001 for the relief member), "aboard": bool, "on_watch": bool}
static var relaxations: Array[String] = []   # posts filled by the more-experienced fallback (for QA)


## The crew seed of this playthrough (rolled and saved the first time anyone asks).
static func crew_seed() -> int:
	var s = WorldState.get_value(KEY_SEED, null)
	if s == null:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		# kept as text: a save stores numbers as JSON, which would give it back as a decimal
		s = str(rng.randi() & 0x7fffffff)
		WorldState.set_value(KEY_SEED, s)
	return int(s)


## Everyone, built for the current seed (cached until the seed changes).
static func roster() -> Dictionary:
	var seed_value := crew_seed()
	if seed_value != _cache_seed or _crew.is_empty():
		_build(seed_value)
	return _crew


static func person(person_id: String) -> Dictionary:
	if STORY_PEOPLE.has(person_id):
		return STORY_PEOPLE[person_id]
	roster()
	return _people.get(person_id, {})


static func post_of(person_id: String) -> Dictionary:
	if STORY_PEOPLE.has(person_id):
		return (STORY_PEOPLE[person_id] as Dictionary).get("post", {})
	return (roster().get(person_id, {}) as Dictionary).get("post", {})


static func is_aboard(person_id: String) -> bool:
	var o = WorldState.get_value(KEY_LEAVE + person_id, null)
	if o != null:
		return not bool(o)
	return bool((roster().get(person_id, {}) as Dictionary).get("aboard", false))


## Story events: send someone on leave or call them back aboard (saved).
static func set_on_leave(person_id: String, on_leave: bool) -> void:
	WorldState.set_value(KEY_LEAVE + person_id, on_leave)


## REV 297: crew the player has spoken to (the Shi'Kahr canvass, Episode 1). WorldState "crew/met/<id>" =
## what they told McCoy: a clue id (ST_...) when they gave a first-hand sighting, "cart" / "transit_partial"
## for a useful half-answer, or "talked:<role>" when they had nothing. Saved; carried into the next episode
## with the rest of crew/* (Ep1/Ep2.new_game(true)). Aboard, a met person can recognise the player.
const KEY_MET := "crew/met/"


## Remember that `person_id` was spoken to. A useful answer replaces a plain "talked"; never the reverse.
static func mark_met(person_id: String, topic: String) -> void:
	if person_id == "":
		return
	var old := String(WorldState.get_value(KEY_MET + person_id, ""))
	if old != "" and not old.begins_with("talked") and topic.begins_with("talked"):
		return
	WorldState.set_value(KEY_MET + person_id, topic)


## What `person_id` told the player ("" if never met).
static func met_topic(person_id: String) -> String:
	return String(WorldState.get_value(KEY_MET + person_id, ""))


## True when what they told the player was some use (a sighting or a lead), not just "nothing, sir".
static func met_helped(person_id: String) -> bool:
	var t := met_topic(person_id)
	return t != "" and not t.begins_with("talked")


## Everyone met, in a stable order - the ones who helped first.
static func met_people() -> Array[String]:
	var out: Array[String] = []
	var all: Dictionary = WorldState.snapshot()
	for k in all.keys():
		var key := String(k)
		if key.begins_with(KEY_MET):
			out.append(key.substr(KEY_MET.length()))
	out.sort_custom(func(a: String, b: String) -> bool:
		var ha := met_helped(a)
		var hb := met_helped(b)
		if ha != hb:
			return ha
		return a < b)
	return out


## "Lieutenant Mirza" - rank and surname, as GameNames does for the named crew.
static func display_name(person_id: String) -> String:
	var p := person(person_id)
	var post := post_of(person_id)
	var rank := String(post.get("rank", "specialist"))
	return "%s %s" % [RANK_TITLE.get(rank, "Crewman"), String(p.get("surname", "?"))]


## The job line under the name: "Nurse - Medical".
static func job_line(person_id: String) -> String:
	var post := post_of(person_id)
	if post.is_empty():
		return "Relief Crew"     # an unknown id (REV 293: the relief member now has RELIEF-001)
	return String(post.get("job_title", ""))


## Officers from lieutenant up wear sleeve braid; crewmen, yeomen, petty officers and ensigns don't.
static func wears_braid(person_id: String) -> bool:
	var rank := String(post_of(person_id).get("rank", "specialist"))
	return rank in ["lieutenant_jg", "lieutenant", "lt_commander", "commander", "captain"]


## Shirt colour for the uniform: gold / blue / red, straight from the CSV.
static func shirt_of(person_id: String) -> String:
	var post := post_of(person_id)
	if post.is_empty():
		var p := person(person_id)
		return _career_shirt(String(p.get("career_field", "support")))
	return String(post.get("shirt_colour", "red"))


## People for a room, in a stable order. location: a crew_posts.csv location (bridge, sickbay,
## engineering, science_labs, security, transporter, general) for people on watch at their post,
## or "off_duty" for people aboard but off watch (rec deck, bowling alley, corridors, mess), or
## "shore_leave" for people who are off the ship.
## salt keeps different rooms from all showing the same off-duty faces.
static func people_for(location: String, count: int, salt: String = "") -> Array[String]:
	var crew := roster()
	var pool: Array[String] = []
	for pid in crew:
		var c: Dictionary = crew[pid]
		# REV 279: "shore_leave" = the crew who are NOT aboard (on Vulcan, Episode 1's streets)
		if location == "shore_leave":
			if not is_aboard(pid):
				pool.append(pid)
			continue
		if not is_aboard(pid):
			continue
		if location == "off_duty":
			if not bool(c["on_watch"]):
				pool.append(pid)
		elif bool(c["on_watch"]) and String((c["post"] as Dictionary).get("location", "")) == location:
			pool.append(pid)
	var s := _cache_seed
	pool.sort_custom(func(a, b): return _h(a + salt, s) < _h(b + salt, s))
	return pool.slice(0, count)


# ---------------------------------------------------------------------------

static func _build(seed_value: int) -> void:
	_cache_seed = seed_value
	_load_csvs()
	_crew.clear()
	relaxations.clear()
	var used := {}
	# candidates in a seed-shuffled but id-stable order
	var cand: Array = _people.keys()
	cand.sort_custom(func(a, b): return _h(a, seed_value) < _h(b, seed_value))
	# hardest posts first (senior, then mid), each band in post-id order
	var open: Array = []
	for p in _posts:
		if String(p.get("canon", "")) == "":
			open.append(p)
	open.sort_custom(func(a, b):
		var la: int = BAND_LEVEL[_band_of(a)]
		var lb: int = BAND_LEVEL[_band_of(b)]
		return la > lb if la != lb else String(a["post_id"]) < String(b["post_id"]))
	for p in open:
		var career := _career_of(p)
		var band: int = BAND_LEVEL[_band_of(p)]
		var pick := ""
		for want in range(band, 3):              # exact band, then more experienced (documented fallback)
			for pid in cand:
				if used.has(pid):
					continue
				var c: Dictionary = _people[pid]
				if String(c["career_field"]) == career and int(BAND_LEVEL.get(String(c["rank_band"]), 0)) == want:
					pick = pid
					break
			if pick != "":
				if want != band:
					relaxations.append("%s %s: filled from band %d" % [p["post_id"], p["job_title"], want])
				break
		if pick == "":
			relaxations.append("%s %s: NO qualified candidate - left empty" % [p["post_id"], p["job_title"]])
			continue
		used[pick] = true
		_crew[pick] = {"post": p, "aboard": false, "on_watch": false}
	# one relief member (Spock holds two posts) -> 430 distinct people. REV 293: given the supplemental
	# assignment RELIEF-001 that matches their own career and experience (the brief), instead of no post.
	for pid in cand:
		if not used.has(pid):
			used[pid] = true
			_crew[pid] = {"post": _relief_post(_people[pid]), "aboard": false, "on_watch": false}
			break
	# shore leave: essential posts aboard first, then by seed until about a third are aboard
	var order: Array = _crew.keys()
	order.sort_custom(func(a, b):
		var ea := String((_crew[a]["post"] as Dictionary).get("essential", "no")) == "yes"
		var eb := String((_crew[b]["post"] as Dictionary).get("essential", "no")) == "yes"
		return ea if ea != eb else _h(a + "leave", seed_value) < _h(b + "leave", seed_value))
	# (the 13 canon people count toward the third aboard)
	var aboard_left := ABOARD_TARGET - 13
	for pid in order:
		if aboard_left <= 0:
			break
		_crew[pid]["aboard"] = true
		aboard_left -= 1
		var essential := String((_crew[pid]["post"] as Dictionary).get("essential", "no")) == "yes"
		# REV 293: the relief member has no fixed station, so they are never "on watch at their post"
		# (aboard, they turn up off duty with everyone else).
		var post_known := not (_crew[pid]["post"] as Dictionary).is_empty() and not is_relief(pid)
		_crew[pid]["on_watch"] = post_known and (essential or _h(pid + "watch", seed_value) % 1000 < int(ON_WATCH_SHARE * 1000))


## REV 293: true for the one relief / floating crew member (assignment RELIEF-001).
static func is_relief(person_id: String) -> bool:
	if STORY_PEOPLE.has(person_id):
		return false
	if _crew.is_empty():
		roster()
	return String((_crew.get(person_id, {}) as Dictionary).get("post", {}).get("post_id", "")) == RELIEF_ID


## REV 293: the relief member's supplemental assignment - same columns as a crew_posts.csv row, so
## names, rank, braid and shirt colour all work as for anyone else. Their division and shirt follow
## their own career field; their rank follows their experience band. Location "relief" is not a room,
## so people_for never puts them at a station.
static func _relief_post(c: Dictionary) -> Dictionary:
	var career := String(c.get("career_field", "support"))
	var shirt := _career_shirt(career)
	var division := "command" if shirt == "gold" else ("sciences" if shirt == "blue" else "operations")
	return {
		"post_id": RELIEF_ID, "division": division, "shirt_colour": shirt, "department": career,
		"rank": String(RELIEF_RANK.get(String(c.get("rank_band", "junior")), "crewman")),
		"job_title": "Relief Crew", "location": "relief", "essential": "no", "canon": "",
	}


static func _load_csvs() -> void:
	if not _posts.is_empty():
		return
	for row in _read_csv(POSTS_CSV):
		_posts.append(row)
	for row in _read_csv(PEOPLE_CSV):
		_people[String(row["person_id"])] = row


static func _read_csv(path: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("CrewRoster: can't read %s" % path)
		return out
	var header := f.get_csv_line()
	if header.size() > 0:
		header[0] = header[0].trim_prefix("﻿")     # the spreadsheet byte-order mark
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < header.size():
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = line[i]
		out.append(row)
	return out


static func _career_of(post: Dictionary) -> String:
	var t := String(post.get("job_title", ""))
	if TITLE_CAREER.has(t):
		return TITLE_CAREER[t]
	return String(post.get("department", "support"))


static func _band_of(post: Dictionary) -> String:
	var t := String(post.get("job_title", ""))
	# high-responsibility billets are senior whatever their minimum rank
	if t.begins_with("Chief") or t.begins_with("Head ") or t.begins_with("Assistant Chief") or t == "Assistant Science Officer":
		return "senior"
	return String(RANK_BAND.get(String(post.get("rank", "specialist")), "junior"))


static func _career_shirt(career: String) -> String:
	match career:
		"command", "helm_nav", "ordnance":
			return "gold"
		"science", "medical":
			return "blue"
	return "red"


## REV 185: how this person reacts when they applaud something (the bowling alley crowd). Worked out
## from their id and the crew seed, so the same person always reacts the same way all playthrough and
## nothing extra is saved. zeal 0..1 (barely reacts .. delighted), delay before they react (0-0.6 s),
## pace (how fast they clap, so how long it lasts), mirror (which hand leads), and whether they are
## the sort who stands up to cheer (men only - see BowlingAlley._crowd_applause).
static func reaction_of(person_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _h(person_id + "applause", crew_seed())
	var zeal := rng.randf()
	zeal = zeal * zeal * (3.0 - 2.0 * zeal)          # fewer in the middle, a few at each end
	var sex := String(person(person_id).get("sex", "male"))
	return {
		"zeal": zeal,
		"delay": snappedf(rng.randf_range(0.0, 0.6), 0.01),
		"pace": snappedf(rng.randf_range(0.88, 1.12), 0.01),
		"mirror": rng.randf() < 0.5,
		"stander": sex == "male" and zeal > 0.55 and rng.randf() < 0.8,
		"sex": sex,
	}


## A stable hash of an id and the seed (never depends on row order or Godot's string hash changing).
static func _h(id: String, seed_value: int) -> int:
	var h := 2166136261 ^ seed_value
	for b in id.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0x7fffffff
	return h
