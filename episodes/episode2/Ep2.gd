extends RefCounted
class_name Ep2
## Ep2 - the facts of Episode 2 in one place: who speaks, the rooms, what the episode remembers, the
## objectives and what Spock's log (the Case File) can contain. Built from Glen's locked script,
## Secret_of_Vulcan_Fury_Episode_2_REVISED_R005_LOCKED.md (E2-R005). Section numbers in comments
## (11.8, 12.13 ...) are that script's.
##
## Episode 2 is Spock's and Chapel's episode. The rooms put them in the two playable slots (see
## EpisodeRoom.lead_people): Spock in the "mccoy" slot (the main one), Chapel in the "kirk" slot.
##
## PLAYER-KNOWLEDGE RULE (script section 6): until the brig reveal nothing in this episode - log,
## objectives, dialogue, interface - may mention the three activation discs, what "three" means,
## Veskar, the destroyed repository world, the mining colony, the hijacking method or Enterprise's real
## destination. The three "Vulcan specialists" are shown as themselves (the cold-open faces) but are
## always NAMED by their cover identities until they are alone in the brig. The name "Tal Shiar" is
## never used.

const PREFIX := "EP2"
const EPISODE_TITLE := "ECHOES OF THE DEAD"     # Glen, 24 Oct (the title card in the opening, the LOG heading)
const SPEECH_ROOT := "res://episodes/episode2/audio/speech/"

## who -> [voice folder, name shown in the subtitle]
const SPEAKERS := {
	"spock": ["spock", "Spock"],
	"mccoy": ["mccoy", "McCoy"],
	"chapel": ["chapel", "Chapel"],
	"kirk": ["kirk", "Kirk"],
	"uhura": ["uhura", "Uhura"],
	"sulu": ["sulu", "Sulu"],          # REV 365: talkable on the bridge
	"chekov": ["chekov", "Chekov"],
	"scott": ["scott", "Scott"],
	"computer": ["computer", "Enterprise Computer (bridge)"],
	"sickbay_computer": ["sickbay_computer", "Sickbay Computer"],    # REV 316: sickbay's own voice
	"vulcan_comms": ["vulcan_comms", "Vulcan Communications"],
	# the dead mind (script 12): echoes of what Turian experienced - they never answer Spock
	"turian": ["turian_memory", "Delegate Memory"],
	"romulan_voice": ["romulan_voice_memory", "Another Romulan Voice"],
	"romulan_official": ["romulan_official_memory", "Romulan Official Memory"],
	"romulan_rep": ["romulan_rep_memory", "Romulan Representative"],
	"archivist": ["archivist_memory", "Archivist Memory"],
	"ancient": ["ancient_record_memory", "Ancient Record Voice"],
	"computer_memory": ["computer_memory", "Computer Memory"],
	# 2.03 (script 13)
	"kyle": ["kyle", "Kyle"],
	"ullus": ["ullus", "Ullus"],          # REV 508: his recorded message on the bridge
	"ent_specialist": ["ent_specialist", "Enterprise Computer Specialist"],
	# REV 342 (Glen): the three "Vulcan computer specialists" ARE the three operatives in disguise, and the
	# Prologue cold open's three Romulans - one voice each: senior_specialist = Varel = the cold open's
	# Director; tech_specialist = Kovek (technical and decryption; a WOMAN - Glen, REV 343) = its Analysis Officer; archive_specialist
	# = Tovan (field operative) = its Operations Officer. Separate folders, same voice.
	"senior_specialist": ["senior_specialist", "Senior Specialist"],
	"archive_specialist": ["archive_specialist", "Archive Specialist"],
	"tech_specialist": ["tech_specialist", "Technical Specialist"],
	# 2.04 (script 14)
	"vulcan_official": ["vulcan_official", "Vulcan Official"],
	"secretary": ["secretary", "Conference Secretary"],
	"hall_archivist": ["hall_archivist", "Archivist"],
	# 2.08 (script 18)
	"vulcan_leader": ["vulcan_leader", "Councillor T'Seva"],    # REV 505: the Vulcan leader IS T'Seva (Episode 1's rescued councillor)
	"varel": ["varel", "Varel"],
	"kovek": ["kovek", "Kovek"],
	"tovan": ["tovan", "Tovan"],
	"security_officer": ["security_officer", "Security Officer"],
	# REV 505 (EPISODE2_SCRIPT.md): Giotto is the 2.06 escort and the 2.08 lead; the Fizzbin pair
	"giotto": ["giotto", "Lt. Cmdr. Giotto"],
	"engineer_1": ["engineer_1", "Engineer"],
	"engineer_2": ["engineer_2", "Engineer"],
	"engineer_3": ["engineer_3", "Engineer (down the tube)"],     # REV 517: not one of the Fizzbin pair - they're in the lobby
	"crewman": ["crewman", "Crewman"],
	"senior_operative": ["varel", "Senior Operative"],
	"operative": ["tovan", "Operative"],
	"second_operative": ["kovek", "Second Operative"],
	# 2.09 (script 19)
	"technician": ["technician", "Vulcan Technician"],
}

## room key -> [name shown on arrival and in the travel menu, scene]
const ROOMS := {
	"walk_ae_alley": ["Enterprise - Deck 21, Bowling Alley", "res://episodes/episode2/scenes/walk/Walk_ae_alley.tscn"],   # REV 640: lift walk-around
	"walk_ae_deck5": ["Enterprise - Deck 5", "res://episodes/episode2/scenes/walk/Walk_ae_deck5.tscn"],   # REV 640: lift walk-around
	"walk_ae_deck7": ["Enterprise - Deck 7", "res://episodes/episode2/scenes/walk/Walk_ae_deck7.tscn"],   # REV 640: lift walk-around
	"walk_ae_deck8": ["Enterprise - Deck 19, Hangar Deck", "res://episodes/episode2/scenes/walk/Walk_ae_deck8.tscn"],   # REV 640: lift walk-around
	"walk_ae_engine": ["Enterprise - Garden Deck", "res://episodes/episode2/scenes/walk/Walk_ae_engine.tscn"],   # REV 640: lift walk-around
	"walk_ae_engineering": ["Enterprise - Engineering", "res://episodes/episode2/scenes/walk/Walk_ae_engineering.tscn"],   # REV 640: lift walk-around
	"walk_ae_main": ["Enterprise - Deck 20, Recreation", "res://episodes/episode2/scenes/walk/Walk_ae_main.tscn"],   # REV 640: lift walk-around
	"walk_ae_pool": ["Enterprise - Deck 20, Recreation", "res://episodes/episode2/scenes/walk/Walk_ae_pool.tscn"],   # REV 640: lift walk-around
	"walk_e_quarters": ["Enterprise - Deck 6, Crew Quarters", "res://episodes/episode2/scenes/walk/Walk_e_quarters.tscn"],   # REV 640: lift walk-around
	"sickbay": ["Enterprise - Sickbay", "res://episodes/episode2/scenes/Sickbay.tscn"],
	"meld1": ["Mind Meld - The Broken Mind", "res://episodes/episode2/scenes/MeldOne.tscn"],
	"bridge": ["Enterprise - Bridge", "res://episodes/episode2/scenes/Bridge.tscn"],
	"intercept": ["Romulan Bird-of-Prey - Vulcan Orbit", "res://episodes/episode2/scenes/RomulanIntercept.tscn"],
	"transporter": ["Enterprise - Transporter Room", "res://episodes/episode2/scenes/TransporterRoom.tscn"],
	"vulcan": ["Vulcan - Hall of Ancient Thought", "res://episodes/episode2/scenes/VulcanHall.tscn"],
	"lab": ["Enterprise - Decryption Lab", "res://episodes/episode2/scenes/DecryptionLab.tscn"],
	"auxcontrol": ["Enterprise - Auxiliary Control", "res://episodes/episode2/scenes/AuxControl.tscn"],
	"meld2": ["Mind Meld - The Coordinates", "res://episodes/episode2/scenes/MeldTwo.tscn"],
	"brig": ["Enterprise - Brig", "res://episodes/episode2/scenes/BrigCutaway.tscn"],
	"chase": ["Enterprise - Deck 6, Security", "res://episodes/episode2/scenes/SecurityChase.tscn"],
	"station": ["Vulcan - Science Station", "res://episodes/episode2/scenes/ScienceStation.tscn"],
	"bop": ["The Impounded Bird-of-Prey", "res://episodes/episode2/scenes/BirdOfPrey2.tscn"],
}

## Everything the episode remembers (saved with the game).
const DEFAULTS := {
	"EP2_STARTED": false,
	"EP2_ACTIVE_CHAR": "mccoy",
	# 2.00 / 2.01 - the impossible signal (script 11.7: the scene's core investigation flags)
	"EP2_REPRISE_DONE": false,
	"EP2_CALL_SENT": false,          # REV 352: Uhura has sent the request (bridge part 1)
	"EP2_INTERCEPT_SEEN": false,     # REV 352: the Romulans intercepted it (RomulanIntercept cutaway)
	"EP2_CALL_DONE": false,          # REV 336: Uhura's call to Vulcan, on the bridge (between the opening and 2.01)
	"EP2_SPOCK_ARRIVED": false,
	"EP2_MONITOR_SEEN": false,
	# REV 505 (EPISODE2_SCRIPT.md 2.01): the three facts by doing - the scanner pointed at things, the
	# repetitions laid over each other; the three conventional methods tried by hand; the hand on Turian
	"EP2_SCANNER_HELD": false,
	"EP2_SCAN_BED": false,
	"EP2_SCAN_FRAME": false,
	"EP2_SCAN_COMPUTER": false,
	"EP2_SCAN_MCCOY": false,
	"EP2_TRACE_OVERLAID": false,
	"EP2_TRY_RESOLUTION": false,
	"EP2_TRY_COMPUTER": false,
	"EP2_STIM_HELD": false,
	"EP2_TRY_STIM": false,
	"EP2_MELD_HAND": false,
	"EP2_FACT_SUBJECT_DEAD": false,
	"EP2_FACT_PATTERN_GENUINE": false,
	"EP2_FACT_PATTERN_NEURAL_ORIGIN": false,
	"EP2_FACT_DEGRADATION_ACTIVE": false,
	"EP2_FACT_PATTERN_STRUCTURED": false,
	"EP2_DED_MEMORY_RESIDUE": false,
	"EP2_DED_MIND_MELD": false,
	"EP2_TALKED_MCCOY": false,
	"EP2_MCCOY_ASKED_HOW": false,          # "How exactly do you plan on asking a dead man...?" (unlocks 11.14)
	"EP2_PRESERVATION_TALK": false,
	"EP2_CHAPEL_WOULD_YOU": false,
	"EP2_MCCOY_AGREED": false,              # "All right. One attempt."
	"EP2_MELD_ONE_STARTED": false,
	# 2.02 - mind meld one (script 12.26)
	"EP2_MELD_ONE_COMPLETE": false,
	"EP2_MELD_ENTERED": false,
	"EP2_MELD_STAGE": 0,                    # 0 chamber, 1 archive, 2 corridor, 3 collapse
	"EP2_MELD_ANCHORS": [],                 # the Memory Anchors found (ids, in order)
	"EP2_MELD_UNREAD_TRIED": false,
	"EP2_MELD_BELIEF_DEDUCED": false,
	"EP2_MELD_CHAMBER_SOLVED": false,
	"EP2_MELD_FURY_OPENED": false,
	"EP2_MELD_CURIOSITY": false,
	"EP2_MELD_RESTRICTED": false,
	"EP2_MELD_DOWNLOAD": false,
	"EP2_MELD_PEACE_DOOR": false,
	"EP2_MELD_DATAPAD_DOOR": false,
	"EP2_MELD_FEAR_DOOR": false,
	"EP2_MELD_SHUTDOWN_DEDUCED": false,
	"EP2_MELD_COORD_TRIED": false,
	# REV 508 (EPISODE2_SCRIPT.md 2.02): the meld played with anchors and hands, not menus
	"EP2_MELD_SPOKEN": false,               # SPEAK to the echo once (rule six: it never answers)
	"EP2_MELD_HESITATES": false,            # the stamped trail followed - the package, and his hesitation
	"EP2_MELD_OBSERVED": false,             # OBSERVE him hesitating
	"EP2_MELD_DATAPAD_ENTERED": false,      # inside the DATAPAD door - the navigational image is there
	"EP2_MELD_NAV_SEEN": false,             # DOWNLOAD used on it: "It still exists."
	"EP2_MELD_TRICORDER_JOKE": false,
	"EP2_SPOCK_STRESS_SEVERE": false,
	"EP2_SECOND_MELD_PROHIBITED": false,
	"EP2_MELD_REVIEW_DONE": false,
	# 2.03 - aftermath (script 13.24)
	"EP2_MCCOY_EXAM_DONE": false,           # McCoy's post-meld scan (13.5 option 1)
	"EP2_SPOCK_LIMITED_DUTY": false,        # spock_limited_duty
	"EP2_DATAPAD_PRIORITY": false,          # 13.5 option 3: the datapad is the immediate priority
	"EP2_CHAPEL_STABILISE_HINT": false,     # 13.6 option 3 (foreshadowing 2.05)
	"EP2_MELD_EVIDENCE_REVIEWED": false,    # meld_evidence_reviewed (REV 508: McCoy's "Summarise, Doctor." recap)
	"EP2_SOUP_SEEN": false,                 # REV 508: Chapel's plomeek flask, "It's for after."
	"EP2_KIRK_GREETED": false,
	"EP2_KIRK_REPORTED": false,             # datapad_coordinates_connection_established
	"EP2_INJECTOR_PLANT": false,            # REV 508: Scotty's injector "singing flat" (pays off at the science station)
	"EP2_ULLUS_MESSAGE": false,             # REV 508: Ullus' recorded complaint ("For a Tellarite, Captain, that was a sonnet.")
	"EP2_SPECIALIST_CONSULTED": false,      # enterprise_decryption_insufficient
	"EP2_TEAM_CALLED": false,               # Uhura: the Vulcan team has arrived
	"EP2_TEAM_MET": false,
	"EP2_ESCORTING": false,                 # REV 508: Spock walks the three to the decryption lab (played)
	"EP2_ESCORT_AUX_SAID": false,
	"EP2_TEAM_ABOARD": false,               # vulcan_specialists_aboard / joint_decryption_underway
	"EP2_RETURN_TO_VULCAN": false,          # spock_return_to_vulcan_required
	# 2.04 - Vulcan: the conference that wasn't (script 14)
	"EP2_V_ARRIVED": false,
	"EP2_V_ARCHIVIST_REFUSED": false,
	# REV 509 (EPISODE2_SCRIPT.md 2.04): played with things, not menus
	"EP2_V_ASKED_RECORD": false,            # "Is there a Fury record?" "There are many."
	"EP2_V_KIRK_SIDES": false,              # "There are no sides in an archive, Captain. There are shelves."
	"EP2_V_MCCOY_LOUD": false,              # "Your request is louder. It is not narrower."
	"EP2_V_HAS_OVERLAYS": false,
	"EP2_V_KIRK_CHARM": false,              # "Captain. Your face is doing something."
	"EP2_V_PLACARD_READ": false,
	"EP2_V_HOPPER_SCANNED": false,
	"EP2_V_SEATING_SOLVED": false,          # THREE REPEATED APPROACH ROUTES
	"EP2_V_IDENTIFIERS": false,             # THREE TEMPORARY IDENTIFIERS
	"EP2_V_CHAPEL_CALLED": false,           # the soft clock
	"EP2_V_SECRETARY_PROCESS": false,       # find the original amendment packet
	"EP2_V_CHUTE_SEEN": false,
	"EP2_V_CARRY_STONE": false,
	"EP2_V_PACKET": false,                  # R-3
	"EP2_V_R3_ACCESS": false,
	"EP2_V_R3_FRAGMENT": false,
	"EP2_V_R3_PLACARD": false,
	"EP2_V_R3_SEEN_VESSELS": false,
	"EP2_V_R3_SEEN_CHAIRS": false,
	"EP2_V_R3_SEEN_ABRASION": false,
	"EP2_V_BACKING_MATCHED": false,
	"EP2_V_R3_GROUP": false,
	"EP2_V_HAS_MARKERS": false,             # McCoy's three medical tags
	"EP2_V_FOOTAGE": false,                 # optional
	"EP2_V_MEDICAL_TIMES": false,
	"EP2_V_INTEGRITY": false,               # optional
	"EP2_V_RECORDS_GRANTED": false,         # the Archivist brings the three oldest Fury records
	"EP2_V_FURY_SOURCES": false,
	"EP2_V_STILLS": false,
	"EP2_V_TARGET": false,                  # TURIAN WAS THE TARGET, NOT THE AGENT
	"EP2_V_FEEDBACK_CLUE": false,           # 14.17, for Chapel later
	"EP2_V_DONE": false,
	# 2.05 - Chapel: the stabiliser (script 15)
	"EP2_C_STARTED": false,                 # Chapel is the player
	# REV 510 (EPISODE2_SCRIPT.md 2.05): her research by hand
	"EP2_C_HEARD_SPOCK": false,
	"EP2_C_ASKED_ALL": false,               # "Request exceeds display capacity." / "Of course it does."
	"EP2_C_ASKED_DAMPENER": false,          # "You wrote the report." / "That's why I don't remember it."
	"EP2_C_HAS_SOUP": false,                # the plomeek flask, "for after"
	"EP2_C_GRADUAL": false,                 # GRADUAL WITHDRAWAL REDUCES REBOUND
	"EP2_C_HAS_STIMULATOR": false,
	"EP2_C_REGULATOR_FAMILY": false,        # INHIBITORY SYNAPTIC REGULATOR (knowledge)
	"EP2_C_SAW_CONTACT_POINTS": false,
	"EP2_C_FEEDBACK_PATH": false,           # FEEDBACK PATH IDENTIFIED
	"EP2_C_EXPERIMENTS": false,
	"EP2_C_HAS_CARTRIDGE": false,
	"EP2_C_HAS_CARRIER": false,
	"EP2_C_CABINET_OK": false,
	"EP2_C_HAS_REGULATOR": false,
	"EP2_C_SUPPORT_KNOWN": false,
	"EP2_C_HAS_SUPPORT": false,
	"EP2_C_PRIMED": false,                  # carrier + regulator (support still to go in)
	"EP2_C_COMPOUND": false,                # EXPERIMENTAL NEURAL STABILISATION COMPOUND
	"EP2_C_PROCEDURE": false,
	"EP2_C_TESTED": false,
	"EP2_C_MCCOY_AGREED": false,
	"EP2_C_DONE": false,                    # Mind Meld Two is possible
	# 2.06 - the second purpose (script 16)
	"EP2_L_ARRIVED": false,
	"EP2_L_DIRECTORY": false,
	"EP2_L_TOO_LONG": false,                # DECRYPTION TIME: TOO LONG TO ASSUME SUCCESS
	"EP2_L_SYNC_DROP": false,
	"EP2_L_SCOTTY": false,
	"EP2_L_GIOTTO": false,                  # Giotto escorts (Scotty: "somebody from Security goes with them")
	"EP2_FIZZBIN_SEEN": false,
	"EP2_L_DELEGATED": false,
	"EP2_A_REROUTED": false,
	"EP2_A_ARRIVED": false,
	"EP2_A_Q_RECONNECT": false,             # authorised diagnostics reconnect automatically
	"EP2_A_Q_REDUNDANT": false,             # auxiliary control keeps a redundant processor route
	"EP2_A_Q_ISOLATOR": false,              # the maintenance interface opens without dropping isolation
	"EP2_A_HAS_TOOL": false,                # Kovek hands Spock her field isolator for the maintenance interface
	"EP2_A_ISOLATOR_SEEN": false,
	"EP2_A_DONE": false,
	"EP2_L_BACK": false,
	"EP2_L_REVISED": false,
	"EP2_L_OTHER_CLOCK": false,
	"EP2_L_DEDUCED": false,                 # conventional decryption can't be relied on in time
	"EP2_L_KIRK_CALL": false,
	"EP2_SECOND_MELD_CHOSEN": false,
	# 2.07 - mind meld two (script 17)
	"EP2_M2_PREP": false,                   # Chapel plays the preparation
	"EP2_M2_SENSOR": false,
	"EP2_M2_COMPOUND_LOADED": false,
	"EP2_M2_BASELINE": false,
	"EP2_M2_PATTERN": false,
	"EP2_M2_STAGES": false,
	"EP2_M2_REBOUND_FIXED": false,
	"EP2_M2_ASKED": false,                  # McCoy: "Are you prepared to authorise another meld?" - she looks first
	"EP2_M2_FACT_BASELINE": false,
	"EP2_M2_FACT_PATTERN": false,
	"EP2_M2_FACT_REBOUND": false,
	"EP2_M2_AUTHORISED": false,
	"EP2_M2_STARTED": false,
	"EP2_M2_STAGE": 0,                      # 0 conference, 1 archive, 2 stellar display, 3 coordinates, 4 motive, 5 withdrawal
	"EP2_M2_COORDS": false,                 # FURY COORDINATES RECOVERED
	# REV 512 - inside Meld Two (after COORDS so the scene select's "before COORDS" leaves them unplayed)
	"EP2_M2_ENTERED": false,
	"EP2_M2_ULLUS_SAID": false,
	"EP2_M2_FORGET": false,                 # FOCUS "FORGET" - the conference dissolves into the archive
	"EP2_M2_DOWNLOAD_SEEN": false,
	"EP2_M2_ALIGNED": false,                # the stellar display rotated until his stars sit where he saw them
	"EP2_M2_V1": false,
	"EP2_M2_V2": false,
	"EP2_M2_GRID": false,                   # followed his hand to the reference grid
	"EP2_M2_V3_TRIED": false,
	"EP2_M2_V3": false,
	"EP2_M2_HOLD": false,                   # the withdrawal: held through the rebound
	"EP2_M2_MOTIVE": false,
	"EP2_M2_THREE": false,
	"EP2_M2_DONE": false,
	"EP2_M2_BACK": false,
	"EP2_M2_CHECKED": false,
	"EP2_SOUP_GIVEN": false,                # "Last time he threw it at you."
	"EP2_M2_REPORTED": false,
	# 2.08 - the team that never existed (script 18)
	"EP2_R_ARRIVED": false,
	"EP2_R_NO_TEAM": false,                 # "No computer specialists were dispatched"
	"EP2_R_INTERCEPTED": false,
	"EP2_R_ARREST": false,
	"EP2_R_BRIG_SEEN": false,               # the Romulan POV cutaway
	"EP2_R_BOP_DONE": false,                # 18.5A hub finished
	"EP2_R_CREDENTIALS": false,
	"EP2_R_SCOTTY_WARNING": false,
	"EP2_S_STARTED": false,
	"EP2_S_GUARD": false,
	"EP2_S_LIFT_FOLLOWED": false,
	"EP2_S_ISOLATOR": false,                # Giotto bags THE ISOLATOR (PLANT: Episode 3)
	"EP2_S_FIZZBIN": false,
	"EP2_S_DECOY": false,
	"EP2_S_DEST": false,
	"EP2_S_MATRIX": false,
	"EP2_S_REAR": false,
	"EP2_S_TRUNK": false,
	"EP2_S_DONE": false,
	"EP2_R_STOLEN": false,                  # "They have my ship."
	# 2.09 - the missing Enterprise (script 19)
	"EP2_X_ARRIVED": false,
	"EP2_X_TRACK": false,                   # ENTERPRISE DEPARTURE TRACK IDENTIFIED
	"EP2_X_VECTOR": false,
	"EP2_X_HAS_SLATE": false,
	"EP2_X_CIVILIANS_GONE": false,
	"EP2_X_TRANSPONDER": false,
	"EP2_X_ASKED_PROFILE": false,
	"EP2_X_INJECTOR": false,                # Kirk remembers Scotty's injector imbalance
	"EP2_X_ENGINE": false,
	"EP2_X_WAKE": false,
	"EP2_X_CANT_TRACK": false,
	"EP2_X_FURY_TRAIL": false,
	"EP2_X_SHIP_CHOSEN": false,
	"EP2_B_ARRIVED": false,
	"EP2_B_POWER_LOCK": false,              # Kirk's authorisation
	"EP2_B_CLAMP_SEEN": false,
	"EP2_B_ATTITUDE": false,
	"EP2_B_CLAMP_FREE": false,
	"EP2_B_CONTROLS": false,                # navigation input identified
	"EP2_B_CONVERTED": false,
	"EP2_B_COMPARED": false,
	"EP2_B_DEPARTED": false,
	"EP2_COMPLETE": false,
}

## objective key -> text. REV 505 (EPISODE2_SCRIPT.md): the script's TRACKER lines - one short line on
## screen, ticked off as you go; never a fetch quest. Some show live words (refresh_tracker).
const OBJECTIVES := {
	"INVESTIGATE_SIGNAL": "FIND OUT WHAT THE PATTERN IS",
	"READ_DEAD_MEMORY": "FIND A WAY TO READ A DEAD MEMORY",
	"DECIDE_MELD": "TALK McCOY INTO THE MELD",
	"PREPARE_MELD": "PREPARE FOR THE MELD",     # REV 528: the goal, not the answer
	"MELD_NAVIGATE": "LEARN HOW THIS MIND IS CONNECTED",
	"MELD_FURY": "FOLLOW WHAT HE FOUND",
	"MELD_FOLLOW": "FOLLOW HIS MEMORY",
	"MELD_REVIEW": "GET McCOY TO CLEAR YOU FOR DUTY",
	"AFTERMATH": "GET McCOY TO CLEAR YOU FOR DUTY",
	"REPORT_KIRK": "REPORT TO THE CAPTAIN",
	"CONSULT_SPECIALIST": "FIND OUT HOW THE DATAPAD IS COMING",
	"MEET_TEAM": "MEET THE VULCAN SPECIALISTS IN THE TRANSPORTER ROOM",
	"ESCORT_TEAM": "SHOW THE SPECIALISTS TO THE DECRYPTION LAB",
	"RETURN_VULCAN": "BEAM DOWN TO VULCAN - FIND OUT WHAT THE CONFERENCE REALLY WAS",
	"WHO_MANIPULATED": "WHO GOT AT TURIAN? - THE CHAMBER / THE AMENDMENTS / HIS PRIVATE TIME",
	"FIND_PACKET": "FIND THE AMENDMENT PACKET",
	"R3": "SEARCH OFFICE R-3",
	"WHAT_DISCOVERED": "FIND OUT WHAT TURIAN FOUND ABOUT FURY",
	"BACK_TO_SHIP": "RETURN TO THE ENTERPRISE",
	"STABILISER": "FIND A WAY TO GET SPOCK BACK OUT SAFELY",
	"STABILISER_TEST": "TEST THE WITHDRAWAL",
	"STABILISER_REPORT": "SHOW McCOY THE PROCEDURE",
	"TO_LAB": "CHECK ON THE DATAPAD",
	"LAB": "FIND OUT IF THE DATAPAD CAN BE OPENED IN TIME",
	"AUX": "GIVE THE SPECIALISTS A CLEAN PATH IN AUXILIARY CONTROL",
	"LAB_BACK": "BACK TO THE DECRYPTION LAB",
	"TO_SICKBAY_MELD": "GO TO SICKBAY",
	"M2_PREP": "PREPARE THE SECOND MELD",
	"M2_AUTHORISE": "AUTHORISE THE MELD - OR DON'T",
	"M2_INITIATE": "MIND MELD TWO",
	"M2_NAVIGATE": "RECOVER THE COORDINATES",
	"M2_WITHDRAW": "COME OUT - SLOWLY",
	"M2_AFTER": "CHECK SPOCK, TURIAN AND THE STABILISER",
	"M2_SOUP": "IT'S 'AFTER' NOW",
	"BACK_TO_VULCAN": "REPORT TO VULCAN",
	"REPORT_VULCAN": "REPORT TO COUNCILLOR T'SEVA",
	"VULCAN_LEADER": "HEAR T'SEVA OUT",
	"SHOW_TSEVA": "SHOW T'SEVA HOW THEY GOT IN",
	"RETURN_ENTERPRISE": "RETURN TO THE ENTERPRISE",
	"INSPECT_BRIG": "FIND THE PRISONERS",
	"FIND_THEM": "FIND THE PRISONERS",
	"GAIN_ENTRY": "GET INTO AUXILIARY CONTROL",
	"RECONTACT": "RE-ESTABLISH CONTACT WITH ENTERPRISE",
	"LOCATE": "FIND ENTERPRISE",
	"FOLLOW": "FIND ENTERPRISE",
	"REACH_BOP": "GET THE BIRD-OF-PREY OFF THE GROUND",
	"BOP_READY": "GET THE BIRD-OF-PREY OFF THE GROUND",
	"DEPART": "TAKE HER OUT - FOLLOW THE TRAIL",
}
const LOG_OBJECTIVE_ENTRY := "LOG_EP2_000"
## REV 296: Spock's log has its own Mission Log entry. It used to share Episode One's id (LOG_EP1_001)
## and only stayed separate because every way in wiped the log first. Old Episode Two saves are fine:
## ensure_state rebuilds this entry from the saved clues, and the old id is simply not registered.
const LOG_CASE_ENTRY := "LOG_EP2_001"

## Spock's log replaces McCoy's Case File (script 11.5).
const CASE_TITLE := "SCIENCE OFFICER'S LOG - SPOCK"

## Case File: two clues the player can compare -> the comparison's key
const COMPARE_RULES: Array = []

## The Memory Anchors (script 12.3 rule two): id -> name shown. REV 508 (EPISODE2_SCRIPT.md): inside a meld
## they are a thought-inventory - real backpack items (EP2_ANCHOR_<id>) you USE on memories, or put
## together (anchor + anchor). Outside a meld they aren't carried.
const ANCHORS := {
	"HOPE": "GENUINE HOPE",
	"SINCERE": "SINCERE PEACE DELEGATE",
	"ACCESS": "LEGITIMATE ARCHIVE ACCESS",
	"PRE_REFORMATION": "PRE-REFORMATION RECORDS",
	"SHUT_DOWN": "FURY - SHUT DOWN",
	"FURY_INDEX": "FURY INDEX REFERENCE",
	"DOWNLOAD": "DOWNLOAD",
	"IT_STILL_EXISTS": "IT STILL EXISTS",
	"SHARED_HISTORY": "SHARED HISTORY",      # Meld Two (from the conference fragment)
	"FURY": "FURY",                          # (older saves)
	"NAV_IMAGE": "NAVIGATIONAL IMAGE",       # (older saves)
}
const ANCHOR_PREFIX := "EP2_ANCHOR_"
## What the first meld leaves Spock holding (the scene select gives these from the end of Meld One on).
const MELD_ONE_ANCHORS := ["HOPE", "SINCERE", "ACCESS", "PRE_REFORMATION", "SHUT_DOWN", "FURY_INDEX", "DOWNLOAD", "IT_STILL_EXISTS"]


static func ensure_state() -> void:
	_define_clues()
	GameState.register_defaults(DEFAULTS)
	Case.register_defaults()
	Case.title_text = CASE_TITLE
	Case.log_id = LOG_CASE_ENTRY     # REV 296: Episode Two's own entry (REV 293 used the shared one)
	Case.refresh_log()
	_register_objectives()
	AudioSubtitleManager.speech_root = SPEECH_ROOT


## Wipes everything and starts the episode fresh (the Chapters menu calls this).
## REV 293: also starts the Case File, the Mission Log and the objective afresh (as the Prologue and
## Ep1.new_game do) - no clues, log entries or objective of another episode left over this session.
## REV 296: carry_over = true when Episode One's end card continues straight into Episode Two. The
## story so far is kept - Episode One's and the Prologue's own flags (EP1_*, PRO_*, VAR_PRO_*, for
## later payoffs such as Spock's bowling remark) and the crew (the roster seed and story leave
## changes, so the same faces are aboard) - but not Episode One's Case File clues, log or objective.
## CHAPTERS and SCENE SELECT start Episode Two without it, as before.
static func new_game(carry_over: bool = false) -> void:
	var kept := {}
	var kept_crew := {}
	if carry_over:
		var snap: Dictionary = GameState.get_snapshot()
		for key in snap.keys():
			var k := String(key)
			if k.begins_with("EP1_") or k.begins_with("PRO_") or k.begins_with("VAR_PRO_") or k.begins_with("VAR_EP1_"):
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
	InventoryManager.clear()     # REV 296: Episode Two starts with an empty backpack
	MissionLog.reset()
	ObjectiveManager.reset()
	Case.title_text = CASE_TITLE
	Case.log_id = LOG_CASE_ENTRY
	Case.register_defaults()
	GameState.set_var("EP2_STARTED", true)
	# REV 505 (EPISODE2_SCRIPT.md CODE NOTES): Episode 1's choices that Episode 2 reads. Started without
	# Episode 1 (chapter select, scene select): McCoy won the argument duel, Otari wasn't asked for help.
	if not GameState.has_var("VAR_EP1_ULLUS_DUEL_WON"):
		GameState.set_var("VAR_EP1_ULLUS_DUEL_WON", true)
	if not GameState.has_var("VAR_EP1_OTARI_HELP"):
		GameState.set_var("VAR_EP1_OTARI_HELP", false)


# ---- REV 288: DEBUG: SCENE SELECT - each scene as if the story had been played up to it ------------
## label, room, "before" (every yes/no flag listed before it in DEFAULTS is set: the story so far),
## "until" (every clue defined before it is in the log: the clues are defined in story order),
## "objective". The Memory Anchors are all held from the end of the first meld on.
const DEBUG_SCENES := [
	{"label": "2.00 SICKBAY - THE IMPOSSIBLE SIGNAL", "room": "sickbay", "objective": "INVESTIGATE_SIGNAL"},
	{"label": "2.00 THE BRIDGE - THE CALL TO VULCAN", "room": "bridge", "before": "EP2_CALL_SENT", "objective": "INVESTIGATE_SIGNAL"},
	{"label": "2.00 ROMULAN BIRD-OF-PREY - THE INTERCEPT", "room": "intercept", "before": "EP2_INTERCEPT_SEEN", "objective": "INVESTIGATE_SIGNAL"},
	{"label": "2.00 THE BRIDGE - VULCAN'S REPLY", "room": "bridge", "before": "EP2_CALL_DONE", "objective": "INVESTIGATE_SIGNAL"},
	{"label": "2.01 SICKBAY - RUN IT AGAIN", "room": "sickbay", "before": "EP2_SPOCK_ARRIVED", "objective": "INVESTIGATE_SIGNAL"},
	{"label": "2.02 MIND MELD ONE", "room": "meld1", "before": "EP2_MELD_ONE_COMPLETE", "until": "EP2_M_BELIEVED_PEACE", "objective": "MELD_NAVIGATE"},
	{"label": "2.03 SICKBAY - THE AFTERMATH", "room": "sickbay", "before": "EP2_MCCOY_EXAM_DONE", "until": "EP2_DATAPAD_COORDS", "objective": "AFTERMATH"},
	{"label": "2.03 THE BRIDGE - REPORT TO KIRK", "room": "bridge", "before": "EP2_KIRK_GREETED", "until": "EP2_DECRYPT_STATUS", "objective": "REPORT_KIRK"},
	{"label": "2.03 TRANSPORTER ROOM - THE VULCAN TEAM", "room": "transporter", "before": "EP2_TEAM_MET", "until": "EP2_SPECIALISTS_ABOARD", "objective": "MEET_TEAM"},
	{"label": "2.03 DECK 7 - THE WALK TO THE LAB", "room": "lab", "before": "EP2_ESCORT_AUX_SAID", "until": "EP2_V_Q_WHO", "objective": "ESCORT_TEAM"},
	{"label": "2.04 VULCAN - THE HALL OF ANCIENT THOUGHT", "room": "vulcan", "before": "EP2_V_ARRIVED", "until": "EP2_V_Q_WHO", "objective": "RETURN_VULCAN"},
	{"label": "2.05 SICKBAY - CHAPEL'S STABILISER", "room": "sickbay", "before": "EP2_C_STARTED", "until": "EP2_C_GRADUAL", "objective": "STABILISER"},
	{"label": "2.06 THE DECRYPTION LAB", "room": "lab", "before": "EP2_L_ARRIVED", "until": "EP2_L_DIRECTORY", "objective": "LAB"},
	{"label": "2.06 AUXILIARY CONTROL", "room": "auxcontrol", "before": "EP2_A_REROUTED", "until": "EP2_A_PATH", "objective": "AUX"},
	{"label": "2.07 SICKBAY - PREPARING THE SECOND MELD", "room": "sickbay", "before": "EP2_M2_PREP", "until": "EP2_M2_COORDS", "objective": "M2_PREP"},
	{"label": "2.07 MIND MELD TWO", "room": "meld2", "before": "EP2_M2_COORDS", "until": "EP2_M2_COORDS", "objective": "M2_NAVIGATE"},
	{"label": "2.08 VULCAN - THE REPORT", "room": "vulcan", "before": "EP2_R_ARRIVED", "until": "EP2_R_NO_TEAM", "objective": "REPORT_VULCAN"},
	{"label": "2.08 THE BRIG (ROMULAN CUTAWAY)", "room": "brig", "before": "EP2_R_BRIG_SEEN", "until": "EP2_R_BOP", "objective": "VULCAN_LEADER"},
	{"label": "2.08 VULCAN - THE OTHER MATTER", "room": "vulcan", "before": "EP2_R_BOP_DONE", "until": "EP2_R_BOP", "objective": "VULCAN_LEADER"},
	{"label": "2.08 ENTERPRISE - THE SECURITY CHASE", "room": "chase", "before": "EP2_S_STARTED", "until": "EP2_S_DECOY", "objective": "FIND_THEM"},
	{"label": "2.08 VULCAN - THEY HAVE MY SHIP", "room": "vulcan", "before": "EP2_R_STOLEN", "until": "EP2_R_STOLEN", "objective": "RECONTACT"},
	{"label": "2.09 THE VULCAN SCIENCE STATION", "room": "station", "before": "EP2_X_ARRIVED", "until": "EP2_X_TRACK", "objective": "LOCATE"},
	{"label": "2.09 THE IMPOUNDED BIRD-OF-PREY", "room": "bop", "before": "EP2_B_ARRIVED", "until": "EP2_MELD_DANGER", "objective": "REACH_BOP"},
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
		if DEFAULTS.keys().find("EP2_MELD_ONE_COMPLETE") < DEFAULTS.keys().find(stop):
			GameState.set_var("EP2_MELD_ANCHORS", MELD_ONE_ANCHORS.duplicate())
			GameState.set_var("EP2_MELD_STAGE", 3)
			if Case.is_defined("EP2_MELD_DANGER") and DEFAULTS.keys().find("EP2_MCCOY_EXAM_DONE") < DEFAULTS.keys().find(stop):
				Case.add("EP2_MELD_DANGER", true)
	if s.has("until"):
		var last := String(s["until"])
		for id in Case._defs.keys():
			if String(id) == last:
				break
			if String(id).begins_with("EP2_"):     # (Episode 1's clues may still be defined this session)
				Case.add(String(id), true)
	ensure_state()
	if s.has("objective"):
		set_objective(String(s["objective"]))
	return String(ROOMS[String(s["room"])][1])


static func _define_clues() -> void:
	if Case.is_defined("EP2_SUBJECT_DEAD"):
		return
	# --- 2.01: what Spock establishes in Sickbay (script 11.8 - 11.14)
	Case.define("EP2_CAUSE_OF_DEATH", "VICTIM", "TURIAN - CATASTROPHIC NEURAL OVERLOAD",
		"The Romulan delegate died following catastrophic neural overload. Doctor McCoy found no toxin, pathogen, physical trauma or conventional energy exposure. The cause of the overload is unknown.")
	Case.define("EP2_SUBJECT_DEAD", "MEDICAL FINDINGS", "THE SUBJECT IS DEAD",
		"No cardiac activity. No respiration. No measurable cortical function consistent with consciousness. The anomalous pattern is not evidence that he remains alive.")
	Case.define("EP2_PATTERN_STRUCTURED", "MEDICAL FINDINGS", "THE PATTERN IS STRUCTURED",
		"The sequence recurs. The probability of identical random neurological discharge repeating at this frequency is negligible. The interval varies as deteriorating tissue would - it is not an artificial carrier signal.")
	Case.define("EP2_PATTERN_NEURAL", "MEDICAL FINDINGS", "THE PATTERN ORIGINATES IN TURIAN'S NEURAL STRUCTURES",
		"Not a scanner malfunction. Not generated by the biobed. Not computer feedback. The signal originates within the subject's remaining neural structures.")
	Case.define("EP2_DEGRADING", "MEDICAL FINDINGS", "THE STRUCTURE IS DEGRADING",
		"Each recurrence contains slightly less information than the previous one. At the present rate of decay the remaining structure will become unrecoverable. The available time is limited.")
	Case.define("EP2_HOW_TO_READ", "UNRESOLVED QUESTIONS", "HOW CAN THE INFORMATION BE ACCESSED?",
		"If information remains physically encoded in the neural tissue, conventional medical equipment can detect the structure but cannot interpret it.")
	Case.define("EP2_MEMORY_RESIDUE", "DEDUCTIONS", "WORKING HYPOTHESIS - SURVIVING MEMORY STRUCTURES",
		"Portions of Turian's memory structures may remain physically intact. The repeating anomaly may represent activity within those surviving structures.")
	Case.define("EP2_MELD_METHOD", "DEDUCTIONS", "A MIND MELD MAY PERMIT ACCESS",
		"Scanner resolution, computer reconstruction, stimulation and the datapad cannot reach the experience encoded in the surviving structures. Direct telepathic contact may. A meld of this nature has never been attempted.")
	# --- 2.02: fragments recovered from the first meld (script 12.24)
	Case.define("EP2_M_BELIEVED_PEACE", "WITNESS STATEMENTS", "FRAGMENT - THE DELEGATE BELIEVED THE PEACE CONFERENCE WAS GENUINE",
		"His belief in the peace initiative was genuine. Whatever larger purpose the conference may have served, he was not consciously participating in a deception. (This establishes what he believed - not that the conference was genuine.)")
	Case.define("EP2_M_LEGIT_ACCESS", "WITNESS STATEMENTS", "FRAGMENT - LEGITIMATE ARCHIVE ACCESS",
		"His access to Vulcan historical records was granted openly, under the cultural exchange provisions of the conference.")
	Case.define("EP2_M_PURSUED_FURY", "WITNESS STATEMENTS", "FRAGMENT - THE DELEGATE PURSUED FURY INDEPENDENTLY",
		"During legitimate research he encountered references to Fury. His interest became personal; he continued beyond the purpose of his authorised research.")
	Case.define("EP2_M_UNAUTHORISED", "WITNESS STATEMENTS", "FRAGMENT - THE VIOLATION WAS DELIBERATE",
		"He followed cross-references from permitted material to a restricted archival package, understood that further access was unauthorised, and opened it. The motive appears personal rather than operational.")
	Case.define("EP2_M_DOWNLOAD", "WITNESS STATEMENTS", "FRAGMENT - A LARGE BODY OF FURY MATERIAL WAS DOWNLOADED",
		"He downloaded all records associated with Fury to his personal datapad - more than he could review. He consciously examined only a small part of it before his death.")
	Case.define("EP2_M_SHUT_DOWN", "DEDUCTIONS", "FURY WAS SHUT DOWN RATHER THAN CONFIRMED DESTROYED",
		"The oldest surviving reference describes an intentional cessation of operation. Later sources interpret Fury as lost or destroyed; those interpretations are not equivalent to the original statement.")
	Case.define("EP2_M_LOCATED_FURY", "WITNESS STATEMENTS", "FRAGMENT - THE DELEGATE BELIEVED HE HAD LOCATED FURY",
		"He consciously viewed a navigational display and believed Fury still exists. The surviving memory of the location is incomplete.")
	Case.define("EP2_M_WANTED_PEACE", "WITNESS STATEMENTS", "FRAGMENT - THE DELEGATE GENUINELY WANTED PEACE",
		"Hope, tempered by considerable doubt. His public advocacy did not differ from his private belief.")
	Case.define("EP2_M_TIMING", "DEDUCTIONS", "THE NEURAL EVENT FOLLOWED THE PROHIBITED FURY ACCESS",
		"The archive only logged the violation; it did not respond further. The catastrophic neural event followed soon after the prohibited Fury access, but its source is not present in the memory. This does not establish the cause of the trauma; it establishes the timing.")
	Case.define("EP2_Q_COORDINATES", "UNRESOLVED QUESTIONS", "FURY'S COORDINATES - NOT RECOVERED",
		"Navigational information exists in the surviving memories, but the structures were too damaged to reconstruct it during the first meld. Another reference point is required.")
	Case.define("EP2_Q_WHY_CONFERENCE", "UNRESOLVED QUESTIONS", "WHY WAS HE IN EXACTLY THAT POSITION?",
		"If this man genuinely believed in peace and was not consciously participating in an intelligence operation, why did the peace conference place him in exactly the position necessary to discover Fury?")
	# --- 2.03: the aftermath (script 13)
	Case.define("EP2_DATAPAD_COORDS", "DEDUCTIONS", "THE DATAPAD MAY CONTAIN THE COORDINATES",
		"The coordinates he consciously viewed were associated with the transfer to his datapad. The datapad may contain them directly - and far more he never read.")
	Case.define("EP2_REVIEW_SINCERE", "DEDUCTIONS", "NO EVIDENCE TURIAN WAS KNOWINGLY PART OF A COVERT OPERATION",
		"The delegate appears to have been sincere. His later unauthorised investigation of Fury was independent of his diplomatic purpose.")
	Case.define("EP2_REVIEW_CONFERENCE", "UNRESOLVED QUESTIONS", "WAS THE PEACE CONFERENCE ITSELF GENUINE?",
		"The meld establishes what the delegate believed. It does not establish whether those beliefs were accurate. Independent investigation is required.")
	Case.define("EP2_REVIEW_CONTRADICTION", "DEDUCTIONS", "A SINCERE DELEGATE, AN UNVERIFIED CONFERENCE",
		"If the delegate was sincere, the possibility remains that somebody else benefited from the access his diplomatic role created. That possibility requires physical evidence.")
	Case.define("EP2_REVIEW_SOURCES", "DEDUCTIONS", "THREE SOURCES FOR THE COORDINATES",
		"The surviving memory establishes that the coordinates existed. The datapad may contain them directly. Vulcan records may provide independent corroboration. No source should be excluded.")
	Case.define("EP2_DECRYPT_STATUS", "PHYSICAL EVIDENCE", "TURIAN'S DATAPAD - ENCRYPTION",
		"Enterprise personnel have broken one layer. There are many more; the encryption changes structure each time a layer is penetrated. Not standard Romulan diplomatic security. Completion: eventually, probably. Not soon.")
	Case.define("EP2_SPECIALISTS_ABOARD", "PERSONS OF INTEREST", "VULCAN COMPUTER SPECIALIST TEAM",
		"Three specialists sent in answer to Captain Kirk's request: a senior computer specialist (secure archive architecture and historical data recovery), an archive systems specialist, a technical specialist (adaptive decryption). Working on the datapad with Enterprise personnel, in an isolated environment, under Starfleet security.")
	Case.define("EP2_CHAPEL_RESEARCH", "MEDICAL FINDINGS", "NURSE CHAPEL - REVIEWING THE FIRST MELD'S DATA",
		"During the meld the two neural patterns partly synchronised; Turian's remaining structures broke down faster as Spock's activity rose. Chapel is studying whether the structures could be stabilised.")
	# --- 2.04: Vulcan (script 14)
	Case.define("EP2_V_Q_WHO", "UNRESOLVED QUESTIONS", "WHO MANIPULATED ACCESS TO TURIAN?",
		"Three physical leads: the conference chamber, the administrative amendments, Turian's private contact windows.")
	Case.define("EP2_V_ROUTES", "PHYSICAL EVIDENCE", "THREE REPEATED APPROACH ROUTES",
		"With the seating chart's three overlays aligned to the marks on the table, three positions form repeated access routes to Turian's seat - out of sight of the main entrance. This does not identify the people.")
	Case.define("EP2_V_IDENTIFIERS", "PHYSICAL EVIDENCE", "THREE TEMPORARY IDENTIFIERS WERE INTRODUCED AFTER THE ORIGINAL SEATING PLAN",
		"Three temporary Vulcan administrative identifiers among the discarded placards. They look legitimate. One carries a tiny manufacturing mark from an off-world replicator standard.")
	Case.define("EP2_V_CLOCK", "MEDICAL FINDINGS", "SOFT CLOCK - TURIAN'S RECOVERABLE MEMORY IS SHRINKING",
		"Chapel: one of the repeating structures mapped earlier is no longer resolving. Deterioration is increasing. The tissue can be preserved; information already disappearing cannot.")
	Case.define("EP2_V_ENDORSEMENT", "WITNESS STATEMENTS", "THE IDENTIFIERS CARRIED A VALID PROCEDURAL ENDORSEMENT",
		"The conference secretary: they were not generated by this office, but they were accepted because they carried a valid procedural endorsement. Whose is recorded in the amendment packet - missing from the active file.")
	Case.define("EP2_V_PACKET", "PHYSICAL EVIDENCE", "THE AMENDMENT PACKET - ROUTED THROUGH R-3",
		"Recovered from the disposal hopper: the original peace proposal, later cultural amendments, the three temporary identifiers, an endorsement stamp, and a routing notation written on the packet itself: R-3.")
	Case.define("EP2_V_R3_GROUP", "DEDUCTIONS", "AT LEAST THREE PEOPLE USED R-3 TOGETHER",
		"Three vessels used in the same short period; three chairs arranged around a portable transmitter's abrasion, not the desk; a backing fragment matching the temporary identifiers. An unrecorded work session connected to the identifiers.")
	Case.define("EP2_V_FOOTAGE", "PHYSICAL EVIDENCE", "THE SAME THREE-PERSON GROUP MOVED THE AMENDMENT MATERIAL",
		"Masked footage, read by consequence rather than face: the same three-person group moved the amendment material through R-3 and the adjacent service route.")
	Case.define("EP2_V_THREE_CONTACTS", "MEDICAL FINDINGS", "THREE CONTACTS, THREE EPISODES OF NEUROLOGICAL DAMAGE",
		"McCoy's three times for Turian's unexplained neural deterioration each fall on a private recess or unscheduled interval in the conference agenda. The correspondence is unlikely to be coincidental.")
	Case.define("EP2_V_ARCHIVE_CLEAR", "DEDUCTIONS", "THE ARCHIVE DID NOT CAUSE HIS NEURAL TRAUMA",
		"The session integrity record: legitimate Fury access, denied restricted requests, a bulk download - and no neural interface, no neurological countermeasure, no archive event matching the injuries.")
	Case.define("EP2_V_SHUT_DOWN", "DEDUCTIONS", "FURY WAS DELIBERATELY SHUT DOWN - ITS DESTRUCTION IS NOT ESTABLISHED",
		"A late summary: destroyed. A secondary index: decommissioned. An ancient primary record: silenced. The oldest evidence supports a deliberate shutdown. This confirms a fragment from Mind Meld One.")
	Case.define("EP2_V_THREE", "PERSONS OF INTEREST", "THREE PEOPLE WITH VULCAN ADMINISTRATIVE CREDENTIALS",
		"Redacted administrative stills from R-3 (faces masked under Vulcan privacy law). Three people carrying valid-looking Vulcan administrative credentials. Not identifiable from the images.")
	Case.define("EP2_V_TARGET", "DEDUCTIONS", "TURIAN WAS THE TARGET OF THE OPERATION, NOT ITS AGENT",
		"His sincere proposal, the manipulated amendment packet, R-3, the three private-access windows, the three neurological episodes and the three administrative operatives. The evidence is consistent with repeated invasive telepathic contact.")
	Case.define("EP2_V_FEEDBACK", "MEDICAL FINDINGS", "THE FIRST MELD - ABRUPT WITHDRAWAL WORSENED THE FEEDBACK",
		"Spock to McCoy: during withdrawal, the feedback became markedly worse when he attempted to break contact abruptly. McCoy recorded it.")
	# --- 2.05: Chapel's research (script 15)
	Case.define("EP2_C_GRADUAL", "MEDICAL FINDINGS", "GRADUAL WITHDRAWAL REDUCES REBOUND",
		"An old examination in Spock's record, McCoy's note: \"Abrupt cortical suppression produced rebound activity. Gradual reduction normalised the response.\"")
	Case.define("EP2_C_REGULATOR", "MEDICAL FINDINGS", "INHIBITORY SYNAPTIC REGULATOR",
		"The experimental neural dampener in the old report - McCoy remembered the drug family once he saw the obsolete cortical stimulator. A family, not a prescription.")
	Case.define("EP2_C_FEEDBACK_PATH", "MEDICAL FINDINGS", "FEEDBACK PATH IDENTIFIED",
		"With one neural pickup moved from the cranial mount to Spock's hand and forearm contact path: the feedback propagates from the contact interface back into Spock during abrupt withdrawal.")
	Case.define("EP2_C_SLOW", "DEDUCTIONS", "SLOW THE CHANGE - DON'T SUPPRESS EITHER MIND",
		"More preservation: Turian steadier, Spock's rebound unchanged. Suppressing residual activity: the memory pattern collapses. Reducing Spock's activity: less feedback, but he can't hold the meld. The answer is to slow the rate at which the connection changes.")
	Case.define("EP2_C_COMPOUND", "PHYSICAL EVIDENCE", "EXPERIMENTAL NEURAL STABILISATION COMPOUND",
		"Carrier first (the refrigerated targeting compound, drawn with a manual hypospray cartridge), the inhibitory regulator second (McCoy's controlled cabinet), Vulcan-compatible metabolic support last.")
	Case.define("EP2_C_PROCEDURE", "DEDUCTIONS", "THE WITHDRAWAL PROCEDURE",
		"Establish Spock's baseline. Administer the stabiliser. Begin the meld. Monitor feedback. Do not break contact abruptly. Reduce contact in stages, on Chapel's instruction. The compound only makes the procedure survivable.")
	Case.define("EP2_MELD_TWO_POSSIBLE", "MEDICAL FINDINGS", "MIND MELD TWO IS POSSIBLE",
		"The controlled neural-load test reproduced the shape of Spock's historical gradual-withdrawal trace. McCoy: medically defensible. He doesn't like it.")
	# --- 2.06: the second purpose (script 16)
	Case.define("EP2_L_DIRECTORY", "PHYSICAL EVIDENCE", "THE DATAPAD'S STRUCTURE",
		"Diplomatic correspondence; archive session metadata; one unusually large downloaded archive package; navigation-related storage. The contents remain encrypted.")
	Case.define("EP2_L_TOO_LONG", "DEDUCTIONS", "DECRYPTION TIME: TOO LONG TO ASSUME SUCCESS",
		"The senior specialist: recovering the protected archive package could take many hours.")
	Case.define("EP2_L_TWO_CLOCKS", "DEDUCTIONS", "TWO CLOCKS",
		"FULL PROTECTED ARCHIVE PACKAGE: 17-19 HOURS (partial structural / navigational recovery possibly sooner).\nTURIAN'S USEFUL NEURAL STRUCTURES: ONLY HOURS (Chapel).")
	Case.define("EP2_L_DECISION", "DEDUCTIONS", "CONVENTIONAL DECRYPTION CANNOT BE RELIED UPON BEFORE THE MEMORY IS LOST",
		"Not a suspicion of the specialists: their legitimate work may simply be too slow. The second meld may be the only timely source.")
	Case.define("EP2_A_PATH", "PHYSICAL EVIDENCE", "AUXILIARY CONTROL - ISOLATED DIAGNOSTIC PATH",
		"Engineering telemetry moved to its redundant channel (Scott's authority); the datapad cable has the auxiliary processor beside the navigation test. Nothing has direct navigation or helm authority. Security present.")
	Case.define("EP2_A_ISOLATOR", "PHYSICAL EVIDENCE", "THE SPECIALIST'S FIELD ISOLATOR",
		"A modified pattern: the standard tool cannot maintain separation at this bandwidth. Back in the specialist's equipment case.")
	# --- 2.07: mind meld two (script 17)
	Case.define("EP2_M2_COORDS", "PHYSICAL EVIDENCE", "FURY COORDINATES RECOVERED",
		"Reconstructed from the stellar display Turian consciously studied before the download: the bright binary pair, the red giant low on the display, the three-star arc, and Fury's marker among them. Derived from a damaged memory; Spock is confident in the reconstruction.")
	Case.define("EP2_M2_MOTIVE", "DEDUCTIONS", "WHY FURY MATTERED TO TURIAN",
		"He believed a shared, forgotten history could give the peace effort something real to build on. SHARED HISTORY. NOT MEANT TO FORGET. A BEGINNING. His pursuit of Fury stayed connected to the reconciliation he sincerely wanted.")
	Case.define("EP2_M2_THREE", "UNRESOLVED QUESTIONS", "THREE",
		"A recurring impression in Turian's damaged memory: three. Not three objects - simply the concept. Its meaning cannot be determined.")
	Case.define("EP2_M2_SECOND", "MEDICAL FINDINGS", "THE SECOND MELD",
		"Staged withdrawal held under a rebound complication. Spock conscious. Turian's residual memory structures deteriorated further. McCoy: no third time. Spock: agreed.")
	# --- 2.08: the team that never existed (script 18)
	Case.define("EP2_R_NO_TEAM", "DEDUCTIONS", "VULCAN DISPATCHED NO COMPUTER TEAM - THE RESPONSE WAS INTERCEPTED",
		"No computer specialists were dispatched to Enterprise. Enterprise's request was intercepted and answered by someone else. The specialists aboard are not who they claim to be.")
	Case.define("EP2_R_BOP", "PHYSICAL EVIDENCE", "CLOAKED ROMULAN BIRD-OF-PREY DISCOVERED - IMPOUNDED",
		"Found by Vulcan orbital scans; its cloak interfered with and boarded by Vulcan science officers. Unoccupied. Equipment and authentication systems associated with the Romulan security apparatus. Impounded pending investigation, science officers aboard.")
	Case.define("EP2_R_DENIAL", "WITNESS STATEMENTS", "ROMULUS DENIES THE VESSEL - AND THE CONFERENCE",
		"Romulus denies authorising the vessel and has no knowledge of a peace conference on Vulcan. An unverified diplomatic claim - not to be treated as proof, nor ignored.")
	Case.define("EP2_R_LINK", "UNRESOLVED QUESTIONS", "THE EMPTY SHIP AND THE FALSE SPECIALISTS",
		"Three people claiming Vulcan sent them; an empty Romulan ship hiding in orbit. A connection is strongly indicated, not yet proven.")
	Case.define("EP2_R_CREDENTIALS", "DEDUCTIONS", "THE SAME OPERATION FABRICATED THE RESPONSE TO ENTERPRISE",
		"The temporary identifiers, R-3's amendment packet, the forged endorsement, Enterprise's request: the operation that manipulated the conference had enough administrative procedure to fabricate a convincing response.")
	Case.define("EP2_S_DECOY", "PHYSICAL EVIDENCE", "THE TURBOLIFT WAS A DECOY",
		"Called, arrived, never moved. Beside it a Jefferies-tube hatch with a forced latch - and the specialists' field isolator, dropped.")
	Case.define("EP2_R_STOLEN", "PHYSICAL EVIDENCE", "ENTERPRISE HAS LEFT ORBIT",
		"No response to hails. Scott's communicator carrier returns, nobody answers. Vulcan's display: Enterprise's berth empty and a fresh warp departure leaving the system.")
	# --- 2.09: the missing Enterprise (script 19)
	Case.define("EP2_X_TRACK", "PHYSICAL EVIDENCE", "ENTERPRISE DEPARTURE TRACK IDENTIFIED",
		"Isolated from the station's sensor events by mass, warp signature, departure time, orbital position and heading - not by name.")
	Case.define("EP2_X_VECTOR", "DEDUCTIONS", "THE VECTOR ESTABLISHES DEPARTURE - NOT DESTINATION",
		"Extended, the initial warp vector crosses several systems, then means nothing: the ship could alter course once outside the sensor envelope.")
	Case.define("EP2_X_TRANSPONDER", "DEDUCTIONS", "ENTERPRISE'S TRANSPONDER WAS DELIBERATELY DISABLED OR MASKED",
		"Received normally before the hijacking; the signal vanishes at the departure event rather than fading with distance.")
	Case.define("EP2_X_ENGINE", "DEDUCTIONS", "THE HIJACKERS TOOK STEPS TO CONCEAL ENTERPRISE AFTER DEPARTURE",
		"Scotty's injector imbalance let Spock pick out her engine profile - for a few seconds. Then deliberate drive-field masking and overlapping traffic.")
	Case.define("EP2_X_WAKE", "DEDUCTIONS", "ONLY ENTERPRISE'S INITIAL DEPARTURE CORRIDOR CAN BE RECONSTRUCTED",
		"Civilian departures removed from the display, the engine fragment overlaid: her initial wake. It disperses before any later course change - but its first vector survives.")
	Case.define("EP2_X_FURY_TRAIL", "DEDUCTIONS", "ENTERPRISE'S LAST RECOVERABLE TRAIL IS COMPATIBLE WITH FURY",
		"Not proof of her final destination. But Fury lies within the continuation of the last course that can be reconstructed, and it is the only destination connected to this operation that is known.")
	Case.define("EP2_X_BOP_BEST", "DEDUCTIONS", "THE BIRD-OF-PREY IS THE BEST SHIP FOR A COVERT PURSUIT",
		"Immediately available, warp-capable, cloaked - and anyone watching the trail may read a Romulan sensor profile as one of their own. Temporarily released by the Vulcan leader; to be returned afterwards.")
	Case.define("EP2_MELD_DANGER", "MEDICAL FINDINGS", "THE FIRST MELD - MEDICAL CONSEQUENCES",
		"Severe neurological stress to Spock. The meld accelerated the deterioration of Turian's remaining neural structures. Doctor McCoy has prohibited a second attempt unless the medical danger can be reduced.")


static func _register_objectives() -> void:
	if MissionLog.get_entry(LOG_OBJECTIVE_ENTRY) == null:
		var entry := MissionLogEntryData.new()
		entry.id = LOG_OBJECTIVE_ENTRY
		entry.title = EPISODE_TITLE     # REV 296: was CASE_TITLE - the LOG showed two entries with the same heading
		entry.current_text = String(OBJECTIVES.values()[0])
		MissionLog.register_entry(entry)
	for id in OBJECTIVES.keys():
		var obj := ObjectiveData.new()
		obj.id = "OBJ_EP2_" + String(id)
		obj.text = String(OBJECTIVES[id])
		obj.mission_log_entry_id = LOG_OBJECTIVE_ENTRY
		ObjectiveManager.register_objective(obj)


static func set_objective(key: String) -> void:
	if not OBJECTIVES.has(key):
		push_warning("Ep2: unknown objective '%s'" % key)
		return
	ObjectiveManager.set_current_objective("OBJ_EP2_" + key)


## The voice file name for a line: SPOCK_EP2_1A2B3C.mp3 (stable as long as the words don't change).
static func line_id(who: String, text: String) -> String:
	var folder: String = String(SPEAKERS.get(who, [who, who])[0])
	return folder.to_upper() + "_EP2_" + text.md5_text().substr(0, 6).to_upper()


static func flag(name: String) -> bool:
	return GameState.has_var(name) and bool(GameState.get_var(name))


static func set_flag(name: String, value: bool = true) -> void:
	GameState.set_var(name, value)


# ---- Memory Anchors (the meld's knowledge inventory, script 12.3 rule two) -----------------------

static func anchors() -> Array:
	var v: Variant = GameState.get_var("EP2_MELD_ANCHORS")
	return (v as Array).duplicate() if v is Array else []


static func has_anchor(id: String) -> bool:
	return anchors().has(id)


## Adds an anchor; true if it was new (and shows the notice).
static func add_anchor(id: String) -> bool:
	var a := anchors()
	if a.has(id):
		return false
	a.append(id)
	GameState.set_var("EP2_MELD_ANCHORS", a)
	MissionLog.notification_requested.emit("Memory Anchor acquired: " + String(ANCHORS.get(id, id)))
	sync_items()     # REV 508: it's in the thought-inventory at once
	return true


## REV 508: the anchor id of a backpack item id ("" if it isn't an anchor).
static func anchor_of(item_id: String) -> String:
	return item_id.substr(ANCHOR_PREFIX.length()) if item_id.begins_with(ANCHOR_PREFIX) else ""


## REV 508: true while the room on screen is a mind meld (room key "meld1" / "meld2").
static func in_meld() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return false
	var k: Variant = tree.current_scene.get("room_key")
	return k != null and String(k).begins_with("meld")


static func _anchor_item(id: String) -> InventoryItemData:
	var iid := ANCHOR_PREFIX + id
	var it := InventoryManager.find_known_item(iid)
	if it != null:
		return it
	it = InventoryItemData.new()
	it.id = iid
	it.display_name = String(ANCHORS.get(id, id))
	it.description = "A memory anchor - a detail stable enough to hold on to. USE it on a memory, or on another anchor."
	it.examine_text = it.description
	InventoryManager.register_item(it)
	return it


## Which rooms the travel menu offers right now (Episode 2 so far moves by story, not by menu).
static func unlocked_rooms() -> Array:
	return []


# ---- optional systems (none in Episode 2) ---------------------------------------------------------

static func clock_text() -> String:
	return ""


static func clock_alert() -> String:
	return ""


static func clock_penalty(_minutes: int = 15) -> int:
	return 0


static func pending_deduction() -> String:
	return ""


static func deduction_ready() -> bool:
	return pending_deduction() != ""


## REV 293: EpisodeRoom hands the Case File's results to the room's episode. Episode 2 has no Case File comparisons or deductions (its reasoning is in each room's own puzzles).
static func run_compare(_room: EpisodeRoom, _rule: String) -> bool:
	return false     # false = "not a rule I know" (the lead shrugs)


static func run_deduction(_room: EpisodeRoom) -> void:
	pass


## Shows "NEW DEDUCTION POSSIBLE" once per deduction key (when pending_deduction() returns one);
## true if it was shown now. (See Ep1.deduction_noticed for an episode that has deductions.)
static func deduction_noticed(key: String) -> bool:
	var flag_name := PREFIX + "_" + key.to_upper() + "_NOTICED"
	if flag(flag_name):
		return false
	set_flag(flag_name)
	MissionLog.notification_requested.emit("NEW DEDUCTION POSSIBLE  (press C)")
	return true


static func find_compare(a: String, b: String) -> String:
	for rule in COMPARE_RULES:
		if (rule[0] == a and rule[1] == b) or (rule[0] == b and rule[1] == a):
			return String(rule[2])
	return ""


# =========================================================================
# REV 505 - THE REDESIGN (EPISODE2_SCRIPT.md, 27 Oct): no Case File on screen. Knowledge lives in people
# (THE PARTNER - "Summarise, Doctor."), evidence is things you carry, SHOW and USE, and every conclusion
# is SAID when its action lands. Spock's log stays as hidden memory (Case) only.
# =========================================================================
const CASE_FILE := false


## Episode 2's carried things. The story still runs on its flags; the backpack MIRRORS them (sync_items,
## like Ep1.ITEMS): an item is in the backpack while its "have" flag is set and its "gone" flag isn't -
## and only while its OWNER is the one being played (each lead carries their own - the script's table).
## id -> [have flag, gone flag ("" = never), name, description, owner]
const ITEMS := {
	# 2.01 - Spock
	"EP2_ITEM_SCANNER": ["EP2_SCANNER_HELD", "EP2_MELD_HAND", "Medical Scanner",
		"Sickbay's scanner head, still on its swing arm. Point it at things.", "spock"],
	"EP2_ITEM_STIMULATOR": ["EP2_STIM_HELD", "EP2_TRY_STIM", "Neural Stimulator",
		"From the instrument tray. Spock has set it very low. Doctor McCoy is watching it very closely.", "spock"],
	# 2.04 - Spock, on Vulcan
	"EP2_ITEM_OVERLAYS": ["EP2_V_HAS_OVERLAYS", "EP2_V_SEATING_SOLVED", "Seating Overlays",
		"Three transparent sheets from the chamber cabinet: delegation placement, security zones, service routes.", "spock"],
	"EP2_ITEM_IDENTIFIERS": ["EP2_V_IDENTIFIERS", "", "Temporary Identifiers",
		"Three Vulcan administrative identifiers from the service alcove. One carries a tiny off-world replicator mark.", "spock"],
	"EP2_ITEM_DOORSTOP": ["EP2_V_CARRY_STONE", "EP2_V_PACKET", "Ceremonial Doorstop",
		"A ceremonial stone, used to hold the gallery doors during public events. Heavy. Very heavy.", "spock"],
	"EP2_ITEM_PACKET": ["EP2_V_PACKET", "", "Amendment Packet",
		"The superseded amendment packet, rescued from the hopper. The original proposal, the cultural amendments, the identifiers' authorisation - and in the corner, by hand: R-3.", "spock"],
	"EP2_ITEM_BACKING": ["EP2_V_R3_FRAGMENT", "", "Identifier Backing",
		"A scrap of identifier backing from under the cabinet in office R-3.", "spock"],
	"EP2_ITEM_MARKERS": ["EP2_V_HAS_MARKERS", "EP2_V_MEDICAL_TIMES", "McCoy's Markers",
		"Three little medical tags in Doctor McCoy's hand: about 11:40, about 15:10, about 19:30.", "spock"],
	# 2.06 - Spock, for a moment
	"EP2_ITEM_KOVEK_TOOL": ["EP2_A_HAS_TOOL", "EP2_A_Q_ISOLATOR", "Field Isolator",
		"The technical specialist's tool. Slim, odd, beautifully made. She'd like it back.", "spock"],
	# 2.05 / 2.07 - Chapel
	"EP2_ITEM_SOUP": ["EP2_C_HAS_SOUP", "EP2_SOUP_GIVEN", "Plomeek Soup",
		"A flask of plomeek soup. It's for after.", "chapel"],
	"EP2_ITEM_OLD_STIM": ["EP2_C_HAS_STIMULATOR", "EP2_C_DONE", "Old Cortical Stimulator",
		"From Doctor McCoy's museum shelf. The tag says TANTALUS V - DO NOT USE.", "chapel"],
	"EP2_ITEM_TANTALUS": ["EP2_C_GRADUAL", "EP2_M2_STARTED", "Tantalus Record",
		"A copy of the Tantalus V meld record: abrupt suppression made it worse; gradual reduction calmed it. Spock's own withdrawal curve, from years ago.", "chapel"],
	"EP2_ITEM_TRACE": ["EP2_C_FEEDBACK_PATH", "EP2_C_DONE", "Feedback Trace",
		"A print-out: the feedback runs back up the contact into Spock's hand when he pulls away fast.", "chapel"],
	"EP2_ITEM_CARTRIDGE": ["EP2_C_HAS_CARTRIDGE", "EP2_C_HAS_CARRIER", "Manual Hypospray Cartridge",
		"From the emergency kit by the door. It's been there all along, looking useless.", "chapel"],
	"EP2_ITEM_CARRIER": ["EP2_C_HAS_CARRIER", "EP2_C_PRIMED", "Carrier",
		"The refrigerated carrier, loaded by hand into the manual cartridge.", "chapel"],
	"EP2_ITEM_REGULATOR": ["EP2_C_HAS_REGULATOR", "EP2_C_PRIMED", "Synaptic Regulator",
		"An inhibitory synaptic regulator from Doctor McCoy's controlled cabinet.", "chapel"],
	"EP2_ITEM_PRIMED": ["EP2_C_PRIMED", "EP2_C_COMPOUND", "Primed Carrier",
		"The carrier with the regulator bound to it. It wants one thing more.", "chapel"],
	"EP2_ITEM_SUPPORT": ["EP2_C_HAS_SUPPORT", "EP2_C_COMPOUND", "Vulcan Support Compound",
		"The stimulant Doctor McCoy gave Spock safely at Tantalus. Not cordrazine.", "chapel"],
	"EP2_ITEM_STABILISER": ["EP2_C_COMPOUND", "EP2_M2_COMPOUND_LOADED", "Experimental Neural Stabiliser",
		"Christine Chapel's own formulation. It doesn't make the meld safe. It makes coming out survivable.", "chapel"],
	# 2.09 - Spock, at the science station
	"EP2_ITEM_SLATE": ["EP2_X_HAS_SLATE", "EP2_X_WAKE", "Traffic Slate",
		"The station's list of civilian departures. A list of everything she isn't.", "spock"],
	"EP2_ITEM_FRAGMENT": ["EP2_X_ENGINE", "EP2_X_WAKE", "Engine Fragment",
		"A few seconds of Enterprise's warp signature - Mister Scott's flat injector, singing.", "spock"],
	# 2.08 - Giotto
	"EP2_ITEM_ISOLATOR": ["EP2_S_ISOLATOR", "", "The Isolator (evidence)",
		"Slim, odd, beautifully made. The technical specialist's 'modified pattern'. Bagged and logged.", "giotto"],
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


## Who is being played as a person right now ("spock", "chapel", "giotto", "kirk").
static func played() -> String:
	return String(GameState.get_var("EP2_ACTIVE_LEAD")) if GameState.has_var("EP2_ACTIVE_LEAD") else "spock"


## Makes the backpack match the story flags and whoever is being played (quietly).
static func sync_items() -> void:
	var who := played()
	var meld := in_meld()
	# REV 508: inside a meld Spock carries only thoughts - the anchors; outside, never
	var held_anchors: Array = anchors() if meld else []
	for aid in ANCHORS.keys():
		var iid := ANCHOR_PREFIX + String(aid)
		var want_a := held_anchors.has(aid)
		if want_a and not InventoryManager.has_item(iid):
			InventoryManager.add_item(_anchor_item(String(aid)), true)
		elif not want_a and InventoryManager.has_item(iid):
			InventoryManager.remove_item(iid)
	for id in ITEMS.keys():
		var row: Array = ITEMS[id]
		var want := flag(String(row[0])) and (String(row[1]) == "" or not flag(String(row[1]))) and String(row[4]) == who and not meld
		var have := InventoryManager.has_item(String(id))
		if want and not have:
			InventoryManager.add_item(_item(String(id)), true)
		elif have and not want:
			InventoryManager.remove_item(String(id))


## One backpack item used on another. True when something was answered.
static func combine_items(room: EpisodeRoom, a: String, b: String) -> bool:
	var pair := [a, b]
	# REV 508: two thoughts together (inside a meld the room decides what they make)
	if anchor_of(a) != "" and anchor_of(b) != "":
		if room.has_method("anchor_combine"):
			return await room.anchor_combine(anchor_of(a), anchor_of(b))
		return false
	# 2.05 - the stabiliser, in order: carrier, then regulator, then support (script 15.9)
	if pair.has("EP2_ITEM_CARRIER") and pair.has("EP2_ITEM_REGULATOR"):
		await room.note("CARRIER + SYNAPTIC REGULATOR", 2.0)
		set_flag("EP2_C_PRIMED")
		sync_items()
		await room.say("chapel", "Carrier first. Then the regulator binds to it. Good.")
		return true
	if pair.has("EP2_ITEM_PRIMED") and pair.has("EP2_ITEM_SUPPORT"):
		await room.note("PRIMED CARRIER + VULCAN SUPPORT COMPOUND  ->  EXPERIMENTAL NEURAL STABILISER", 2.8)
		set_flag("EP2_C_COMPOUND")
		Case.add("EP2_C_COMPOUND")
		sync_items()
		await room.say("chapel", "Clear. It's clear.")
		await room.say("mccoy", "Don't sound so surprised, Christine.")
		await room.say("chapel", "I'm not surprised. I'm relieved. It's different.")
		return true
	if pair.has("EP2_ITEM_REGULATOR") and pair.has("EP2_ITEM_SUPPORT"):
		await room.note("(A cloudy mess in the vial.)", 1.6)
		await room.say("chapel", "No. The regulator is binding before the carrier is ready.")
		return true
	if pair.has("EP2_ITEM_CARRIER") and pair.has("EP2_ITEM_SUPPORT"):
		await room.note("(A cloudy mess in the vial.)", 1.6)
		await room.say("chapel", "No. Support goes in last, or it swamps everything else.")
		return true
	if pair.has("EP2_ITEM_SOUP"):
		await room.say("chapel", "No. That's for after.")
		return true
	if pair.has("EP2_ITEM_ISOLATOR"):
		await room.say("giotto", "Evidence doesn't get used, it gets logged.")
		return true
	if pair.has("EP2_ITEM_IDENTIFIERS") and pair.has("EP2_ITEM_BACKING"):
		await room.say("spock", "A perfect match. The identifiers were assembled in office R-3.")
		set_flag("EP2_V_BACKING_MATCHED")
		return true
	if pair.has("EP2_ITEM_SCANNER") or pair.has("EP2_ITEM_STIMULATOR"):
		await room.say("spock", "That combination would serve no purpose.")
		return true
	return false


# ---- THE PARTNER - "Summarise, Doctor." (EPISODE2_SCRIPT.md) ------------------------------------
## Talk to the partner in the room - McCoy for Spock, McCoy for Chapel, Scotty on the comm for Giotto,
## Spock for Kirk; Spock to himself inside a meld. Line 1 nudges, 2 points, 3 says it plainly; the same
## lines play unasked when the player has been stuck a couple of minutes (EpisodeRoom.partner_hint).
## REV 715 (Glen's 29 Oct list, item 3): the CURRENT OBJECTIVE at the top of the Mission Log for each PARTNER stage - the
## goal, never the method (EpisodeRoom.current_goal). Keep one for every PARTNER stage.
const GOALS := {
	"pattern": "Find out what's wrong with Ambassador Turian's brain pattern.",
	"read_memory": "Find a way to read Turian's memory.",
	"talk_mccoy": "Convince Dr. McCoy the meld is necessary.",
	"prepare_meld": "Get ready for the mind meld.",
	"m1_hub": "Find your way through Turian's memory.",
	"m1_fury": "Find out what Fury is.",
	"m1_archive": "Find out who read the old records.",
	"m1_restricted": "Follow the trail through the restricted records.",
	"m1_download": "Find out what was taken from the archive.",
	"m1_doors": "See what lies behind the memory's doors.",
	"m1_pressure": "Find what Turian is afraid of.",
	"cleared": "Get Dr. McCoy to clear you for duty.",
	"recap": "Go over what the meld showed.",
	"report_kirk": "Report to Captain Kirk on the bridge.",
	"meet_team": "Meet the away team in the transporter room.",
	"meet_team_bridge": "Meet the away team in the transporter room.",
	"archivist": "Get the Archivist to help you.",
	"chamber": "Work out who sat where in the conference chamber.",
	"alcove": "Search the conference chamber.",
	"r3_search": "Search room R-3.",
	"secretary": "Find out who the delegates really were.",
	"hopper": "Get into the sealed records.",
	"r3": "Find room R-3.",
	"markers": "Work out what was really on the agenda.",
	"records": "Find out how old the records are.",
	"c_record": "Find out what's been done to Spock before.",
	"c_drug": "Find something that can help Spock through a second meld.",
	"c_sensor": "Get a clean reading of Spock.",
	"c_three": "Prepare the treatment.",
	"c_bench": "Set up the treatment.",
	"c_test": "Match the treatment to the Tantalus record.",
	"c_report": "Report the procedure to Dr. McCoy.",
	"lab_time": "Get the decryption moving.",
	"lab_start": "Find out how long the decryption will take.",
	"lab_scotty": "Find a faster way through - Engineering can help.",
	"lab_aux": "Take the specialists to Auxiliary Control.",
	"lab_back": "Get a new estimate for the decryption.",
	"aux_q1": "Find what's slowing the processor.",
	"aux_q2": "Find the way round the blockage.",
	"aux_q3": "Open the maintenance interface.",
	"aux": "Get the decryption a clear path.",
	"m2_prep": "Get Spock ready for the second meld.",
	"m2_auth": "Check everything is ready for the meld.",
	"m2_after": "Look after Spock and Turian.",
	"m2_soup": "Help Spock recover.",
	"m2_conf": "Find what Turian was made to forget.",
	"m2_inside": "Find where Fury is.",
	"m2_v1": "Find the first of Fury's coordinates.",
	"m2_v2": "Find the second of Fury's coordinates.",
	"m2_value3": "Find the third of Fury's coordinates.",
	"m2_motive": "Find out why Turian hid Fury.",
	"m2_three": "Find what 'three' means.",
	"m2_withdraw": "Bring Spock safely out of the meld.",
	"g_brig": "Find out what happened in the brig.",
	"g_trail": "Follow the intruders.",
	"g_branches": "Work out where the intruders went.",
	"g_door": "Get after the intruders.",
	"g_trunk": "Cut the intruders off from the ship's systems.",
	"g_clamps": "Release the clamps.",
	"kirk_stolen": "Find out what's happened to the Enterprise.",
	"tseva_report": "Report to Councillor T'Seva.",
	"tseva_hub": "Find out what the Vulcans can offer.",
	"tseva_creds": "Prove who the intruders really were.",
	"go_home": "Get back to the ship.",
	"find_ent": "Find the Enterprise.",
	"x_vector": "Work out where the Enterprise is heading.",
	"x_transponder": "Pick up the Enterprise's transponder.",
	"x_engine": "Identify the Enterprise from her engines.",
	"x_wake": "Sort the Enterprise from the civilian traffic.",
	"x_ship": "Find a ship to go after her.",
	"x_go": "Get to the Bird-of-Prey.",
	"bop_go": "Get the Bird-of-Prey under way.",
	"engine": "Get the Bird-of-Prey's engines working.",
	"clamp": "Get free of the docking clamp.",
	"controls": "Work out the Romulan controls.",
	"coords": "Set course for Fury.",
}

## REV 745 (Glen, 31 Oct: the map's pulsing objective marker, every episode): the hotspot(s) each PARTNER stage points
## at - the first one present in the room you're in. Not in this room: the room's way out (an *_EXIT spot), or on the
## ship the nearest turbolift (EpisodeRoom.objective_target). "" = nothing to point at (a call, a choice).
const MARKERS := {
	"pattern": ["EP2_SB_BODY", "EP2_SB_MONITOR"], "read_memory": "EP2_SB_BODY", "talk_mccoy": "EP2_SB_MCCOY",
	"prepare_meld": "EP2_SB_BIOBED", "cleared": "EP2_SB_DAREV", "recap": "EP2_SB_MCCOY",
	"report_kirk": "EP2_BR_KIRK", "meet_team": ["EP2_TR_KIRK", "EP2_TR_CONSOLE"], "meet_team_bridge": "EP2_TR_CONSOLE",
	"c_record": "EP2_SB_COMPUTER", "c_drug": ["EP2_SB_TRAY_STIM", "EP2_SB_STIMULATOR"], "c_sensor": "EP2_SB_SCANNER",
	"c_three": ["EP2_SB_KIT", "EP2_SB_CABINET", "EP2_SB_COMPUTER"], "c_bench": "EP2_SB_BENCH", "c_test": "EP2_SB_BENCH",
	"c_report": "EP2_SB_MCCOY", "m2_auth": ["EP2_SB_CHAPEL_DESK", "EP2_SB_MONITOR", "EP2_SB_BIOBED"], "m2_prep": "",
	"m2_soup": "EP2_SB_SOUP", "m2_after": ["EP2_SB_BIOBED", "EP2_SB_MONITOR", "EP2_SB_CHAPEL_DESK"],
	"m1_fury": "EP2_M1_TERMINAL", "m1_hub": ["EP2_M1_ECHO", "EP2_M1_CREDENTIALS", "EP2_M1_ARCHIVIST"],
	"m1_archive": "EP2_M1_READER", "m1_restricted": "EP2_M1_RESTRICTED", "m1_download": "EP2_M1_DOWNLOAD",
	"m1_pressure": "EP2_M1_PRESSURE", "m1_doors": "EP2_M1_DATAPAD",
	"m2_conf": "EP2_M2_ECHO", "m2_inside": "EP2_M2_STARS", "m2_v1": "EP2_M2_STARS", "m2_v2": ["EP2_M2_HAND", "EP2_M2_GRID"],
	"m2_value3": "EP2_M2_MARKER", "m2_motive": ["EP2_M2_ECHO", "EP2_M2_MARKER"], "m2_three": "EP2_M2_THREE",
	"m2_withdraw": "EP2_M2_THREADS",
	"kirk_stolen": "EP2_V_ORBIT", "tseva_report": "EP2_V_LEADER", "tseva_hub": "EP2_V_LEADER", "tseva_creds": "EP2_V_LEADER",
	"go_home": "", "r3": "EP2_V_ARCHIVIST", "hopper": "EP2_V_HOPPER", "secretary": "EP2_V_SECRETARY",
	"r3_search": ["EP2_V_R3_VESSELS", "EP2_V_R3_CHAIRS", "EP2_V_R3_CABINET"], "chamber": "EP2_V_CHART",
	"alcove": "EP2_V_ALCOVE", "markers": "EP2_V_AGENDA", "records": "EP2_V_AGENDA", "archivist": "EP2_V_ARCHIVIST",
	"lab_time": "", "lab_back": "EP2_L_SENIOR", "lab_aux": "EP2_L_AUXDOOR", "lab_scotty": "",
	"lab_start": ["EP2_L_DIRECTORY", "EP2_L_SENIOR"],
	"aux": "EP2_A_PROCESSOR", "aux_q1": "EP2_A_LEAD", "aux_q2": "EP2_A_DIAGRAM", "aux_q3": "EP2_A_MAINT",
	"g_brig": ["EP2_S_PULSE", "EP2_S_INJURY", "EP2_S_HOLSTER"], "g_trail": ["EP2_S_LIFT", "EP2_S_TOOL", "EP2_S_HATCH"],
	"g_branches": "EP2_S_AUXDOOR", "g_door": "EP2_S_MAINT", "g_trunk": "EP2_S_TRUNK", "g_clamps": "EP2_S_REAR",
	"find_ent": "EP2_X_SENSORS", "engine": "EP2_X_ANALYSER", "x_vector": "EP2_X_DISPLAY", "x_transponder": "EP2_X_RECEIVER",
	"x_engine": "EP2_X_ANALYSER", "x_wake": ["EP2_X_SLATE", "EP2_X_DISPLAY"], "x_ship": ["EP2_X_KIRK", "EP2_X_LEADER"],
	"x_go": "EP2_X_EXIT", "clamp": ["EP2_B_CLAMP", "EP2_B_ATTITUDE"], "controls": "EP2_B_CONSOLE",
	"coords": "EP2_B_LIBRARY", "bop_go": ["EP2_B_KIRK", "EP2_B_CONSOLE"],
}

const PARTNER := {
	# 2.01 - Sickbay
	"pattern": {"who": "mccoy", "lines": ["Prove he's dead, prove it's real, prove it's going. In that order, if you've any manners.",
		"Your tricorder, the scanner, that monitor.", "Scan Turian, point the scanner at things, and lay two repeats of the trace over each other."]},
	"read_memory": {"who": "mccoy", "lines": ["You'll think of something. That's what worries me.",
		"Try the scanner, the computer, that stimulator - see what fails.", "Try two of the conventional ways. Then use your hand on Turian."]},
	"talk_mccoy": {"who": "mccoy", "lines": ["Ask me properly, Spock.", "Tell me it's necessary.", "Talk to me. Tell me the meld is necessary."]},
	"prepare_meld": {"who": "mccoy", "lines": ["Well? Get on the bed, Spock.", "The empty biobed.", "Use the empty biobed."]},
	# 2.02 - Meld One (Spock, to himself)
	"m1_hub": {"who": "spock", "lines": ["Consider, Spock. What in this room is stable?", "The echo. The credentials. The archivist without a face.",
		"Speak to the echo. Focus on the credentials. Use 'sincere peace delegate' on the archivist."]},
	"m1_fury": {"who": "spock", "lines": ["Two thoughts belong together.", "Access, and the old records.",
		"Combine legitimate archive access with the pre-Reformation records."]},
	"m1_archive": {"who": "spock", "lines": ["Which record did he believe?", "The sharp one. He read it three times.",
		"Focus on the oldest record. Then use 'Fury - shut down' on his echo."]},
	"m1_restricted": {"who": "spock", "lines": ["He followed something into the dark.", "The stamped cards.",
		"Focus a stamped card. Use the index reference on the trail. Focus his curiosity."]},
	"m1_download": {"who": "spock", "lines": ["He took something he never read.", "The worn key. Then the storm around him.",
		"Focus on the bright key. Then the datapad in the storm - and the unread data, for what it cannot give."]},
	"m1_doors": {"who": "spock", "lines": ["Follow what he saw, not what he saved.", "The datapad door.",
		"Enter the datapad door and use the download on the navigational image. Then the door marked fear."]},
	"m1_pressure": {"who": "spock", "lines": ["Something stayed behind when that memory ended.", "The end of the corridor. The light is wrong there.",
		"Focus on the pressure at the end of the corridor."]},
	# 2.03
	"cleared": {"who": "mccoy", "lines": ["Hold still. Follow the light. Squeeze my hand. Ow.", "Finish the exam.",
		"Do what I tell you, then ask me if you're fit."]},
	"recap": {"who": "mccoy", "lines": ["Before you go running to Jim - what do you think you found?", "Ask me to sum it up.", "Ask me: 'Summarise, Doctor.'"]},
	"report_kirk": {"who": "mccoy", "lines": ["Jim's waiting. Try not to frighten him.", "The bridge.", "Take the turbolift to the bridge and talk to Jim."]},
	"meet_team": {"who": "mccoy", "lines": ["Your computer people are here.", "Transporter room.", "Go to the transporter room."]},
	"meet_team_bridge": {"who": "kirk", "lines": ["Your computer people are here, Spock.", "Transporter room.", "Take the lift to the transporter room."]},
	# 2.04 - Vulcan (McCoy for Spock)
	"archivist": {"who": "mccoy", "lines": ["He's not going to hand you everything.", "Ask for one thing he can say yes to.",
		"Find something specific - the conference papers - then ask him about it."]},
	"chamber": {"who": "mccoy", "lines": ["Somebody got close to Turian without being seen.", "The seating chart.",
		"Lay the three overlays on the room plan until they match the marks on the table."]},
	"alcove": {"who": "mccoy", "lines": ["Somebody swapped three nameplates. Recently.", "That service alcove.", "Search the service alcove."]},
	"r3_search": {"who": "mccoy", "lines": ["Three of everything in here, Spock.", "The vessels, the chairs, under the cabinet.",
		"Scan the vessels, read the placard and look at the chairs, and look under the cabinet."]},
	"secretary": {"who": "mccoy", "lines": ["Show her, Spock.", "The identifiers.", "Show the temporary identifiers to the secretary."]},
	"hopper": {"who": "mccoy", "lines": ["Forty-one hours. I'm not waiting forty-one hours.", "That placard says it opens for a jam.",
		"Put the ceremonial doorstop on the loading tray."]},
	"r3": {"who": "mccoy", "lines": ["You've got a room number. Use it.", "The Archivist likes narrow questions.",
		"Say 'R-3' to the Archivist. Then search the office."]},
	"markers": {"who": "mccoy", "lines": ["I gave you three times.", "The agenda cards.", "Put my three markers on the agenda cards that fit."]},
	"records": {"who": "mccoy", "lines": ["Old beats new, Spock. Even I know that.", "Look at what they're made of.",
		"Put the slate, the book and the tablet in order of age."]},
	# 2.05 - Chapel (McCoy for Chapel)
	"c_record": {"who": "mccoy", "lines": ["Christine, the answer's in his file somewhere.", "Only the telepathic ones.",
		"Open TELEPATHIC CONTACT on my computer and find Tantalus."]},
	"c_drug": {"who": "mccoy", "lines": ["I remember nothing. Remind me.", "Something from Tantalus. Look at my shelf.", "Show me that old cortical stimulator."]},
	"c_sensor": {"who": "mccoy", "lines": ["Where's the noise getting IN?", "Watch his hand.", "Move a sensor to Spock's forearm and run it again."]},
	"c_three": {"who": "mccoy", "lines": ["Carrier, regulator, support. Three jobs.", "Emergency kit. My cabinet. The Tantalus record.",
		"Cartridge on the ampoule. Show me the trace. Use the record on the storage."]},
	"c_bench": {"who": "mccoy", "lines": ["Order matters, Christine.", "What has to be ready first?", "Carrier, then regulator, then support."]},
	"c_test": {"who": "mccoy", "lines": ["Match his old curve.", "Three dials.", "Move placement, damping and rate until the live curve sits on the Tantalus one."]},
	"c_report": {"who": "mccoy", "lines": ["Well? Show me.", "Your slate, Christine.", "Talk to me about the procedure."]},
	# 2.06
	"lab_time": {"who": "mccoy", "lines": ["Nineteen hours, they say. Ask how long Turian's got.", "Call Christine.", "Call Chapel from the lab."]},
	"lab_start": {"who": "spock", "lines": ["The datapad first.", "Its structure, then its time.", "Read the directory, then ask the specialist how long."]},
	"lab_scotty": {"who": "spock", "lines": ["The bridge is starving.", "An auxiliary path needs Engineering.", "Call Mister Scott on the communicator."]},
	"lab_aux": {"who": "giotto", "lines": ["Auxiliary Control's up the corridor, sir.", "End of the corridor. The door.", "Walk them to the Auxiliary Control door."]},
	"lab_back": {"who": "giotto", "lines": ["How long now, sir?", "Ask the senior one for a new estimate.", "Talk to the senior specialist about the time."]},
	"aux_q1": {"who": "giotto", "lines": ["She asked what plugs it back in.", "That test lead on the processor.", "Pull the test lead."]},
	"aux_q2": {"who": "giotto", "lines": ["The other one wants a second road.", "That green diagram.", "Trace the redundancy diagram."]},
	"aux_q3": {"who": "giotto", "lines": ["She gave you her gadget, sir.", "The maintenance interface.", "Use her isolator on the maintenance interface."]},
	"aux": {"who": "giotto", "lines": ["Two seats, three customers.", "Which one's got a twin somewhere else?", "Move the engineering telemetry to its redundant socket."]},
	# 2.07
	"m2_prep": {"who": "mccoy", "lines": ["Sensor, stabiliser, his baseline, Turian's pattern.", "Four jobs, Christine. Any order.",
		"Clip the sensor at the biobed, use the stabiliser on Spock, work the workstation and the monitor."]},
	"m2_auth": {"who": "mccoy", "lines": ["Look at what you built, Christine.", "His baseline, Turian's pattern, the rebound.", "LOOK at the workstation, the monitor and the biobed."]},
	"m2_after": {"who": "mccoy", "lines": ["Checks, Christine.", "Spock, Turian, the stabiliser.", "Spock's biobed, Turian's monitor, your workstation."]},
	"m2_soup": {"who": "mccoy", "lines": ["Wasn't there something for after?", "That flask in your pocket.", "Use the plomeek soup on Spock."]},
	"m2_conf": {"who": "spock", "lines": ["Things neither of our peoples were meant to forget.", "One of those words leads somewhere.", "Focus on FORGET."]},
	"m2_inside": {"who": "spock", "lines": ["What did he look at?", "The stars he noticed.",
		"Focus on the stellar display. Turn and tilt it until the binary pair sits upper left, the red giant low."]},
	"m2_v1": {"who": "spock", "lines": ["The values, in order.", "The first one is clear.", "Focus on the first value."]},
	"m2_v2": {"who": "spock", "lines": ["The second value was never on the display.", "Where did his hand go?", "Focus on Turian's hand, then on the reference grid."]},
	"m2_value3": {"who": "spock", "lines": ["Do not look at the number.", "Look at what it describes.", "Focus on Fury's marker instead."]},
	"m2_motive": {"who": "spock", "lines": ["What did Fury mean to him?", "Something he said in the conference.", "Talk to Turian's echo again for SHARED HISTORY if you haven't got it. Then use it on Fury's marker."]},
	"m2_three": {"who": "spock", "lines": ["Something else drifted in.", "A single word, overhead.", "Focus on THREE."]},
	"m2_withdraw": {"who": "chapel", "lines": ["Slowly, Spock. One thread at a time.", "When it climbs - wait.", "One thread, then the second. When it climbs, choose HOLD. Break the last only when I say."]},
	# 2.08 - Giotto (Scotty on the comm) and Kirk (Spock)
	"g_brig": {"who": "scott", "lines": ["Talk to me, Commander. What've ye got?", "Check the guard.", "Check his pulse, his injury and his holster."]},
	"g_trail": {"who": "scott", "lines": ["A lift that doesnae go anywhere isnae a lift.", "Ride it if ye must. Then look round.", "Ride the lift, pick up what's on the deck, then try the hatch."]},
	"g_branches": {"who": "scott", "lines": ["Where would ye go if ye knew my ship?", "Where were they this morning?", "Auxiliary Control."]},
	"g_door": {"who": "scott", "lines": ["Ye got in once already.", "The way ye came.", "Back into the maintenance access."]},
	"g_trunk": {"who": "scott", "lines": ["They're on my helm, Commander!", "The data trunk junction in the tube.", "Pull the primary link at the trunk junction. Then the secondary."]},
	"g_clamps": {"who": "scott", "lines": ["The rear panel, man!", "Read the placard.", "Release the lower clamp, the upper clamp, then the locking bar."]},
	"kirk_stolen": {"who": "mccoy", "lines": ["Get Jim through to the ship, Spock.", "Hail her. Call Scotty. Look at that orbital display.", "Communicator: Enterprise, then Mister Scott. Then the orbital display."]},
	"tseva_report": {"who": "mccoy", "lines": ["Tell the lady what we found, Spock.", "All of it. Our guests too.", "Talk to Councillor T'Seva."]},
	"tseva_hub": {"who": "mccoy", "lines": ["She said there's another matter, Jim.", "That ship. Ask her about it.", "Talk to T'Seva until you've asked what happens to the ship."]},
	"tseva_creds": {"who": "mccoy", "lines": ["She asked you how they got in, Spock.", "You've got their paperwork in your pocket.", "Show T'Seva the identifiers, the packet or the backing."]},
	"go_home": {"who": "mccoy", "lines": ["Let's get home.", "Call the ship.", "Communicator: Enterprise (beam up)."]},
	# 2.09 (McCoy for Spock; Kirk for the engine)
	"find_ent": {"who": "mccoy", "lines": ["Sift it, Spock.", "Mass, time, position.", "Turn all three filters until there's one track left."]},
	"x_vector": {"who": "mccoy", "lines": ["Where's she pointing, Spock?", "The big display.", "Use the navigation display - extend her vector."]},
	"x_transponder": {"who": "mccoy", "lines": ["Can't you just call her?", "That transponder receiver.", "Use the transponder receiver and widen the band all the way."]},
	"x_engine": {"who": "mccoy", "lines": ["What does she sound like?", "That engine analyser.", "Use the engine signature analyser. If it wants her profile, ask Jim."]},
	"x_wake": {"who": "mccoy", "lines": ["Too much traffic, Spock.", "That slate lists the civilians.", "Take the traffic slate; use it on the display, then the engine fragment."]},
	"x_ship": {"who": "mccoy", "lines": ["We'll need a ship.", "Jim'll have ideas. He always does.", "Talk to Jim, or to T'Seva."]},
	"x_go": {"who": "mccoy", "lines": ["Well? Let's go.", "The impound facility.", "Use the door to the impound facility."]},
	"bop_go": {"who": "mccoy", "lines": ["Tell Jim we're ready.", "He's in the big chair. Near enough.", "Talk to Kirk - or use the helm."]},
	"engine": {"who": "kirk", "lines": ["Something Scotty said...", "The injector.", "Scotty's been complaining about an injector imbalance for a week. Said she was singing flat."]},
	"clamp": {"who": "mccoy", "lines": ["Lift before you let go.", "Look at the clamp, then the thrusters.", "Look at the clamp view; at the thruster panel fire the VENTRAL pair, then say 'Mark.'"]},
	"controls": {"who": "mccoy", "lines": ["Press something harmless.", "Repeated symbols - like ours.", "At the helm: the one that repeats three times on the left, and the numeric grid."]},
	"coords": {"who": "mccoy", "lines": ["Same numbers, different shelves.", "Their axes are in another order.", "Third value first, then the first, then the second."]},
}


## What the played lead says first when they ask (not when the hint plays unasked).
static func partner_ask(speaker: String, lead_played: String) -> String:
	if lead_played == "spock" and speaker == "mccoy":
		return "Summarise, Doctor."
	if lead_played == "chapel" and speaker == "mccoy":
		return "Doctor?"
	if lead_played == "giotto" and speaker == "scott":
		return "Bridge, Security - talk to me, Mister Scott."
	if lead_played == "kirk" and speaker == "spock":
		return "Options, Mister Spock?"
	return ""


static func partner_name(_speaker: String, _played: String) -> String:
	return ""


## Where the story is, as a key of PARTNER ("" = nothing to say here).
static func partner_stage(room_key: String) -> String:
	match room_key:
		"sickbay":
			if not flag("EP2_SPOCK_ARRIVED"):
				return ""
			if not flag("EP2_MELD_ONE_STARTED"):
				if not (flag("EP2_FACT_SUBJECT_DEAD") and flag("EP2_FACT_PATTERN_GENUINE") and flag("EP2_FACT_DEGRADATION_ACTIVE")):
					return "pattern"
				if not flag("EP2_DED_MIND_MELD"):
					return "read_memory"
				if not flag("EP2_MCCOY_AGREED"):
					return "talk_mccoy"
				return "prepare_meld"
			if flag("EP2_MELD_ONE_COMPLETE") and not flag("EP2_SPOCK_LIMITED_DUTY"):
				return "cleared"
			if flag("EP2_SPOCK_LIMITED_DUTY") and not flag("EP2_MELD_EVIDENCE_REVIEWED"):
				return "recap"
			if flag("EP2_SPOCK_LIMITED_DUTY") and not flag("EP2_KIRK_REPORTED"):
				return "report_kirk"
			if flag("EP2_TEAM_CALLED") and not flag("EP2_TEAM_MET"):
				return "meet_team"
			if flag("EP2_C_STARTED") and not flag("EP2_C_DONE"):
				if not flag("EP2_C_GRADUAL"):
					return "c_record"
				if not flag("EP2_C_REGULATOR_FAMILY"):
					return "c_drug"
				if not flag("EP2_C_FEEDBACK_PATH"):
					return "c_sensor"
				if not (flag("EP2_C_HAS_CARRIER") and flag("EP2_C_HAS_REGULATOR") and flag("EP2_C_HAS_SUPPORT")) and not flag("EP2_C_COMPOUND"):
					return "c_three"
				if not flag("EP2_C_COMPOUND"):
					return "c_bench"
				if not flag("EP2_C_TESTED"):
					return "c_test"
				return "c_report"
			if flag("EP2_M2_PREP") and not flag("EP2_M2_AUTHORISED"):
				return "m2_auth" if flag("EP2_M2_ASKED") else "m2_prep"
			if flag("EP2_M2_CHECKED") and not flag("EP2_SOUP_GIVEN"):
				return "m2_soup"
			if flag("EP2_M2_DONE") and not flag("EP2_M2_CHECKED"):
				return "m2_after"
			return ""
		"bridge":
			if flag("EP2_TEAM_CALLED") and not flag("EP2_TEAM_MET"):
				return "meet_team_bridge"
			return ""
		"meld1":
			var st := int(GameState.get_var("EP2_MELD_STAGE")) if GameState.has_var("EP2_MELD_STAGE") else 0
			if st == 0:
				return "m1_fury" if has_anchor("ACCESS") and has_anchor("PRE_REFORMATION") else "m1_hub"
			if st == 1:
				if not flag("EP2_MELD_CURIOSITY"):
					return "m1_archive"
				if not flag("EP2_MELD_RESTRICTED"):
					return "m1_restricted"
				return "m1_download"
			if flag("EP2_MELD_FEAR_DOOR") and not Case.has("EP2_M_TIMING"):
				return "m1_pressure"
			return "m1_doors"
		"meld2":
			if not flag("EP2_M2_FORGET"):
				return "m2_conf"
			if not flag("EP2_M2_ALIGNED"):
				return "m2_inside"
			if not flag("EP2_M2_V1"):
				return "m2_v1"
			if not flag("EP2_M2_V2"):
				return "m2_v2"
			if not flag("EP2_M2_V3"):
				return "m2_value3"
			if not flag("EP2_M2_MOTIVE"):
				return "m2_motive"
			if not flag("EP2_M2_THREE"):
				return "m2_three"
			return "m2_withdraw"
		"vulcan":
			if flag("EP2_M2_REPORTED"):
				if flag("EP2_S_DONE") and not flag("EP2_R_STOLEN"):
					return "kirk_stolen"
				if not flag("EP2_R_NO_TEAM"):
					return "tseva_report"
				if flag("EP2_R_BRIG_SEEN") and not flag("EP2_R_BOP_DONE"):
					return "tseva_hub"
				if flag("EP2_R_BOP_DONE") and not flag("EP2_R_CREDENTIALS"):
					return "tseva_creds"
				if flag("EP2_R_CREDENTIALS") and not flag("EP2_R_SCOTTY_WARNING"):
					return "go_home"
				return ""
			if not flag("EP2_V_ARRIVED") or flag("EP2_V_DONE"):
				return ""
			if flag("EP2_V_PACKET") and not flag("EP2_V_R3_ACCESS"):
				return "r3"
			if flag("EP2_V_SECRETARY_PROCESS") and not flag("EP2_V_PACKET"):
				return "hopper"
			if flag("EP2_V_IDENTIFIERS") and not flag("EP2_V_SECRETARY_PROCESS"):
				return "secretary"
			if flag("EP2_V_R3_ACCESS") and not flag("EP2_V_R3_GROUP"):
				return "r3_search"
			if not flag("EP2_V_SEATING_SOLVED"):
				return "chamber"
			if not flag("EP2_V_IDENTIFIERS"):
				return "alcove"
			if flag("EP2_V_HAS_MARKERS") and not flag("EP2_V_MEDICAL_TIMES"):
				return "markers"
			if flag("EP2_V_TARGET") and not flag("EP2_V_FURY_SOURCES"):
				return "records"
			return "archivist" if not flag("EP2_V_R3_ACCESS") else ""
		"lab":
			if flag("EP2_L_REVISED") and not flag("EP2_L_OTHER_CLOCK"):
				return "lab_time"
			if flag("EP2_A_DONE") and not flag("EP2_L_REVISED"):
				return "lab_back"
			if flag("EP2_L_GIOTTO") and not flag("EP2_A_ARRIVED"):
				return "lab_aux"
			if flag("EP2_L_SYNC_DROP") and not flag("EP2_L_SCOTTY"):
				return "lab_scotty"
			if flag("EP2_L_ARRIVED") and not flag("EP2_L_SYNC_DROP"):
				return "lab_start"
			return ""
		"auxcontrol":
			if not flag("EP2_A_REROUTED"):
				return "aux"
			if not flag("EP2_A_Q_RECONNECT"):
				return "aux_q1"
			if not flag("EP2_A_Q_REDUNDANT"):
				return "aux_q2"
			if not flag("EP2_A_Q_ISOLATOR"):
				return "aux_q3"
			return ""
		"chase":
			if not flag("EP2_S_GUARD"):
				return "g_brig"
			if not flag("EP2_S_DECOY"):
				return "g_trail"
			if not flag("EP2_S_DEST"):
				return "g_branches"
			if not flag("EP2_S_MATRIX"):
				return "g_door"
			if not flag("EP2_S_TRUNK"):
				return "g_trunk"
			return "g_clamps"
		"station":
			if not flag("EP2_X_TRACK"):
				return "find_ent"
			if flag("EP2_X_ASKED_PROFILE") and not flag("EP2_X_INJECTOR"):
				return "engine"
			if not flag("EP2_X_VECTOR"):
				return "x_vector"
			if not flag("EP2_X_TRANSPONDER"):
				return "x_transponder"
			if not flag("EP2_X_ENGINE"):
				return "x_engine"
			if not flag("EP2_X_WAKE"):
				return "x_wake"
			if not flag("EP2_X_SHIP_CHOSEN"):
				return "x_ship"
			return "x_go"
		"bop":
			if not flag("EP2_B_CLAMP_FREE"):
				return "clamp"
			if not flag("EP2_B_CONTROLS"):
				return "controls"
			if not flag("EP2_B_CONVERTED"):
				return "coords"
			return "bop_go"
	return ""


## The one-line tracker's live text (EpisodeRoom calls it on arrival, on load and after every scene):
## the words still to do, ticking off.
static func refresh_tracker() -> void:
	if ObjectiveManager.is_current("OBJ_EP2_INVESTIGATE_SIGNAL"):
		var left: Array = []
		if not flag("EP2_FACT_SUBJECT_DEAD"):
			left.append("DEAD?")
		if not flag("EP2_FACT_PATTERN_GENUINE"):
			left.append("REAL?")
		if not flag("EP2_FACT_DEGRADATION_ACTIVE"):
			left.append("GOING?")
		var text := "FIND OUT WHAT THE PATTERN IS" + (" - " + " / ".join(left) if not left.is_empty() else " - ASK CHAPEL")
		ObjectiveManager.show_objective("OBJ_EP2_INVESTIGATE_SIGNAL", text, LOG_OBJECTIVE_ENTRY)
	elif ObjectiveManager.is_current("OBJ_EP2_WHO_MANIPULATED"):
		var left: Array = []
		if not flag("EP2_V_SEATING_SOLVED"):
			left.append("THE CHAMBER")
		if not flag("EP2_V_R3_GROUP"):
			left.append("THE AMENDMENTS")
		if not flag("EP2_V_MEDICAL_TIMES"):
			left.append("HIS PRIVATE TIME")
		var text := "WHO GOT AT TURIAN? - " + (" / ".join(left) if not left.is_empty() else "PUT IT TOGETHER")
		ObjectiveManager.show_objective("OBJ_EP2_WHO_MANIPULATED", text, LOG_OBJECTIVE_ENTRY)


# REV 640 (Glen's standing rule: every lift lever works, every episode): where each lift stop / ship door leads in
# Episode 2 - its own story room where it has one, otherwise a walk-around deck (scenes/walk/Ep2Walk.gd).
const LIFT_ROOMS := {
	"ae_transporter": "transporter",
	"ae_deck7": "walk_ae_deck7", "ae_deck5": "walk_ae_deck5", "e_quarters": "walk_e_quarters", "ae_deck8": "walk_ae_deck8",
	"ae_alley": "walk_ae_alley", "ae_engine": "walk_ae_engine", "ae_engineering": "walk_ae_engineering",
	"ae_main": "walk_ae_main", "ae_pool": "walk_ae_pool",
}


static func lift_room(ship_key: String) -> String:
	return String(LIFT_ROOMS.get(ship_key, ship_key))

