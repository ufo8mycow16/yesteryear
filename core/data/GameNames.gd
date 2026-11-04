class_name GameNames
## REV 144: the ONE place that says what every character and room is called on screen
## (CLAUDE.md items 15 and 20). Subtitles, name tags, HUD prompts, the minimap room label and the
## debug overlay all read from here, so a name is changed once and changes everywhere.
##
## Rule (Glen, 14 Oct): rank + surname everywhere, never the surname alone.
## Room labels (Glen, 14 Oct): "Deck N - Room Name".

## character id (also the voice folder name) -> name shown on screen
const CHARACTERS := {
	"kirk": "Captain Kirk",
	"spock": "Commander Spock",
	"mccoy": "Dr McCoy",
	"uhura": "Lieutenant Uhura",
	"scott": "Lieutenant Commander Scott",
	"scotty": "Lieutenant Commander Scott",
	"sulu": "Lieutenant Sulu",
	"chekov": "Ensign Chekov",
	"riley": "Lieutenant Riley",     # REV 856: Shi'Kahr, on shore leave with a holo-camera (TOS: The Naked Time)
	"kyle": "Lieutenant Kyle",
	"pell": "Yeoman Pell",
	"chapel": "Nurse Chapel",   # REV 271 (Episode 2); REV 281: a lieutenant; REV 317: shown as "Nurse Chapel" (Glen)
	# Episode 1. Ranks/titles not decided yet - Glen to confirm (shown as written until then).
	"tuvall": "Tuvall",
	"ullus": "Ullus",
	"otari": "Otari",
	"darev": "Darev",
	"mbenga": "Dr M'Benga",
	"council": "Councillor T'Seva",
	"komack": "Admiral Komack",       # REV 867: Starfleet Command (TOS: Amok Time, A Private Little War)
	"sarek": "Ambassador Sarek",      # REV 862: the conference's Vulcan host (TOS: Journey to Babel)   # REV 495: the High Council leader (Glen, 27 Oct), named on screen in the ruins
	# Episode 2 (REV 505, EPISODE2_SCRIPT.md)
	"giotto": "Lieutenant Commander Giotto",   # security chief (TOS: The Devil in the Dark); the 2.06 escort, the 2.08 lead
	# Episode 3 (REV 592+, EPISODE3_SCRIPT.md). Romaine is Episode 2's unnamed computer specialist (shown there as
	# "Computer Specialist" - her name is first said in Episode 3's computer core).
	"romaine": "Lieutenant Romaine",
	"desalle": "Lieutenant DeSalle",
	"leslie": "Lieutenant Leslie",
	"ross": "Ensign Ross",
}

## Voice folders whose names differ from the character id.
const FOLDER_TO_ID := {
	"vulcan_guard": "guard",
	"vulcan_security": "officer",
	"council_leader": "council",
	"vulcan_leader": "council",     # REV 505: Episode 2's Vulcan leader IS T'Seva
}

## Scene file name (no extension) -> room label. Rooms not listed yet show their file name, so it's
## obvious which ones still need a proper name from Glen.
const ROOMS := {
	"BowlingAlley": "Deck 21 - Bowling Alley",
}


## The on-screen name for a character id, e.g. "kirk" -> "Captain Kirk".
## Unknown ids give `fallback` (or the id, capitalised) so nothing ever shows blank.
static func character(id: String, fallback: String = "") -> String:
	var key := id.to_lower()
	key = String(FOLDER_TO_ID.get(key, key))
	if CHARACTERS.has(key):
		return String(CHARACTERS[key])
	return fallback if fallback != "" else id.capitalize()


## True if this id has an entry in the table.
static func has_character(id: String) -> bool:
	return CHARACTERS.has(id.to_lower())


## The room label for a scene (a Node or a scene path).
static func room_of(scene_or_path: Variant) -> String:
	var path := ""
	if scene_or_path is Node:
		var n := scene_or_path as Node
		if n.has_method("room_display_name"):
			var own := String(n.call("room_display_name"))
			if own != "":
				return own
		path = n.scene_file_path
	else:
		path = String(scene_or_path)
	var key := path.get_file().get_basename()
	return String(ROOMS.get(key, key if key != "" else "Unknown Room"))
