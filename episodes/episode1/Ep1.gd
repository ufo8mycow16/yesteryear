extends RefCounted
class_name Ep1
## Ep1 — the facts of Episode 1 ("In Sheep's Clothing") in one place:
## who speaks, what the Case File can contain, what the objectives are, which
## comparisons mean something, and which rooms the player can travel between.
##
## Nothing here runs by itself. The rooms (TuvallOffice.gd, HoldingCell.gd, ...)
## read this. If you want to change a clue's wording or an objective, this is the
## file.

const SPEECH_ROOT := "res://episodes/episode1/audio/speech/"

## who -> [voice folder, name shown in the subtitle]
const SPEAKERS := {
	"mccoy": ["mccoy", "McCoy"],
	"kirk": ["kirk", "Kirk"],
	"spock": ["spock", "Spock"],
	"tuvall": ["tuvall", "Tuvall"],
	"ullus": ["ullus", "Ullus"],
	"guard": ["vulcan_guard", "Vulcan Guard"],
	"officer": ["vulcan_security", "Security Officer"],
	"custodian": ["custodian", "Evidence Custodian"],
	"examiner": ["vulcan_examiner", "Vulcan Examiner"],
	# REV 316 (Glen): three computers, three voices - the Enterprise's on the bridge (Majel Barrett),
	# sickbay's own (a more electronic TOS voice), and Shi'Kahr's public terminal
	"computer": ["computer", "Enterprise Computer (bridge)"],
	"sickbay_computer": ["sickbay_computer", "Sickbay Computer"],
	"vulcan_computer": ["vulcan_computer", "Vulcan Computer"],
	"chapel": ["chapel", "Nurse Chapel"],
	"otari": ["otari", "Otari"],
	"receptionist": ["vulcan_receptionist", "Vulcan Receptionist"],
	"darev": ["darev", "Darev"],
	"council": ["council_leader", "Councillor T'Seva"],
	"uhura": ["uhura", "Uhura"],
	"sulu": ["sulu", "Sulu"],          # REV 365: talkable on the bridge
	"chekov": ["chekov", "Chekov"],
	"kyle": ["kyle", "Lieutenant Kyle"],      # REV 227: the opening, transporter room
	"scott": ["scott", "Lieutenant Commander Scott"],
	"civilian": ["vulcan_civilian", "Vulcan Civilian"],
	# REV 283: the Shi'Kahr streets
	"attendant": ["vulcan_attendant", "Kiosk Attendant"],
	"vendor": ["vulcan_vendor", "Botanical Vendor"],
	"stallkeeper": ["vulcan_stallkeeper", "Stallkeeper"],
	"tellarite_visitor": ["tellarite_visitor", "Tellarite Visitor"],
	"andorian": ["andorian_visitor", "Andorian Visitor"],
	"vulcan_child": ["vulcan_child", "Vulcan Child"],     # REV 499: the streets chain
	"mbenga": ["mbenga", "Dr. M'Benga"],
	"andorian_b": ["andorian_visitor_b", "Andorian Visitor"],
	"romulan_staff": ["romulan_staff", "Romulan Delegation Staff"],
	# REV 856: the city (SHIKAHR_SCRIPT.md)
	"tmir": ["tmir", "T'Mir"],
	"selt": ["selt", "Selt"],
	"sorev": ["sorev", "Sorev"],
	"tvora": ["tvora", "T'Vora"],
	"kuvak": ["kuvak", "Kuvak"],
	"student_a": ["student_a", "Vulcan Student"],
	"student_b": ["student_b", "Vulcan Student"],
	"riley": ["riley", "Lieutenant Riley"],
	"hall_keeper": ["hall_keeper", "Hall Keeper"],
	# REV 860: the delegates' lounge (EPISODE1_SCRIPT.md "THE DELEGATIONS ON THE BRINK", EXPANSION)
	"grath": ["grath", "Grath"],
	"sevek": ["sevek", "Sevek"],
	"shras": ["shras", "Shras"],
	"coridanite": ["coridanite", "Coridanite Delegate"],
	"rigelian": ["rigelian", "Rigelian Observer"],
	"sarek": ["sarek", "Ambassador Sarek"],          # REV 862: SPOCK ON VULCAN
	# REV 864: the Romulan wing, the chase, the market table
	"wing_guard": ["vulcan_wing_guard", "Vulcan Guard"],
	"tlani": ["tlani", "T'Lani"],
	"stall_keeper": ["vulcan_tea_keeper", "Tea Stall Keeper"],
	"family_father": ["vulcan_family_father", "Vulcan Father"],
	"velik": ["velik", "Velik"],                     # REV 865: the desert route
	"komack": ["komack", "Admiral Komack"],          # REV 867: Starfleet calls (TOS: Amok Time)
	"tellarite_aide": ["tellarite_delegate", "Tellarite Aide"],   # REV 867: Ullus' table
}

## room key -> [display name, scene file]
const ROOMS := {
	"streets": ["Shi'Kahr - The Streets", "res://episodes/episode1/scenes/ShiKahrStreets.tscn"],
	"lounge": ["High Council Hall - Delegates' Lounge", "res://episodes/episode1/scenes/CouncilLounge.tscn"],   # REV 860
	"office": ["Tuvall's Office", "res://episodes/episode1/scenes/TuvallOffice.tscn"],
	"cell": ["Holding Cell", "res://episodes/episode1/scenes/HoldingCell.tscn"],
	"evidence": ["Evidence Room", "res://episodes/episode1/scenes/EvidenceRoom.tscn"],
	"morgue": ["Morgue Complex", "res://episodes/episode1/scenes/Morgue.tscn"],
	"quarters": ["Turian's Quarters", "res://episodes/episode1/scenes/TurianQuarters.tscn"],
	"otari": ["Otari's Room", "res://episodes/episode1/scenes/OtariRoom.tscn"],
	"maintenance": ["Maintenance Room", "res://episodes/episode1/scenes/MaintenanceRoom.tscn"],
	"ullus_hall": ["Ullus' Hallway", "res://episodes/episode1/scenes/UllusHallway.tscn"],
	"ullus_room": ["Ullus' Room", "res://episodes/episode1/scenes/UllusRoom.tscn"],
	"table": ["Ullus' Room - Dinner", "res://episodes/episode1/scenes/UllusTable.tscn"],   # REV 867: Ullus' table (optional)
	"serrin_lobby": ["Serrin's Office Building - Lobby", "res://episodes/episode1/scenes/SerrinLobby.tscn"],
	"serrin_office": ["Serrin's Office", "res://episodes/episode1/scenes/SerrinOffice.tscn"],
	"darev_hall": ["Darev's Hallway", "res://episodes/episode1/scenes/DarevHallway.tscn"],
	"darev_room": ["Darev's Room", "res://episodes/episode1/scenes/DarevRoom.tscn"],
	"exterior": ["Exterior Shi'Kahr", "res://episodes/episode1/scenes/ExteriorShiKahr.tscn"],
	"waystation": ["The Desert Waystation", "res://episodes/episode1/scenes/Waystation.tscn"],     # REV 865
	"gallery": ["Ancient Ruins - The Gallery", "res://episodes/episode1/scenes/RuinsGallery.tscn"],     # REV 866
	"desert": ["Vulcan Desert", "res://episodes/episode1/scenes/DesertSearch.tscn"],
	"ruins_ext": ["Ancient Ruins - Exterior", "res://episodes/episode1/scenes/RuinsExterior.tscn"],
	"ruins_int": ["Ancient Ruins - Interior", "res://episodes/episode1/scenes/RuinsInterior.tscn"],
	"sickbay": ["Enterprise - Sickbay", "res://episodes/episode1/scenes/EnterpriseSickbay.tscn"],
	"bridge": ["Enterprise - Bridge", "res://episodes/episode1/scenes/EnterpriseBridge.tscn"],
	"bop": ["Romulan Bird of Prey", "res://episodes/episode1/scenes/BirdOfPrey.tscn"],
	"ae_engineering": ["Enterprise - Engineering", "res://episodes/episode1/scenes/MapRoom_ae_engineering.tscn"],       # REV 308: Deck 7 map
	"ae_engineering_up": ["Enterprise - Engineering (Upper Level)", "res://episodes/episode1/scenes/MapRoom_ae_engineering.tscn"],   # lift menu only (ShipDecks.LIFT_UPPER)
	"ae_transporter": ["Enterprise - Transporter Room", "res://episodes/episode1/scenes/MapRoom_ae_transporter.tscn"],   # REV 308: Deck 7 map
	"e_quarters": ["Enterprise - Crew Quarters", "res://episodes/episode1/scenes/MapRoom_e_quarters.tscn"],
	"turbolift": ["Enterprise - Turbolift", "res://episodes/episode1/scenes/Turbolift.tscn"],
	"ae_deck5": ["Enterprise - Deck 5 Corridors", "res://episodes/episode1/scenes/MapRoom_ae_deck5.tscn"],
	"ae_deck6": ["Enterprise - Deck 6 Corridors", "res://episodes/episode1/scenes/MapRoom_ae_deck6.tscn"],
	"ae_deck7": ["Enterprise - Deck 7 Main Deck", "res://episodes/episode1/scenes/MapRoom_ae_deck7.tscn"],
	"ae_deck8": ["Enterprise - Deck 19 Hangar Deck", "res://episodes/episode1/scenes/MapRoom_ae_deck8.tscn"],
	"ae_deck8_aux": ["Enterprise - Deck 15, Auxiliary Control", "res://episodes/episode1/scenes/MapRoom_ae_deck8.tscn"],   # REV 617: lift menu only (ShipDecks.LIFT_SPOTS)
	"ae_main": ["Enterprise - Deck 20 Recreation (Pool)", "res://episodes/episode1/scenes/MapRoom_ae_main.tscn"],
	"ae_pool": ["Enterprise - Deck 20 Recreation (Pool)", "res://episodes/episode1/scenes/MapRoom_ae_pool.tscn"],
	"ae_alley": ["Enterprise - Deck 21 Bowling Alley", "res://episodes/episode1/scenes/MapRoom_ae_alley.tscn"],
	"ae_engine": ["Enterprise - Garden Deck (Act 1)", "res://episodes/episode1/scenes/MapRoom_ae_engine.tscn"],
	"d_transporter": ["Daedalus Station - Transporter Room", "res://episodes/episode1/scenes/MapRoom_d_transporter.tscn"],
	"d_core": ["Daedalus Station - Engine Core", "res://episodes/episode1/scenes/MapRoom_d_core.tscn"],
	"d_science": ["Daedalus Station - Science Lab", "res://episodes/episode1/scenes/MapRoom_d_science.tscn"],
	"d_dock": ["Daedalus Station - Shuttle Dock", "res://episodes/episode1/scenes/MapRoom_d_dock.tscn"],
	"x_enterprise1": ["Enterprise (original map)", "res://episodes/episode1/scenes/MapRoom_x_enterprise1.tscn"],
	"x_enterprise2": ["Enterprise (second map)", "res://episodes/episode1/scenes/MapRoom_x_enterprise2.tscn"],
	"x_incident": ["TOS Incident", "res://episodes/episode1/scenes/MapRoom_x_incident.tscn"],
	"x_wreckdeck": ["Wreck Deck", "res://episodes/episode1/scenes/MapRoom_x_wreckdeck.tscn"],
	"tc": ["TOS Cruiser (whole ship)", "res://episodes/episode1/scenes/MapRoom_tc.tscn"],
	# REV 421: Tork's 1701demo secondary hull (Glen, 25 Oct) - debug only, listed deck by deck (MAP_LEVELS)
	"x_s16_18": ["Secondary hull - Decks 16-18", "res://episodes/episode1/scenes/MapRoom_x_s16_18.tscn"],
	"x_s19_21": ["Secondary hull - Decks 19-21", "res://episodes/episode1/scenes/MapRoom_x_s19_21.tscn"],
	"x_s22_24": ["Secondary hull - Decks 22-24", "res://episodes/episode1/scenes/MapRoom_x_s22_24.tscn"],
}

## Everything the game remembers about this episode that is not a clue.
## (Clues are CLUE_<ID> and live in Case.gd's bookkeeping.)
const DEFAULTS := {
	"EP1_STARTED": false,
	"EP1_ACTIVE_CHAR": "mccoy",
	"EP1_OFFICE_INTRO_DONE": false,
	# Tuvall's office
	"EP1_TUVALL_TALKED": false,
	"EP1_TOPIC_WHERE": false,
	"EP1_TOPIC_DOCTORS": false,
	"EP1_TOPIC_WHYKILLED": false,
	"EP1_TOPIC_WHY_STARFLEET": false,
	"EP1_TOPIC_WHO_FOUND": false,
	"EP1_TOPIC_EVIDENCE": false,
	"EP1_TOPIC_NEURAL_STOPPED": false,
	"EP1_TERMINAL_MEDICAL_DONE": false,
	"EP1_TERMINAL_NEURAL_SEEN": false,
	"EP1_CASE_ATTITUDE_DONE": false,
	"EP1_KIRK_NEGOTIATION_DONE": false,
	"EP1_AUTHORITY_GRANTED": false,
	"EP1_HAS_CREDENTIAL": false,          # REV 490: Tuvall's investigative credential (a backpack item)
	"EP1_TIMELINE_VIEWED": false,
	"EP1_MANIFEST_VIEWED": false,
	"EP1_HUB1_ANNOUNCED": false,
	# Holding cell
	"EP1_CELL_MET_ULLUS": false,
	# REV 490 (EPISODE1_SCRIPT.md Hub One): the guard's honesty puzzle, the argument duel, the ornaments
	"EP1_GUARD_PRESSURED": false,
	"EP1_PROPERTY_ASKED": false,
	"EP1_DUEL_WON": false,
	"EP1_CLASP_SET_SEEN": false,
	"EP1_ULLUS_MOVEMENTS": false,
	"EP1_ULLUS_STATEMENT_REVIEWED": false,
	"EP1_ULLUS_DATAPAD_MENTIONED": false,
	"EP1_PROPERTY_VIEWED": false,
	"EP1_ULLUS_ACCESS_ASKED": false,
	# Evidence room
	"EP1_EV_TOKEN": false,
	"EP1_EV_CLASP": false,
	"EP1_EV_BIO": false,
	"EP1_EV_CLOTHES": false,
	"EP1_EV_BROKEN": false,
	"EP1_EV_IMAGES": false,
	"EP1_EV_CREDENTIALS": false,
	# REV 305: room flags later scenes depend on, listed here (in story order) so a new game resets them
	# and DEBUG: SCENE SELECT sets them for the scenes after them (they used to be missing from DEFAULTS)
	"EP1_EV_ANALYSER_SEEN": false,
	"EP1_EV_HAS_SWAB": false,
	"EP1_EV_PREPARED": false,
	"EP1_EV_ANALYSED": false,
	"EP1_CLASP_RECORDED": false,          # REV 490: the custodian lets you record the clasp
	"EP1_CUSTODIAN_COUNT": false,         # REV 490: the recovery team's count was one more than his
	"EP1_EV_ORNAMENT_DONE": false,        # REV 527: the clasp recording held up to the box - "Somebody prised it open"
	"EP1_AUTO_CLASP_SET": false,     # REV 476: Kirk and McCoy have matched the clasp to its set (auto connection)
	# Morgue
	"EP1_MORGUE_AUTHORISED": false,
	"EP1_MORGUE_EQUIPPED": false,
	"EP1_STORAGE_OPEN": false,
	"EP1_BODY_ON_GURNEY": false,
	"EP1_MORGUE_BODY_MOVED": false,
	"EP1_AUTOPSY_EXTERNAL_DONE": false,
	"EP1_AUTOPSY_TOX_DONE": false,
	"EP1_AUTOPSY_CARDIAC_DONE": false,
	"EP1_SCANNER_SEEN_LOCKED": false,     # REV 490: the sealed neural scanner (and its examiner)
	"EP1_EX_WILL": false,                 # REV 490: the examiner. Edit pass (27 Oct): only WILL and WHO are used now;
	                                      # FORBIDDEN/BYWHOM/REASON kept so old saves and scene select still load
	"EP1_EX_FORBIDDEN": false,
	"EP1_EX_BYWHOM": false,
	"EP1_EX_WHO": false,
	"EP1_EX_REASON": false,
	"EP1_EX_REF_ASKED": false,
	"EP1_SCANNER_UNLOCKED": false,        # REV 490: the examiner unlocked the neural scanner
	"EP1_SCANNER_NEEDS_REF": false,       # REV 490: the scanner asked for a living Vulcan reference
	"EP1_SPOCK_IN_MORGUE": false,         # REV 490: Spock answered the communicator call
	"EP1_SPOCK_REFERENCE": false,         # REV 490: Spock stood in as the reference sample
	"EP1_AUTOPSY_NEURAL_DONE": false,
	"EP1_COD_KNOWN": false,
	"EP1_AUTOPSY_COMPLETE": false,
	"EP1_EVIDENCE_REVIEWED": false,
	"EP1_TURIAN_TO_SHIP": false,          # REV 490: Turian's body transferred to the Enterprise (Episode 2 opens on it)
	# Hub one wrap-up
	"EP1_ULLUS_TOLD_COD": false,
	"EP1_HUB1_DEDUCTION_DONE": false,
	"EP1_DEDUCTION_NOTICED": false,
	"EP1_NEG_STAGE": 0,
	"EP1_NEG_FAILED": false,
	"EP1_STEPPED_IN": false,
	"EP1_QUARTERS_UNLOCKED": false,
	# Part 3: Turian's quarters
	"EP1_QUARTERS_ENTERED": false,
	"EP1_MOTIF_SEEN": false,
	"EP1_CONTACT_FOUND": false,
	"EP1_Q_PROJECTOR_ON": false,          # REV 492: the scene projector (Vulcan Security's ghosts)
	"EP1_Q_PROJECTOR_SEEN": false,
	"EP1_DESK_OPEN": false,
	"EP1_DESK_WRONG_ATTEMPT": false,
	"EP1_TERMINAL_SYNC_SEEN": false,
	"EP1_ARCHIVE_SEEN": false,
	"EP1_MESSAGES_SEEN": false,
	"EP1_QUARTERS_SUMMARY": false,
	"EP1_OTARI_UNLOCKED": false,
	# Part 3: Otari's room
	"EP1_OTARI_MET": false,
	"EP1_OTARI_L1_ASKED": false,          # REV 492: his three lies, asked ...
	"EP1_OTARI_L2_ASKED": false,
	"EP1_OTARI_L3_ASKED": false,
	"EP1_OTARI_P_MESSAGES": false,        # ... and broken by SHOWing the proof
	"EP1_OTARI_P_TERMINAL": false,
	"EP1_OTARI_P_COD": false,
	"EP1_OTARI_P_DATAPAD": false,         # (retired REV 492)
	"EP1_OTARI_COOPERATING": false,
	"EP1_OTARI_TOLD_SECRET": false,
	"EP1_OTARI_ASKED_WHO": false,
	"EP1_OTARI_ASKED_ROOM": false,
	# Part 3: maintenance room
	"EP1_MAINT_UNLOCKED": false,
	"EP1_MAINT_SCAN_TERMINAL": false,
	"EP1_MAINT_SCAN_RELAY": false,
	"EP1_MAINT_SCAN_JUNCTION": false,
	"EP1_MAINT_SCAN_CABLE": false,
	"EP1_MAINT_STARTED": false,
	"EP1_MAINT_HAS_CABLE": false,         # REV 492: the interface cable is in the backpack
	"EP1_MAINT_CABLE_CONNECTED": false,
	"EP1_MAINT_ADAPTER_BUILT": false,     # REV 303/305
	"EP1_MAINT_JUNCTION_ALIVE": false,
	"EP1_MAINT_DIAG_SEEN": false,         # REV 492: the terminal's credential test (and PROVE IT)
	"EP1_MAINT_FALSE_EVENT_DONE": false,  # REV 492: the prank on Tuvall's outer door
	"EP1_MAINT_ROD_WRONG": false,
	"EP1_MAINT_HISTORY_DONE": false,
	"EP1_MAINT_PERSONNEL_DONE": false,
	"EP1_PART3_NOTICED": false,
	"EP1_PART3_DONE": false,
	# Part 4: the frame collapses
	"EP1_ULLUS_AREA_UNLOCKED": false,
	"EP1_COMP_FOUND": false,
	"EP1_HALL_SENSOR_SEEN": false,
	"EP1_PLATE_HINT": false,              # REV 493: Kirk's weigh-in
	"EP1_COMP_CALIBRATED": false,
	"EP1_ULLUS_WEIGHT_KNOWN": false,      # (the guard, or Ullus: ninety-four kilograms)
	"EP1_ULLUS_HALL_DONE": false,
	"EP1_CLASP_MOUNT_MATCHED": false,
	"EP1_ULLUS_ROOM_DONE": false,
	"EP1_ULLUS_RETURN_READY": false,
	"EP1_ULLUS_RETURNED": false,
	"EP1_ULLUS_PROOF_ASKED": false,
	"EP1_LOBBY_UNLOCKED": false,
	"EP1_LOBBY_ASKED": false,             # REV 493: the receptionist's honesty puzzle
	"EP1_SL_SAID": false,
	"EP1_SL_COMPLAINED": false,
	"EP1_SL_WHERE": false,
	"EP1_REGISTRY_DONE": false,
	"EP1_HAS_COMPLAINT": false,           # REV 493: ULLUS' COMPLAINT (copy)
	"EP1_ULLUS_CLEARED": false,
	"EP1_SERRIN_ABSENT_SEEN": false,
	"EP1_OFFICE_OPEN": false,
	"EP1_DAREV_UNLOCKED": false,
	"EP1_DH_SENSOR_SEEN": false,
	"EP1_DAREV_COMP_CALIBRATED": false,
	"EP1_DAREV_HALL_DONE": false,
	"EP1_DH_LOCK_HINT": false,
	"EP1_DAREV_DOOR_OPEN": false,
	"EP1_DR_ARRIVED": false,
	"EP1_DR_FLOOR": false,
	"EP1_DR_PANEL": false,                # REV 493: the powder on the wall panel
	"EP1_HAS_DUST": false,                # REV 493: DESERT DUST SAMPLE
	"EP1_DAREV_ROOM_DONE": false,
	"EP1_PART4_NOTICED": false,
	"EP1_PART4_DONE": false,
	"EP1_EXTERIOR_UNLOCKED": false,
	# Part 5: into the desert
	"EP1_EX_REGION": false,
	"EP1_EX_MINERAL": false,
	"EP1_EX_WEATHER": false,
	"EP1_EX_DEST_SET": false,
	"EP1_TRANSPORT_ASKED": false,
	"EP1_HAS_FLASK": false,               # REV 495: the streets chain (Sulu, Chekov)
	"EP1_ST_V_COLLECTOR": false,
	"EP1_ST_V_GROW": false,
	"EP1_ST_CHIT_SEEN": false,
	"EP1_HAS_TOURIST_MAP": false,
	"EP1_EQ_WATER": false,
	"EP1_EQ_BEACON": false,
	"EP1_IN_FIELD": false,
	"EP1_P6_DP_TRIES": 0,
	# REV 268 (GAMEPLAY LOCKED): Darev's datapad - TRUE only if he SAID he had it (asked in time);
	# FALSE on the fallback route (found among his concealed belongings while he was unconscious)
	"EP1_DAREV_DATAPAD_TESTIMONY": false,
	"EP1_PROTECTED_ITEM_FOUND": false,
	"EP1_PROTECTED_ITEM_IDENTIFIED": false,
	"EP1_DAREV_PRELIM_SCAN": false,
	"EP1_RUINS_TRAILS_SEEN": false,
	"EP1_PASSAGE_BUFFER_DONE": false,
	"EP1_HANDOFF_CORROBORATED": false,
	"EP1_CASE_UNDERMINED": false,
	"EP1_CELL_HEARD_UNDERMINED": false,
	"EP1_ULLUS_RILED": false,
	"EP1_SO_AUTHORISED": false,
	# The Council clock (see clock_minutes_left): a story clock, never a fail state.
	"EP1_CLOCK_STARTED": false,
	"EP1_CLOCK_PENALTY": 0,
	"EP1_CLOCK_EXTENDED": false,
	"EP1_CLOCK_ALERT_180": false,
	"EP1_CLOCK_ALERT_90": false,
	"EP1_CLOCK_ALERT_60": false,
	"EP1_RUINS_LOCKED": [false, false, false],
	"EP1_DESERT_PATH_B": false,
	"EP1_HAS_ANTENNA": false,             # REV 495
	"EP1_STRAP_USED": false,
	"EP1_SENSOR_COUPLED": false,     # REV 303/305
	"EP1_SENSOR_FITTED": false,           # REV 495: the coupling is on the sensor
	"EP1_SENSOR_POWERED": false,
	"EP1_SENSOR_USED_COMM_CELL": false,
	"EP1_SENSOR_ANALYSED": false,
	"EP1_HEAT_WARNED": false,
	"EP1_HEAT_DONE": false,
	"EP1_RUINS_GATE_OK": false,
	"EP1_DESERT_NOTICED": false,
	"EP1_DESERT_DONE": false,
	"EP1_RUINS_OPEN": false,
	"EP1_COUNCIL_FREED": false,
	"EP1_BRACE_CUT": false,
	"EP1_DAREV_TREATED": false,
	"EP1_DAREV_INTERVIEW_DONE": false,
	"EP1_HAS_DATAPAD": false,
	"EP1_STRETCHER_BUILT": false,
	"EP1_DAREV_ON_STRETCHER": false,      # REV 495
	"EP1_RESCUE_OUT": false,
	"EP1_PART5_NOTICED": false,
	"EP1_PART5_DONE": false,
	# Part 6: the return
	"EP1_P6_STABLE": false,
	"EP1_P6_DEMO": false,                 # REV 497: Kirk and Spock beam down for the demonstration
	"EP1_DEMO_INTRO": false,
	"EP1_DEMO_READOUT": false,
	"EP1_DEMO_CLASP": false,
	"EP1_DEMO_PRANK": false,
	"EP1_P6_COINCIDENCES": false,
	"EP1_P6_DATAPAD_DONE": false,
	"EP1_P6_CORROB_DONE": false,
	"EP1_P6_SPOCK_DONE": false,
	"EP1_PART6_NOTICED": false,
	"EP1_P6_RECON_DONE": false,
	"EP1_P6_VULCAN_DONE": false,
	"EP1_P6_REVIEW_DONE": false,
	"EP1_P6_REPORT_REVIEWED": false,
	"EP1_P6_VERIFY_STARTED": false,
	"EP1_P6_CHAPEL_QUIP": false,      # REV 316: Chapel's remark about the sickbay computer's voice (once)
	"EP1_EPISODE_COMPLETE": false,
	# REV 856: Shi'Kahr, the city (SHIKAHR_SCRIPT.md) - all optional, and at the END of this list on purpose: the
	# debug scene select sets every flag listed before a scene's "before" flag, and none of these should be pre-set.
	# (No _DONE/_OPEN/_UNLOCKED/_GRANTED/_NOTICED endings either: _debug_state sets those.)
	"EP1_ST_CITY_SEEN": false,
	"EP1_ST_TMIR": false,
	"EP1_ST_HAS_TOUR_CARD": false,
	"EP1_ST_TOUR_1": false,
	"EP1_ST_TOUR_2": false,
	"EP1_ST_TOUR_3": false,
	"EP1_ST_TOUR_4": false,
	"EP1_ST_TOUR_5": false,
	"EP1_ST_TOUR_6": false,
	"EP1_ST_TOUR_7": false,
	"EP1_ST_TOUR_FINISHED": false,
	"EP1_ST_TMIR_TOLD": false,
	"EP1_ST_SALUTE": false,
	"EP1_ST_RILEY_MET": false,
	"EP1_ST_RILEY_SHOT": false,
	"EP1_ST_HAS_HOLO": false,
	"EP1_ST_DEBATE_HEARD": false,
	"EP1_ST_DEBATE": false,
	"EP1_ST_KUVAK": false,
	"EP1_ST_WATER_DRUNK": false,
	"EP1_ST_SELT_MET": false,
	"EP1_ST_SELT_GUESSED": false,
	"EP1_ST_SELT_CLAIM_BORN": false,
	"EP1_ST_SELT_CLAIM_ROMULANS": false,
	"EP1_ST_SELT_CLAIM_ACADEMY": false,
	"EP1_ST_IMPOSTOR": false,             # caught a "Vulcan" lying - for Episode 2 to remember
	"EP1_ST_SOREV_MET": false,
	"EP1_ST_SEHLAT": false,
	"EP1_ST_HAS_STRING": false,
	"EP1_ST_SOREV_TOLD": false,
	"EP1_ST_ANDORIAN_ASKED": false,
	"EP1_ST_ANDORIAN_HIRED": false,
	"EP1_ST_ANDORIAN_Q": 0,
	"EP1_ST_HAS_VISOR": false,
	"EP1_ST_VIEWER_TRIED": false,
	"EP1_ST_VIEWER": false,
	"EP1_ST_SAW_PLUME": false,
	"EP1_ST_HALL": false,
	"EP1_ST_TRANSIT_RIDDEN": false,
	"EP1_ST_TMIR_FACT": 0,
	# REV 860: THE DELEGATIONS ON THE BRINK (the fourth Hub One word; CouncilLounge.gd). At the END on purpose -
	# DEBUG: SCENE SELECT never pre-sets them.
	"EP1_DL_CALLED": false,              # Spock's call on the first Hub One exit - the lounge opens
	"EP1_DL_ARRIVED": false,             # Grath on his chair
	"EP1_DL_ASKED_STAY": false,          # "What would make you stay?" - GET VULCAN TO ACKNOWLEDGE THE INSULT
	"EP1_DL_SEVEK_FORM": false,          # Sevek: a Form of Grievance, in triplicate, from the records room
	"EP1_DL_SHRAS_MET": false,           # Shras behind the door - FIX THE SEATING PLAN
	"EP1_DL_KIRK_HUMS": false,           # Kirk took the chair by the recycler (the line, once)
	"EP1_DL_PLAN_REVISED": false,        # all delegations concur; Shras comes out
	"EP1_DL_HAS_FORM": false,            # + FORM OF GRIEVANCE
	"EP1_DL_FORM_FILLED": false,         # Grath wrote it (three pages, both sides)
	"EP1_DL_FORM_STAMPED": false,        # RECEIVED
	"EP1_DL_GRATH_STAYS": false,         # the tick: THE DELEGATIONS
	"EP1_DL_CLERK_GONE": false,          # the hooded clerk left the Romulan table (Part Four's walker)
	"EP1_DL_SEATS": [],
	# REV 862: SPOCK ON VULCAN (EPISODE1_SCRIPT.md) - the lounge with Spock and Sarek, Spock's Shi'Kahr, Spock in the desert
	"EP1_SP_LOUNGE_SPLIT": false,        # "I'll take the Tellarites. You know these people."
	"EP1_SP_SEVEK_MET": false,
	"EP1_SP_SAREK_MET": false,
	"EP1_SP_SAREK_KIRK": false,
	"EP1_SP_SAREK_PARTING": false,
	"EP1_SP_JOINED": false,              # Spock walks the streets with you (from the delegations to Part Four)
	"EP1_SP_LEFT": false,                # Grath's second grievance - back to the delegations
	"EP1_SP_RECOGNISED": false,
	"EP1_SP_TMIR": false,
	"EP1_SP_HOUSE": false,
	"EP1_SP_STUDENTS": false,
	"EP1_SP_SEHLAT": false,
	"EP1_SP_SOREV": false,
	"EP1_SP_BENCH": false,
	"EP1_SP_GATE": false,
	"EP1_SP_DOOR_LINE": false,
	"EP1_SP_DESERT_JOINED": false,       # waiting at the city's edge
	"EP1_SP_AMOK": false,
	"EP1_SP_WEATHER": false,
	"EP1_SP_HEAT": false,
	"EP1_SP_SENSOR_STAYED": false,       # he holds the signal at the dead sensor
	# REV 863: McCoy's patient (EPISODE1_SCRIPT.md, the holding cell, EXPANSION)
	"EP1_PT_FEVER": false,               # McCoy scanned him: two degrees over and climbing
	"EP1_PT_HYPO": false,                # "We negotiate with it."
	"EP1_PT_REFRESHMENT": false,         # the guard: approved refreshment
	"EP1_PT_KESH_NAMED": false,          # "One noun recurred. Kesh."
	"EP1_PT_KESH_EXPLAINED": false,
	"EP1_PT_CHAIRS": false,              # told the Tellarite tourist the chairs are terrible
	"EP1_PT_HAS_KESH": false,
	"EP1_PT_DOCTORED": false,
	"EP1_PT_TREATED": false,
	# REV 864: THE ROMULAN WING AND THE HOODED WALKER, THE MARKET TABLE
	"EP1_WK_ARRIVED": false,
	"EP1_WK_CREDENTIAL": false,          # the three polite failures at the wing
	"EP1_WK_ASKED": false,
	"EP1_WK_SEAL": false,
	"EP1_WK_CHASED": false,              # the chase is over (the chit found)
	"EP1_WK_TABLE": false,               # the market table played
	"EP1_WK_DONE": false,                # FOLLOW THE SECOND WALKER ticked
	# REV 865: THE ROUTE - the waystation, the le-matya canyon, the storm
	"EP1_WS_ARRIVED": false,
	"EP1_WS_SILENCE": false,
	"EP1_WS_LEAK_SEEN": false,
	"EP1_WS_SEAL_TRIED": false,
	"EP1_WS_FIXED": false,
	"EP1_WS_CISTERN": false,
	"EP1_WS_HAS_SLED": false,
	"EP1_WS_VELIK_DONE": false,
	"EP1_LM_SEEN": false,
	"EP1_LM_PAST": false,
	"EP1_LM_SLEEP": false,
	"EP1_STORM_DONE": false,
	# REV 866: the ruins - the outer court, the gallery, the trap floor, the light-well
	"EP1_RC_DONE": false,                # the camp read ("They left in a hurry. They didn't leave in a panic.")
	"EP1_RG_ENDFIGURE": false,           # the carving catching light (the light-well's hint)
	"EP1_RG_MARKS": false,               # the boots stepped, the heel didn't
	"EP1_RG_FLOOR_DONE": false,
	"EP1_RG_PLATE_FREED": false,         # the stiff middle plate loosened
	"EP1_RG_LIT": false,                 # the deep chambers lit by starlight
	# REV 867: Part Six expansion (EP1_P6_ - the debug set-up leaves these alone)
	"EP1_P6_KOMACK": false,              # Starfleet called (the bridge, after the datapad)
	"EP1_P6_COMMENDED": false,           # Grath's formal complaint against Kirk, for being correct
	"EP1_P6_TABLE_ASKED": false,         # Ullus' summons to dinner accepted
	"EP1_P6_TABLE_DONE": false,          # the insult feast eaten
}

## id -> text. (The id is shown nowhere; the text goes in the Mission Log.)
const OBJECTIVES := {
	"REPORT": "REPORT TO TUVALL",
	"QUESTION_TUVALL": "FIND OUT WHY McCOY WAS CALLED",
	"AUTHORITY": "GET PERMISSION TO EXAMINE TURIAN",
	"SECURE_ACCESS": "TALK TUVALL INTO GIVING YOU THE CASE",
	"HUB1": "INVESTIGATE TURIAN'S DEATH - ULLUS / THE EVIDENCE / THE BODY",
	"REVIEW_TIMELINE": "Review the official security timeline (Tuvall's terminal).",
	"VERIFY_MOVEMENTS": "Verify Ullus' movements.",
	"RECHECK_MANIFEST": "Recheck the evidence manifest.",   # REV 293: set in the cell when Ullus mentions the datapad before the manifest was read
	"SEARCH_DATAPAD": "SEARCH TURIAN'S QUARTERS FOR THE DATAPAD",
	"RETRIEVE_BODY": "Retrieve Turian's body.",
	"COD": "Determine Turian's cause of death.",
	"DEDUCE": "Work out what we are looking for.",
	"FIND_DATAPAD": "Find Turian's missing datapad.",
	"QUESTION_OTARI": "FIND OUT WHAT OTARI KNOWS",
	"GIVE_OTARI_REASON": "Give Otari a reason to talk.",
	"INSPECT_MAINT": "INSPECT THE MAINTENANCE ROOM",
	"PROVE_FAKE": "PROVE IT TO TUVALL",     # REV 528: the goal, not the answer
	"RESET_JUNCTION": "Reset the security junction.",
	# REV 293: PART3_DONE ("...examine Ullus' quarters and Serrin's office lobby") removed - never set; since
	# REV 268 the part3 deduction sets VERIFY_ACCOUNT and the lobby opens later, from the cell.
	"VERIFY_ACCOUNT": "PROVE WHERE ULLUS REALLY WENT",
	"RECONSTRUCT_CORRIDOR": "FIND OUT WHERE ULLUS REALLY WENT",     # REV 528: no longer names the machine
	"SEARCH_ULLUS_ROOM": "SEARCH ULLUS' ROOM",
	"RETURN_ULLUS": "Return to the holding cell and tell Ullus what we know.",
	"VERIFY_ALIBI": "CHECK ULLUS' ALIBI AT SERRIN'S OFFICE",
	"CLEAR_ULLUS": "TELL TUVALL WHERE ULLUS REALLY WAS",
	"WHERE_SERRIN": "FIND OUT WHERE SERRIN WENT",
	"LOCATE_DAREV": "FIND DAREV",
	"ENTER_DAREV": "GET INTO DAREV'S ROOM",
	"DETERMINE_DAREV": "FIND OUT WHAT HAPPENED TO DAREV",
	"P4_NEXT": "FOLLOW TURIAN'S COORDINATES INTO THE DESERT",
	"DETERMINE_ROUTE": "FIND WHERE TURIAN'S COORDINATES LEAD",
	"LOCATE_COORDS": "FIND WHERE TURIAN'S COORDINATES LEAD",
	"REACH_RUINS": "REACH THE RUINS",
	"ENTER_RUINS": "GET INTO THE RUINS",
	"FREE_VULCAN": "FIND THE MISSING PEOPLE",
	"REACH_ROMULAN": "REACH THE ROMULAN",
	"GET_OUT": "GET DAREV TO SICKBAY",
	"CONTACT_ENTERPRISE": "GET DAREV TO SICKBAY",
	"ANALYSE_DAREV": "FIND OUT WHAT'S WRONG WITH DAREV",
	"P6_STABILISE": "STABILISE DAREV",
	"P6_DATAPAD": "FIND OUT WHAT'S ON TURIAN'S DATAPAD",
	"P6_CORROBORATE": "Corroborate Darev's account.",
	"P6_CORROBORATE_CUSTODY": "Corroborate the datapad's custody.",
	"P6_SPOCK": "SHOW THE DATAPAD TO SPOCK",
	"P6_RECONSTRUCT": "Take apart the case against Ullus.",
	"P6_VULCAN": "Contact the Vulcan authorities.",
	"P6_REVIEW": "Review where the investigation stands with Spock.",
	"P6_TUVALL": "TAKE THE CASE APART IN FRONT OF TUVALL",
	"P6_TO_MCCOY": "REPORT TO McCOY",
	"P6_REPORT": "FINISH TURIAN'S MEDICAL REPORT",
	"P6_VERIFY": "CHECK THE NEUROLOGICAL FINDINGS",
	"P5_DEDUCE": "Put the conspiracy together.",
	# REV 293: P5_NEXT ("Review what we know. The datapad is in Kirk's hands.") removed - never set; the
	# part5 deduction goes straight on to P6_DATAPAD.
}

const LOG_OBJECTIVE_ENTRY := "LOG_EP1_000"

## REV 268: THE MASTER TIMELINE of the day Turian died (the GAMEPLAY LOCKED document asks for exact
## timestamps; the build had the alibi filed two hours after the body was found). Every screen that
## shows a time uses these. The day of the murder, Shi'Kahr local time:
##   18:40  Ullus' credential at the outer door of Turian's quarters wing (he arrives)
##   18:42  The argument - heard from the corridor by members of the Romulan delegation
##   19:05  Ullus leaves the quarters wing (credential at the outer door)
##   19:08  A person of Ullus' mass enters Ullus' own corridor toward his room; leaves toward the exit 19:15
##   19:11  Service passage: first authorised movement (diplomatic residential area <-> Darev's corridor)
##   19:18  A lighter person lingers at Ullus' door for 1 min 50 s (door log: NO ENTRY)
##   19:19  Service passage: second movement
##   19:31  Ullus files a procedural objection IN PERSON at Serrin's office building (receipt 19:44)
##   19:37  "Ullus' credential" on the corridor sensor by Turian's quarters - the simulated event
##          (the deleted maintenance diagnostic entry: 19:37:03 - 19:37:09)
##   20:14  Turian found dead. Darev enters his own room 21:52 and is never seen to leave.
const TIMELINE := {
	"ullus_arrives": "18:40", "argument": "18:42", "ullus_departs": "19:05",
	"ullus_own_corridor": "19:08", "passage_1": "19:11", "visitor": "19:18", "passage_2": "19:19",
	"objection_filed": "19:31", "objection_receipt": "19:44", "false_event": "19:37",
	"turian_found": "20:14", "darev_enters": "21:52",
}


# ------------------------------------------------------------------ setup ----

## Call at the start of every Episode 1 room. Safe to call repeatedly.
static func ensure_state() -> void:
	_define_clues()
	GameState.register_defaults(DEFAULTS)
	Case.register_defaults()
	# REV 293: McCoy's own heading ("CASE FILE - TURIAN"). Episode 2 sets Spock's log; without this,
	# playing Episode 1 after it in the same session kept Spock's title.
	Case.reset_to_episode_defaults()
	Case.refresh_log()
	_register_objectives()
	AudioSubtitleManager.speech_root = SPEECH_ROOT


## REV 860 (EPISODE1_SCRIPT.md, THE DELEGATIONS - "How it opens"): the first time Kirk and McCoy come out of any
## Hub One room, Kirk's communicator chirps - the Tellarites are packing. EpisodeRoom._start awaits this on every
## arrival (after the room's own arrival scene).
const HUB1_ROOMS := ["cell", "evidence", "morgue"]


static func after_arrival(room: EpisodeRoom) -> void:
	if flag("EP1_SP_JOINED") and flag("EP1_PART3_DONE") and not flag("EP1_SP_LEFT") and not flag("EP1_IN_FIELD"):
		await _spock_leaves(room)
		return
	if flag("EP1_DL_CALLED") or not flag("EP1_AUTHORITY_GRANTED") or flag("EP1_HUB1_DEDUCTION_DONE") or flag("EP1_IN_FIELD"):
		return
	var came := String(GameState.get_var("ep_came_from")) if GameState.has_var("ep_came_from") else ""
	if not HUB1_ROOMS.has(came) or room.room_key == came:
		return
	set_flag("EP1_DL_CALLED")
	await room.pause(0.4)
	await room.note("(Kirk's communicator chirps.)", 1.2)
	await room.say("spock", "Captain. I regret the interruption. The Tellarite delegation has begun packing.")
	await room.say("kirk", "Packing?")
	await room.say("spock", "Their deputy informs me that every Tellarite on Vulcan will leave at first light unless Ambassador Ullus is released. He has informed me of this eleven times. The volume has not diminished.")
	await room.say("kirk", "On my way, Mister Spock.")
	await room.say("mccoy", "A dead Romulan, a Tellarite in jail and the Tellarites walking out. If the Andorians start complaining we've got the full set.")
	refresh_tracker()
	MissionLog.notification_requested.emit("NEW LOCATION UNLOCKED: THE HIGH COUNCIL HALL - DELEGATES' LOUNGE")


## REV 862 (SPOCK ON VULCAN): Spock walks the streets with Kirk and McCoy once the Tellarites agree to stay, until
## Part Three closes (Grath's second grievance calls him back).
static func spock_in_city() -> bool:
	return flag("EP1_DL_GRATH_STAYS") and not flag("EP1_PART3_DONE") and not flag("EP1_SP_LEFT") and not flag("EP1_IN_FIELD")


## ...and in the desert, from the city's edge until he stays at the dead sensor.
static func spock_in_desert() -> bool:
	return flag("EP1_SP_DESERT_JOINED") and not flag("EP1_SP_SENSOR_STAYED")


static func _spock_leaves(room: EpisodeRoom) -> void:
	set_flag("EP1_SP_LEFT")
	await room.pause(0.3)
	await room.note("(Kirk's communicator chirps.)", 1.2)
	await room.say("spock", "Captain. Deputy Grath has begun a second grievance. Sevek has asked for me by name. That has not happened before.")
	await room.say("kirk", "Go, Mister Spock. Before he runs out of stamps.")


## Wipes everything and starts the episode fresh.
## REV 293: also starts the Case File, the Mission Log and the objective afresh, the way the Prologue
## does: no clue definitions, log entries or objective left over from another episode (or an earlier
## run) in this session.
## REV 297: `carry_over` = coming straight on from the Prologue (its end screen passes true). Like
## Ep2.new_game(carry_over), it keeps the Prologue's story (PRO_* / VAR_PRO_* flags, e.g. an optional
## bowling victory Spock can remember in Episode 2) and the crew (WorldState "crew/*": the crew seed,
## so the same people are aboard, and anyone already met). A new game from the menu passes nothing.
static func new_game(carry_over: bool = false) -> void:
	var kept := {}
	var kept_crew := {}
	if carry_over:
		var snap: Dictionary = GameState.get_snapshot()
		for key in snap.keys():
			var k := String(key)
			if k.begins_with("PRO_") or k.begins_with("VAR_PRO_"):
				kept[k] = snap[key]
		var world: Variant = snap.get(WorldState.VAR, {})
		if world is Dictionary:
			for wk in (world as Dictionary).keys():
				if String(wk).begins_with("crew/"):
					kept_crew[wk] = (world as Dictionary)[wk]
	Case.clear_definitions()
	_define_clues()
	GameState.reset_to_defaults(DEFAULTS)
	for k in kept.keys():
		GameState.set_var(k, kept[k])
	if not kept_crew.is_empty():
		GameState.set_var(WorldState.VAR, kept_crew)
	InventoryManager.clear()     # REV 296: nothing from an earlier run (the bowling ball) in the backpack
	MissionLog.reset()
	ObjectiveManager.reset()
	Case.reset_to_episode_defaults()
	Case.register_defaults()
	GameState.set_var("EP1_STARTED", true)


## DEBUG ONLY (main menu: DEBUG: LOCATIONS). Nothing in the real game calls these.
## Starts a fresh episode, then fast-forwards it to just before the given part
## (4 = Parts 1 to 4 finished, 5 = the desert and rescue finished, 6 = Part 6 started):
## every flag for the finished parts is set and their clues are in the Case File.
static func _debug_state(upto: int) -> void:
	var skip: Array = _debug_part_ids(7)
	if upto < 5:
		skip.append_array(_debug_part_ids(5))
	if upto < 6:
		skip.append_array(_debug_part_ids(6))
	else:
		skip.append_array(["CHRONOLOGY", "DATAPAD_SECURED", "CASE_FAILS", "ULLUS_RELEASED"])
	skip.append("NEURAL_CONFIRMED")   # REV 293: never added in play (Sickbay rewords DAREV_NEURAL instead)
	new_game()
	for id in Case._defs.keys():
		if not skip.has(String(id)):
			Case.add(String(id), true)
	var in_part5 := false
	for key in DEFAULTS.keys():
		var k := String(key)
		if k == "EP1_EX_REGION":
			in_part5 = true
		var part5_key := in_part5
		if k == "EP1_PART5_DONE":
			in_part5 = false
		if k.begins_with("EP1_P6_") or k == "EP1_EPISODE_COMPLETE" or k == "EP1_PART6_NOTICED":
			continue
		if part5_key and upto < 5:
			continue
		for suffix in ["_DONE", "_NOTICED", "_UNLOCKED", "_GRANTED", "_OPEN"]:
			if k.ends_with(suffix):
				set_flag(k)
				break
	set_flag("EP1_AUTHORITY_GRANTED")
	set_flag("EP1_EXTERIOR_UNLOCKED")


## The clue ids that one part defines (found by defining that part alone).
static func _debug_part_ids(part: int) -> Array:
	Case.clear_definitions()
	match part:
		3:
			_define_part3_clues()
		4:
			_define_part4_clues()
		5:
			_define_part5_clues()
		6:
			_define_part6_clues()
		7:
			_define_street_clues()   # (the streets' optional clues: never pre-filled)
	var ids: Array = Case._defs.keys()
	Case.clear_definitions()
	return ids


## REV 87: the TOS Cruiser (one map, six levels). Each entry is [name, Vector3(map x, map y, floor height)].
## The L key inside the room shows these as buttons, and the debug menu lists the levels.
const TC_LEVELS := [
	["1  Main level (transporters, sickbay, engineering)", Vector3(-1.0, -1696.0, 0.0)],
	["2  Upper level (rec room, conference room)", Vector3(1803.0, 2233.0, 133.0)],
	["3  Lower hangar level", Vector3(2097.0, -3023.0, 541.0)],
	["4  Hangar deck (shuttle bay)", Vector3(2097.0, -3023.0, 701.0)],
	["5  Bridge", Vector3(33.0, 183.0, 827.0)],
	["6  Hangar gallery", Vector3(3269.0, -3112.0, 794.0)],
]
const TC_PLACES := [
	["Transporter rooms", Vector3(-1.0, -1696.0, 0.0)],
	["Sickbay", Vector3(-479.0, -63.0, 0.0)],
	["Briefing room", Vector3(450.0, -1450.0, 0.0)],
	["Engineering", Vector3(2473.0, -276.0, 0.0)],
	["Upper engineering", Vector3(2777.0, -589.0, 98.0)],
	["Conference room", Vector3(2487.0, 1212.0, 133.0)],
	["Rec room", Vector3(1803.0, 2233.0, 133.0)],
]


## REV 421: every multi-level map's levels for DEBUG: LOCATIONS (one entry per level; tc_arrive puts you there).
## [label, Vector3(map x, map y, floor height)] - spots found from the maps' floors (largest open floor of each level).
const MAP_LEVELS := {
	"tc": TC_LEVELS,
	"x_s16_18": [
		["Deck 16 (security, corridors)", Vector3(1385.0, 151.0, -380.0)],
		["Deck 17 (crew quarters, hangar gallery)", Vector3(-1102.0, -290.0, -524.0)],
		["Deck 18 (crew quarters, lounge)", Vector3(-930.0, -380.0, -668.0)],
		["Deck 19 (hangar deck)", Vector3(2698.0, -31.0, -776.0)],
	],
	"x_s19_21": [
		["Deck 17 (hangar gallery)", Vector3(2131.0, -360.0, -548.0)],
		["Deck 19 (hangar deck, corridors)", Vector3(2702.0, -31.0, -776.0)],
		["Deck 20 (pool, gym, rec room, shuttle hangar)", Vector3(118.0, -424.0, -956.0)],
		["Deck 21 (bowling alley)", Vector3(13.0, -25.0, -1100.0)],
	],
	"x_s22_24": [
		["Deck 22 (cargo hold)", Vector3(256.0, -114.0, -1244.0)],
		["Deck 23 (corridors, security)", Vector3(1256.0, -24.0, -1388.0)],
		["Deck 24", Vector3(-1080.0, 23.0, -1532.0)],
	],
}
const MAP_LEVEL_NAMES := {"tc": "TOS CRUISER - LEVEL ", "x_s16_18": "SECONDARY HULL 16-18 - ", "x_s19_21": "SECONDARY HULL 19-21 - ", "x_s22_24": "SECONDARY HULL 22-24 - "}


## Ask the TOS Cruiser room to open at a spot (the next room load only).
static func tc_arrive(spot: Vector3) -> void:
	ShipDecks.arrive_spot_on = true
	ShipDecks.arrive_spot = Vector2(spot.x, spot.y)
	ShipDecks.arrive_z = spot.z


# ---- REV 288: DEBUG: SCENE SELECT - each scene as if the story had been played up to it ------------

const _OFFICE_CLUES := ["ARGUED", "COD_UNKNOWN", "CRED_NEAR", "DEATH_LOCATION", "MANIFEST", "NEURAL_INCOMPLETE", "PHYS_RECOVERED", "TIMELINE", "TURIAN", "ULLUS"]
const _QUARTERS_CLUES := ["DATAPAD_CONCEALED", "ENCRYPTED_COPY", "MAINT_ROUTE", "Q_CLASP_ENTRY", "Q_SEARCHED", "STRUGGLE_UNRELATED", "TERMINAL_POSTMORTEM", "TURIAN_DISCOVERY", "VESSELS"]
const _OTARI_CLUES := ["MAINT_BEFORE_DEATH", "OTARI_STATEMENT", "UNKNOWN_KNEW"]
const _ULLUS_ROOMS_CLUES := ["CLASP_MOUNT_CLEAN", "CLASP_STORAGE_RESIDUE", "DOOR_OVERRIDE", "FRAME_PREPARED", "GARMENT_MOUNTS", "ULLUS_VESSEL", "ENV_SUPPORTS", "Q_VISITOR", "VISITOR_LOITER"]
const _SERRIN_CLUES := ["ALIBI_TIME", "NO_MEETING", "Q_SERRIN", "ULLUS_EXONERATED", "DAREV", "Q_DAREV_GUILTY", "SERRIN_CONTACT", "TURIAN_ARCHIVE_ACCESS"]
## Flags never fast-forwarded (failures, wrong tries, the clock, being out in the field).
const _DEBUG_SKIP := ["EP1_STARTED", "EP1_NEG_FAILED", "EP1_STEPPED_IN", "EP1_DESK_WRONG_ATTEMPT", "EP1_IN_FIELD",
	"EP1_CLOCK_STARTED", "EP1_CLOCK_EXTENDED", "EP1_CLOCK_ALERT_180", "EP1_CLOCK_ALERT_90", "EP1_CLOCK_ALERT_60"]

## label, room, and how to set the story up:
##   "before": every yes/no flag listed before this one in DEFAULTS is set (the story so far)
##   "parts": the Case File holds every clue of the main block ("main" = Parts 1-2) / Part 3 / Part 4
##   "clues": lists of more clues; "flags": more flags on top;  "enter": use debug_enter() as it is (Parts 5-6)
const DEBUG_SCENES := [
	{"label": "1. TUVALL'S OFFICE (THE BEAM-IN)", "room": "office"},
	{"label": "2. HUB ONE - THE STREETS", "room": "streets", "before": "EP1_CELL_MET_ULLUS", "clues": [_OFFICE_CLUES]},
	{"label": "2. HUB ONE - THE HOLDING CELL", "room": "cell", "before": "EP1_CELL_MET_ULLUS", "clues": [_OFFICE_CLUES]},
	{"label": "2. HUB ONE - THE EVIDENCE ROOM", "room": "evidence", "before": "EP1_CELL_MET_ULLUS", "clues": [_OFFICE_CLUES]},
	{"label": "2. HUB ONE - THE MORGUE", "room": "morgue", "before": "EP1_CELL_MET_ULLUS", "clues": [_OFFICE_CLUES]},
	{"label": "2. HUB ONE - THE DELEGATES' LOUNGE", "room": "lounge", "before": "EP1_CELL_MET_ULLUS", "clues": [_OFFICE_CLUES], "flags": ["EP1_DL_CALLED"]},
	{"label": "3. TURIAN'S QUARTERS", "room": "quarters", "before": "EP1_QUARTERS_ENTERED", "parts": ["main"]},
	{"label": "3. OTARI'S ROOM", "room": "otari", "before": "EP1_OTARI_MET", "parts": ["main"], "clues": [_QUARTERS_CLUES]},
	{"label": "3. THE MAINTENANCE ROOM", "room": "maintenance", "before": "EP1_MAINT_SCAN_TERMINAL", "parts": ["main"], "clues": [_QUARTERS_CLUES, _OTARI_CLUES]},
	{"label": "4. ULLUS' HALLWAY", "room": "ullus_hall", "before": "EP1_COMP_FOUND", "parts": ["main", 3]},
	{"label": "4. THE STREETS (ULLUS SUSPECTED)", "room": "streets", "before": "EP1_COMP_FOUND", "parts": ["main", 3]},
	{"label": "4. THE ROMULAN WING (THE HOODED WALKER)", "room": "streets", "before": "EP1_COMP_FOUND", "parts": ["main", 3], "flags": ["EP1_COMP_FOUND", "EP1_ULLUS_HALL_DONE"], "clues": [["VISITOR_LOITER", "ENV_SUPPORTS", "Q_VISITOR"]]},
	{"label": "4. SERRIN'S OFFICE BUILDING - LOBBY", "room": "serrin_lobby", "before": "EP1_REGISTRY_DONE", "parts": ["main", 3], "clues": [_ULLUS_ROOMS_CLUES]},
	{"label": "4. DAREV'S HALLWAY", "room": "darev_hall", "before": "EP1_DAREV_HALL_DONE", "parts": ["main", 3], "clues": [_ULLUS_ROOMS_CLUES, _SERRIN_CLUES], "flags": ["EP1_CASE_UNDERMINED"]},
	{"label": "5. THE CITY'S EDGE (INTO THE DESERT)", "room": "exterior", "enter": true},
	{"label": "5. THE STREETS (THE COUNCIL LEADER MISSING)", "room": "streets", "state": 5},
	{"label": "5. THE WAYSTATION", "room": "waystation", "enter": true},
	{"label": "5. THE DESERT", "room": "desert", "enter": true},
	{"label": "5. THE RUINS - OUTSIDE", "room": "ruins_ext", "enter": true},
	{"label": "5. THE RUINS - THE GALLERY", "room": "gallery", "enter": true},
	{"label": "5. THE RUINS - INSIDE", "room": "ruins_int", "enter": true},
	{"label": "6. ENTERPRISE SICKBAY (THE RETURN)", "room": "sickbay", "enter": true},
	{"label": "6. ENTERPRISE BRIDGE", "room": "bridge", "enter": true},
	{"label": "6. ULLUS' TABLE", "room": "table", "enter": true},
]


## Sets the story up for DEBUG_SCENES[i] and returns the scene to open.
static func debug_scene(i: int) -> String:
	var s: Dictionary = DEBUG_SCENES[clampi(i, 0, DEBUG_SCENES.size() - 1)]
	var room := String(s["room"])
	if bool(s.get("enter", false)):
		return debug_enter(room)
	if s.has("state"):
		_debug_state(int(s["state"]))
		set_flag("EP1_IN_FIELD", false)
		return String(ROOMS[room][1])
	# the clue ids of each part have to be worked out before new_game() defines everything again
	var later: Array = []
	for p in [3, 4, 5, 6, 7]:
		later.append_array(_debug_part_ids(p))
	var part3: Array = _debug_part_ids(3)
	new_game()
	if s.has("before"):
		var stop := String(s["before"])
		for key in DEFAULTS.keys():
			var k := String(key)
			if k == stop:
				break
			if typeof(DEFAULTS[key]) == TYPE_BOOL and not _DEBUG_SKIP.has(k):
				set_flag(k)
	for f in s.get("flags", []):
		set_flag(String(f))
	var parts: Array = s.get("parts", [])
	for id in Case._defs.keys():
		var cid := String(id)
		if (parts.has("main") and not later.has(cid)) or (parts.has(3) and part3.has(cid)):
			Case.add(cid, true)
	for group in s.get("clues", []):
		for c in group:
			if Case.is_defined(String(c)):
				Case.add(String(c), true)
	return String(ROOMS[room][1])


## Sets the game up to open this room (an Ep1.ROOMS key) and returns its scene path.
static func debug_enter(key: String) -> String:
	var info: Array = ROOMS.get(key, [])
	if info.is_empty():
		return ""
	match key:
		"exterior":
			_debug_state(4)
		"desert", "ruins_ext", "ruins_int", "waystation", "gallery":
			_debug_state(4 if key == "desert" or key == "waystation" else 5)
			for k in ["EP1_EX_REGION", "EP1_EX_MINERAL", "EP1_EX_WEATHER", "EP1_EX_DEST_SET", "EP1_EQ_WATER", "EP1_EQ_BEACON", "EP1_IN_FIELD"]:
				set_flag(k)
			if key == "desert":
				set_flag("EP1_WS_FIXED")     # REV 865: came on past the waystation
				set_flag("EP1_WS_VELIK_DONE")
			if key != "desert" and key != "waystation":
				set_flag("EP1_RUINS_GATE_OK")
				set_flag("EP1_DESERT_DONE")
			if key == "ruins_int" or key == "gallery":
				set_flag("EP1_RUINS_OPEN")
				set_flag("EP1_STORM_DONE")
			if key == "ruins_int":
				set_flag("EP1_RG_FLOOR_DONE")
				set_flag("EP1_RG_LIT")
		"sickbay":
			_debug_state(5)
			set_flag("EP1_IN_FIELD", false)
			set_flag("EP1_RESCUE_OUT")
			set_flag("EP1_HAS_DATAPAD")
			set_flag("EP1_COUNCIL_FREED")
			set_flag("EP1_DAREV_TREATED")
		"bridge":
			debug_jump_to_bridge()
		_:
			new_game()
	return String(info[1])


## Parts 1 to 5 finished and the datapad corroborated in Sickbay: ready for the bridge scenes.
static func debug_jump_to_bridge() -> void:
	_debug_state(6)
	set_flag("EP1_IN_FIELD", false)
	for k in ["EP1_RESCUE_OUT", "EP1_COUNCIL_FREED", "EP1_DAREV_TREATED", "EP1_HAS_DATAPAD",
			"EP1_P6_STABLE", "EP1_P6_DATAPAD_DONE", "EP1_P6_CORROB_DONE",
			"EP1_NEURAL_DONE"]:     # REV 305: Sickbay's neural analysis is done by the bridge scenes
		set_flag(k)
	GameState.set_var("EP1_ACTIVE_CHAR", "kirk")


static func _register_objectives() -> void:
	if MissionLog.get_entry(LOG_OBJECTIVE_ENTRY) == null:
		var entry := MissionLogEntryData.new()
		entry.id = LOG_OBJECTIVE_ENTRY
		entry.title = "IN SHEEP'S CLOTHING"
		entry.current_text = "Report to Tuvall."
		MissionLog.register_entry(entry)
	for id in OBJECTIVES.keys():
		var obj := ObjectiveData.new()
		obj.id = "OBJ_EP1_" + String(id)
		obj.text = String(OBJECTIVES[id])
		obj.mission_log_entry_id = LOG_OBJECTIVE_ENTRY
		ObjectiveManager.register_objective(obj)


static func set_objective(key: String) -> void:
	if not OBJECTIVES.has(key):
		push_warning("Ep1: unknown objective '%s'" % key)
		return
	ObjectiveManager.set_current_objective("OBJ_EP1_" + key)


static func line_id(who: String, text: String) -> String:
	var folder: String = String(SPEAKERS.get(who, [who, who])[0])
	return folder.to_upper() + "_EP1_" + text.md5_text().substr(0, 6).to_upper()


# ---------------------------------------------------------- Council clock ----
## The High Council sits at first light and will charge Ullus. This is a STORY clock:
## it does not run in real time. It starts at six hours when Tuvall grants access,
## drops by about half an hour for each thing the player gets done, and drops further
## when they follow a wrong idea (clock_penalty). It stops, and disappears, once
## Ullus is cleared. It can never "run out": if it gets very low Tuvall buys one
## more hour, once. So it is pressure and a sense of progress, never a game over.
## REV 268: the clock is not in Glen's GAMEPLAY LOCKED document (no version of it has one). Parked: false
## hides it everywhere and Tuvall never announces it. Set true to bring it back exactly as it was.
const CLOCK_ENABLED := false
const CLOCK_START_MINUTES := 360
const CLOCK_STEP_MINUTES := 28
const CLOCK_FLOOR_MINUTES := 30
const CLOCK_MILESTONES := [
	"EP1_CELL_MET_ULLUS", "EP1_TERMINAL_MEDICAL_DONE", "EP1_MORGUE_AUTHORISED",
	"EP1_AUTOPSY_EXTERNAL_DONE", "EP1_AUTOPSY_COMPLETE", "EP1_EVIDENCE_REVIEWED",
	"EP1_QUARTERS_SUMMARY", "EP1_OTARI_ASKED_ROOM", "EP1_MAINT_UNLOCKED",
	"EP1_MAINT_HISTORY_DONE", "EP1_SERRIN_ABSENT_SEEN",
]


## Minutes left before the Council sits, or -1 when there is no clock to show.
static func clock_minutes_left() -> int:
	if not CLOCK_ENABLED or not flag("EP1_CLOCK_STARTED") or flag("EP1_REGISTRY_DONE"):
		return -1
	var done := 0
	for f in CLOCK_MILESTONES:
		if flag(String(f)):
			done += 1
	var left: int = CLOCK_START_MINUTES - done * CLOCK_STEP_MINUTES - int(GameState.get_var("EP1_CLOCK_PENALTY"))
	if flag("EP1_CLOCK_EXTENDED"):
		left += 60
	return maxi(left, CLOCK_FLOOR_MINUTES)


static func clock_text() -> String:
	var m := clock_minutes_left()
	if m < 0:
		return ""
	return "THE HIGH COUNCIL SITS IN  %d:%02d" % [int(floor(m / 60.0)), m % 60]


## A wrong idea costs time. Returns the minutes lost (0 if there is no clock).
static func clock_penalty(minutes: int = 15) -> int:
	if clock_minutes_left() < 0:
		return 0
	GameState.set_var("EP1_CLOCK_PENALTY", int(GameState.get_var("EP1_CLOCK_PENALTY")) + minutes)
	return minutes


## The one-off warning for the clock crossing 3 hours, 90 minutes or an hour, and
## the "Tuvall buys one more hour" rescue. Returns "" if there is nothing to say.
static func clock_alert() -> String:
	var m := clock_minutes_left()
	if m < 0:
		return ""
	if m <= CLOCK_FLOOR_MINUTES + 20 and not flag("EP1_CLOCK_EXTENDED"):
		set_flag("EP1_CLOCK_EXTENDED")
		return "TUVALL HAS BOUGHT YOU ONE MORE HOUR.  Use it. What haven't you checked: the timeline, the maintenance records, Serrin's office?"
	if m <= 60 and not flag("EP1_CLOCK_ALERT_60"):
		set_flag("EP1_CLOCK_ALERT_60")
		return "ONE HOUR UNTIL THE COUNCIL SITS."
	if m <= 90 and not flag("EP1_CLOCK_ALERT_90"):
		set_flag("EP1_CLOCK_ALERT_90")
		return "NINETY MINUTES. Tuvall will not delay the Council."
	if m <= 180 and not flag("EP1_CLOCK_ALERT_180"):
		set_flag("EP1_CLOCK_ALERT_180")
		return "THREE HOURS UNTIL THE COUNCIL SITS."
	return ""


static func flag(name: String) -> bool:
	return GameState.has_var(name) and bool(GameState.get_var(name))


static func set_flag(name: String, value: bool = true) -> void:
	GameState.set_var(name, value)


## REV 298 (design: Turian's messages are OPTIONAL): Otari's room also opens once Ullus has named him
## and Turian's quarters are open - not only through the MESSAGES on Turian's terminal. Called where
## either happens; safe to call any number of times.
static func unlock_otari_if_named(set_obj: bool = true) -> void:
	if flag("EP1_OTARI_UNLOCKED") or not flag("EP1_OTARI_NAMED") or not flag("EP1_QUARTERS_UNLOCKED"):
		return
	set_flag("EP1_OTARI_UNLOCKED")
	if set_obj:
		set_objective("QUESTION_OTARI")
	MissionLog.notification_requested.emit("NEW LOCATION UNLOCKED: OTARI'S ROOM")


## Which rooms the player may travel to right now.
static func unlocked_rooms() -> Array:
	if flag("EP1_IN_FIELD"):
		return []   # in the desert: rooms lead to each other directly, not by the travel menu
	var rooms: Array = ["office"]
	if flag("EP1_AUTHORITY_GRANTED"):
		rooms.insert(0, "streets")   # REV 283: the city between the locations (walk it, or fast-travel past it)
		rooms.append("cell")
		rooms.append("evidence")
		rooms.append("morgue")
	if flag("EP1_DL_CALLED"):
		rooms.append("lounge")     # REV 860: once Spock calls, and from then on
	if flag("EP1_QUARTERS_UNLOCKED"):
		rooms.append("quarters")
	if flag("EP1_ULLUS_AREA_UNLOCKED"):
		rooms.append("ullus_hall")
		rooms.append("ullus_room")
	if flag("EP1_LOBBY_UNLOCKED"):
		rooms.append("serrin_lobby")
	if flag("EP1_OFFICE_OPEN"):
		rooms.append("serrin_office")
	if flag("EP1_DAREV_UNLOCKED"):
		rooms.append("darev_hall")
	if flag("EP1_DAREV_DOOR_OPEN"):
		rooms.append("darev_room")
	if flag("EP1_EXTERIOR_UNLOCKED") and not flag("EP1_IN_FIELD"):
		rooms.append("exterior")
	if flag("EP1_OTARI_UNLOCKED"):
		rooms.append("otari")
	if flag("EP1_MAINT_UNLOCKED"):
		rooms.append("maintenance")
	return rooms


# --------------------------------------------------------------- partner -----
## REV 490: THE PARTNER - "What have we got, Bones?" / "Jim, where are we?" (EPISODE1_SCRIPT.md). Talk to
## whoever you're not playing: one line where you are, plainer each time (EpisodeRoom.partner_hint). The
## same lines play unasked when you've been stuck a while. {name} = what the speaker calls the other.
## REV 715 (Glen's 29 Oct list, item 3): the CURRENT OBJECTIVE at the top of the Mission Log for each PARTNER stage - the
## goal, never the method (EpisodeRoom.current_goal). Keep one for every PARTNER stage.
const GOALS := {
	"report": "Report to Tuvall.",
	"why_called": "Find out why Tuvall called you in.",
	"permission": "Find out why the neural scan was stopped.",
	"the_case": "Get Tuvall to let you work the case.",
	"hub1_ullus": "Hear what Ullus has to say - he's in the holding cell.",
	"hub1_evidence": "See what the evidence room can tell you.",
	"hub1_body": "Finish the examination in the morgue.",
	"hub1_delegations": "Stop the Tellarites walking out of the conference.",     # REV 860
	"pt_fever": "Get something into Ullus before the heat does him in.",     # REV 863
	"wing": "Follow the second walker toward the Romulan wing.",     # REV 864
	"trap_floor": "Cross the floor.",     # REV 866
	"light_well": "Get some light into the deep chambers.",
	"waystation": "Find out what the keeper's seen.",     # REV 865
	"ws_talk": "Find out what the keeper's seen.",
	"lematya": "Get past the le-matya.",
	"dl_seating": "Fix the conference seating plan.",
	"dl_grievance": "Get Vulcan to acknowledge the insult - in writing.",
	"ullus_duel": "Get Ullus to talk.",
	"datapad_missing": "Find out what happened to Turian's datapad.",
	"scanner_locked": "Get access to the neural scanner.",
	"no_reference": "Find someone who can read a Vulcan neural scan.",
	"talk_it_over": "Work out what doesn't add up.",
	"search_quarters": "Search Turian's quarters.",
	"desk_lock": "Get into Turian's desk.",
	"quarters_terminal": "Find out how Turian spent his last hours.",
	"otari": "Get Otari to admit what he knows.",
	"otari_talks": "Find out what Turian was working on.",
	"junction": "Get the power back on.",
	"prove_it": "Prove to Tuvall that the log was tampered with.",
	"deleted_entry": "Find out what the deleted entry was.",
	"ullus_hallway": "Get past the compensator into Ullus' room.",
	"ullus_room": "Find out what's missing from Ullus' room.",
	"alibi": "Check Ullus' alibi.",
	"call_tuvall_alibi": "Tell Tuvall what you've found.",
	"serrin": "Find Serrin.",
	"darev_door": "Get into Darev's room.",
	"darev_room": "Find out where Darev went.",
	"coordinates": "Work out where in the desert Darev was taken.",
	"desert": "Find Darev's trail in the desert.",
	"heat": "Survive the heat.",
	"sensor": "Get a signal out of the desert.",
	"ruins_door": "Get into the ruins.",
	"restraints": "Free Councillor T'Seva.",
	"brace": "Clear the way through the ruins.",
	"darev": "Keep Darev alive.",
	"darev_talk": "Find out what Darev knows.",
	"stretcher": "Get Darev out of the ruins.",
	"stabilise": "Stabilise Darev in sickbay.",
	"analyse": "Find out what was done to Darev.",
	"datapad": "Find out what's on the datapad.",
	"spock": "Take the datapad to Spock on the bridge.",
	"med_report": "Finish the medical report.",
	"call_tuvall_darev": "Tell Tuvall about Darev.",
}

## REV 745 (Glen, 31 Oct: the map's pulsing objective marker, every episode): the hotspot(s) each PARTNER stage points
## at - the first one present in the room you're in. Not in this room: the room's way out (an *_EXIT spot), or on the
## ship the nearest turbolift (EpisodeRoom.objective_target). "" = nothing to point at (a call, a backpack combine).
const MARKERS := {
	"report": "EP1_TUVALL", "the_case": "EP1_TUVALL", "why_called": "EP1_TUVALL", "permission": "EP1_TUVALL",
	"ullus_duel": "EP1_ULLUS", "no_reference": "", "scanner_locked": "EP1_EXAMINER",
	"hub1_ullus": "EP1_ULLUS", "hub1_evidence": ["EP1_EV_ANALYSER", "EP1_CUSTODIAN"], "hub1_body": "EP1_BODY",
	"pt_fever": ["EP1_CELL_GUARD", "EP1_ULLUS"],
	"wing": ["EP1_ST_WING_GUARD", "EP1_ST_WING_SEAL"],
	"trap_floor": "EP1_RG_MARKS", "light_well": ["EP1_RG_PLATE_0", "EP1_RG_PLATE_1", "EP1_RG_PLATE_2"],
	"waystation": ["EP1_WS_CONDENSER", "EP1_WS_VELIK"], "ws_talk": "EP1_WS_VELIK", "lematya": ["EP1_LM_LEMATYA", "EP1_LM_KILL"],
	"hub1_delegations": ["EP1_DL_GRATH", "EP1_DL_SEVEK", "EP1_DL_RECORDS"], "dl_seating": "EP1_DL_TABLE", "dl_grievance": ["EP1_DL_GRATH", "EP1_DL_SEVEK"],
	"talk_it_over": "", "datapad_missing": ["EP1_ULLUS", "EP1_CUSTODIAN"],
	"desk_lock": "EP1_Q_TERMINAL", "quarters_terminal": "EP1_Q_TERMINAL", "search_quarters": ["EP1_Q_PROJECTOR", "EP1_Q_DESK"],
	"otari": "EP1_OTARI", "otari_talks": "EP1_OTARI", "junction": "EP1_M_JUNCTION", "prove_it": "EP1_M_PORT",
	"deleted_entry": "EP1_M_RELAY", "ullus_room": ["EP1_UR_MOUNT", "EP1_UR_STORAGE"], "ullus_hallway": "EP1_UH_PLATE",
	"alibi": ["EP1_SL_RECEPTIONIST", "EP1_SL_REGISTRY"], "call_tuvall_alibi": "",
	"serrin": ["EP1_SL_RECEPTIONIST", "EP1_SL_DIRECTORY"], "darev_door": "EP1_DH_LOCK",
	"darev_room": ["EP1_DR_PANEL", "EP1_DR_TERMINAL", "EP1_DR_COMMUNICATOR"], "call_tuvall_darev": "",
	"coordinates": ["EP1_EX_MAP", "EP1_EX_WEATHER"], "desert": "EP1_DS_FOOTPRINTS", "heat": "EP1_DS_SHADE",
	"sensor": "EP1_DS_SENSOR", "ruins_door": ["EP1_RX_DOOR", "EP1_RX_CONTROL"],
	"restraints": ["EP1_RI_COUNCIL", "EP1_RI_PANEL"], "brace": "EP1_RI_SUPPORT", "darev": "EP1_RI_DAREV",
	"darev_talk": "EP1_RI_DAREV", "stretcher": "", "stabilise": "EP1_SB_DAREV", "analyse": "EP1_SB_DAREV",
	"datapad": "EP1_SB_DATAPAD", "spock": "EP1_BR_SPOCK", "med_report": "EP1_SB_WORKSTATION",
}

const PARTNER := {
	"report": ["Tuvall's waiting, {name}.", "Go and talk to her.", "Walk up to Tuvall and talk."],
	"why_called": ["She's holding something back.", "Ask her what her doctors found.", "Ask her what her doctors found, then look at her report."],
	"permission": ["That neural scan bothers me.", "Ask her why it was stopped.", "Ask Tuvall why the neural scan was stopped."],
	"the_case": ["She's not going to hand it to us.", "Make it about her case, not ours.", "Tell her Ullus is a Federation representative - then that it has to stand up to scrutiny. Or ask Spock."],
	"hub1_ullus": ["We've still got Ullus to look at, {name}.", "The holding cell - that's where.", "Go to the holding cell and talk to Ullus."],
	"hub1_evidence": ["We've still got the evidence to look at, {name}.", "The evidence room - that's where.", "Go to the evidence room: analyse the sample, and hold the clasp recording up to that broken box."],
	"hub1_body": ["We've still got Turian to look at, {name}.", "The morgue - that's where.", "Go to the morgue and finish the neural scan."],
	# REV 860 (EPISODE1_SCRIPT.md partner table, the expansion rows)
	# REV 865
	"trap_floor": ["The boots stepped. The heel didn't.", "Walk only where the boots walked.", "Step on the tiles with boot marks; never the ones the drag line crosses."],     # REV 866
	"light_well": ["That carving in the gallery - catching light.", "Turn the mirrors till the light goes down the slot.", "Turn the top plate to the middle one, the middle (both of you - it's stiff) to the bottom, the bottom into the slot."],
	"waystation": ["He doesn't need a captain. He needs a doctor.", "Look at his water.", "Seal the condenser with the medical kit - one holds the tower while the other seals."],
	"ws_talk": ["He'll talk now, {name}.", "Ask him what he's seen out there.", "Ask Velik if he's seen anyone pass."],
	"lematya": ["Fire, or sleep. He told us.", "The beacon has a flare. Or the kit has a sedative.", "Use the emergency beacon on her - or the medical kit on her kill."],
	"wing": ["They won't open that door for us.", "Try what you like. Somebody's watching while you do.", "Show the guard your credential, ask for the delegation, and walk up to the seal."],     # REV 864
	"pt_fever": ["He won't take a hypo. He'll take a drink.", "Ask the guard what he'd drink - then find some.", "Get kesh from the Tellarite tourist in the Old Quarter, add the medical kit, give it to the guard."],     # REV 863
	"hub1_delegations": ["The Tellarites want something in writing, {name}.", "Somebody here stamps things - and somebody's sitting on the forms.", "Talk to Sevek about the form, then to the Andorian behind the records room door."],
	"dl_seating": ["Somebody's always going to end up by that recycler.", "Who wouldn't mind the humming?", "Put your own card - the Federation's - beside the recycler."],
	"dl_grievance": ["Grath's got the form. Let him write.", "Then Sevek needs to see it.", "Give the form to Grath, then the filled form to Sevek, then the stamped one to Grath."],
	"ullus_duel": ["He wants a fight, {name}.", "Tellarites respect a good argument.", "Win the argument - turn his own line back on him."],
	"datapad_missing": ["Ullus saw Turian with a datapad.", "Is it on Tuvall's evidence list?", "Show Ullus the evidence manifest - or ask the custodian about the recovery team's count."],
	"scanner_locked": ["That examiner doesn't like what he did.", "Talk to him doctor to doctor.", "Ask him how stopping the scan sits with him, as a doctor."],
	"no_reference": ["It wants a living Vulcan.", "We know a Vulcan.", "Call Spock on your communicator."],
	"talk_it_over": ["We've done all three, {name}.", "Let's talk it over.", "Talk to me - let's say what doesn't add up."],
	"search_quarters": ["Vulcan security already searched it. Search it differently.", "Switch on that projector.", "Use the projector, then scan the desk."],
	"desk_lock": ["That datapad synced with something in this room.", "Ask the terminal to sync it.", "Use the terminal: SYNC PERSONAL DATAPAD."],
	"quarters_terminal": ["His terminal's still logged in, {name}.", "A man's last hours are in there.", "Use Turian's terminal."],
	"otari": ["He's lying, {name}. Romulans can.", "Show him what he says doesn't exist.", "Show him Turian's messages, the access log and the neural readout."],
	"otari_talks": ["He'll talk now.", "Ask him what Turian was working on.", "Ask him about Turian's rooms that day."],
	"junction": ["It needs a jolt. A gentle one.", "The defibrillator in the medical kit.", "Put the cable and the medical kit together, then medium, charge, discharge."],
	"prove_it": ["Saying it isn't proving it.", "Tuvall needs to see it with her own eyes.", "Put your own credential in the port and pick the sensor outside Tuvall's office."],
	"deleted_entry": ["The log forgot. Something here didn't.", "That relay jumped when you ran your test.", "Look at the power relay's meter."],
	"ullus_hallway": ["Something in this corridor noticed him.", "The compensator weighs everybody.", "Stand on the plate to calibrate it, then dial in Ullus' weight - ask the guard."],
	"ullus_room": ["If the clasp came from here, it says how.", "Look at the empty mount - and where he kept it.", "Use the clasp recording on the mount; scan the storage and the lock."],
	"alibi": ["Ullus complains. Everywhere.", "Vulcans keep every complaint.", "Ask the receptionist about Ullus, then use the registry terminal."],
	"call_tuvall_alibi": ["Tuvall needs to hear this.", "Your communicator.", "Call Tuvall on your communicator."],
	"serrin": ["Where's Serrin?", "Ask for him - then check the Council's schedule.", "Ask the receptionist for Serrin, check the directory, then show her your credential."],
	"darev_door": ["Medical emergency, {name}?", "A doctor can open that.", "Use the medical kit on the lock."],
	"darev_room": ["He didn't walk out of that door.", "That wall panel. Make it talk.", "Dust the panel with the medical kit's powder; then his terminal, and the communicator he left."],
	"coordinates": ["Three places it could be.", "The dust, and the weather.", "Use the dust on the geological display, then check the weather monitor."],
	"desert": ["Read the ground, {name}.", "Somebody was bleeding. Follow that.", "Scan the footprints, then scan the three paths."],
	"heat": ["It's the heat, {name}.", "Water. Or shade.", "Hand me the water - or get us under that overhang."],
	"sensor": ["Two problems: it won't stay aimed, and it's dead.", "Strap the antenna. Then power.", "Antenna and strap, then the beacon - or your communicator's cell."],
	"ruins_door": ["That third symbol's buried in dust.", "Something to blow the dust out.", "Use the medical kit's air bulb, then press them in the order on the carvings."],
	"restraints": ["She was here when they set them, {name}.", "Ask the Councillor how they locked her in.", "Ask T'Seva, then press the tones she heard on the control: low, high, high."],
	"brace": ["One of those holds the ceiling up.", "Look at the floor, the ceiling, the wall.", "Cut the upper-left brace."],
	"darev": ["Treat him first, ask later.", "Fluids first.", "Fluids, stabiliser, cardiac, stimulant."],
	"darev_talk": ["He's coming round, {name}.", "Talk to him. Carefully.", "Talk to Darev - and ask about the datapad first."],
	"stretcher": ["He can't walk, {name}.", "That panel - and something to tie him on.", "Put the support panel and the restraint material together."],
	"stabilise": ["He's in a bad way, {name}.", "The biobed panel.", "Fluids, electrolytes, then cooling - slowly."],
	"analyse": ["Something's wrong with him that isn't the desert.", "The scanner at his head.", "Use the medical scanner on Darev."],
	"datapad": ["Turian's datapad, {name}.", "Have a look at it.", "Use the datapad on the lab table."],
	"spock": ["Spock should see it.", "The bridge.", "Take the turbolift to the bridge and show Spock the datapad."],
	"med_report": ["Just the paperwork, {name}.", "Confirm each section.", "Confirm them, then check the neurological findings four ways."],
	"call_tuvall_darev": ["Tuvall should hear about this.", "Your communicator.", "Call Tuvall on your communicator."],
}


## What the speaker calls the one being played (THE PARTNER's {name}).
static func partner_name(speaker: String, played: String) -> String:
	if speaker == "kirk" and played == "mccoy":
		return "Bones"
	if speaker == "spock" and played == "kirk":
		return "Captain"      # REV 862: the lounge, Spock played with Kirk
	if speaker == "kirk" and played == "spock":
		return "Spock"
	if speaker == "mccoy" and played == "kirk":
		return "Jim"
	return ""


## Where the story is, as a key of PARTNER ("" = nothing to say). Hub One is room by room: the cell's
## stages in the cell, the morgue's in the morgue, otherwise the first word still to do.
static func partner_stage(room_key: String) -> String:
	if not flag("EP1_TUVALL_TALKED"):
		return "report"
	if flag("EP1_STEPPED_IN") and not flag("EP1_AUTHORITY_GRANTED"):
		return "the_case"
	if not flag("EP1_AUTHORITY_GRANTED"):
		return "why_called" if not flag("EP1_TOPIC_DOCTORS") else "permission"
	if not flag("EP1_HUB1_DEDUCTION_DONE"):
		var ticks := hub1_ticks()
		if room_key == "cell" and not ticks.has("ULLUS") and flag("EP1_CELL_MET_ULLUS") and not flag("EP1_DUEL_WON"):
			return "ullus_duel"
		if room_key == "cell" and flag("EP1_PT_FEVER") and not flag("EP1_PT_TREATED") and ticks.has("ULLUS"):
			return "pt_fever"     # REV 863: the side line, once his own word is ticked
		if room_key == "lounge" and flag("EP1_DL_CALLED") and not ticks.has("THE DELEGATIONS"):
			return dl_stage()
		if room_key == "morgue" and not ticks.has("THE BODY"):
			if flag("EP1_SCANNER_NEEDS_REF") and not flag("EP1_SPOCK_REFERENCE"):
				return "no_reference"
			if flag("EP1_AUTOPSY_CARDIAC_DONE") and not flag("EP1_SCANNER_UNLOCKED"):
				return "scanner_locked"
		if not ticks.has("ULLUS"):
			return "hub1_ullus"
		if not ticks.has("THE EVIDENCE"):
			return "hub1_evidence"
		if not ticks.has("THE BODY"):
			return "hub1_body"
		if flag("EP1_DL_CALLED") and not ticks.has("THE DELEGATIONS"):
			return dl_stage()
		return "talk_it_over"
	if Case.has("DATAPAD_POSSESSED") and not Case.has("DATAPAD_MISSING"):
		return "datapad_missing"
	# Part Three (REV 492)
	if not flag("EP1_PART3_DONE"):
		if room_key == "quarters" and flag("EP1_TERMINAL_SYNC_SEEN") and flag("EP1_CONTACT_FOUND") and not flag("EP1_DESK_OPEN"):
			return "desk_lock"
		if not flag("EP1_TERMINAL_SYNC_SEEN"):
			if room_key == "quarters" and flag("EP1_Q_PROJECTOR_SEEN"):
				return "quarters_terminal"
			return "search_quarters"
		if not flag("EP1_OTARI_COOPERATING"):
			return "otari"
		if not flag("EP1_MAINT_UNLOCKED"):
			return "otari_talks"
		if not flag("EP1_MAINT_JUNCTION_ALIVE"):
			return "junction"
		if not flag("EP1_MAINT_FALSE_EVENT_DONE"):
			return "prove_it"
		if not flag("EP1_MAINT_HISTORY_DONE"):
			return "deleted_entry"
		return ""
	# Part Four (REV 493)
	if not flag("EP1_PART4_DONE"):
		if not flag("EP1_ULLUS_RETURN_READY"):
			# REV 864: two lines after the hallway - the room and the walker, either first
			if flag("EP1_ULLUS_HALL_DONE") and not flag("EP1_WK_DONE") and (room_key == "streets" or flag("EP1_ULLUS_ROOM_DONE")):
				return "wing"
			if room_key == "ullus_room" or flag("EP1_ULLUS_HALL_DONE"):
				return "ullus_room"
			return "ullus_hallway"
		if not flag("EP1_REGISTRY_DONE"):
			return "alibi"
		if not flag("EP1_ULLUS_CLEARED"):
			return "call_tuvall_alibi"
		if not flag("EP1_DAREV_UNLOCKED"):
			return "serrin"
		if not flag("EP1_DAREV_DOOR_OPEN"):
			return "darev_door"
		if not (Case.has("DAREV_REMOVED") and Case.has("COORDS") and Case.has("DAREV_MESSAGE")):
			return "darev_room"
		if not Case.has("COUNCIL_LEADER_MISSING"):
			return "call_tuvall_darev"
		return ""
	# Part Five (REV 495)
	if not flag("EP1_BEAMED"):
		if not flag("EP1_EX_DEST_SET"):
			return "coordinates"
		if room_key == "waystation":     # REV 865
			if not flag("EP1_WS_FIXED"):
				return "waystation"
			if not flag("EP1_WS_VELIK_DONE"):
				return "ws_talk"
		if room_key == "desert":
			if not flag("EP1_DESERT_PATH_B"):
				return "desert"
			if not flag("EP1_LM_PAST"):
				return "lematya"     # REV 865
			if flag("EP1_HEAT_WARNED") and not flag("EP1_HEAT_DONE"):
				return "heat"
			if not flag("EP1_SENSOR_POWERED"):
				return "sensor"
		if room_key == "ruins_ext" and not flag("EP1_RUINS_OPEN"):
			return "ruins_door"
		if room_key == "gallery":     # REV 866
			if not flag("EP1_RG_FLOOR_DONE"):
				return "trap_floor"
			if not flag("EP1_RG_LIT"):
				return "light_well"
		if room_key == "ruins_int":
			if not flag("EP1_COUNCIL_FREED"):
				return "restraints"
			if not flag("EP1_BRACE_CUT"):
				return "brace"
			if not flag("EP1_DAREV_TREATED"):
				return "darev"
			if not flag("EP1_DAREV_INTERVIEW_DONE"):
				return "darev_talk"
			if not flag("EP1_DAREV_ON_STRETCHER") and flag("EP1_DAREV_INTERVIEW_DONE"):
				return "stretcher"
		return ""
	# Part Six (REV 497)
	if not flag("EP1_P6_STABLE"):
		return "stabilise"
	if not flag("EP1_NEURAL_DONE"):
		return "analyse"
	if not flag("EP1_P6_DATAPAD_DONE"):
		return "datapad"
	if not flag("EP1_P6_SPOCK_DONE"):
		return "spock"
	if flag("EP1_P6_REVIEW_DONE") and not flag("EP1_EPISODE_COMPLETE"):
		return "med_report"
	return ""


# ----------------------------------------------------------------- clues -----

static func _define_clues() -> void:
	if Case.is_defined("TURIAN"):
		return
	# --- VICTIM
	_define_part3_clues()
	_define_part4_clues()
	_define_part5_clues()
	_define_part6_clues()
	_define_street_clues()
	Case.define("TURIAN", "VICTIM", "AMBASSADOR TURIAN",
		"Romulan ambassador and the driving force behind the peace conference. Found dead in his private quarters about two hours before Tuvall called us in. Brought to Vulcan aboard the Enterprise less than a day ago.")
	Case.define("DEATH_LOCATION", "VICTIM", "DEATH LOCATION: TURIAN'S QUARTERS",
		"Turian was found in his private quarters.")
	# --- SUSPECT
	Case.define("ULLUS", "SUSPECT", "AMBASSADOR ULLUS",
		"Tellarite ambassador from Tellar Prime. Detained by Vulcan security as the suspect in Turian's death.\n\nDETENTION RECORD: APPROXIMATE MASS RANGE 85-100 KG.")
	Case.define("MOTIVE", "SUSPECT", "MOTIVE: POLITICAL HOSTILITY",
		"Ullus opposed Turian over Romulus. He argued with him loudly. Whether that is a motive for murder is not established.")
	# --- WITNESS
	Case.define("ARGUED", "WITNESS STATEMENTS", "ULLUS AND TURIAN ARGUED",
		"A witness confirms the two argued shortly before Turian's death. Ullus admits it.")
	Case.define("ULLUS_DENIES", "WITNESS STATEMENTS", "ULLUS DENIES KILLING TURIAN",
		"Ullus admits the argument. He insists he left Turian alive.")
	Case.define("ULLUS_MOVEMENTS", "WITNESS STATEMENTS", "ULLUS' CLAIMED MOVEMENTS",
		"Ullus says he left Turian alive, went to his own quarters, then to Serrin's office lobby, and never returned to Turian's room.")
	Case.define("ULLUS_STATEMENT", "WITNESS STATEMENTS", "ULLUS' STATEMENT TO VULCAN SECURITY",
		"Obtained after prolonged questioning. Ullus admits the argument and admits making threats in anger, but his acceptance of responsibility is not based on any direct memory of causing Turian's death.\n\nCLAIMS REQUIRE INDEPENDENT VERIFICATION.")
	Case.define("DATAPAD_POSSESSED", "WITNESS STATEMENTS", "TURIAN HAD A PERSONAL DATAPAD",
		"Ullus says Turian kept checking a personal datapad shortly before his death. 'There are things neither of our peoples were meant to forget.'")
	# --- PHYSICAL
	Case.define("CRED_NEAR", "PHYSICAL EVIDENCE", "ULLUS' ACCESS CREDENTIAL NEAR TURIAN'S QUARTERS",
		"Vulcan security says Ullus' access credential was detected near Turian's quarters.")
	Case.define("PHYS_RECOVERED", "PHYSICAL EVIDENCE", "ULLUS-RELATED PHYSICAL EVIDENCE RECOVERED",
		"Material belonging to Ullus was recovered at the scene. Not yet examined.")
	Case.define("TIMELINE", "PHYSICAL EVIDENCE", "OFFICIAL MURDER TIMELINE",
		"Vulcan security's timeline:\n  - Turian / Ullus argument\n  - Ullus departs\n  - Ullus credential detected near Turian's quarters\n  - Turian found\n\nProves nothing by itself. Somebody made this timeline.")
	Case.define("MANIFEST", "PHYSICAL EVIDENCE", "EVIDENCE MANIFEST",
		"Items logged by Vulcan security:\n  - Ullus access token\n  - Tellarite ceremonial clasp\n  - Biological sample\n  - Turian's clothing\n  - Turian's diplomatic credentials\n  - Broken decorative object")
	Case.define("CRED_PRESENT", "PHYSICAL EVIDENCE", "ULLUS' CREDENTIAL WAS PRESENT",
		"The access token's movement history confirms the credential registered near Turian's quarters.\n\nNote the wording: the CREDENTIAL was present. That is not the same as ULLUS.")
	Case.define("CLASP", "PHYSICAL EVIDENCE", "ULLUS' CEREMONIAL CLASP FOUND IN TURIAN'S ROOM",
		"Tellarite manufacture. Biological residue consistent with Ullus. The clasp is not broken; its mounting is intact.")
	Case.define("BIO", "PHYSICAL EVIDENCE", "TELLARITE BIOLOGICAL MATERIAL",
		"Tellarite epithelial cells, recently deposited. Recovered from a drinking vessel in Turian's room. At face value, damning.")
	Case.define("CLASP_SET", "PHYSICAL EVIDENCE", "ULLUS' FORMAL CLOTHING: MATCHED CEREMONIAL SET",
		"In Ullus' property: formal dress ornaments, one of which is part of a matched Tellarite ceremonial set.")
	# --- MEDICAL
	Case.define("COD_UNKNOWN", "MEDICAL FINDINGS", "PRELIMINARY CAUSE OF DEATH: UNKNOWN",
		"Vulcan doctors found no immediately apparent cause of death.")
	Case.define("NEURAL_INCOMPLETE", "MEDICAL FINDINGS", "INCOMPLETE NEURAL SCAN",
		"The preliminary neural scan was stopped before it finished and shows anomalous readings. The Vulcan examiner halted it when evidence implicating a Federation diplomat turned up.")
	Case.define("NO_TRAUMA", "MEDICAL FINDINGS", "NO OBVIOUS LETHAL PHYSICAL TRAUMA",
		"Turian's clothing shows no damage consistent with a struggle violent enough to explain his death. Reinforces the preliminary examination; does not establish a cause.")
	Case.define("NO_EXTERNAL_INJURY", "MEDICAL FINDINGS", "NO EXTERNAL INJURY EXPLAINS DEATH",
		"No blunt-force trauma, no strangulation injury, no penetrating wound, no defensive injuries.")
	Case.define("NO_TOXIN", "MEDICAL FINDINGS", "NO IDENTIFIED LETHAL TOXIN",
		"Common, Romulan and Tellarite compounds all negative; broad-spectrum screen found nothing lethal.")
	Case.define("COD_NEURAL", "MEDICAL FINDINGS", "CAUSE OF DEATH: CATASTROPHIC NEURAL OVERLOAD",
		"Neural overload came first, then autonomic failure, then cardiac arrest, then death. His heart didn't kill him. Something overloaded his nervous system.")
	# --- QUESTIONS
	Case.define("Q_DATAPAD", "UNRESOLVED QUESTIONS", "WHERE IS TURIAN'S DATAPAD?",
		"Ullus says Turian had a personal datapad shortly before his death.")
	Case.define("Q_VESSEL", "UNRESOLVED QUESTIONS", "HOW DID ULLUS' BIOLOGICAL MATERIAL GET ON THE VESSEL?",
		"Not answered.")
	Case.define("Q_SEARCHED", "UNRESOLVED QUESTIONS", "WAS TURIAN'S ROOM SEARCHED?",
		"Several storage compartments were found open in the crime-scene images. Nobody can say whether Turian left them that way.")
	Case.define("Q_VERIFY", "UNRESOLVED QUESTIONS", "CAN ULLUS' MOVEMENTS BE VERIFIED?",
		"Ullus says he lodged a procedural objection at Serrin's office. Several delegates saw him later, but he cannot account for every minute.")
	# --- PERSONS
	Case.define("ROMULAN_ACCESS", "PERSONS OF INTEREST", "POSSIBLE ACCESS: ROMULAN DELEGATION PERSONNEL",
		"Turian was surrounded by Romulan diplomatic personnel throughout the conference. Some of them he believed supported the peace initiative. No accusation.")
	Case.define("OTARI", "PERSONS OF INTEREST", "OTARI - TURIAN'S AIDE",
		"Ullus says Otari was rarely more than a pace from Turian and certainly knew about the datapad.")
	# --- DEDUCTIONS
	Case.define("CONTRADICTION", "DEDUCTIONS", "ULLUS' STATEMENT CONFLICTS WITH ACCESS LOG",
		"ULLUS CLAIM: returned to own quarters.\nSECURITY RECORD: Ullus' credential later detected near Turian.\n\nOne of them is wrong.")
	Case.define("DATAPAD_MISSING", "DEDUCTIONS", "TURIAN'S DATAPAD IS MISSING",
		"Ullus saw Turian with it before he died. It is not on the evidence manifest. Somebody removed it, or Vulcan security never found it.")
	Case.define("STRUGGLE", "DEDUCTIONS", "POSSIBLE STRUGGLE",
		"The broken decorative object could have been knocked over in a struggle. Not confirmed.")
	Case.define("SEARCH", "DEDUCTIONS", "POSSIBLE SEARCH",
		"Or it could have been knocked over by somebody searching the room. Not confirmed.")
	Case.define("EVIDENCE_NO_EXPLAIN", "DEDUCTIONS", "EVIDENCE AGAINST ULLUS DOES NOT EXPLAIN CAUSE OF DEATH",
		"The argument, the credential, the clasp and the Tellarite cells: none of it explains catastrophic neural overload. This does not clear Ullus, but the simple murder case is starting to collapse.")


static func _define_part4_clues() -> void:
	# Ullus' hallway
	Case.define("ENV_SUPPORTS", "PHYSICAL EVIDENCE", "ENVIRONMENTAL RECORD SUPPORTS ULLUS' ACCOUNT",
		"The corridor's atmospheric compensator was not altered. It logs mass, direction and time, not identity. A person of Ullus' mass entered the corridor and approached Ullus' room, then left toward the main exit several minutes later. Not absolute proof, but the record is untouched.")
	Case.define("VISITOR_LOITER", "PHYSICAL EVIDENCE", "SOMEONE LINGERED AT ULLUS' DOOR AFTER HE LEFT",
		"A lighter person approached Ullus' room and stayed near the door for almost two minutes. The door log says NO ENTRY.")
	Case.define("Q_VISITOR", "UNRESOLVED QUESTIONS", "WHO APPROACHED ULLUS' ROOM AFTER HE LEFT?",
		"Not identified. The compensator doesn't record identity.")
	# Ullus' room
	Case.define("GARMENT_MOUNTS", "PHYSICAL EVIDENCE", "ULLUS' GARMENT: ONE CLASP MISSING FROM A MATCHED SET",
		"The garment has mounting points for a matched set of ceremonial clasps. One is missing. It matches the clasp found in Turian's room.")
	Case.define("CLASP_MOUNT_CLEAN", "PHYSICAL EVIDENCE", "CLASP WAS REMOVED CLEANLY FROM ULLUS' CLOTHING",
		"The fibres around the empty mount are not torn. No damage consistent with the clasp being ripped free in a struggle. Doesn't prove who removed it.")
	Case.define("CLASP_STORAGE_RESIDUE", "PHYSICAL EVIDENCE", "CLASP RESIDUE IN ULLUS' STORAGE",
		"Microscopic residue in a fitted recess in Ullus' storage. The clasp was kept here at some point.")
	# REV 268 (GAMEPLAY LOCKED): the clasp finding is hedged - it does not prove who moved it
	Case.define("CLASP_PLANTED", "DEDUCTIONS", "ULLUS' CLASP WAS REMOVED CLEANLY, STORED IN HIS QUARTERS, AND LATER APPEARED AT TURIAN'S CRIME SCENE",
		"Ullus wasn't wearing it when he confronted Turian, so it wasn't torn off him in a struggle. This does not prove who removed or moved it. The official struggle theory is inconsistent with the physical evidence; deliberate placement is the strongest working hypothesis.")
	Case.define("DOOR_OVERRIDE", "PHYSICAL EVIDENCE", "ULLUS' ROOM WAS ACCESSED THROUGH A MAINTENANCE OVERRIDE",
		"The lock's override buffer shows a temporary technical authorisation: the same class found in the Maintenance Room. The ordinary door log claims no unauthorised entry.")
	Case.define("ULLUS_VESSEL", "PHYSICAL EVIDENCE", "ULLUS' DRINKING VESSEL IN HIS OWN ROOM",
		"Ullus' epithelial cells are present. Nothing surprising. But the cells look a lot like the sample from Turian's room.")
	Case.define("SAMPLE_TRANSFER", "DEDUCTIONS", "BIOLOGICAL EVIDENCE MAY HAVE BEEN TRANSFERRED FROM ULLUS' QUARTERS",
		"Same kind of cells, same concentration, same distribution. McCoy can't prove it yet. But somebody could have lifted the cells from something Ullus used here and put them on the glass in Turian's room.")
	Case.define("FRAME_PREPARED", "DEDUCTIONS", "THE FRAME-UP WAS PREPARED, NOT IMPROVISED",
		"ORIGINAL CASE:\n  ULLUS ARGUED WITH TURIAN - TRUE (he admits it).\n  ULLUS' BIOLOGICAL MATERIAL IN THE ROOM - TRUE, but consistent with his admitted earlier visit, and potentially transferred.\n  ULLUS' CLASP IN THE ROOM - deliberate placement is the strongest hypothesis; the official struggle account is inconsistent with the physical evidence.\n  ULLUS' CREDENTIAL NEAR THE ROOM - a false security event.\n\nThe only completely solid fact remaining is that Ullus argued with Turian. That is nowhere near enough for murder.")
	# Return to the holding cell / Serrin's lobby
	Case.define("ULLUS_ALIBI_LEAD", "WITNESS STATEMENTS", "ULLUS WENT TO SERRIN'S OFFICE BUILDING",
		"After leaving his room, Ullus went straight to Serrin's office building and spoke to a receptionist, loudly.")
	Case.define("ALIBI_TIME", "DEDUCTIONS", "ULLUS WAS AT SERRIN'S OFFICE BUILDING DURING THE CRITICAL PERIOD",
		"Ullus filed a formal procedural objection while waiting. The timestamp overlaps the period when the falsified record placed his credential near Turian's quarters. His badge was in two places. Ullus wasn't.")
	# REV 268 (GAMEPLAY LOCKED): Ullus is NOT cleared here - only in Part Six, Act 6
	Case.define("ULLUS_EXONERATED", "DEDUCTIONS", "CASE AGAINST ULLUS SERIOUSLY COMPROMISED",
		"An independent record places Ullus at Serrin's office building while the manipulated credential trail placed his badge near Turian's quarters. Key evidence against him was manipulated. Enough to challenge the case - not yet the formal end of the Vulcan investigation. Tuvall acknowledges the evidence materially undermines the case; Ullus remains detained.")
	Case.define("NO_MEETING", "DEDUCTIONS", "NO EMERGENCY HIGH COUNCIL MEETING EXISTS",
		"Serrin left after receiving notice of an emergency High Council meeting. It is not on the office schedule or the official Council schedule.")
	Case.define("Q_SERRIN", "UNRESOLVED QUESTIONS", "SERRIN - DEPARTED AFTER FALSE HIGH COUNCIL MEETING NOTICE; CURRENT WHEREABOUTS UNCONFIRMED",
		"Not at his office. He may have received false information, misunderstood the communication, or left for some other reason.")
	# Serrin's office
	Case.define("SERRIN_CONTACT", "PHYSICAL EVIDENCE", "SERRIN HAD BEEN TRYING TO CONTACT THE COUNCIL LEADER",
		"Several attempts, no response. Last note: 'Unable to establish contact. Security staff investigating.' It was logged before the false emergency notice arrived.")
	Case.define("TURIAN_ARCHIVE_ACCESS", "PHYSICAL EVIDENCE", "TURIAN HAD LEGITIMATE ACCESS TO NORMALLY RESTRICTED MATERIAL",
		"His request for expanded historical archive access was authorised through senior Vulcan diplomatic channels. Nothing in the request identifies what he wanted.")
	Case.define("DAREV", "PERSONS OF INTEREST", "DAREV - TURIAN'S CHIEF OF SECURITY",
		"Romulan. Assigned security contact for the missing Council leader. Appears in communications connected to Serrin's failed attempts. Also missing.\n\nDIPLOMATIC RECORD: APPROXIMATE MASS RANGE 75-85 KG.")
	Case.define("Q_DAREV_GUILTY", "UNRESOLVED QUESTIONS", "DID DAREV MURDER TURIAN AND FLEE?",
		"A tempting theory: Darev killed Turian, took the datapad, framed Ullus and ran. Nothing supports it yet.")
	# Darev's hallway and room
	Case.define("DAREV_NO_EXIT", "PHYSICAL EVIDENCE", "DAREV ENTERED HIS ROOM AND DID NOT LEAVE THROUGH THE CORRIDOR",
		"The compensator logs one person of Darev's mass entering. No matching departure. This time the security record appears genuine.")
	Case.define("DAREV_COMM", "PHYSICAL EVIDENCE", "DAREV LEFT HIS COMMUNICATOR BEHIND",
		"His personal communicator and diplomatic credentials are in the room.")
	Case.define("DAREV_NO_FLIGHT", "DEDUCTIONS", "NO EVIDENCE DAREV FLED VOLUNTARILY",
		"His travel case is still packed. No sign he planned to leave Vulcan.")
	Case.define("DAREV_INJURED", "MEDICAL FINDINGS", "DAREV WAS INJURED IN HIS ROOM",
		"A tiny quantity of Romulan blood and floor abrasions. The blood matches Darev's medical profile.")
	Case.define("DAREV_REMOVED", "DEDUCTIONS", "DAREV WAS TAKEN THROUGH THE SERVICE ACCESS",
		"A brief confrontation, then movement toward the wall. He didn't leave through the hallway. Somebody took him out the back way.")
	Case.define("DAREV_MESSAGE", "PHYSICAL EVIDENCE", "TURIAN SENT DAREV AN ENCRYPTED MESSAGE BEFORE HE DIED",
		"Opened shortly before Darev disappeared. Origin: Ambassador Turian. Sent shortly before Turian's death. The message body can't be read.")
	Case.define("COORDS", "PHYSICAL EVIDENCE", "TURIAN SENT DAREV COORDINATES IN THE VULCAN DESERT",
		"Rebuilt from three fragments left in the terminal cache: GRID 3-7C, BEARING 217, RANGE 38 KM from Shi'Kahr. A region, not an exact destination.")
	Case.define("DESERT_PARTICULATE", "PHYSICAL EVIDENCE", "DESERT PARTICULATE IN THE SERVICE PASSAGE",
		"Recent traces of desert mineral dust inside a controlled diplomatic building.")
	Case.define("DAREV_TO_DESERT", "DEDUCTIONS", "DAREV MAY HAVE BEEN TAKEN TO THE DESERT LOCATION",
		"The dust matches the mineral composition of the region the coordinates point to.")
	Case.define("COUNCIL_LEADER_MISSING", "DEDUCTIONS", "THE LEADER OF THE VULCAN HIGH COUNCIL CANNOT BE LOCATED",
		"Commander Tuvall confirmed what Vulcan authorities had been trying to contain.")
	Case.define("P4_CONNECTION", "DEDUCTIONS", "TURIAN'S ARCHIVE DISCOVERY CONNECTS THE DISAPPEARANCES",
		"Why Ullus was framed is not settled: to hide what Turian copied, to end the conference, to distract us. Maybe all three. We have coordinates in the desert.")


## REV 283: what the Shi'Kahr streets can add. Only confirmed first-hand observations; each one narrows,
## removes a false option or corroborates - none of them is needed to finish.
static func _define_street_clues() -> void:
	Case.define("ST_SECURITY_MOVING", "WITNESS STATEMENTS", "CREW: SECURITY VEHICLES TO THE DIPLOMATIC DISTRICT",
		"An Enterprise crew member on shore leave watched Vulcan security vehicles head fast for the diplomatic district in the early evening.")
	Case.define("ST_DATAPAD_SEEN", "WITNESS STATEMENTS", "CREW: TURIAN CHECKING A PERSONAL DATAPAD",
		"A crew member at the conference's public session saw Turian keep checking a personal datapad, 'like he was waiting for something to change on it.' Corroborates Ullus.")
	Case.define("ST_ULLUS_TRANSIT", "WITNESS STATEMENTS", "CREW: A TELLARITE CROSSING TOWARD THE ADMINISTRATIVE QUARTER",
		"A crew member saw a robed Tellarite cross toward the administrative quarter just after seven, complaining loudly about the queues. Fits the window immediately after the argument.")
	Case.define("ST_RESTRICTED", "WITNESS STATEMENTS", "CREW: ONE DELEGATION BUILDING LOCKED DOWN HARDER",
		"A security crew member noticed access around one delegation building became much tighter than the others after the death. He was turned back himself.")
	Case.define("ST_DAREV_TRANSIT", "WITNESS STATEMENTS", "CREW: DAREV ON THE TRANSIT TERRACE",
		"A crew member identified Darev from his conference identification: he nearly walked through a group of them on the transit terrace, moving fast.")
	Case.define("ST_SERVICE_TAG", "PHYSICAL EVIDENCE", "DAMAGED SERVICE TAG FROM THE DIPLOMATIC WALKWAY",
		"Caught under a public maintenance kiosk where a crew member saw a cart blocking the walkway. ALLOCATION: TEMPORARY DIPLOMATIC MAINTENANCE. Issuing area illegible, technician torn away.")


static func _define_part6_clues() -> void:
	Case.define("DATAPAD_PEACE", "PHYSICAL EVIDENCE", "TURIAN'S DATAPAD: HE MEANT WHAT HE SAID ABOUT PEACE",
		"Correspondence and personal notes show a man who believed in the conference. Nothing suggests he knew it was being used for anything else.")
	Case.define("DATAPAD_ARCHIVE_DIR", "PHYSICAL EVIDENCE", "DATAPAD HOLDS RESTRICTED FILES COPIED FROM A VULCAN ARCHIVE",
		"Every file is marked ACCESS RESTRICTED. Filenames are encoded and mean nothing without their catalogue. Kirk won't risk destroying the device by forcing them.")
	Case.define("DATAPAD_TRANSFER_TIME", "PHYSICAL EVIDENCE", "THE ARCHIVE FILES WERE COPIED DURING TURIAN'S TIME ON VULCAN",
		"File properties show the transfer onto the datapad happened while Turian was on Vulcan. That is all they establish.")
	Case.define("U_WHEN", "WITNESS STATEMENTS", "DAREV: DATAPAD TRANSFER WAS AFTER TURIAN'S MEETING WITH ULLUS AND BEFORE HIS DEATH",
		"Witness testimony. Not independently established on its own.")
	Case.define("U_BEFORE", "WITNESS STATEMENTS", "DAREV: TURIAN GAVE IT TO HIM AFTER WORKING WITH THE VULCAN HISTORICAL RECORDS",
		"'Only that he had found something he could not risk losing.' Witness testimony.")
	Case.define("U_WHY", "WITNESS STATEMENTS", "DAREV: TURIAN ENTRUSTED IT AS A PRECAUTION, BEFORE HE KNEW WHO THREATENED HIM",
		"'I was responsible for his security. He trusted me. I don't think he knew.' Witness testimony.")
	Case.define("CHRONOLOGY", "DEDUCTIONS", "TURIAN ACCESSED THE RECORDS, COPIED THEM, THEN ENTRUSTED THE DATAPAD TO DAREV",
		"Established independently: archive access, datapad transfer timestamps and Darev's account agree. Whatever happened to Turian, it happened after he found these records.")
	Case.define("DATAPAD_SECURED", "PHYSICAL EVIDENCE", "TURIAN'S DATAPAD - SECURED ABOARD ENTERPRISE",
		"The data is intact. It cannot be read without further analysis. Contents unknown.")
	Case.define("CASE_FAILS", "DEDUCTIONS", "THE OFFICIAL CASE AGAINST ULLUS CANNOT ACCOUNT FOR THE ESTABLISHED EVIDENCE",
		"Three independent pillars: the medical contradiction, the physical-presence contradiction and the independent alibi.\n\nTHE EVIDENCE IS INSUFFICIENT TO SUSTAIN THE CLAIM THAT ULLUS MURDERED TURIAN.")
	Case.define("ULLUS_RELEASED", "DEDUCTIONS", "ULLUS - RELEASED / CASE AGAINST HIM UNSUSTAINED ON PRESENT EVIDENCE",
		"Vulcan authorities will release Ullus pending further investigation. The charges relating to Turian's death will not proceed on the present evidence.")
	Case.define("Q_TURIAN_KILLED", "UNRESOLVED QUESTIONS", "HOW WAS TURIAN KILLED?",
		"Unresolved. The investigation remains open.")
	Case.define("Q_TURIAN_FOUND", "UNRESOLVED QUESTIONS", "WHAT DID TURIAN FIND IN THE ARCHIVES?",
		"Unresolved. The datapad is secure; the contents are unknown.")


static func _define_part5_clues() -> void:
	Case.define("RESTRAINT_INTERIOR", "PHYSICAL EVIDENCE", "COUNCIL LEADER'S RESTRAINTS: VULCAN HARDWARE, ROMULAN INTERFACE",
		"Modern Vulcan manufacture, with a modified control assembly. Hidden inside it, a Romulan interface.")
	# Exterior Shi'Kahr
	Case.define("DEST_RUINS", "DEDUCTIONS", "TURIAN'S COORDINATES POINT TO THE SOUTHERN RUINS REGION",
		"The partial coordinates, the mineral trace from Darev's service passage and the recent dust-storm path all agree. Best match: the southern ruins region.")
	# Rock shelter
	Case.define("ROUTE_INJURED", "MEDICAL FINDINGS", "DAREV WAS INJURED AND AT TIMES SUPPORTED ALONG THE DESERT ROUTE",
		"Romulan blood in a protected footprint, consistent with the trace from Darev's room. The weight distribution shows that every few steps somebody else was taking part of his weight.")
	Case.define("ROMULAN_FRAGMENT", "PHYSICAL EVIDENCE", "ROMULAN MATERIAL FOUND ALONG THE DESERT ROUTE",
		"A metallic fragment of Romulan alloy. It might be Darev's. It might not.")
	Case.define("DAREV_MOVED", "DEDUCTIONS", "DAREV WAS MOVED FROM SHI'KAHR INTO THE DESERT AFTER BEING INJURED",
		"Whatever happened in his room didn't end there. Somebody kept him moving afterward.")
	Case.define("SCUFFED_ROCK", "PHYSICAL EVIDENCE", "FRESH ABRASIONS ON THE ROCK",
		"Low, irregular marks that normal foot traffic wouldn't make. Somebody went down hard here. A fall, or somebody fought being moved.")
	Case.define("Q_RESIST", "UNRESOLVED QUESTIONS", "DID ONE OF THE GROUP RESIST?",
		"Not yet established. Not yet allowed to assume Darev was a prisoner.")
	# Abandoned sensor
	Case.define("SENSOR_PROFILES", "PHYSICAL EVIDENCE", "FIELD SENSOR LOGGED FOUR LIFE SIGNS",
		"One Romulan profile, one Vulcan profile, two unreadable because of interference.")
	Case.define("FOUR_MOVED", "PHYSICAL EVIDENCE", "FOUR PEOPLE MOVED DIRECTLY TOWARD THE RUINS",
		"Group size four. Heading for the ancient ruins. Uneven but continuous rate. Minimal stops. No searching, no doubling back, no course corrections. At least one was physically compromised: one life sign kept changing pace while another adjusted to it.")
	Case.define("SENSOR_DISABLED", "PHYSICAL EVIDENCE", "THE FIELD SENSOR WAS DELIBERATELY DISABLED",
		"The antenna wasn't broken by weather. A specific control junction was severed. Whoever did it knew what the sensor was.")
	Case.define("PLANNED_ROUTE", "DEDUCTIONS", "THE GROUP'S MOVEMENT WAS PLANNED OR GUIDED BY SOMEONE FAMILIAR WITH THE ROUTE",
		"A deliberately disabled sensor on a route that goes straight to the ruins. This does not establish that every member of the group knew the route. It fits the missing Council leader and Darev. It doesn't say who the other two are.")
	# Narrow pass
	Case.define("TURNED_BACK", "PHYSICAL EVIDENCE", "ONE TRACK TURNED BACK",
		"A deep partial footprint, turned against the direction of travel. Somebody turned back, or tried to.")
	Case.define("RESTRAINT_FRAGMENT", "PHYSICAL EVIDENCE", "TORN RESTRAINT FRAGMENT",
		"Modern Vulcan manufacture, torn under load. Incomplete.")
	Case.define("AGAINST_WILL", "DEDUCTIONS", "AT LEAST ONE MEMBER OF THE GROUP WAS BEING MOVED AGAINST THEIR WILL",
		"The scuffed rock, the irregular movement and the torn restraint fragment together. Four people, at least one prisoner, straight to the ruins.")
	# Ruins exterior
	Case.define("DISCARDED_RESTRAINT", "PHYSICAL EVIDENCE", "DISCARDED RESTRAINT AT THE RUINS",
		"Vulcan manufacture, used by contemporary security services. Broken forcibly.")
	Case.define("PRISONER_FORCED", "DEDUCTIONS", "AT LEAST ONE PRISONER WAS FORCIBLY BROUGHT TO THE RUINS",
		"The discarded restraint and the fragment from the narrow pass came from the same restraint. It started breaking back there. Whoever wore it had been fighting it for a while.")
	Case.define("DESERT_RECONSTRUCTED", "DEDUCTIONS", "DESERT MOVEMENT RECONSTRUCTED",
		"A group of four moved from Shi'Kahr toward the ruins. At least one Vulcan and one Romulan. At least one injured. At least one moved against their will. Direct route, taking steps to avoid detection. Someone involved knew the route and destination in advance. This wasn't a flight into the desert. Somebody brought them here.")
	# Ruins interior
	Case.define("RESTRAINT_REPURPOSED", "DEDUCTIONS", "THE ABDUCTORS REPURPOSED VULCAN SECURITY EQUIPMENT",
		"Vulcan hardware with a concealed Romulan control interface. Somebody went to a lot of trouble to make one look like the other, or had access to both.")
	Case.define("Q_EQUIPMENT", "UNRESOLVED QUESTIONS", "WHICH VULCAN PERSONNEL OR ACCESS CHANNEL PROVIDED THE ABDUCTORS WITH SECURITY EQUIPMENT AND OVERRIDE CAPABILITY?",
		"Earlier evidence already shows the conspiracy could exploit Vulcan maintenance and security systems. Who enabled that access is not resolved in this episode.")
	# REV 268 (GAMEPLAY LOCKED): the ruins, the datapad's custody, the service passage
	Case.define("Q_ENTRY_SEQUENCE", "UNRESOLVED QUESTIONS", "HOW DID THE ABDUCTORS KNOW THE ANCIENT ENTRY SEQUENCE?",
		"Recent scoring and disturbed dust on the control symbols: the mechanism was operated recently. Either they'd been here before, or somebody told them how to get in.")
	Case.define("RUINS_OUTBOUND", "PHYSICAL EVIDENCE", "TWO SETS OF OUTBOUND TRAILS DEPARTED THE RUINS",
		"Two overlapping sets of fresher outbound disturbance through a narrow secondary exit; unreadable beyond the rock. Four came in. Two left - before Kirk and McCoy arrived. Destination unknown. The site appears to have been abandoned hastily.")
	Case.define("RUINS_PROFILES_MATCH", "DEDUCTIONS", "RUINS LIFE-SIGN PROFILES MATCH DAREV AND THE HIGH COUNCIL LEADER",
		"One Romulan, one Vulcan: the two profiles picked up coming in. The two who left were members of the four-person group, and were the abductors. Their hurried departure explains why the prisoners were left alive and restrained.")
	Case.define("DAREV_COUNCIL_WARNING", "WITNESS STATEMENTS", "DAREV: TURIAN TOLD HIM TO WARN THE COUNCIL",
		"'Turian told me... if anything happened to him, warn the Council. He thought the Vulcans might be in danger too.'\n\nCORROBORATION: Darev's account is independently supported by the High Council leader's testimony - Darev approached the leader to deliver Turian's warning.")
	Case.define("DATAPAD_RECOVERED_CONCEALED", "PHYSICAL EVIDENCE", "TURIAN'S PERSONAL DATAPAD - PHYSICALLY RECOVERED FROM DAREV'S DELIBERATELY CONCEALED BELONGINGS",
		"Found secured on Darev's person while he was unconscious. Kirk took possession of it.")
	Case.define("DATAPAD_CUSTODY_PHYSICAL", "PHYSICAL EVIDENCE", "DATAPAD CUSTODY - TURIAN -> DAREV -> KIRK",
		"PHYSICAL POSSESSION ESTABLISHED; HANDOFF CIRCUMSTANCES NOT YET CONFIRMED.")
	Case.define("CUSTODY_CORROBORATED", "DEDUCTIONS", "DATAPAD CUSTODY: TURIAN -> DAREV -> KIRK - CORROBORATED",
		"Established from independent evidence. The datapad passed into Darev's protective custody before the investigation recovered it - not theft by Darev after the murder.")
	Case.define("SERVICE_PASSAGE_USED", "PHYSICAL EVIDENCE", "SERVICE PASSAGE USED TWICE BETWEEN TURIAN'S MEETING WITH ULLUS AND HIS DEATH",
		"The passage-control buffer in Darev's room holds two earlier authorised movements: one shortly after Turian's meeting with Ullus, a second minutes later. Identities aren't stored. The passage connects the diplomatic residential area with the security corridor serving Darev's quarters.")
	Case.define("HANDOFF_ROUTE", "DEDUCTIONS", "A PHYSICALLY PLAUSIBLE HANDOFF ROUTE",
		"Darev's account, the service-passage movements and the datapad timestamps agree: the handoff could have happened by that route, in that window. Corroborated where the independent evidence supports it.")
	Case.define("COUNCIL_TESTIMONY", "WITNESS STATEMENTS", "HIGH COUNCIL LEADER'S ACCOUNT",
		"Darev approached the Council leader voluntarily and tried to deliver a warning. Before he could explain, both were attacked. The Council leader never saw the attackers clearly. Not independently established; claims can be corroborated by independent evidence.")
	Case.define("DAREV_WARNED", "DEDUCTIONS", "DAREV WAS ATTEMPTING TO WARN THE HIGH COUNCIL",
		"He wasn't fleeing with the Council leader. He was trying to warn them when both were attacked. Darev: 'Turian found something he was never meant to find.'")
	Case.define("COUNCIL_RECOVERED", "VICTIM", "VULCAN HIGH COUNCIL LEADER - RECOVERED ALIVE",
		"The disappearance itself is resolved. Unresolved: why the Council leader was abducted, what access the abductors wanted, and who ordered it.")
	Case.define("Q_ABDUCTION_WHY", "UNRESOLVED QUESTIONS", "WHY WAS THE COUNCIL LEADER ABDUCTED, AND WHO ORDERED IT?",
		"What access the abductors wanted. Who gave the order.")
	Case.define("DAREV_FOUND", "VICTIM", "DAREV - FOUND ALIVE IN THE RUINS",
		"Unconscious, badly injured, not dead. Stabilised by McCoy. Not the villain: another victim.")
	Case.define("DAREV_ROMULANS", "WITNESS STATEMENTS", "DAREV: ROMULANS ATTACKED HIM",
		"'Romulans.' Members of his own delegation? 'They weren't... what Turian believed.' Testimony only; not independently established.")
	Case.define("DAREV_OLD_RECORDS", "WITNESS STATEMENTS", "DAREV: TURIAN FOUND OLD RECORDS, BEFORE THE SEPARATION",
		"Turian wouldn't tell Darev what the records were about. Testimony only.")
	Case.define("DAREV_ACCESS", "WITNESS STATEMENTS", "DAREV: THE COUNCIL LEADER WAS TAKEN FOR ACCESS",
		"Access to what? Darev couldn't say. Testimony only.")
	Case.define("DAREV_TRUST", "WITNESS STATEMENTS", "DAREV: 'NOT ALL OF US.' 'TURIAN BELIEVED THEM.'",
		"A warning about who can be trusted. Testimony only.")
	Case.define("DATAPAD_CUSTODY", "PHYSICAL EVIDENCE", "TURIAN ENTRUSTED HIS DATAPAD TO DAREV BEFORE HIS DEATH",
		"CHAIN OF CUSTODY: TURIAN -> DAREV -> KIRK.\n\nTurian told him to protect it. From whom? 'He didn't know. That was the problem.' The datapad is now with Kirk and will return to the Enterprise.\n\nDarev's account is testimony, not independently established fact.")
	Case.define("DAREV_NEURAL", "MEDICAL FINDINGS", "DAREV - NEURAL TRAUMA DETECTED (PRELIMINARY)",
		"Unusual. Doesn't match the exposure or captivity injuries. McCoy can't tell what it means with a field tricorder: 'I want a better look at this when we get him back aboard.'")
	# Sickbay
	# REV 293: NEURAL_CONFIRMED is never added - Sickbay rewords DAREV_NEURAL to say this instead. Kept
	# defined so nothing that names it breaks; the audit and the debug scene select leave it out.
	Case.define("NEURAL_CONFIRMED", "MEDICAL FINDINGS", "DAREV: UNEXPLAINED NEURAL TRAUMA CONFIRMED",
		"Separated from exposure damage and physical trauma, the neural pattern is abnormal and matches neither. CAUSE: UNKNOWN.")
	Case.define("P5_CONCLUSION", "DEDUCTIONS", "ALMOST THE WHOLE CONSPIRACY, RECONSTRUCTED",
		"Turian found something in the archives, copied it, grew afraid, entrusted it to Darev, was killed. Ullus was framed. Darev tried to warn the Vulcans, and he and the Council leader were abducted. Darev survived and gave the datapad to Kirk.\n\nUNANSWERED: WHAT DID TURIAN FIND? HOW WAS TURIAN KILLED?")


static func _define_part3_clues() -> void:
	Case.define("STRUGGLE_UNRELATED", "DEDUCTIONS", "APPARENT STRUGGLE MAY BE UNRELATED TO CAUSE OF DEATH",
		"Turian's body position fits a sudden collapse. If there was a struggle, it isn't what killed him.")
	Case.define("VESSELS", "PHYSICAL EVIDENCE", "TWO DRINKING VESSELS IN TURIAN'S ROOM",
		"The crime-scene record shows two vessels. One held Tellarite cells; the other held Turian's.")
	Case.define("BIO_CONSISTENT", "DEDUCTIONS", "TELLARITE MATERIAL CONSISTENT WITH ULLUS' STATEMENT",
		"Ullus never denied being in the room. Turian apparently offered him a drink. The cells prove he was there, which he told us. They don't show what happened afterward.")
	Case.define("Q_CLASP_ENTRY", "UNRESOLVED QUESTIONS", "HOW DID ULLUS' CLASP ENTER TURIAN'S ROOM?",
		"Found near Turian's desk, with no obvious reason to be there. Either Ullus lost it, or somebody wanted it found. Stays open until Ullus' own room can be examined.")
	Case.define("DATAPAD_CONCEALED", "PHYSICAL EVIDENCE", "TURIAN CONCEALED HIS DATAPAD IN THE DESK",
		"A concealed compartment behind the desk holds an empty datapad dock with a recent power transfer. The datapad is gone.")
	Case.define("TERMINAL_POSTMORTEM", "PHYSICAL EVIDENCE", "TURIAN'S TERMINAL ACCESSED AFTER HIS DEATH",
		"The terminal logs an unknown device connection after Turian died. The person is not identified.")
	Case.define("MAINT_ROUTE", "PHYSICAL EVIDENCE", "POST-MORTEM ACCESS ROUTED THROUGH THE LOCAL MAINTENANCE NETWORK",
		"Not the diplomatic network. Building maintenance.")
	Case.define("TURIAN_DISCOVERY", "WITNESS STATEMENTS", "TURIAN DISCOVERED SOMETHING ON VULCAN",
		"'There is more here than I expected. I will explain when I am certain.' (Turian, to Otari.)")
	Case.define("ENCRYPTED_COPY", "PHYSICAL EVIDENCE", "TURIAN COPIED ENCRYPTED HISTORICAL DATA",
		"An archive session shows an encrypted transfer. The data itself is gone, and so is whatever he moved it onto.")
	Case.define("OTARI_STATEMENT", "WITNESS STATEMENTS", "OTARI'S STATEMENT",
		"Turian became secretive after accessing Vulcan historical archives. 'If this is genuine, there are people on both worlds who would kill to possess it.' Otari says he doesn't know what it was. Truthful, perhaps. Not necessarily complete.")
	Case.define("UNKNOWN_KNEW", "PERSONS OF INTEREST", "UNKNOWN DELEGATION MEMBERS MAY HAVE KNOWN OF TURIAN'S RESEARCH",
		"Turian discussed his work with a few senior members of the delegation. Otari won't name them without proof. Names to follow.")
	Case.define("MAINT_BEFORE_DEATH", "WITNESS STATEMENTS", "MAINTENANCE ACCESS OCCURRED BEFORE TURIAN'S DEATH",
		"Turian complained earlier that day about his room's environmental controls. Maintenance personnel attended.")
	Case.define("FALSE_EVENT", "DEDUCTIONS", "ULLUS' ACCESS RECORD CAN BE REPRODUCED WITHOUT HIM",
		"The maintenance system can make the security network record any credential at any sensor. Ullus' record near Turian's quarters could have been made without Ullus or his credential being there.")
	Case.define("DELETED_ENTRY", "PHYSICAL EVIDENCE", "SECURITY SYSTEM WAS USED TO GENERATE A FALSE CREDENTIAL EVENT",
		"A deleted diagnostic entry: CREDENTIAL SIMULATION, identifier redacted, sensor Turian Corridor, time matching the post-argument window. CONFIRMED.\n\nWhose badge was simulated? The identifier was erased. We know which badge turned up.")
	Case.define("FRAMED", "DEDUCTIONS", "ULLUS WAS FRAMED USING THE MAINTENANCE NETWORK",
		"STRONGLY INDICATED. Not proven.")
	Case.define("DELEGATION_ACCESS", "PERSONS OF INTEREST", "FRAME-UP ORIGINATED FROM ACCESS ASSOCIATED WITH THE ROMULAN DELEGATION",
		"A temporary diplomatic maintenance authorisation, issued on the day of Turian's death, traces to Turian's delegation area. The personal identifier is corrupted. No individual is identified.")
	Case.define("P3_CONCLUSION", "DEDUCTIONS", "ULLUS WAS FRAMED",
		"Turian found something in the Vulcan archives and copied it. He was killed. His room was searched and his datapad is missing. Security records were manipulated to implicate Ullus.\n\nThat is what we can prove. We keep digging.")


# -------------------------------------------------------------- comparing ----

# =========================================================================
# REV 476 (the redesign, docs/design/redesign/EPISODE1_PLAN.md): NO CASE FILE ON SCREEN. The clues are
# still kept (they're what Kirk and McCoy remember, and what the story checks), but the player never
# opens a notebook, compares cards or picks a conclusion from a menu. When two things that mean
# something together are both known, Kirk and McCoy simply say it, right after the moment that found
# the second one (EpisodeRoom._auto_reason, after every scene). The same goes for the big deductions:
# they play as conversations the moment their facts are in.
# =========================================================================
const CASE_FILE := false

## Connections the characters make by themselves: [rule (Ep1Compare.run), clues needed, done when].
## "Done when" is a clue id, or a flag (EP1_...) - once it is set the rule never plays again.
const AUTO_CONNECTIONS: Array = [
	["movements_vs_timeline", ["ULLUS_MOVEMENTS", "TIMELINE"], "CONTRADICTION"],
	# REV 490: the datapad and the clasp set are found by hand now (SHOW the manifest to Ullus or ask the
	# custodian; USE the clasp recording on the ornaments in the cell) - no automatic connection for them
	["bio_vs_vessels", ["BIO", "VESSELS"], "BIO_CONSISTENT"],
	["clasp_deduction", ["CLASP", "CLASP_MOUNT_CLEAN", "CLASP_STORAGE_RESIDUE"], "CLASP_PLANTED"],
	["vessel_vs_bio", ["ULLUS_VESSEL", "BIO"], "SAMPLE_TRANSFER"],
	["postmortem_vs_maintenance", ["TERMINAL_POSTMORTEM", "MAINT_BEFORE_DEATH"], "EP1_MAINT_UNLOCKED"],
	["particulate_vs_coords", ["DESERT_PARTICULATE", "COORDS"], "DAREV_TO_DESERT"],
	["darev_moved", ["DAREV_INJURED", "ROUTE_INJURED"], "DAREV_MOVED"],
	["planned_route", ["SENSOR_DISABLED", "FOUR_MOVED"], "PLANNED_ROUTE"],
	["against_will", ["SCUFFED_ROCK", "ROUTE_INJURED", "RESTRAINT_FRAGMENT"], "AGAINST_WILL"],
	["restraint_match", ["RESTRAINT_FRAGMENT", "DISCARDED_RESTRAINT"], "PRISONER_FORCED"],
	["restraint_repurposed", ["DISCARDED_RESTRAINT", "RESTRAINT_INTERIOR"], "RESTRAINT_REPURPOSED"],
	["darev_target", ["COUNCIL_TESTIMONY", "DAREV_REMOVED", "ROUTE_INJURED"], "DAREV_WARNED"],
]


static func _done(marker: String) -> bool:
	return flag(marker) if marker.begins_with("EP1_") else Case.has(marker)


## The next connection whose clues are all known and which hasn't been made yet ("" = none).
static func next_auto_connection() -> String:
	for c in AUTO_CONNECTIONS:
		if _done(String(c[2])):
			continue
		var ready := true
		for id in c[1]:
			if not Case.has(String(id)):
				ready = false
		if ready:
			return String(c[0])
	return ""


## After a connection has played: make sure it is marked done even if its scene had nothing to add.
static func mark_connection(rule: String) -> void:
	for c in AUTO_CONNECTIONS:
		if String(c[0]) == rule and String(c[2]).begins_with("EP1_"):
			set_flag(String(c[2]))


## The big deduction to play now ("" = none). Like pending_deduction, but Part Six waits until all
## three pillars of the case against Ullus can stand (otherwise Kirk would keep saying "not yet").
static func pending_deduction_auto() -> String:
	var key := pending_deduction()
	if key == "part6":
		for i in RECON.size():
			if not recon_category_ready(i):
				return ""
	return key


## Comparisons that mean something: [clue A, clue B, rule id]. Order doesn't matter.
const COMPARE_RULES: Array = [
	["ULLUS_MOVEMENTS", "TIMELINE", "movements_vs_timeline"],
	["DATAPAD_POSSESSED", "MANIFEST", "datapad_vs_manifest"],
	["CLASP", "CLASP_SET", "clasp_vs_set"],
	["BIO", "VESSELS", "bio_vs_vessels"],
	["CLASP_MOUNT_CLEAN", "CLASP_STORAGE_RESIDUE", "clasp_deduction"],
	["CLASP_STORAGE_RESIDUE", "CLASP", "clasp_deduction"],
	["CLASP_MOUNT_CLEAN", "CLASP", "clasp_deduction"],
	["ULLUS_VESSEL", "BIO", "vessel_vs_bio"],
	["DESERT_PARTICULATE", "COORDS", "particulate_vs_coords"],
	["DAREV_INJURED", "ROUTE_INJURED", "darev_moved"],
	["SENSOR_DISABLED", "FOUR_MOVED", "planned_route"],
	["SCUFFED_ROCK", "ROUTE_INJURED", "against_will"],
	["SCUFFED_ROCK", "RESTRAINT_FRAGMENT", "against_will"],
	["ROUTE_INJURED", "RESTRAINT_FRAGMENT", "against_will"],
	["RESTRAINT_FRAGMENT", "DISCARDED_RESTRAINT", "restraint_match"],
	["DISCARDED_RESTRAINT", "RESTRAINT_INTERIOR", "restraint_repurposed"],
	["COUNCIL_TESTIMONY", "DAREV_REMOVED", "darev_target"],
	["COUNCIL_TESTIMONY", "ROUTE_INJURED", "darev_target"],
	["TERMINAL_POSTMORTEM", "MAINT_BEFORE_DEATH", "postmortem_vs_maintenance"],
]


## The Hub One deduction: three established facts open it.
static func hub1_ready() -> bool:
	if flag("EP1_HUB1_DEDUCTION_DONE") or not flag("EP1_AUTHORITY_GRANTED"):
		return false
	return hub1_ticks().size() == HUB1_WORDS.size()     # REV 860: four words - the delegations too


## REV 490 (EPISODE1_SCRIPT.md, Hub One): the tracker's three words, each ticked by its room's big moment -
## ULLUS once he's told you about the datapad, THE EVIDENCE once the sample is analysed and the ornament
## put back together, THE BODY once the neural scan is done and Turian is on his way to the Enterprise.
static func hub1_ticks() -> Array:
	var out: Array = []
	if Case.has("DATAPAD_POSSESSED"):
		out.append("ULLUS")
	if flag("EP1_EV_ANALYSED") and flag("EP1_EV_ORNAMENT_DONE"):
		out.append("THE EVIDENCE")
	if flag("EP1_TURIAN_TO_SHIP"):
		out.append("THE BODY")
	if flag("EP1_DL_GRATH_STAYS"):
		out.append("THE DELEGATIONS")     # REV 860
	return out


## REV 860: Hub One's four words (the fourth joins the tracker when Spock calls, EP1_DL_CALLED).
const HUB1_WORDS := ["ULLUS", "THE EVIDENCE", "THE BODY", "THE DELEGATIONS"]


## REV 860: where the lounge stands (a PARTNER key).
static func dl_stage() -> String:
	if flag("EP1_DL_HAS_FORM") or flag("EP1_DL_FORM_FILLED") or flag("EP1_DL_FORM_STAMPED"):
		return "dl_grievance"
	if flag("EP1_DL_SHRAS_MET") and not flag("EP1_DL_PLAN_REVISED"):
		return "dl_seating"
	return "hub1_delegations"


## REV 860: what the delegations' word says while it's open (the tracker is one line).
static func dl_word() -> String:
	if flag("EP1_DL_SHRAS_MET") and not flag("EP1_DL_PLAN_REVISED"):
		return "THE DELEGATIONS (FIX THE SEATING PLAN)"
	if flag("EP1_DL_ASKED_STAY") and not flag("EP1_DL_FORM_STAMPED"):
		return "THE DELEGATIONS (GET VULCAN TO ACKNOWLEDGE THE INSULT)"
	return "THE DELEGATIONS"


## REV 490: keeps the one-line tracker's live text right (EpisodeRoom calls it on arrival, on load and
## after every scene). Hub One shows the words still to do.
static func refresh_tracker() -> void:
	if ObjectiveManager.is_current("OBJ_EP1_HUB1"):
		var ticks := hub1_ticks()
		var left: Array = []
		for w in HUB1_WORDS:
			if w == "THE DELEGATIONS" and not flag("EP1_DL_CALLED"):
				continue     # REV 860: joins when Spock calls
			if not ticks.has(w):
				left.append(dl_word() if w == "THE DELEGATIONS" else w)
		var text := "INVESTIGATE TURIAN'S DEATH - " + (" / ".join(left) if not left.is_empty() else "TALK IT OVER")
		ObjectiveManager.show_objective("OBJ_EP1_HUB1", text, LOG_OBJECTIVE_ENTRY)


## REV 268 (GAMEPLAY LOCKED "Hub One deduction gate - reworked"): four core facts across three
## disciplines. Returns the facts still missing (empty = the deduction can run).
static func hub1_missing() -> Array:
	var missing: Array = []
	# 1. MEDICAL: the substantive stages of McCoy's examination, not just the neural scanner
	if not (Case.has("COD_NEURAL") and Case.has("NO_EXTERNAL_INJURY") and Case.has("NO_TOXIN") and Case.has("EVIDENCE_NO_EXPLAIN")):
		missing.append("MEDICAL: WHAT THE EXAMINATION RULES OUT")
	# 2. FORENSIC: the access token, the biological sample and one contextual crime-scene record
	var context := false
	# REV 296: Q_SEARCHED (the evidence room's crime-scene images) is a contextual record too
	for id in ["STRUGGLE", "SEARCH", "Q_VESSEL", "NO_TRAUMA", "BIO_CONSISTENT", "Q_SEARCHED"]:
		if Case.has(id):
			context = true
	if not (Case.has("CRED_PRESENT") and Case.has("BIO") and context):
		missing.append("FORENSIC: WHAT THE PHYSICAL EVIDENCE ACTUALLY SHOWS")
	# 3. WITNESS: Ullus says Turian had a personal datapad
	if not Case.has("DATAPAD_POSSESSED"):
		missing.append("WITNESS: WHAT ULLUS SAW")
	# 4. RECORDS: the datapad is absent from the recovered evidence
	if not Case.has("DATAPAD_MISSING"):
		missing.append("RECORDS: WHAT THE EVIDENCE MANIFEST LEAVES OUT")
	return missing


## The Part Three deduction ("RECONSTRUCT THE CRIME"): six established facts.
static func part3_ready() -> bool:
	if flag("EP1_PART3_DONE"):
		return false
	for id in ["DATAPAD_MISSING", "TERMINAL_POSTMORTEM", "ENCRYPTED_COPY", "OTARI_STATEMENT", "FALSE_EVENT", "DELETED_ENTRY", "DELEGATION_ACCESS"]:
		if not Case.has(id):
			return false
	return true


## The Part Four deduction: what connects the disappearances?
static func part4_ready() -> bool:
	if flag("EP1_PART4_DONE"):
		return false
	return Case.has("COUNCIL_LEADER_MISSING")


## The five findings that let the player approach the ruins.
const DESERT_GATE: Array = [
	["FOUR_MOVED", "FOUR INDIVIDUALS MOVED TOWARD THE RUINS", "the abandoned field sensor"],
	["ROUTE_INJURED", "AT LEAST ONE MEMBER WAS PHYSICALLY COMPROMISED", "the rock shelter"],
	["AGAINST_WILL", "AT LEAST ONE MEMBER WAS BEING MOVED AGAINST THEIR WILL", "the rock shelter and the narrow pass"],
	["SENSOR_DISABLED", "THE FIELD SENSOR WAS DELIBERATELY DISABLED", "the abandoned field sensor"],
	["PLANNED_ROUTE", "THE GROUP MOVED DIRECTLY TOWARD A PREDETERMINED DESTINATION", "the abandoned field sensor"],
]


static func desert_gate_ok() -> bool:
	for g in DESERT_GATE:
		if not Case.has(String(g[0])):
			return false
	return true


static func desert_ready() -> bool:
	return false     # REV 495 (EPISODE1_SCRIPT.md): no reconstruction screen - the ruins door is the gate


## Part Six: once Spock has helped establish the chronology.
static func part6_ready() -> bool:
	return false     # REV 497: the reconstruction is Kirk's demonstration in Tuvall's office now


## The three independent pillars of the reconstruction (REV 268, GAMEPLAY LOCKED Act 5 - "not a
## four-box checklist"). Each: [key, heading, question, correct clue ids, suspicious ids ("suspicion
## isn't proof"), unexplained ids ("we don't know what it means")]. The pressured statement and the
## archive/datapad chronology are supporting evidence only - never gates.
const RECON: Array = [
	["medical", "MEDICAL CONTRADICTION", "WHAT DOES THE MEDICAL EVIDENCE SAY ACTUALLY KILLED TURIAN?",
		["COD_NEURAL", "EVIDENCE_NO_EXPLAIN"], ["MOTIVE", "ARGUED", "STRUGGLE_UNRELATED"], ["COD_UNKNOWN"]],
	["physical", "PHYSICAL-PRESENCE CONTRADICTION", "DOES THE PHYSICAL EVIDENCE RELIABLY PLACE ULLUS AT THE MURDER?",
		["FALSE_EVENT", "DELETED_ENTRY", "CLASP_PLANTED", "FRAMED", "BIO_CONSISTENT", "SAMPLE_TRANSFER"], ["CRED_NEAR", "CLASP", "BIO"], ["ULLUS_VESSEL", "Q_CLASP_ENTRY"]],
	["alibi", "INDEPENDENT ALIBI / TIMELINE CONTRADICTION", "WHAT INDEPENDENT EVIDENCE CONFLICTS WITH THAT PLACEMENT?",
		["ALIBI_TIME", "ULLUS_EXONERATED"], ["ULLUS_STATEMENT", "ULLUS_MOVEMENTS", "ENV_SUPPORTS"], ["CONTRADICTION", "TIMELINE"]],
]


## REV 306 (design review 3.5, "USE one inventory object ON another"): Episode 1's carried things as
## real backpack items. The story still runs on its flags; the backpack MIRRORS them (sync_items, every
## room, every load): an item is in the backpack while its "have" flag is set and its "gone" flag isn't.
## id -> [have flag, gone flag ("" = never), name, description]
const ITEMS := {
	# REV 490 (EPISODE1_SCRIPT.md inventory): an optional 5th column is the icon picture
	"EP1_ITEM_MEDKIT": ["EP1_STARTED", "", "Medical Kit",
		"McCoy's medical kit: defibrillator leads, an air bulb, antiseptic powder, a hypospray. And a stylus - mostly for signing other doctors' mistakes.",
		"res://assets/ui/icons/icon_medkit.png"],
	"EP1_ITEM_CREDENTIAL": ["EP1_HAS_CREDENTIAL", "", "Investigative Credential",
		"Commander Tuvall's investigative credential. It opens the doors you need. It also records every door it opens."],
	"EP1_ITEM_TIMELINE": ["EP1_TIMELINE_VIEWED", "", "Security Timeline (data card)",
		"Vulcan Security's timeline, copied from Tuvall's terminal:\n18:42  Turian / Ullus argument\n19:05  Ullus departs\n19:37  Ullus' credential near Turian's quarters\n20:14  Turian found"],
	"EP1_ITEM_MANIFEST": ["EP1_MANIFEST_VIEWED", "", "Evidence Manifest (data card)",
		"What Vulcan Security recovered from Turian's quarters: Ullus' access token, a Tellarite ceremonial clasp, a biological sample, Turian's clothing, his diplomatic credentials, a broken decorative object."],
	"EP1_ITEM_CLASP_REC": ["EP1_CLASP_RECORDED", "", "Clasp Recording (tricorder)",
		"A tricorder recording of Ullus' ceremonial clasp from the evidence room - every angle, every mark on the mounting."],
	"EP1_ITEM_READOUT": ["EP1_AUTOPSY_NEURAL_DONE", "", "Neural Scan Readout",
		"Turian's completed neural scan: catastrophic neural overload - cortex, autonomic centres, then the heart."],
	"EP1_ITEM_ACCESS_LOG": ["EP1_TERMINAL_SYNC_SEEN", "", "Terminal Access Log (data card)",
		"Turian's terminal: an unknown device connected at 20:31 - after his death - through the local maintenance network."],
	"EP1_ITEM_MESSAGES": ["EP1_MESSAGES_SEEN", "", "Turian's Messages (data card)",
		"Eleven messages to Otari in two days. The last, from Turian: 'There is more here than I expected. I will explain when I am certain.'"],
	"EP1_ITEM_CABLE": ["EP1_MAINT_HAS_CABLE", "EP1_MAINT_ADAPTER_BUILT", "Interface Cable",
		"A loose interface cable from the maintenance room."],
	"EP1_ITEM_ADAPTER": ["EP1_MAINT_ADAPTER_BUILT", "EP1_MAINT_JUNCTION_ALIVE", "Controlled Pulse Adapter",
		"The interface cable wired to McCoy's defibrillator leads."],
	"EP1_ITEM_COMPLAINT": ["EP1_HAS_COMPLAINT", "", "Ullus' Complaint (copy)",
		"Procedural objection, filed in person at 19:31, receipt signed 19:44. Three pages. The third page is about the lighting."],
	"EP1_ITEM_DUST": ["EP1_HAS_DUST", "", "Desert Dust Sample",
		"Fine mineral dust from the service passage behind Darev's room."],
	"EP1_ITEM_SWAB": ["EP1_EV_HAS_SWAB", "EP1_EV_PREPARED", "Trace Swab",
		"A sealed forensic trace swab from the evidence room. The analyser won't take it until it's been prepared."],
	"EP1_ITEM_SAMPLE": ["EP1_EV_PREPARED", "EP1_EV_ANALYSED", "Prepared Forensic Sample",
		"The trace swab, prepared and ready for the evidence room's medical analyser."],
	"EP1_ITEM_BUFFER_VIAL": ["EP1_HAS_BUFFER_VIAL", "EP1_EV_BUFFERED", "Sterile Buffer Vial",
		"A mineral buffer from a Shi'Kahr market stall. It keeps cells from breaking down."],
	"EP1_ITEM_WATER": ["EP1_EQ_WATER", "", "Water Supply", "Desert water, from the rack at the city's edge."],
	"EP1_ITEM_FLASK": ["EP1_HAS_FLASK", "", "Sulu's Water Flask", "Lieutenant Sulu's own. It smells faintly of fertiliser."],
	"EP1_ITEM_TOURIST_MAP": ["EP1_HAS_TOURIST_MAP", "", "Tourist Map", "Chekov's map of the desert. He has circled three regions, and written 'RUSSIAN' by the ruins."],
	"EP1_ITEM_ANTENNA": ["EP1_HAS_ANTENNA", "EP1_SENSOR_COUPLED", "Broken Antenna", "The field sensor's antenna. It won't stay aligned on its own."],
	"EP1_ITEM_STRAP": ["EP1_IN_FIELD", "EP1_STRAP_USED", "Equipment Strap", "Kirk's equipment strap."],
	"EP1_ITEM_COUPLING": ["EP1_SENSOR_COUPLED", "EP1_SENSOR_FITTED", "Temporary Coupling", "The broken antenna, splinted so it holds its alignment."],
	"EP1_ITEM_STRETCHER": ["EP1_STRETCHER_BUILT", "EP1_DAREV_ON_STRETCHER", "Improvised Stretcher", "A support panel bound with restraint material."],
	"EP1_ITEM_BEACON": ["EP1_EQ_BEACON", "", "Emergency Beacon",
		"A field emergency beacon: a power module and a detachable mounting clip."],
	"EP1_ITEM_PANEL": ["EP1_RI_GOT_PANEL", "EP1_STRETCHER_BUILT", "Support Panel",
		"A long, rigid panel prised out of the ruins."],
	"EP1_ITEM_RESTRAINT": ["EP1_RI_GOT_MATERIAL", "EP1_STRETCHER_BUILT", "Intact Restraint Material",
		"Long lengths of the restraint material - strong, and still in one piece."],
	# REV 856: the city (SHIKAHR_SCRIPT.md)
	"EP1_ITEM_TOUR_CARD": ["EP1_ST_HAS_TOUR_CARD", "EP1_ST_TOUR_FINISHED", "Tour Card",
		"T'Mir's tour card. Seven circles, one for each tour stone in Shi'Kahr. Show it to her when they're all lit."],
	"EP1_ITEM_STRING": ["EP1_ST_HAS_STRING", "EP1_ST_SOREV_TOLD", "Lyre String",
		"A coil of lyre string - one of T'Vora's late husband's. Forty years old and still perfect."],
	"EP1_ITEM_VISOR": ["EP1_ST_HAS_VISOR", "", "Andorian Sun-Visor",
		"A tinted sun-visor, Andorian, and very dark. A tip, from two Andorians who think Kirk is a tour guide."],
	"EP1_ITEM_HOLO": ["EP1_ST_HAS_HOLO", "EP1_ST_IMPOSTOR", "Riley's Holo-Image",
		"Riley in the Garden of T'Plana-Hath, this morning. Behind him on the bench: a Vulcan scholar, heads together with a man from the Romulan delegation."],
	# REV 860: the delegates' lounge
	"EP1_ITEM_GRIEVANCE_FORM": ["EP1_DL_HAS_FORM", "EP1_DL_FORM_FILLED", "Form of Grievance",
		"A Vulcan Form of Grievance, in triplicate. Blank. Shras was sitting on it."],
	"EP1_ITEM_GRIEVANCE_FILLED": ["EP1_DL_FORM_FILLED", "EP1_DL_FORM_STAMPED", "Grath's Grievance",
		"Three pages, both sides, in triplicate. GRIEVANCE THE FIRST: the chairs."],
	"EP1_ITEM_GRIEVANCE_STAMPED": ["EP1_DL_FORM_STAMPED", "EP1_DL_GRATH_STAYS", "Stamped Grievance",
		"Grath's grievance, stamped by the conference's protocol officer: RECEIVED. Technically that isn't an acknowledgement. Nobody needs to know that."],
	# REV 863: McCoy's patient
	"EP1_ITEM_KESH": ["EP1_PT_HAS_KESH", "EP1_PT_DOCTORED", "Kesh Flask",
		"A battered Tellarite travel flask of mulled kesh. Black, hot, and strong enough to strip paint. Tellar remembers."],
	"EP1_ITEM_KESH_DOCTORED": ["EP1_PT_DOCTORED", "EP1_PT_TREATED", "Doctored Kesh",
		"The kesh, with a cooling compound and an electrolyte mix stirred in. He'll never taste it under that."],
	# REV 864: the chase
	"EP1_ITEM_CHIT": ["EP1_WK_CHASED", "", "Maintenance Authorisation Chit",
		"TEMPORARY DIPLOMATIC MAINTENANCE AUTHORISATION. Name: - . Blank. Dropped by the hooded walker in the Old Quarter."],
	"EP1_ITEM_SLEEVE": ["EP1_WK_SLEEVE", "", "Clerk's Sleeve Band",
		"A strip of grey cloth from a Vulcan clerk's robe. Kirk had him. For about a second."],
	# REV 865: the waystation
	"EP1_ITEM_SLED": ["EP1_WS_HAS_SLED", "EP1_DAREV_ON_STRETCHER", "Sand-Sled",
		"Velik's sand-sled: a long, light runner-board with a towrope. 'I have nothing to carry that does not carry itself.'"],
	# REV 867: Part Six
	"EP1_ITEM_COMMENDATION": ["EP1_P6_COMMENDED", "", "Tellarite Commendation",
		"COMPLAINT, FORMAL: AGAINST JAMES T. KIRK, FOR BEING CORRECT. Stamped by Sevek: RECEIVED - and, under it, the seventh stamp: ADMIRED."],
	"EP1_ITEM_DATAPAD": ["EP1_HAS_DATAPAD", "EP1_P6_DATAPAD_DONE", "Turian's Datapad",
		"Turian's personal datapad. Some of its files are protected."],
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
	if (ITEMS[id] as Array).size() > 4 and ResourceLoader.exists(String(ITEMS[id][4])):
		it.icon = load(String(ITEMS[id][4]))
	InventoryManager.register_item(it)
	return it


## Makes the backpack match the story flags (quietly - nothing is "picked up" again on a load).
static func sync_items() -> void:
	for id in ITEMS.keys():
		var row: Array = ITEMS[id]
		var want := flag(String(row[0])) and (String(row[1]) == "" or not flag(String(row[1])))
		var have := InventoryManager.has_item(String(id))
		if want and not have:
			InventoryManager.add_item(_item(String(id)), true)
		elif have and not want:
			InventoryManager.remove_item(String(id))


## REV 306: one backpack item used on another (the backpack's USE WITH, InteractionManager.combine_items).
## The same results as the rooms' own combine menus: the same flags, the same lines. Returns true when
## something was answered (a combination or a particular refusal); false = nothing to say about this pair
## (the played character's "that won't work" line is said instead).
static func combine_items(room: EpisodeRoom, a: String, b: String) -> bool:
	var pair := [a, b]
	# REV 863: McCoy's patient - the kesh
	if pair.has("EP1_ITEM_KESH"):
		var other := String(b if a == "EP1_ITEM_KESH" else a)
		if other == "EP1_ITEM_MEDKIT":
			await room.note("KESH FLASK + MEDICAL KIT  ->  DOCTORED KESH", 2.4)
			set_flag("EP1_PT_DOCTORED")
			sync_items()
			await room.say("mccoy", "Something to bring the fever down. He'll never taste it under that.")
			await room.say("kirk", "Bones, I don't think he'd taste a photon torpedo under that.")
			return true
		if other == "EP1_ITEM_FLASK" or other == "EP1_ITEM_WATER":
			await room.say("mccoy", "Water it down and he'll know. Tellarites can taste weakness.")
			return true
		if other in ["EP1_ITEM_SAMPLE", "EP1_ITEM_SWAB", "EP1_ITEM_BUFFER_VIAL", "EP1_ITEM_CLASP_REC", "EP1_ITEM_READOUT"]:
			await room.say("mccoy", "That's evidence, Jim. I'm not putting evidence in a man's drink.")
			return true
	if pair.has("EP1_ITEM_SWAB") and pair.has("EP1_ITEM_BUFFER_VIAL"):
		await room.note("TRACE SWAB + STERILE BUFFER VIAL  ->  PREPARED FORENSIC SAMPLE", 2.6)
		set_flag("EP1_EV_BUFFERED")
		set_flag("EP1_EV_PREPARED")
		await room.say("mccoy", "The vendor's mineral buffer. Stops the cells breaking down - better than anything on that rack.")
		sync_items()
		return true
	if pair.has("EP1_ITEM_PANEL") and pair.has("EP1_ITEM_RESTRAINT"):
		await room.note("SUPPORT PANEL + INTACT RESTRAINT MATERIAL  ->  IMPROVISED STRETCHER", 3.0)
		await room.say("mccoy", "Panel, restraint material and your straps. Bind him down, Jim. Flat, and tight at the chest.")
		set_flag("EP1_STRETCHER_BUILT")
		await room.say("mccoy", "That'll hold him. Gently, now.")
		await room.say("kirk", "The Council leader can walk slowly. Let's get everyone out.")
		sync_items()
		return true
	if pair.has("EP1_ITEM_CABLE") and pair.has("EP1_ITEM_MEDKIT"):
		await room.note("INTERFACE CABLE + MEDICAL KIT (defibrillator leads)  ->  CONTROLLED PULSE ADAPTER", 2.6)
		await room.say("mccoy", "Jim, if this fries my defibrillator, you're explaining it to Starfleet Medical.")
		await room.say("kirk", "I'll put it in my report.")
		await room.say("mccoy", "That's what I'm afraid of.")
		set_flag("EP1_MAINT_ADAPTER_BUILT")
		sync_items()
		return true
	if pair.has("EP1_ITEM_ANTENNA") and (pair.has("EP1_ITEM_STRAP") or pair.has("EP1_ITEM_BEACON")):
		var with_strap := pair.has("EP1_ITEM_STRAP")
		await room.note(("BROKEN ANTENNA + EQUIPMENT STRAP" if with_strap else "BROKEN ANTENNA + THE BEACON'S MOUNTING CLIP") + "  ->  TEMPORARY COUPLING", 2.6)
		if with_strap:
			set_flag("EP1_STRAP_USED")
		else:
			await room.say("kirk", "Just the clip. The beacon stays in one piece.")
		set_flag("EP1_SENSOR_COUPLED")
		sync_items()
		return true
	if pair.has("EP1_ITEM_PANEL") and pair.has("EP1_ITEM_MEDKIT"):
		await room.say("mccoy", "Not the kit, Jim. Tie him on - there's restraint material over there.")     # quiet zone - edit pass
		return true
	if pair.has("EP1_ITEM_SWAB") and pair.has("EP1_ITEM_MEDKIT"):
		await room.say("mccoy", "I've got antiseptic in there, Jim. That's the opposite of what I want.")
		return true
	if pair.has("EP1_ITEM_DATAPAD"):
		await room.say(room.lead(room.current), "That datapad stays exactly as it is.")
		return true
	if pair.has("EP1_ITEM_SAMPLE"):
		await room.say("mccoy", "It's prepared. The only thing it goes in now is the analyser.")
		return true
	return false


## REV 302: the Case File's INVESTIGATION BOARD (CaseFileUI). These clues go under DOESN'T ADD UP
## (the other deductions under ESTABLISHED) - only ever the ones the player already holds.
const BOARD_CONFLICTS := ["CONTRADICTION", "DATAPAD_MISSING", "EVIDENCE_NO_EXPLAIN", "CLASP_PLANTED",
	"NO_MEETING", "FALSE_EVENT", "DELETED_ENTRY", "SAMPLE_TRANSFER"]


## OPEN QUESTIONS from the gates the game already checks - by KIND only (the same words the gates
## show as "STILL OPEN"), never which clue is missing.
static func board_open() -> Array:
	var out: Array = []
	if flag("EP1_AUTHORITY_GRANTED") and not flag("EP1_HUB1_DEDUCTION_DONE"):
		for c in hub1_missing():
			out.append("STILL TO ESTABLISH - " + String(c))
	if flag("EP1_PART5_DONE") and not flag("EP1_P6_RECON_DONE"):
		for i in RECON.size():
			if not recon_category_ready(i):
				out.append("STILL TO PROVE - " + String(RECON[i][1]))
	if pending_deduction() != "":
		out.append("A NEW DEDUCTION IS READY - choose it below the clues.")
	return out


## LEADS: the places open to you right now (the travel menu's list).
static func board_leads() -> Array:
	var names: Array = []
	for key in unlocked_rooms():
		if ROOMS.has(key):
			names.append(String(ROOMS[key][0]))
	if names.is_empty():
		return []
	return ["PLACES OPEN TO YOU:  " + ",  ".join(names)]


## REV 298 (design, PILLAR TWO: "The mandatory core of this pillar is the credential reconstruction and
## the clasp analysis" - the biological material and the optional transfer experiment only support it).
## A pillar listed here is established only when one clue from EACH group has been chosen; its other
## good clues are accepted as support but don't finish it. Pillars not listed: any good clue finishes.
const RECON_CORE := {
	"physical": [["FALSE_EVENT", "DELETED_ENTRY", "FRAMED"], ["CLASP_PLANTED"]],
}


static func recon_category_ready(idx: int) -> bool:
	var key := String(RECON[idx][0])
	if RECON_CORE.has(key):
		for group in RECON_CORE[key]:
			var any := false
			for id in group:
				if Case.has(String(id)):
					any = true
			if not any:
				return false
		return true
	for id in RECON[idx][3]:
		if Case.has(String(id)):
			return true
	return false


static func part5_ready() -> bool:
	# REV 268 (GAMEPLAY LOCKED): the PRELIMINARY ruins finding is what Part Five needs; the Sickbay
	# confirmation must never be required. (In play the analysis comes first anyway.)
	return false     # REV 497 (EPISODE1_SCRIPT.md): no Part Five recap - sickbay's scanner moves the story on


## Which deduction is open right now: "hub1", "part3", "part4", "desert", "part5", "part6" or "".
static func pending_deduction() -> String:
	if hub1_ready():
		return "hub1"
	if part3_ready():
		return "part3"
	if part4_ready():
		return "part4"
	if desert_ready():
		return "desert"
	if part5_ready():
		return "part5"
	if part6_ready():
		return "part6"
	return ""


static func deduction_ready() -> bool:
	return pending_deduction() != ""


## REV 293: what EpisodeRoom calls for the Case File's results (it used to call Ep1Compare directly,
## whichever episode the room was in). Episode 1's comparisons and deductions live in Ep1Compare.
static func run_compare(room: EpisodeRoom, rule: String) -> bool:
	return await Ep1Compare.run(room, rule)


static func run_deduction(room: EpisodeRoom) -> void:
	await Ep1Compare.run_deduction(room)


## REV 293: shows the "NEW DEDUCTION POSSIBLE" notice once per deduction (EpisodeRoom asks when a
## scene ends). Remembers it in that deduction's flag; for hub1 it also sets the DEDUCE objective.
## Returns true if the notice was shown now.
const DEDUCTION_NOTICE_FLAGS := {"hub1": "EP1_DEDUCTION_NOTICED", "part3": "EP1_PART3_NOTICED",
	"part4": "EP1_PART4_NOTICED", "desert": "EP1_DESERT_NOTICED", "part5": "EP1_PART5_NOTICED",
	"part6": "EP1_PART6_NOTICED"}


static func deduction_noticed(key: String) -> bool:
	var flag_name := String(DEDUCTION_NOTICE_FLAGS.get(key, "EP1_" + key.to_upper() + "_NOTICED"))
	if flag(flag_name):
		return false
	set_flag(flag_name)
	if CASE_FILE:
		MissionLog.notification_requested.emit("NEW DEDUCTION POSSIBLE  (press C)")
	if key == "hub1":
		set_objective("DEDUCE")
	return true


static func find_compare(a: String, b: String) -> String:
	for rule in COMPARE_RULES:
		if (rule[0] == a and rule[1] == b) or (rule[0] == b and rule[1] == a):
			return String(rule[2])
	return ""
