extends RefCounted
class_name Ep3
## Ep3 - the facts of Episode 3, "GHOST IN THE MACHINE", in one place: who speaks, the rooms, what the
## episode remembers, the two missions, the things carried, THE PARTNER table, the collector cards and the
## ship explored. Built from episodes/episode3/EPISODE3_SCRIPT.md (REV 585-589) - the design authority.
## Section numbers in comments (3.05, 3.22 ...) are that script's.
##
## Episode 3 is Scotty's and Kyle's episode (EpisodeRoom.lead_people): Scotty in the "mccoy" slot (the
## main one), Lieutenant Kyle in the "kirk" slot from 3.06 on.
##
## THE SHAPE (Glen, 27 Oct): the Enterprise stays at warp for four-fifths of the episode while the three
## Romulans, still aboard, lead the crew on a wild goose chase. MAIN mission CAPTURE ROMULAN INTRUDERS
## (from the first minutes, never completed - FAILED at 3.35, though the game never says it can fail);
## SIDE mission REGAIN CONTROL OF THE ENTERPRISE, won back a system at a time, NAVIGATION last - it only
## lets go when she drops out of warp (3.30).
## WHAT THE CREW KNOWS: a prisoner recovery. Nobody aboard knows the Romulans meant to come here, or why.

const PREFIX := "EP3"
const EPISODE_TITLE := "GHOST IN THE MACHINE"     # Glen, 27 Oct (confirmed)
const SPEECH_ROOT := "res://episodes/episode3/audio/speech/"

## who -> [voice folder, name shown in the subtitle]
const SPEAKERS := {
	"scotty": ["scotty", "Scott"],
	"kyle": ["kyle", "Kyle"],
	"giotto": ["giotto", "Giotto"],
	"leslie": ["leslie", "Leslie"],
	"ross": ["ross", "Ross"],
	"uhura": ["uhura", "Uhura"],
	"sulu": ["sulu", "Sulu"],
	"chekov": ["chekov", "Chekov"],
	"chapel": ["chapel", "Chapel"],
	"romaine": ["romaine", "Romaine"],          # the same voice as Episode 2's ent_specialist
	"desalle": ["desalle", "DeSalle"],
	"pell": ["pell", "Pell"],
	"mess_crewman": ["mess_crewman", "Crewman"],
	"crewman": ["crewman", "Crewman"],
	# REV 628: the two background crew at the bridge's side stations (Bridge.gd), one voice each way
	"bridge_crewman": ["bridge_crewman", "Crewman"],
	"bridge_crewwoman": ["bridge_crewwoman", "Crewwoman"],
	"guard": ["security_guard", "Security Guard"],
	"engineer_1": ["engineer_1", "Engineer"],
	"engineer_2": ["engineer_2", "Engineer"],
	# the ship's computer: its own plain voice, and the Matrix's leftovers ("glorious commander") - two line
	# sets, one voice (the script's CODE NOTES)
	"computer": ["computer", "Computer"],
	"computer_glorious": ["computer_glorious", "Computer"],
	# the three - heard, not seen (the audio log, the door comm); the same voices as Episode 2
	"varel": ["varel", "Varel"],
	"kovek": ["kovek", "Kovek"],
	"tovan": ["tovan", "Tovan"],
	"vulcan_comms": ["vulcan_comms", "Vulcan Communications"],
}

## room key -> [name shown on arrival and in the travel menu, scene]
const ROOMS := {
	"opening": ["Previously", "res://episodes/episode3/scenes/Ep3Opening.tscn"],
	"bridge": ["Enterprise - Bridge", "res://episodes/episode3/scenes/Bridge.tscn"],
	"deck7": ["Enterprise - Deck 7 Corridor", "res://episodes/episode3/scenes/Deck7.tscn"],
	"auxdeck": ["Enterprise - Deck 15, Auxiliary Control", "res://episodes/episode3/scenes/AuxDeck.tscn"],   # REV 625: the real door (3.04-3.08)
	"auxcontrol": ["Enterprise - Auxiliary Control", "res://episodes/episode3/scenes/AuxControl.tscn"],
	"transporter": ["Enterprise - Transporter Room 1", "res://episodes/episode3/scenes/TransporterRoom.tscn"],
	"security": ["Enterprise - Security Office", "res://episodes/episode3/scenes/SecurityOffice.tscn"],
	"cargobay": ["Enterprise - Cargo Bay 2", "res://episodes/episode3/scenes/CargoBay.tscn"],
	"sickbay": ["Enterprise - Sickbay", "res://episodes/episode3/scenes/Sickbay.tscn"],
	"lab": ["Enterprise - Decryption Lab", "res://episodes/episode3/scenes/DecryptionLab.tscn"],
	"engineering": ["Enterprise - Engineering", "res://episodes/episode3/scenes/Engineering.tscn"],
	"deck6": ["Enterprise - Deck 6, Crew Quarters", "res://episodes/episode3/scenes/Deck6.tscn"],
	"messhall": ["Enterprise - Mess Hall", "res://episodes/episode3/scenes/MessHall.tscn"],
	"tube": ["Enterprise - Jefferies Tube", "res://episodes/episode3/scenes/JefferiesTube.tscn"],
	"deck5": ["Enterprise - Deck 5", "res://episodes/episode3/scenes/Deck5.tscn"],
	"core": ["Enterprise - Computer Core", "res://episodes/episode3/scenes/ComputerCore.tscn"],
	"recdeck": ["Enterprise - Deck 21, Bowling Alley", "res://episodes/episode3/scenes/RecDeck.tscn"],
	# free roam: decks with no story of their own (every lift lever works - Glen's standing rule)
	"walk_ae_deck8": ["Enterprise - Deck 19, Hangar Deck", "res://episodes/episode3/scenes/walk/Walk_ae_deck8.tscn"],
	"walk_ae_pool": ["Enterprise - Deck 20, Recreation", "res://episodes/episode3/scenes/walk/Walk_ae_pool.tscn"],
	"walk_ae_main": ["Enterprise - Deck 20, Recreation", "res://episodes/episode3/scenes/walk/Walk_ae_main.tscn"],
	"walk_ae_engine": ["Enterprise - Garden Deck", "res://episodes/episode3/scenes/walk/Walk_ae_engine.tscn"],
}

## The turbolift's deck list (ShipDecks) names rooms by the ship's keys; these are Episode 3's rooms for them.
const LIFT_ROOMS := {
	"bridge": "bridge", "sickbay": "sickbay", "ae_transporter": "transporter", "ae_engineering": "engineering",
	"ae_deck7": "deck7", "ae_deck8_aux": "auxdeck", "e_quarters": "deck6", "ae_deck5": "deck5", "ae_alley": "recdeck", "computer_core": "engineering",
	"ae_deck8": "walk_ae_deck8", "ae_pool": "walk_ae_pool", "ae_main": "walk_ae_main", "ae_engine": "walk_ae_engine",
}

## USS ENTERPRISE EXPLORED - XX% (Glen's synopsis): every accessible area counts once. Add areas freely -
## old saves simply have a smaller share found.
const EXPLORE := ["bridge", "deck7", "auxdeck", "auxcontrol", "transporter", "security", "cargobay", "sickbay", "lab",
	"engineering", "engineering_upper", "deck6", "cabin_scotty", "cabin_uhura", "cabin_pell", "cabin_sulu",
	"tube_6a", "tube_6b", "deck5", "lounge", "core", "recdeck", "walk_ae_deck8", "walk_ae_pool", "walk_ae_main",
	"walk_ae_engine"]

## Everything the episode remembers (saved with the game). Yes/no flags in STORY ORDER (the scene select
## sets every one listed before a scene's "before" flag).
const DEFAULTS := {
	"EP3_STARTED": false,
	"EP3_ACTIVE_CHAR": "mccoy",
	"EP3_ACTIVE_LEAD": "scotty",
	"EP3_EXPLORED": [],
	"EP3_LAST_CALL": "",
	"EP3_GIOTTO_ARGS": 0,
	"EP3_MATRIX_WAY": "",
	"EP3_MESSAGE_TONE": "",
	"EP3_VAREL_LAST": "",
	"EP3_ENERGIZE_TRIES": 0,
	"EP3_FIZZBIN_ROUND": 0,
	"EP3_BANKS_ASKED": [],
	"EP3_FAKES": 0,
	# 3.00 - 3.03: the opening and the bridge
	"EP3_OPENING_DONE": false,
	"EP3_BRIDGE_ARRIVED": false,
	"EP3_THRUSTERS_ORDERED": false,
	"EP3_ASKED_HEADING": false,
	"EP3_ASKED_SENSORS": false,
	"EP3_CHEKOV_PRAISED": false,
	"EP3_COMPUTER_GLORIOUS": false,
	"EP3_CHAIR_SAT": false,
	"EP3_BRIDGE_DONE": false,
	# 3.04 - 3.05: the lift, Giotto's seal
	"EP3_LIFT_PROCEEDING": false,
	"EP3_D7_ARRIVED": false,
	"EP3_GIOTTO_ORDERED": false,
	"EP3_DECK7_OPEN": true,      # REV 633 (Glen): no seals any more - the ship's open (the flag kept, always true)
	# 3.06 - 3.08: Kyle, the plate, the wiring
	"EP3_KYLE_MET": false,
	"EP3_PLATE_SEEN": false,
	"EP3_PLATE_CUT": false,
	"EP3_SIGNAL_TAUGHT": false,
	"EP3_DOOR_OPEN": false,
	# 3.09: the Matrix
	"EP3_AUX_ENTERED": false,
	"EP3_AUX_TALKED": false,
	"EP3_ZAPPED": false,
	"EP3_MATRIX_DOWN": false,
	"EP3_LOG_SEEN": false,
	"EP3_HELM_BACK": false,
	"EP3_SULU_ANSWERED": false,     # REV 678: Sulu's call answered on the intercom by the Aux Control door
	"EP3_HAS_TOOLKIT": false,
	# 3.10: Deck 6, the first sighting
	"EP3_D6_ARRIVED": false,
	"EP3_D6_SIGHTING": false,
	"EP3_HATCH_CHOICE": false,
	"EP3_LESLIE_2": false,
	"EP3_SPLIT_ASKED": false,
	# 3.11: Kyle's room
	"EP3_TR_SUGGESTED": false,
	"EP3_SCHEDULE_SEEN": false,
	"EP3_SHIELDS_CHECKED": false,
	"EP3_SCHEDULE_REPORTED": false,
	"EP3_MANUAL_SEEN": false,
	"EP3_CARGO_PANEL_SEEN": false,
	# 3.12: Pell's door
	"EP3_PELL_CALL": false,
	"EP3_PELL_MET": false,
	"EP3_KYLE_AT_PELL": false,
	"EP3_INTERVAL_KNOWN": false,
	"EP3_PELL_FREE": false,
	"EP3_LEAD_514": false,
	# 3.13: the lounge, the listener, the message
	"EP3_UHURA_JUNCTION": false,
	"EP3_D5_ARRIVED": false,
	"EP3_LOUNGE_SEEN": false,
	"EP3_CUPS_SEEN": false,
	"EP3_LOUNGE_TRAP": false,
	"EP3_JUMPER_ON": false,
	"EP3_LISTENER_OFF": false,
	"EP3_LISTENER_HEARD": false,
	"EP3_COMMS_BACK": false,
	"EP3_MESSAGE_SENT": false,
	"EP3_LISTENER_BAGGED": false,
	# 3.14 - 3.15: the living ship, the optional extras
	"EP3_CALL_DESALLE": false,
	"EP3_CALL_CHAPEL": false,
	"EP3_CALL_GIOTTO": false,
	"EP3_CALL_SULU": false,
	"EP3_SMOKEY_ASKED": false,
	"EP3_SANDWICH": false,
	"EP3_SANDWICH_GONE": false,
	"EP3_CARD_SCOTTY": false,
	"EP3_CALL_ROMAINE": false,
	# 3.20 - 3.21: the core, the evidence locker
	"EP3_CORE_ARRIVED": false,
	"EP3_LESLIE_3": false,
	"EP3_TRIBBLE": false,
	"EP3_ROMAINE_MET": false,
	"EP3_NEED_ISOLATOR": false,
	"EP3_SEC_ARRIVED": false,
	"EP3_PRINTER_JAMMED": false,
	"EP3_LIVE_1": false,
	"EP3_FORM_IDEA": false,
	"EP3_HAS_FORM": false,
	"EP3_FORM_FILED": false,
	"EP3_HAS_ISOLATOR": false,
	# 3.22: the forensics
	"EP3_BANK_RECORDS": false,
	"EP3_BANK_SENSORS": false,
	"EP3_ROMAINE_BEAT": false,
	"EP3_SWEEP_STARTED": false,
	"EP3_TRAP_REWIRED": false,
	"EP3_FINDINGS": false,
	# 3.23 - 3.26: the audio log, Engineering, Fizzbin, the injectors
	"EP3_AUDIO_LOG": false,
	"EP3_LIVE_2": false,
	"EP3_ENG_ARRIVED": false,
	"EP3_NEED_SPANNER": false,
	"EP3_FIZZBIN_DEALT": false,
	"EP3_LIVE_3": false,
	"EP3_FIZZBIN_WON": false,
	"EP3_HAS_SPANNER": false,
	"EP3_LIVE_4": false,
	"EP3_ENGINES_STABLE": false,
	# 3.27 - 3.28: Vulcan's reply, the bay
	"EP3_REPLY_CALL": false,
	"EP3_VULCAN_REPLY": false,
	"EP3_LESLIE_4": false,
	"EP3_TRIBBLE_HOME": false,
	"EP3_BAY_CALL": false,
	"EP3_BAY_SURROUNDED": false,
	"EP3_VAREL_TALKED": false,
	"EP3_SLOWING": false,
	# 3.30 - 3.31: the drop out of warp, the empty bay
	"EP3_DROPPED_OUT": false,
	"EP3_NAV_BACK": false,
	"EP3_DEFLECTOR": false,
	"EP3_ASTEROIDS_CLEAR": false,
	"EP3_CORE_DOWN": false,
	"EP3_NO_PLANET": false,
	"EP3_BAY_CUT": false,
	"EP3_BAY_EMPTY": false,
	"EP3_PLATFORM_SEEN": false,
	"EP3_CONTROLS_SEEN": false,
	# 3.32 - 3.34: the shield blip, the colony, the buffer
	"EP3_CYCLE_RAN": false,
	"EP3_SHIELD_BLIP": false,
	"EP3_KYLE_HAS_ISOLATOR": false,
	"EP3_COLONY_POWER": false,
	"EP3_COLONY_STRUCTURES": false,
	"EP3_COLONY_FOUND": false,
	"EP3_BUFFER_TRIED": false,
	"EP3_SHIELDED_TRICORDER": false,
	"EP3_BUFFER_READ": false,
	"EP3_KNOW_COLONY": false,
	# 3.35: the finale
	"EP3_AWAY_CALLED": false,
	"EP3_TRANSPORTER_DEAD": false,
	"EP3_COMPLETE": false,
}

## The tracker (big goals only, never a discovery). The MAIN line is always CAPTURE ROMULAN INTRUDERS;
## the side mission sits under it as a checklist (refresh_tracker), with a step-goal line where the script
## has one (GET THE ROMULAN ISOLATOR, THE ENGINES).
const OBJECTIVES := {
	"CAPTURE": "CAPTURE ROMULAN INTRUDERS",
}
const LOG_OBJECTIVE_ENTRY := "LOG_EP3_000"
const CASE_TITLE := "CHIEF ENGINEER'S LOG - SCOTT"
const COMPARE_RULES: Array = []
## The redesign (no Case File, in any form - Tiffany: "Burn the bloody thing.").
const CASE_FILE := false

## The side mission, system by system: [label, done flag].
const CONTROL := [
	["HELM", "EP3_HELM_BACK"],
	["COMMUNICATIONS", "EP3_COMMS_BACK"],
	["DOORS", "EP3_TRAP_REWIRED"],
	["RECORDS", "EP3_BANK_RECORDS"],
	["INTERNAL SENSORS", "EP3_BANK_SENSORS"],
	["ENGINES", "EP3_ENGINES_STABLE"],
	["NAVIGATION", "EP3_NAV_BACK"],
]


static func ensure_state() -> void:
	GameState.register_defaults(DEFAULTS)
	Case.register_defaults()
	Case.title_text = CASE_TITLE
	_register_objectives()
	AudioSubtitleManager.speech_root = SPEECH_ROOT
	EquipmentManager.setup_episode_equipment()


## Wipes everything and starts the episode fresh (the Chapters menu, the Episode 2 end card). carry_over =
## true keeps the story so far (the Prologue's, Episode 1's and Episode 2's flags and the crew) - Episode 3
## reads VAR_PRO_OPTIONAL_BOWLING_VICTORY and the VAR_EP2_* choices.
static func new_game(carry_over: bool = false) -> void:
	var kept := {}
	var kept_crew := {}
	if carry_over:
		var snap: Dictionary = GameState.get_snapshot()
		for key in snap.keys():
			var k := String(key)
			if k.begins_with("EP1_") or k.begins_with("EP2_") or k.begins_with("PRO_") or k.begins_with("VAR_"):
				kept[k] = snap[key]
		var world: Variant = snap.get(WorldState.VAR, {})
		if world is Dictionary:
			for wk in (world as Dictionary).keys():
				if String(wk).begins_with("crew/"):
					kept_crew[wk] = (world as Dictionary)[wk]
	Case.clear_definitions()
	GameState.reset_to_defaults(DEFAULTS)
	for k in kept.keys():
		GameState.set_var(k, kept[k])
	if not kept_crew.is_empty():
		GameState.set_var(WorldState.VAR, kept_crew)
	InventoryManager.clear()
	MissionLog.reset()
	ObjectiveManager.reset()
	Case.title_text = CASE_TITLE
	Case.register_defaults()
	GameState.set_var("EP3_STARTED", true)
	_tracker_last = ""
	# CODE NOTES: Episode 2's choices that Episode 3 reads. Started without Episode 2 (chapter select, scene
	# select): Giotto's cut false, the rest false.
	for v in ["VAR_EP2_VAREL_CREDENTIALS", "VAR_EP2_MCCOY_THANKED", "VAR_EP2_CHAPEL_THANKED", "VAR_EP2_KOVEK_THANKED",
			"VAR_EP2_SCOTTY_GIOTTO_CUT", "VAR_PRO_OPTIONAL_BOWLING_VICTORY"]:
		if not GameState.has_var(v):
			GameState.set_var(v, false)
	# Episode 3's own carried-out choices (read by Episode 4)
	for v in ["VAR_EP3_SMOKEY_FED", "VAR_EP3_CHEKOV_PRAISED"]:
		GameState.set_var(v, false)
	for v in ["VAR_EP3_GIOTTO_SPLIT", "VAR_EP3_MATRIX_WAY", "VAR_EP3_VAREL_LAST"]:
		GameState.set_var(v, "")
	GameState.set_var("VAR_EP3_CARDS", [])


static func _register_objectives() -> void:
	if MissionLog.get_entry(LOG_OBJECTIVE_ENTRY) == null:
		var entry := MissionLogEntryData.new()
		entry.id = LOG_OBJECTIVE_ENTRY
		entry.title = EPISODE_TITLE
		entry.current_text = String(OBJECTIVES["CAPTURE"])
		MissionLog.register_entry(entry)
	for id in OBJECTIVES.keys():
		var obj := ObjectiveData.new()
		obj.id = "OBJ_EP3_" + String(id)
		obj.text = String(OBJECTIVES[id])
		obj.mission_log_entry_id = LOG_OBJECTIVE_ENTRY
		ObjectiveManager.register_objective(obj)


static func set_objective(key: String) -> void:
	if not OBJECTIVES.has(key):
		push_warning("Ep3: unknown objective '%s'" % key)
		return
	ObjectiveManager.set_current_objective("OBJ_EP3_" + key)


## The voice file name for a line: SCOTTY_EP3_1A2B3C.mp3 (stable as long as the words don't change).
static func line_id(who: String, text: String) -> String:
	var folder: String = String(SPEAKERS.get(who, [who, who])[0])
	return folder.to_upper() + "_EP3_" + text.md5_text().substr(0, 6).to_upper()


static func flag(name: String) -> bool:
	return GameState.has_var(name) and bool(GameState.get_var(name))


static func set_flag(name: String, value: bool = true) -> void:
	GameState.set_var(name, value)


static func value(name: String, default: Variant = null) -> Variant:
	return GameState.get_var(name) if GameState.has_var(name) else default


static func set_value(name: String, v: Variant) -> void:
	GameState.set_var(name, v)


## Which rooms the old travel menu offers (Episode 3 moves by lift and doors).
static func unlocked_rooms() -> Array:
	return []


## The ship's key (ShipDecks) for one of Episode 3's rooms - the minimap's "Deck N", the lift's YOU ARE HERE.
const SHIP_KEYS := {"auxcontrol": "ae_deck8_aux", "core": "ae_deck7", "security": "ae_deck7", "cargobay": "ae_deck7", "lab": "ae_deck7",
	"messhall": "e_quarters", "tube": "e_quarters"}


static func ship_key(room_key: String) -> String:
	if SHIP_KEYS.has(room_key):
		return String(SHIP_KEYS[room_key])
	for k in LIFT_ROOMS.keys():
		if String(LIFT_ROOMS[k]) == room_key:
			return String(k)
	return room_key


## Arriving in a map room at a point given in the map file's metres (glb x, z), facing a glb direction -
## e.g. stepping out of a grey-box room back into the Deck 7 corridor at its door. (MapRoom reads it.)
static func arrive_on_map(_room_key: String, glb: Vector3, face_glb: Vector2 = Vector2.ZERO) -> void:
	ShipDecks.arrive_spot_on = true
	ShipDecks.arrive_spot = Vector2(glb.x / 0.03, -glb.z / 0.03)
	ShipDecks.arrive_face = Vector2(face_glb.x, -face_glb.y).normalized() if face_glb != Vector2.ZERO else Vector2.ZERO


## The turbolift picked a ship room (a ShipDecks key): Episode 3's room for it.
static func lift_room(ship_key: String) -> String:
	return String(LIFT_ROOMS.get(ship_key, ship_key))


# ---- the two missions on the tracker ---------------------------------------------------------------

static var _tracker_last := ""

## Called by EpisodeRoom on arrival, on load and after every scene: the main line, and the side mission's
## checklist under it (only re-sent when it changes - every change makes the tracker peek).
static func refresh_tracker() -> void:
	if not flag("EP3_BRIDGE_ARRIVED"):
		return
	if not ObjectiveManager.is_current("OBJ_EP3_CAPTURE"):
		set_objective("CAPTURE")
	var items: Array = []
	if flag("EP3_BRIDGE_DONE") or flag("EP3_THRUSTERS_ORDERED") or flag("EP3_BRIDGE_ARRIVED"):
		var done := 0
		for c in CONTROL:
			if flag(String(c[1])):
				done += 1
		items.append(["REGAIN CONTROL OF THE ENTERPRISE  %d/%d" % [done, CONTROL.size()], done == CONTROL.size()])
		var won: Array = []
		for c in CONTROL:
			if flag(String(c[1])):
				won.append(String(c[0]))
		if not won.is_empty() and done < CONTROL.size():
			items.append(["  BACK: " + ", ".join(won), true])
		var step := current_step()
		if step != "":
			items.append([step, false])
	var key := str(items)
	if key == _tracker_last:
		return
	_tracker_last = key
	var tree := Engine.get_main_loop() as SceneTree
	var hud: Node = tree.get_first_node_in_group("hud") if tree != null else null
	if hud != null and hud.has_method("tracker_checklist"):
		hud.call("tracker_checklist", items)


## A step-goal under the side mission, where the script gives one (TRACKER (side) lines).
static func current_step() -> String:
	if flag("EP3_NEED_ISOLATOR") and not flag("EP3_HAS_ISOLATOR"):
		return "GET THE ROMULAN ISOLATOR"
	if flag("EP3_AUDIO_LOG") and not flag("EP3_ENGINES_STABLE"):
		return "THE ENGINES"
	return ""


# ---- what each lead carries (the backpack mirrors the story flags, as Episode 2) -------------------
## id -> [have flag, gone flag ("" = never), name, description, owner ("scotty" / "kyle")]
const ITEMS := {
	"EP3_ITEM_TOOLKIT": ["EP3_HAS_TOOLKIT", "EP3_PELL_FREE", "Kyle's Toolkit",
		"Kyle's tools, rolled up in their cloth. Every one of them has already failed to open a door today.", "kyle"],
	"EP3_ITEM_INTERVAL": ["EP3_INTERVAL_KNOWN", "EP3_BUFFER_READ", "Trap Interval",
		"Ninety seconds, to the second. Every one of their tricks runs on the same clock.", "kyle"],
	"EP3_ITEM_LISTENER": ["EP3_LISTENER_OFF", "EP3_LISTENER_BAGGED", "Romulan Listener",
		"A small dark Romulan device the size of a thumb. It was eating Uhura's calls. Evidence - Mister Giotto likes evidence.", "scotty"],
	"EP3_ITEM_LISTENER_B": ["EP3_LISTENER_BACK", "", "Romulan Listener",
		"The Romulan listener, back from Giotto's locker. Dead as a doornail. Good. A souvenir now.", "scotty"],
	"EP3_ITEM_SANDWICH": ["EP3_SANDWICH", "EP3_SANDWICH_GONE", "Half a Sandwich",
		"Pastrami. Offered by a crewman who hasn't noticed the ship's been hijacked.", "scotty"],
	"EP3_ITEM_FORM": ["EP3_HAS_FORM", "EP3_FORM_GIVEN", "Blank Requisition Card",
		"A blank requisition card from the back of Kyle's transporter manual case. Unclipped carefully.", "kyle"],
	"EP3_ITEM_FORM_S": ["EP3_FORM_TO_SCOTTY", "EP3_FORM_FILED", "Blank Requisition Card",
		"Kyle's blank requisition card, from the back of his transporter manual case. It's for transporter maintenance. Close enough.", "scotty"],
	"EP3_ITEM_ISOLATOR": ["EP3_HAS_ISOLATOR", "EP3_KYLE_HAS_ISOLATOR", "The Isolator",
		"Kovek's modified field isolator. Slim, odd, beautifully made. Their own tool - and now it's ours.", "scotty"],
	"EP3_ITEM_ISOLATOR_K": ["EP3_KYLE_HAS_ISOLATOR", "EP3_SHIELDED_TRICORDER", "The Isolator",
		"Kovek's modified field isolator, sent down by Mister Scott. 'Don't touch anything that zaps.'", "kyle"],
	"EP3_ITEM_TRIBBLE": ["EP3_TRIBBLE", "EP3_TRIBBLE_HOME", "Tribble",
		"Uhura's. She promised there was only one. It's purring at you.", "scotty"],
	"EP3_ITEM_SPANNER": ["EP3_HAS_SPANNER", "EP3_ENGINES_STABLE", "Hyperspanner",
		"The last hyperspanner aboard. Won at Fizzbin with a royal fizzbin, which is a thing now.", "scotty"],
	"EP3_ITEM_TIMESTAMP": ["EP3_SHIELD_BLIP", "EP3_BUFFER_READ", "Shield-Blip Timestamp",
		"SHIELDS 0% - 3.1 SECONDS - the second she dropped out of warp. Nobody noticed. Everybody was looking at rocks.", "kyle"],
	"EP3_ITEM_SHIELDED": ["EP3_SHIELDED_TRICORDER", "", "Shielded Tricorder",
		"Kyle's tricorder with the Romulan isolator clipped to its back. Same size. As if it was made to fit.", "kyle"],
	"EP3_ITEM_PATTERNS": ["EP3_BUFFER_READ", "", "Three Patterns",
		"The cargo transporter's buffer, read without wiping it: three unauthorised transports, in the three seconds the shields were down.", "kyle"],
}


static func _item(id: String) -> InventoryItemData:
	var it := InventoryManager.find_known_item(id)
	if it != null:
		return it
	it = InventoryItemData.new()
	it.id = id
	it.display_name = String(ITEMS[id][2])
	it.description = String(ITEMS[id][3])
	it.examine_text = it.description
	InventoryManager.register_item(it)
	return it


## Who is being played as a person ("scotty" / "kyle").
static func played() -> String:
	return String(value("EP3_ACTIVE_LEAD", "scotty"))


static func sync_items() -> void:
	var who := played()
	for id in ITEMS.keys():
		var row: Array = ITEMS[id]
		var want := flag(String(row[0])) and (String(row[1]) == "" or not flag(String(row[1]))) and String(row[4]) == who
		var have := InventoryManager.has_item(String(id))
		if want and not have:
			InventoryManager.add_item(_item(String(id)), true)
		elif have and not want:
			InventoryManager.remove_item(String(id))


## One backpack thing used on another (or on the kit). True when it was answered.
static func combine_items(room: EpisodeRoom, a: String, b: String) -> bool:
	var pair := [a, b]
	var tric := a.contains("TRICORDER") or b.contains("TRICORDER")
	# 3.34 - ISOLATOR + TRICORDER = SHIELDED TRICORDER ("...Huh. Same size.")
	if pair.has("EP3_ITEM_ISOLATOR_K") and tric:
		await make_shielded(room)
		return true
	if pair.has("EP3_ITEM_ISOLATOR") and tric:
		await room.say("scotty", "Not yet, laddie. I've banks to cut with it first.")
		return true
	if pair.has("EP3_ITEM_TRIBBLE"):
		await room.say(room.lead(room.current), "It's purring at that as well." if played() == "scotty" else "...It likes everything, sir.")
		return true
	if pair.has("EP3_ITEM_SANDWICH"):
		await room.say("scotty", "It's a sandwich. It doesn't go with anything.")
		return true
	if pair.has("EP3_ITEM_INTERVAL") or pair.has("EP3_ITEM_TIMESTAMP"):
		await room.say("kyle", "That's in my head, sir. I need something to read it into.")
		return true
	return false


## The 3.34 combine, from the backpack or from the buffer itself.
static func make_shielded(room: EpisodeRoom) -> void:
	if flag("EP3_SHIELDED_TRICORDER"):
		return
	await room.note("ISOLATOR + TRICORDER  ->  SHIELDED TRICORDER", 2.4)
	set_flag("EP3_SHIELDED_TRICORDER")
	sync_items()
	await room.say("kyle", "...Huh. Same size.")


## REV 597: something used on the other lead, in any room (EpisodeRoom.partner_item). Always answers.
static func partner_item(room: EpisodeRoom, source: String) -> bool:
	var me := played()
	if me == "kyle" and source == "EP3_ITEM_FORM":
		set_flag("EP3_FORM_GIVEN")
		set_flag("EP3_FORM_TO_SCOTTY")
		sync_items()
		await room.say("kyle", "Your form, sir.")
		await room.say("scotty", "Good lad.")
		return true
	if me == "scotty" and source == "EP3_ITEM_ISOLATOR" and flag("EP3_SHIELD_BLIP") and not flag("EP3_KYLE_HAS_ISOLATOR"):
		set_flag("EP3_KYLE_HAS_ISOLATOR")
		sync_items()
		await room.say("scotty", "Take it - and don't touch anything that zaps.")
		return true
	if source == "EP3_ITEM_SANDWICH":
		await room.say("kyle", "I've eaten, sir. Thank you.")
		return true
	if source == "EP3_ITEM_TRIBBLE":
		await room.say("kyle", "...It's purring at me, sir.")
		return true
	if me == "scotty":
		await room.say("kyle", "I'd better not, sir. You'll want that.")
	else:
		await room.say("scotty", "Keep it, laddie. Ye found it.")
	return true


# ---- THE PARTNER - "Think, Montgomery." (EPISODE3_SCRIPT.md) ---------------------------------------
## who = the speaker (Kyle for Scotty, Scotty for Kyle, Romaine in the core, DeSalle in Engineering, the lead
## himself when alone). Line 1 nudges, 2 points, 3 says it plainly; the same lines play unasked when the
## player has been stuck a couple of minutes (EpisodeRoom.partner_hint).
## REV 714 (Glen's 29 Oct list, item 3: "the Mission Log always shows a CURRENT OBJECTIVE - the goal, never the method;
## broad where there are several solutions"): what the player is after at each partner-hint stage (partner_stage), shown
## at the top of the Mission Log (MissionLogUI, from EpisodeRoom.current_goal). Keep one for every PARTNER stage.
const GOALS := {
	"helm": "Find out where the Enterprise is being steered from - Auxiliary Control, Deck 15.",
	"go_aux": "Get to Auxiliary Control on Deck 15.",
	"door": "Get into Auxiliary Control - its door on Deck 15 won't open, and the lock circuits are behind a welded bulkhead plate beside it.",
	"wiring": "Get Auxiliary Control's door open - the lock circuits are exposed behind the plate you cut.",
	"matrix": "Deactivate the Romulan device on Auxiliary Control's curved console - it's behind a force field.",
	"console": "Get the helm back - Auxiliary Control's console under the status screens.",
	"intercom": "The bridge is calling Auxiliary Control - answer the intercom by the door.",
	"sighting": "Meet Lieutenant Commander Giotto at Jefferies Tube 6-A - the far end of Deck 6's long corridor. Turbolift to Deck 6.",
	"kyle_room": "Find out what was done in Transporter Room One.",
	"kyle_room_s": "Kyle is checking Transporter Room One.",
	"report_schedule": "Tell Mister Scott about the maintenance cycle on Kyle's schedule - use the communicator in Kyle's backpack.",
	"back_to_scotty": "Kyle is keeping an eye on the schedule - back to Mister Scott.",
	"pell_due": "Carry on the search with Lieutenant Commander Giotto - security will call.",
	"pell": "Get Yeoman Pell out of his cabin on Deck 6 - the door keeps locking itself every ninety seconds. It takes two: call Kyle on the communicator.",
	"lounge": "Find out who used Terminal 5-14 in the Officers' Lounge, Deck 5.",
	"listener": "Find what's listening in on the comms relay outside the Officers' Lounge, Deck 5 - and take it off the line.",
	"message": "Get a message to Vulcan - Lieutenant Uhura can send it.",
	"wait_romaine": "Find out what the Romulans left in the ship's computer - the computer core on Deck 7, beside Engineering.",
	"isolator": "Find a way to cut into the computer without it noticing - the Romulans' own isolator is in Giotto's evidence locker, Deck 7 security office.",
	"form": "Get Lieutenant Commander Giotto to release the Romulan isolator from his evidence locker - he wants it signed for.",
	"forensics": "Find the Romulans' memory banks in the computer core (Deck 7) - and cut them out with the isolator.",
	"trap": "Turn the Romulans' door trap against them - computer core, Deck 7.",
	"audio_log": "Hear the recording on the Recording Log screen in Auxiliary Control, Deck 15.",
	"spanner": "Find a hyperspanner - the engineers in Jefferies Tube 5-B on Deck 5 have one.",
	"to_engineering": "The engines are past their limits - get to Engineering on Deck 7.",
	"fizzbin": "Win the hyperspanner from the two engineers playing cards in Jefferies Tube 5-B, Deck 5.",
	"injectors": "Stabilise the engines - the injector gauges in Engineering, Deck 7.",
	"reply": "Vulcan has answered - go to the bridge (turbolift, Deck 1).",
	"bay": "The intruders are trapped in Cargo Bay 2 on Deck 7.",
	"to_bay": "Get to Cargo Bay 2 on Deck 7.",
	"to_bridge": "The ship is slowing - get to the bridge (turbolift, Deck 1).",
	"drop": "Bring the Enterprise safely out of warp - from the bridge.",
	"cut_bay": "Get into Cargo Bay 2 on Deck 7 - its door is sealed.",
	"empty_bay": "Find out where the intruders went - Kyle can check the transporters.",
	"blip": "Find out what the cargo transporter is still holding - Kyle will need the isolator from Mister Scott.",
	"buffer": "Read the cargo transporter's buffer without wiping it.",
	"finale": "Bring the Romulans back aboard.",
}

## REV 741 (Glen's bug list item 6): where each stage's goal is, for the map's objective marker - hotspot id(s);
## when none is in the room you're in, the marker shows the nearest turbolift (EpisodeRoom.objective_target).
const MARKERS := {
	"helm": "EP3_AX_AUX", "go_aux": "EP3_AX_AUX", "door": "EP3_AX_PLATE", "wiring": "EP3_AX_PLATE",
	"matrix": "EP3_A_MATRIX", "console": "EP3_A_CONSOLE", "intercom": "EP3_A_INTERCOM",
	"sighting": "EP3_D6_HATCH", "kyle_room": "EP3_TR_CONSOLE", "kyle_room_s": "", "report_schedule": "", "back_to_scotty": "", "pell_due": "",
	"pell": ["EP3_D6_PELL_PANEL", "EP3_D6_PELL_DOOR"], "lounge": "EP3_D5_TERMINAL", "listener": "EP3_D5_JUNCTION",
	"message": "EP3_BR_CHAIR", "wait_romaine": "EP3_CC_CONSOLE", "isolator": "EP3_SO_LOCKER",
	"form": ["EP3_TR_MANUAL", "EP3_SO_LOCKER"], "forensics": "EP3_CC_CONSOLE", "trap": "EP3_CC_CONSOLE",
	"audio_log": "EP3_A_LOG", "spanner": "EP3_D5_TUBE_5B", "to_engineering": "EP3_EN_CONSOLE",
	"fizzbin": ["EP3_TB_SPANNER", "EP3_D5_TUBE_5B"], "injectors": "EP3_EN_ASSEMBLY", "reply": "EP3_BR_CHAIR",
	"bay": "EP3_D7_BAY_COMM", "to_bay": "EP3_D7_BAY_PANEL", "to_bridge": "EP3_BR_CHAIR", "drop": "EP3_BR_CHAIR",
	"cut_bay": ["EP3_D7_BAY_PANEL", "EP3_D7_BAY_HOUSING"], "empty_bay": "EP3_TR_CONSOLE", "blip": "EP3_CB_BUFFER", "buffer": "EP3_CB_BUFFER",
	"finale": "EP3_TR_CONSOLE",
}

const PARTNER := {
	"helm": {"who": "sulu", "lines": ["Auxiliary Control, sir. Deck Fifteen.", "The turbolift's behind you.", "Take the turbolift to Deck Fifteen."]},
	"go_aux": {"who": "scotty", "lines": ["Auxiliary Control. That's where she's being driven from.", "Deck Fifteen.", "The turbolift - Deck Fifteen, Auxiliary Control."]},
	"door": {"who": "kyle", "lines": ["The circuits are behind that plate, sir.", "It's welded. We'll have to cut it.", "Use your phaser on the bulkhead plate - a narrow cut."]},
	"wiring": {"who": "kyle", "lines": ["Those circuits are open now, sir.", "Your tricorder - it can answer the lock's signal.", "Use your tricorder on the open circuits."]},
	"matrix": {"who": "kyle", "lines": ["We can't reach it through that field, sir.", "You've a phaser on your belt, sir.",
		"Use your phaser on the device - on full."]},
	"console": {"who": "kyle", "lines": ["The console's coming back, sir.", "The one under the status screens, sir.", "Use the console under the status screens."]},
	"intercom": {"who": "kyle", "lines": ["That's the bridge calling, sir.", "The intercom by the door, sir.", "Answer the intercom by the door."]},
	"sighting": {"who": "scotty", "lines": ["Giotto's waiting on Deck Six.", "Jefferies tube Six-A - the end of the long corridor.", "Turbolift to Deck Six, then the Jefferies tube hatch at the end of the corridor."]},
	"kyle_room_s": {"who": "scotty", "lines": ["Kyle's seeing to his transporter room.", "That's Kyle's end of it now.", "Over to Kyle - he's checking his transporter console."]},
	"kyle_room": {"who": "scotty", "lines": ["Is your room still yours, laddie?", "Check your console.", "Look at the system schedule on your transporter console."]},
	"report_schedule": {"who": "scotty", "lines": ["Anything in your room, laddie?", "Tell me what ye found.", "Call me on your communicator - it's in your backpack."]},
	"back_to_scotty": {"who": "scotty", "lines": ["Keep an eye on it, laddie.", "I'll take it from here.", "Over to me, laddie."]},
	"pell_due": {"who": "kyle", "lines": ["I'm watching that schedule, sir.", "Mister Giotto's still searching.", "Security will call, sir."]},
	"pell": {"who": "kyle", "lines": ["It locks before ye get there.", "One of us at the panel, one at the door.", "I'll hold the panel when it goes green, sir. You hold the door."]},
	"lounge": {"who": "kyle", "lines": ["Terminal five-fourteen, sir. The officers' lounge.", "Deck Five.", "Take the lift to Deck Five and look at the lounge terminal."]},
	"listener": {"who": "kyle", "lines": ["Something's sitting on the line.", "Keep the line closed while it comes off.", "Use your communicator on the relay line, then take the listener."]},
	"message": {"who": "uhura", "lines": ["I can reach Vulcan now, sir.", "Tell me what to say.", "Talk to me and send the message."]},
	"wait_romaine": {"who": "kyle", "lines": ["The ship's still full of their leftovers, sir.", "Somebody in the computer core might know more.", "Take the lift to the computer core - Deck Seven, by engineering."]},
	"isolator": {"who": "romaine", "lines": ["We need to cut without her noticing.", "Mister Giotto bagged a Romulan tool.", "Get the isolator from Giotto's evidence locker."]},
	"form": {"who": "kyle", "lines": ["He wants a form.", "The dispenser's useless. I keep spares, sir.", "Switch to me, sir - there's a blank requisition card in the back of my transporter manual. Give it to Mister Giotto."]},
	"forensics": {"who": "romaine", "lines": ["Listen to how it answers ye.", "The banks that call ye 'glorious' are theirs.",
		"Use the isolator on banks four and five - on five, cut only the strands with something on them."]},
	"trap": {"who": "romaine", "lines": ["The doors still answer to them.", "One word in that rule does all the work.", "Bank two, Montgomery. Change the rule so it locks the intruders in."]},
	"audio_log": {"who": "romaine", "lines": ["There's a recording in Auxiliary Control.", "It was sealed. It isn't now.", "Play the internal log in Auxiliary Control."]},
	"spanner": {"who": "desalle", "lines": ["Ye need the hyperspanner.", "The card players have it.", "Find the two engineers in Jefferies tube Five-B, by the officers' lounge."]},
	"to_engineering": {"who": "kyle", "lines": ["'Past her limits.' Your engines, sir.", "Engineering.", "Take the lift to Engineering on Deck Seven."]},
	"fizzbin": {"who": "scotty", "lines": ["They want a stake.", "Something to eat, maybe - or just your good word.",
		"Give them the sandwich, or stake your good opinion - then play the most confident call each round."]},
	"injectors": {"who": "desalle", "lines": ["All three in the green, sir - and hold them.", "I'll call number three. Small turns.",
		"Bring gauges one and two into the green, listen for me on three, and hold for five."]},
	"reply": {"who": "uhura", "lines": ["Vulcan's answered, sir.", "Up here, on the bridge.", "Come to the bridge and talk to me."]},
	"bay": {"who": "kyle", "lines": ["They're in the bay, sir. They can't get out.", "Mister Giotto's got the door.", "Talk to them if you like, sir. They're not going anywhere."]},
	"to_bay": {"who": "kyle", "lines": ["Cargo Bay Two, sir.", "Deck Seven.", "Take the lift to Deck Seven and go to Cargo Bay Two."]},
	"to_bridge": {"who": "kyle", "lines": ["She's slowing, sir!", "The bridge.", "Take the lift to the bridge."]},
	"drop": {"who": "chekov", "lines": ["I cannot see the rocks, sir.", "The deflector - a wide sweep?", "Tell me to switch the navigational deflector to a wide sweep, sir."]},
	"cut_bay": {"who": "scotty", "lines": ["It's welded from in there.", "I've done this before today - or there's the quiet way.",
		"Use your phaser on the cargo bay door - a narrow cut. Or quietly: Kyle holds the door's power feed out while Scotty opens the lock clamps, lower first."]},
	"empty_bay": {"who": "kyle", "lines": ["Sir... I want to check something in my room.", "Let me look at the logs, sir.", "Switch to me, sir - Transporter Room One."]},
	"blip": {"who": "kyle", "lines": ["The shields dropped when they were cornered.", "The cargo transporter's buffer might still hold something - if I can read it without wiping it.",
		"Get the isolator from Mister Scott and take it to the cargo transporter."]},
	"buffer": {"who": "kyle", "lines": ["Hold it still before I read it.", "The fakes are on their ninety-second clock. The real ones are when the shields dropped.",
		"Isolator plus tricorder; clear the entries on the ninety-second clock; dial to the shield drop and read the three."]},
	"finale": {"who": "sulu", "lines": ["Ready when you are, Mister Kyle.", "The levers.", "Energize, Mister Kyle."]},
}


## What the played lead says first when he asks (not when the hint plays unasked).
static func partner_ask(speaker: String, lead_played: String) -> String:
	if lead_played == "scotty" and speaker == "kyle":
		return "Talk to me, Mister Kyle."
	if lead_played == "kyle" and speaker == "scotty":
		return "Mister Scott?"
	if lead_played == "scotty" and speaker == "romaine":
		return "Lieutenant?"
	if lead_played == "scotty" and speaker == "desalle":
		return "Well, laddie?"
	return ""


static func partner_name(_speaker: String, _played: String) -> String:
	return ""


## The helper's self-talk opener when alone ("Think, Montgomery.").
static func think_line(lead_played: String) -> String:
	return "Right... think." if lead_played == "scotty" else "Come on... think."


## Where the story is, as a key of PARTNER ("" = nothing to say here).
static func partner_stage(room_key: String) -> String:
	if flag("EP3_COMPLETE"):
		return ""
	# Act One
	if not flag("EP3_BRIDGE_DONE"):
		return "helm" if room_key == "bridge" else ""
	if not flag("EP3_KYLE_MET"):     # REV 633: no seal - on the way to Kyle at the Auxiliary Control door
		# REV 625 (Glen heard Sulu's "take the lift" on Deck 16): Sulu only on the bridge; anywhere else Scotty
		# reminds himself where he's going
		if room_key == "auxdeck":
			return "door"
		return "helm" if room_key == "bridge" else "go_aux"
	if not flag("EP3_PLATE_CUT"):
		return "door"
	if not flag("EP3_DOOR_OPEN"):
		return "wiring"
	if not flag("EP3_MATRIX_DOWN"):
		return "matrix"
	if not flag("EP3_HELM_BACK"):
		return "console"
	if not flag("EP3_SULU_ANSWERED"):     # REV 678: the bridge calling on the intercom by the door
		return "intercom"
	# Act Two
	if not flag("EP3_D6_SIGHTING"):
		return "sighting"
	if not flag("EP3_SCHEDULE_SEEN"):
		# REV 741 (Glen heard Scotty give himself Kyle's hint): this step is Kyle's - played as Scotty, he points
		# himself back at Kyle (the story hands over by itself - Ep3Calls._tr_suggest)
		return "kyle_room" if played() == "kyle" else "kyle_room_s"
	# REV 757 (Glen: after Kyle's report the game left him as Kyle with no goal): until Giotto's call about Pell
	# (a Scotty call), Kyle reports the schedule, then the story hands over to Scotty (_tr_report_schedule)
	if not flag("EP3_PELL_CALL"):
		if played() == "kyle":
			return "report_schedule" if not flag("EP3_SCHEDULE_REPORTED") else "back_to_scotty"
		return "pell_due"
	if flag("EP3_PELL_CALL") and not flag("EP3_PELL_FREE"):
		return "pell"
	if flag("EP3_PELL_FREE") and not flag("EP3_LISTENER_OFF"):
		return "listener" if room_key == "deck5" and flag("EP3_LOUNGE_SEEN") else "lounge"
	if flag("EP3_COMMS_BACK") and not flag("EP3_MESSAGE_SENT"):
		return "message"
	if not flag("EP3_ROMAINE_MET"):
		return "wait_romaine" if flag("EP3_CALL_ROMAINE") else ""
	# Act Three
	if not flag("EP3_HAS_ISOLATOR"):
		if flag("EP3_PRINTER_JAMMED"):
			return "form"
		return "isolator" if room_key == "core" else "form" if room_key == "security" else "isolator"
	if not (flag("EP3_BANK_RECORDS") and flag("EP3_BANK_SENSORS")):
		return "forensics"
	if not flag("EP3_TRAP_REWIRED"):
		return "trap"
	if not flag("EP3_AUDIO_LOG"):
		return "audio_log"
	if not flag("EP3_HAS_SPANNER"):
		if room_key == "engineering":
			return "spanner"
		if room_key == "tube" and flag("EP3_NEED_SPANNER"):
			return "fizzbin"
		return "spanner" if flag("EP3_NEED_SPANNER") else "to_engineering"
	if not flag("EP3_ENGINES_STABLE"):
		return "injectors"
	if not flag("EP3_VULCAN_REPLY"):
		return "reply"
	if not flag("EP3_BAY_SURROUNDED"):
		return "to_bay" if flag("EP3_BAY_CALL") else ""
	# Act Four
	if not flag("EP3_DROPPED_OUT"):
		return "bay" if not flag("EP3_SLOWING") else "to_bridge"
	if not flag("EP3_ASTEROIDS_CLEAR"):
		return "drop"
	if not flag("EP3_BAY_CUT"):
		return "cut_bay" if room_key == "deck7" else "to_bay"
	if not flag("EP3_SHIELD_BLIP"):
		return "empty_bay"
	if not flag("EP3_BUFFER_READ"):
		return "blip" if not flag("EP3_KYLE_HAS_ISOLATOR") else "buffer"
	if not flag("EP3_TRANSPORTER_DEAD"):
		return "finale"
	return ""


# ---- the collector cards (3.15 - this episode INTRODUCES character cards) ---------------------------
## id -> [CollectorCards id, where it is, name on the card]. REV 742: floating cards you walk through
## (EpisodeRoom.float_card) - the collection is the player's, so "has it" asks CollectorCards.
const CARDS := {
	"scotty": ["card_scotty", "his quarters, Deck 6", "Montgomery Scott"],
	"uhura": ["card_uhura", "her quarters, Deck 6", "Nyota Uhura"],
	"sulu": ["card_sulu", "his cabin, Deck 6", "Hikaru Sulu"],
	"chekov": ["card_chekov", "the bridge", "Pavel Chekov"],
	"kyle": ["card_kyle", "his locker, Transporter Room 1", "Lieutenant Kyle"],
	"chapel": ["card_chapel", "Sickbay", "Christine Chapel"],
	"giotto": ["card_giotto", "the evidence locker", "Lieutenant Commander Giotto"],
}


static func has_card(who: String) -> bool:
	return CARDS.has(who) and CollectorCards.is_unlocked(String(CARDS[who][0]))


## Gives a character card outright (debug / old saves - in play the floating cards do it).
static func give_card(who: String) -> bool:
	if has_card(who):
		return false
	var got: Array = (value("VAR_EP3_CARDS", []) as Array).duplicate()
	got.append(who)
	set_value("VAR_EP3_CARDS", got)
	CollectorCards.unlock(String(CARDS[who][0]))
	return true


# ---- USS ENTERPRISE EXPLORED - XX% -------------------------------------------------------------------

static func explored_share() -> int:
	var got: Variant = value("EP3_EXPLORED", [])
	var n := 0
	if got is Array:
		for a in got:
			if EXPLORE.has(String(a)):
				n += 1
	return int(round(100.0 * float(n) / float(EXPLORE.size())))


## Marks an area found; true when it's new (the room shows the line under the minimap).
static func explore(area: String) -> bool:
	if not EXPLORE.has(area):
		return false
	var got: Array = (value("EP3_EXPLORED", []) as Array).duplicate()
	if got.has(area):
		return false
	got.append(area)
	set_value("EP3_EXPLORED", got)
	MissionLog.notification_requested.emit("USS ENTERPRISE EXPLORED - %d%%" % explored_share())
	return true


# ---- REV 288's DEBUG: SCENE SELECT ------------------------------------------------------------------
## label, room, "before" (every yes/no flag listed before it in DEFAULTS is set), "lead" (who is played).
const DEBUG_SCENES := [
	{"label": "3.00 THE OPENING (PREVIOUSLY, TITLES, SCOTTY'S LOG)", "room": "opening"},
	{"label": "3.03 THE BRIDGE - SHE'S NOT ANSWERING", "room": "bridge", "before": "EP3_BRIDGE_ARRIVED"},
	{"label": "3.06 DECK 15 - KYLE AT THE DOOR", "room": "auxdeck", "before": "EP3_KYLE_MET"},
	{"label": "3.09 AUXILIARY CONTROL - THE MATRIX", "room": "auxcontrol", "before": "EP3_AUX_ENTERED"},
	{"label": "3.10 DECK 6 - THE FIRST SIGHTING", "room": "deck6", "before": "EP3_D6_ARRIVED"},
	{"label": "3.11 TRANSPORTER ROOM - THE SCHEDULED CYCLE", "room": "transporter", "before": "EP3_TR_SUGGESTED", "lead": "kirk"},
	{"label": "3.12 DECK 6 - PELL'S DOOR", "room": "deck6", "before": "EP3_PELL_MET"},
	{"label": "3.13 DECK 5 - THE LOUNGE AND THE LISTENER", "room": "deck5", "before": "EP3_D5_ARRIVED"},
	{"label": "3.20 THE COMPUTER CORE - SPOCK ISN'T HERE", "room": "core", "before": "EP3_CORE_ARRIVED"},
	{"label": "3.21 THE SECURITY OFFICE - THE EVIDENCE LOCKER", "room": "security", "before": "EP3_SEC_ARRIVED"},
	{"label": "3.22 THE COMPUTER CORE - THE FORENSICS", "room": "core", "before": "EP3_BANK_RECORDS"},
	{"label": "3.23 AUXILIARY CONTROL - THE AUDIO LOG", "room": "auxcontrol", "before": "EP3_AUDIO_LOG"},
	{"label": "3.24 ENGINEERING - THE MISSING HYPERSPANNER", "room": "engineering", "before": "EP3_LIVE_2"},
	{"label": "3.25 JEFFERIES TUBE 5-B - FIZZBIN", "room": "tube", "before": "EP3_FIZZBIN_DEALT"},
	{"label": "3.26 ENGINEERING - THE INJECTORS", "room": "engineering", "before": "EP3_LIVE_4"},
	{"label": "3.27 THE BRIDGE - VULCAN'S REPLY", "room": "bridge", "before": "EP3_VULCAN_REPLY"},
	{"label": "3.28 DECK 7 - THE BAY SURROUNDED", "room": "deck7", "before": "EP3_BAY_SURROUNDED"},
	{"label": "3.30 THE BRIDGE - THE DROP OUT OF WARP", "room": "bridge", "before": "EP3_DROPPED_OUT"},
	{"label": "3.31 DECK 7 - CARGO BAY TWO", "room": "deck7", "before": "EP3_BAY_CUT"},
	{"label": "3.32 TRANSPORTER ROOM - THE SHIELD BLIP", "room": "transporter", "before": "EP3_CYCLE_RAN", "lead": "kirk"},
	{"label": "3.34 CARGO BAY - THE PATTERN BUFFER", "room": "cargobay", "before": "EP3_SHIELDED_TRICORDER", "lead": "kirk"},
	{"label": "3.35 TRANSPORTER ROOM - THE FINALE", "room": "transporter", "before": "EP3_AWAY_CALLED", "lead": "kirk"},
]


## Sets the story up for DEBUG_SCENES[i] and returns the scene to open.
static func debug_scene(i: int) -> String:
	var s: Dictionary = DEBUG_SCENES[clampi(i, 0, DEBUG_SCENES.size() - 1)]
	new_game()
	if s.has("before"):
		var stop := String(s["before"])
		for key in DEFAULTS.keys():
			var k := String(key)
			if k == stop:
				break
			if typeof(DEFAULTS[key]) == TYPE_BOOL:
				set_flag(k)
		# the scene-select story so far takes the methodical choices
		if flag("EP3_MATRIX_DOWN"):
			set_value("EP3_MATRIX_WAY", "phaser")
			set_value("VAR_EP3_MATRIX_WAY", "phaser")
		if flag("EP3_SPLIT_ASKED"):
			set_value("VAR_EP3_GIOTTO_SPLIT", "hunt")
	if s.has("lead"):
		set_value("EP3_ACTIVE_CHAR", String(s["lead"]))
		set_value("EP3_ACTIVE_LEAD", "kyle" if String(s["lead"]) == "kirk" else "scotty")
	ensure_state()
	set_objective("CAPTURE")
	return String(ROOMS[String(s["room"])][1])


# ---- TWO LEADS, TWO PLACES (Scotty and Kyle are often in different rooms - EpisodeRoom's REV 593 hooks) ----
## Where each lead is: EP3_ROOM_<lead> = room key, EP3_POS_<lead> = [room key, x, y, z, yaw] (where they
## stood when that room was left). Kyle starts at the Auxiliary Control door (3.06).

static var _switch_arrival := false

const LEAD_START := {"scotty": "bridge", "kyle": "auxdeck"}


## REV 672: room keys that are one scene (Deck 15's corridor and Auxiliary Control) - a lead in either is "here".
## REV 700: Deck 7's six (the corridor, the security office, Transporter Room 1, engineering, sickbay, the computer
## core) are one scene too (Deck7.gd).
const ONE_PLACE := {"auxdeck": "deck15", "auxcontrol": "deck15",
	"deck7": "deck7", "security": "deck7", "transporter": "deck7", "engineering": "deck7", "sickbay": "deck7", "core": "deck7"}

static func same_place(a: String, b: String) -> bool:
	return a == b or (ONE_PLACE.has(a) and ONE_PLACE.get(a) == ONE_PLACE.get(b, ""))


static func lead_room(lead: String) -> String:
	return String(value("EP3_ROOM_" + lead, LEAD_START.get(lead, "")))


## The story moves a lead (pos: a world point in that room, or Vector3.INF for the room's own spot for him).
static func place_lead(lead: String, room_key: String, pos: Vector3 = Vector3.INF, yaw: float = 0.0) -> void:
	set_value("EP3_ROOM_" + lead, room_key)
	if pos == Vector3.INF:
		set_value("EP3_POS_" + lead, [])
	else:
		set_value("EP3_POS_" + lead, [room_key, pos.x, pos.y, pos.z, yaw])


static func can_switch(_room: EpisodeRoom) -> bool:
	return flag("EP3_KYLE_MET") and not flag("EP3_COMPLETE")


## The room has just been built (EpisodeRoom._start): who is here, where they stand, what's been found.
static func room_opened(room: EpisodeRoom, from_save: bool) -> void:
	var me_slot := room.current
	var me := room.lead(me_slot)
	set_value("EP3_ACTIVE_LEAD", me)
	set_value("EP3_ROOM_" + me, room.room_key)
	var other_slot := room.other_character()
	var other := room.lead(other_slot)
	# Kyle is on the ship from the start, but only SEEN from 3.05 (the field drops - he's at the door)
	var other_here := same_place(lead_room(other), room.room_key) and (other != "kyle" or flag("EP3_DECK7_OPEN"))
	var body := room.body_of(other_slot)
	# the one being played, arriving by TAB from somewhere else: where he was left standing
	if _switch_arrival and not from_save:
		_place_from_memory(room, me_slot, me)
	_switch_arrival = false
	if other_here:
		body.visible = true
		body.process_mode = Node.PROCESS_MODE_INHERIT
		if not from_save and not _place_from_memory(room, other_slot, other) and room.has_method("lead_spot"):
			var sp: Variant = room.call("lead_spot", other)
			if sp is Array and (sp as Array).size() >= 2:
				room.teleport(other_slot, sp[0], sp[1])
	else:
		body.visible = false
		body.process_mode = Node.PROCESS_MODE_DISABLED
		body.global_position = Vector3(0.0, -60.0, 0.0)
		if room.partner_spot != null:
			room.partner_spot.visible = false
			room.partner_spot.monitorable = false
	explore(room.room_key)
	sync_items()


static func _place_from_memory(room: EpisodeRoom, slot: String, lead: String) -> bool:
	var p: Variant = value("EP3_POS_" + lead, [])
	if p is Array and (p as Array).size() >= 5 and same_place(String(p[0]), room.room_key):
		var at := Vector3(float(p[1]), float(p[2]), float(p[3]))
		# REV 700: a scene that joined rooms together stamps the positions it remembers; one without its stamp was
		# remembered by the old room scene (its own world middle) - the joined scene moves it into its own
		if room.has_method("pos_frame"):
			var stamp := String(p[5]) if (p as Array).size() >= 6 else ""
			if stamp != String(room.call("pos_frame")) and room.has_method("convert_old_pos"):
				at = room.call("convert_old_pos", String(p[0]), at)
		room.teleport(slot, at)
		room.body_of(slot).rotation.y = float(p[4])
		return true
	return false


## The room is being left: where each lead in it stood.
static func room_leaving(room: EpisodeRoom) -> void:
	for slot in ["kirk", "mccoy"]:
		var b := room.body_of(slot)
		if b == null or not b.visible:
			continue
		var lead := room.lead(slot)
		# REV 700: in a scene of several areas (Deck 7) each lead is in the area HE stands in, stamped with its frame
		var where: String = String(room.call("area_of", b)) if room.has_method("area_of") else room.room_key
		var entry: Array = [where, b.global_position.x, b.global_position.y, b.global_position.z, b.rotation.y]
		if room.has_method("pos_frame"):
			entry.append(String(room.call("pos_frame")))
		set_value("EP3_POS_" + lead, entry)
		set_value("EP3_ROOM_" + lead, where)


## REV 741 (Glen: story first - the game does the switching): the story hands play to `lead` at the end of the
## current scene (EpisodeRoom._end_scene asks take_pending_switch).
static var _pending_switch := ""

static func hand_over(room: EpisodeRoom, lead: String) -> void:
	for slot in ["kirk", "mccoy"]:
		if room.lead(slot) == lead:
			_pending_switch = slot
			return


static func take_pending_switch() -> String:
	var s := _pending_switch
	_pending_switch = ""
	return s


## TAB / the portrait: the other lead is somewhere else - go to him (true = handled here).
static func switch_lead(room: EpisodeRoom, slot: String) -> bool:
	if not can_switch(room):
		return true
	var lead := room.lead(slot)
	var where := lead_room(lead)
	if same_place(where, room.room_key) or where == "" or not ROOMS.has(where):
		return false
	if room._busy or room._leaving:
		return true
	if not ResourceLoader.exists(String(ROOMS[where][1])):
		MissionLog.notification_requested.emit("(%s isn't built yet.)" % String(ROOMS[where][0]))
		return true
	set_value("EP3_ACTIVE_CHAR", slot)
	set_value("EP3_ACTIVE_LEAD", lead)
	MissionLog.notification_requested.emit("Now playing: " + room.lead_name(slot))
	_switch_arrival = true
	room.go_to(where)
	return true


static func after_arrival(room: EpisodeRoom) -> void:
	await Ep3Calls.play_due(room, true)


static func after_scene(room: EpisodeRoom) -> void:
	await Ep3Calls.play_due(room, false)


## The communicator's list (rooms put their own calls in front).
static func calls(room: EpisodeRoom) -> Array:
	return Ep3Calls.calls(room)


# ---- optional systems Episode 3 doesn't use ---------------------------------------------------------

static func clock_text() -> String:
	return ""


static func clock_alert() -> String:
	return ""


static func clock_penalty(_minutes: int = 15) -> int:
	return 0


static func pending_deduction() -> String:
	return ""


static func deduction_ready() -> bool:
	return false


static func run_compare(_room: EpisodeRoom, _rule: String) -> bool:
	return false


static func run_deduction(_room: EpisodeRoom) -> void:
	pass


static func deduction_noticed(_key: String) -> bool:
	return false


static func find_compare(_a: String, _b: String) -> String:
	return ""
