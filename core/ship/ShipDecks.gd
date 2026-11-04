extends RefCounted
class_name ShipDecks
## ShipDecks — the deck list of the U.S.S. Enterprise (NCC-1701) as laid out in
## the Franz Joseph Star Fleet Technical Manual, and which of OUR rooms sit on
## which deck.
##
## To put a room on a deck, add its Ep1.ROOMS key to that deck's "rooms" list
## below, as [room key, label shown in the lift menu]. That is all. A deck with
## no rooms shows "NOT AVAILABLE YET" in the lift menu.
##
## "parts": which part of the ship the deck is in
##   "saucer"  = primary hull (decks 0-11)
##   "dorsal"  = the neck joining the two hulls (decks 8-14)
##   "hull"    = secondary hull (decks 15-24)
## Decks 8 to 11 exist in both the saucer and the dorsal, at the same height.

## REV 593: the episode playing (EpisodeRoom sets it as a lift opens). A deck-list room may carry a third value,
## the first episode it's in (Episode 3's computer core) - earlier episodes' lifts don't list it.
static var episode: int = 1

## Where the player was before they stepped into the turbolift (an Ep1.ROOMS key).
static var came_from: String = ""

## True for one room load after the player picked a deck: the room puts them at its
## turbolift instead of at the usual start. The room clears it again.
static var arrive_by_lift: bool = false

## Where the lift is in the story rooms that are not MapRooms (Quake x, y), by room key.
const STORY_LIFTS := {
	"bridge": Vector2(2855.0, -1327.0),
	# REV 290: sickbay is on Glen's Deck 7 map (aedeck7.glb) now - the lift up its corridor (LiftHandles "aedeck7").
	"sickbay": Vector2(375.0, 1755.0),
}

## True for one room load: the room puts the players at arrive_spot (map x, y) instead of the usual start. The room clears it.
static var arrive_spot_on: bool = false
static var arrive_spot: Vector2 = Vector2.ZERO
## Optional extras for an arrive_spot arrival (REV 84, the stairs between Deck 20 and Deck 21): the map height to appear at
## (-99999 = the room's floor) and the map direction to face (Vector2.ZERO = don't turn). The room clears them.
static var arrive_z: float = -99999.0
static var arrive_face: Vector2 = Vector2.ZERO

## True for one room load: engineering opens on its upper level (Deck 6) instead of its main floor (Deck 7). The room clears it.
static var eng_upper: bool = false

## Places that cannot be reached by turbolift. Picking one in the lift menu takes you to the room named
## here instead (the nearest lift), and you walk the rest of the way. [picked room] = room you arrive in.
const LIFT_REDIRECT := {
	# REV 645 (Glen: decks 15-19 on every turbolift; "you should always be dumped into a turbolift, I can give you
	# the co-ords later"): the hangar map's levels 16-18 have no lift car of their own yet, so for now they all
	# arrive in the hangar's one car (MapRoom.LIFTS["ae_deck8"]). When Glen sends a level's car, move its key
	# from here into LIFT_SPOTS with that spot.
	"ae_deck8_d16": "ae_deck8",
	"ae_deck8_d17": "ae_deck8",
	"ae_deck8_d18": "ae_deck8",
}

## REV 308: picking one of these in the lift menu opens the room on its upper level (eng_upper): the
## Deck 6 entry for Deck 7 engineering's walkway, reached by its own lift.
const LIFT_UPPER := {
	"ae_engineering_up": "ae_engineering",
}

## REV 617: lift stops that open a room at one particular lift, on another level of the same map - [map room key,
## map spot to step out at (map x, y), floor height there (map units), the way to face]. Deck 19's upper level
## (Auxiliary Control - Glen could never find it: the map only came up at the hangar floor). REV 622: you step out of the new lift in the
## alcove beside it (LiftHandles, (1081, 81)) into the corridor. (REV 618 put you straight into the room (floor 15.84 m = 528 units - map units are 0.03 m) - the upper lift's 'corridor' turned out to be the tops of the ribbed ducts.
const LIFT_SPOTS := {
	"ae_deck8_aux": ["ae_deck8", Vector2(1080.0, 105.0), 528.0, Vector2(0.0, 1.0)],   # REV 631: the second figure stands 35 behind this - Scotty in the car's middle (72 put him against its back wall)
	#   # REV 625/626: inside the copied lift car, facing its doors
}

const COUNT := 25   # decks 0 to 24

const DECKS := [
	{"n": 0, "name": "Upper Sensor Platform", "parts": ["saucer"],
	 "text": "The upper sensor platform.",
	 "rooms": []},
	{"n": 1, "name": "Bridge", "parts": ["saucer"],
	 "text": "The bridge.",
	 "rooms": [["bridge", "Bridge"]]},
	{"n": 2, "name": "Sciences Laboratories", "parts": ["saucer"],
	 "text": "Sciences laboratories.",
	 "rooms": []},
	{"n": 3, "name": "Photon Torpedo Bank - Sci. Labs", "parts": ["saucer"],
	 "text": "The photon torpedo bank and science laboratories.",
	 "rooms": []},
	{"n": 4, "name": "Officers' Quarters", "parts": ["saucer"],
	 "text": "Officers' quarters.",
	 "rooms": []},
	{"n": 5, "name": "Officers' Quarters", "parts": ["saucer"],
	 "text": "Officers' quarters.",
	 "rooms": [["ae_deck5", "Deck 5 Corridors"]]},
	{"n": 6, "name": "Crew's Quarters / Engineering", "parts": ["saucer"],
	 "text": "Crew's quarters and engineering.",
	 "rooms": [["e_quarters", "Crew Quarters"], ["ae_engineering_up", "Engineering (Upper Level)"]]},   # REV 390: ae_deck6 retired (Glen: e_quarters is THE Deck 6; debug menu only)
	{"n": 7, "name": "Computers / Medical Section / Engrg.", "parts": ["saucer"],
	 "text": "The computers, the medical section and engineering.",
	 "rooms": [["sickbay", "Sickbay"], ["ae_transporter", "Transporter Room"], ["ae_engineering", "Engineering"], ["ae_deck7", "Main Deck (Act 1)"],
		["computer_core", "Computer Core", 3]]},     # REV 699: Episode 3's computer core is on Deck 7 now (Turbo Lift 3, by engineering)
	{"n": 8, "name": "Life Quality Facilities", "parts": ["saucer", "dorsal"],
	 "text": "Life quality facilities. In the dorsal, the dorsal separation level.",
	 "rooms": []},     # (REV 593-698 Episode 3's computer core was here; REV 699 moved it to Deck 7)
	{"n": 9, "name": "Cargo / Maint. Facilities", "parts": ["saucer", "dorsal"],
	 "text": "Cargo and maintenance facilities. In the dorsal, the auxiliary machinery room.",
	 "rooms": []},
	{"n": 10, "name": "Cargo / Maint. Facilities", "parts": ["saucer", "dorsal"],
	 "text": "Cargo and maintenance facilities. In the dorsal, the observation lounges.",
	 "rooms": []},
	{"n": 11, "name": "Fwd. Phaser Bank / Aux. Fire Control", "parts": ["saucer", "dorsal"],
	 "text": "The forward phaser bank, auxiliary fire control and the lower sensor platform.",
	 "rooms": []},
	{"n": 12, "name": "Dorsal", "parts": ["dorsal"],
	 "text": "The interconnecting dorsal.",
	 "rooms": []},
	{"n": 13, "name": "Dorsal - Lounges", "parts": ["dorsal"],
	 "text": "The dorsal lounges.",
	 "rooms": []},
	{"n": 14, "name": "Dorsal", "parts": ["dorsal"],
	 "text": "The foot of the interconnecting dorsal, where it meets the secondary hull.",
	 "rooms": []},
	{"n": 15, "name": "Visicons / Air Cond. Mach. Room", "parts": ["hull"],
	 "text": "Visicons and the air conditioning machinery room.",
	 "rooms": [["ae_deck8_aux", "Auxiliary Control"]]},     # REV 624 (Glen): Auxiliary Control is Deck 15
	{"n": 16, "name": "Medical / Engineering", "parts": ["hull"],
	 "text": "The medical section and engineering.",
	 "rooms": [["ae_deck8_d16", "Hangar Upper Gallery"]]},     # REV 645: the hangar map's levels (LIFT_REDIRECT)
	{"n": 17, "name": "Crew's Quarters", "parts": ["hull"],
	 "text": "Crew's quarters.",
	 "rooms": [["ae_deck8_d17", "Hangar Gallery"]]},     # REV 705 (Glen: "Deck 17 is NOT a garden deck, it has nothing to do with the enterprise") - ae_engine off the lifts, debug only
	{"n": 18, "name": "Crew's Quarters", "parts": ["hull"],
	 "text": "Crew's quarters.",
	 "rooms": [["ae_deck8_d18", "Hangar Deck, Main Level"]]},
	{"n": 19, "name": "Bridge / Hangar Deck", "parts": ["hull"],
	 "text": "The engineering bridge and the hangar deck.",
	 "rooms": [["ae_deck8", "Hangar Deck"]]},
	{"n": 20, "name": "Recreation Area", "parts": ["hull"],
	 "text": "The recreation area and the pool.",
	 "rooms": [["ae_pool", "Recreation Area (Pool)"], ["ae_main", "Recreation Area (Pool, other map)"]]},
	{"n": 21, "name": "Food Preparation / Bowling Alley", "parts": ["hull"],
	 "text": "Food preparation facilities and the bowling alley.",
	 "rooms": [["ae_alley", "Bowling Alley"]]},
	{"n": 22, "name": "Fabrication Facilities", "parts": ["hull"],
	 "text": "Fabrication facilities.",
	 "rooms": []},
	{"n": 23, "name": "Stowage / Cargo Holds", "parts": ["hull"],
	 "text": "Stowage and cargo holds.",
	 "rooms": []},
	{"n": 24, "name": "Tank Top - Cargo Holds", "parts": ["hull"],
	 "text": "The tank top: cargo holds.",
	 "rooms": []},
]


static func deck(n: int) -> Dictionary:
	return DECKS[clampi(n, 0, DECKS.size() - 1)]


## The deck a room (an Ep1.ROOMS key) is on, or -1 if it is not on the ship.
static func deck_of_room(room_key: String) -> int:
	for d in DECKS:
		for r in d["rooms"]:
			if String(r[0]) == room_key:
				return int(d["n"])
	return -1


static func is_available(n: int) -> bool:
	return not deck(n)["rooms"].is_empty()
