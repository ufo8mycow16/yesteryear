extends RefCounted
class_name Ep1Compare
## Ep1Compare — the connections Kirk and McCoy make between things they've found, and the big
## deductions. REV 476 (the redesign): nobody picks a conclusion from a menu any more - every one of
## these plays as the characters saying it, the moment its facts are in (Ep1.AUTO_CONNECTIONS,
## EpisodeRoom._auto_reason). Every function here is a short scene: it talks through the room.


## Returns true if the pair meant something (so the room can shrug otherwise).
static func run(room: EpisodeRoom, rule: String) -> bool:
	match rule:
		"movements_vs_timeline":
			await room.say("mccoy", "Ullus says he went back to his own quarters.")
			await room.say("kirk", "And the security record says his credential turned up near Turian's.")
			await room.say("mccoy", "One of them is wrong.")
			Case.add("CONTRADICTION")     # REV 490: no objective change - Hub One's tracker stays up
			return true
		"datapad_vs_manifest":
			await room.say("mccoy", "Turian had a datapad. It's not on the manifest.")
			await room.say("kirk", "Then somebody removed it.")
			Case.add("DATAPAD_MISSING")
			Ep1.set_objective("FIND_DATAPAD")
			return true
		"clasp_vs_set":
			await room.say("mccoy", "Same set.")
			await room.say("kirk", "One missing.")
			await room.say("mccoy", "That doesn't prove anyone planted it.")
			await room.say("kirk", "No. But somebody should look at the rest of that set.")
			return true
		"bio_vs_vessels":
			await room.say("kirk", "Ullus didn't deny being here.")
			await room.say("mccoy", "And apparently Turian offered him a drink while they were arguing.")
			await room.say("kirk", "Which means the biological evidence may only prove what Ullus already told us.")
			if Case.has("BIO_CONSISTENT"):
				return true
			await room.say("mccoy", "Skin cells on a glass say somebody drank from it, Jim. Not that anybody was hurt.")
			Case.relabel("BIO", "TELLARITE BIOLOGICAL MATERIAL: CONSISTENT WITH ULLUS' STATEMENT",
				"Tellarite epithelial cells on a drinking vessel in Turian's room. Ullus admits he was there. This proves it, which he told us already.")
			Case.add("BIO_CONSISTENT", true)
			await room.say("kirk", "It proves Ullus was here.")
			await room.say("mccoy", "Which he already told us.")
			await room.say("kirk", "It doesn't prove what happened afterward.")
			return true
		"postmortem_vs_maintenance":
			await room.say("kirk", "Maintenance staff were in Turian's quarters before he died. Somebody got into his terminal through the maintenance network after he died.")
			await room.say("mccoy", "Same building system, both ends of the night.")
			await room.say("kirk", "Somebody had a reason to learn that system before Turian died.")
			Ep1.set_flag("EP1_MAINT_UNLOCKED")
			Ep1.set_objective("INSPECT_MAINT")
			MissionLog.notification_requested.emit("NEW LOCATION UNLOCKED: MAINTENANCE ROOM")
			return true
		"clasp_deduction":
			await clasp_deduction(room)
			return true
		"vessel_vs_bio":
			await vessel_vs_bio(room)
			return true
		"particulate_vs_coords":
			await room.say("mccoy", "It's the same mineral mix those coordinates point to.")
			await room.say("kirk", "Somebody took Darev out into the desert.")
			Case.add("DAREV_TO_DESERT")
			return true
		"darev_moved":
			await room.say("kirk", "So whatever happened in his room didn't end there.")
			await room.say("mccoy", "No. Somebody kept him moving.")
			Case.add("DAREV_MOVED")
			return true
		"planned_route":
			await room.say("kirk", "Somebody knew this route before they ever set foot on it.")
			Case.add("PLANNED_ROUTE")
			return true
		"against_will":
			await against_will(room)
			return true
		"restraint_match":
			await room.say("kirk", "It started breaking back there.")
			await room.say("mccoy", "Which means whoever was wearing it had been fighting it a long way.")
			Case.add("PRISONER_FORCED")
			return true
		"restraint_repurposed":
			await room.say("mccoy", "Vulcan security restraint on the outside. Look at the control assembly.")
			await room.say("kirk", "A Romulan interface, hidden inside a Vulcan casing.")
			await room.say("mccoy", "Somebody went to a lot of trouble to make one look like the other.")
			await room.say("kirk", "Or had access to both.")
			if Case.add("RESTRAINT_REPURPOSED"):
				Case.add("Q_EQUIPMENT")
			return true
		"darev_target":
			await darev_target(room)
			return true
	return false


## Three clues, one conclusion: the clasp was taken from Ullus' own quarters.
static func clasp_deduction(room: EpisodeRoom) -> void:
	if not (Case.has("CLASP") and Case.has("CLASP_MOUNT_CLEAN") and Case.has("CLASP_STORAGE_RESIDUE")):
		await room.say("kirk", "There's something in this. I need the clasp, the mount and the storage residue side by side.")
		return
	if Case.has("CLASP_PLANTED"):
		await room.say("kirk", "We've already worked this one out. It was stored here and removed cleanly - nothing like a struggle.")
		return
	await room.say("kirk", "Ullus wasn't wearing it when he went to see Turian.")
	await room.say("mccoy", "Then nobody tore it off him in a struggle.")
	Case.add("CLASP_PLANTED")
	if Case.has("Q_CLASP_ENTRY"):
		Case.relabel("Q_CLASP_ENTRY", "HOW DID ULLUS' CLASP ENTER TURIAN'S ROOM? NOT IN A STRUGGLE",
			"It was stored in Ullus' quarters and removed cleanly. Its appearance at the crime scene is inconsistent with the claimed struggle. Who moved it is unknown.")
	await check_return_ullus(room)


## Ullus' cells are on a glass here. Are they also on the glass there?
static func vessel_vs_bio(room: EpisodeRoom) -> void:
	await room.say("mccoy", "Same kind of cells. Same concentration.")
	await room.say("kirk", "What?")
	# REV 524: said, not a text card (Nikki doesn't read)
	await room.say("mccoy", "The glass in his room and the vessel in Turian's. Ullus' skin cells on both - laid down in exactly the same pattern.")
	if Case.has("SAMPLE_TRANSFER"):
		await room.say("mccoy", "Still looks like a transfer to me.")
		return
	await room.say("kirk", "He drank in Turian's room. He drank here. That would explain two glasses.")
	await room.say("mccoy", "It doesn't explain two identical patterns. Same concentration, same distribution, two different glasses in two different rooms. I don't like coincidences.")
	await room.say("mccoy", "I can't prove it yet.")
	await room.say("mccoy", "Somebody could've lifted the cells from something Ullus used here and transferred them onto the glass in Turian's room.")
	if Ep1.flag("EP1_ST_DRINKWARE"):
		# REV 283: the refreshment stall's cups in the streets - a control sample, not proof
		await room.say("mccoy", "And remember those market cups, Jim - same glaze. I checked a used one: it holds skin cells like glue in this dry air. A clean surface to lift a pattern from, and a clean one to put it on.")
		await room.say("kirk", "So it can be done.")
		await room.say("mccoy", "It can be done. That's all a control sample tells you. It's enough to stop me calling it a coincidence.")
	Case.add("SAMPLE_TRANSFER")
	if Case.has("Q_VESSEL"):
		Case.relabel("Q_VESSEL", "HOW DID ULLUS' CELLS GET ON THE VESSEL? PROBABLY TRANSFERRED",
			"Same cells, same concentration and distribution as the glass in Ullus' own room. Not proven, but a transfer fits best.")
	Case.relabel("BIO_CONSISTENT", "TELLARITE MATERIAL: ULLUS WAS THERE, BUT THE CELLS MAY BE PLANTED",
		"Ullus never denied being in the room, so the cells prove nothing new. And the same pattern turns up in his own quarters: some of it may have been moved there on purpose.")
	await room.say("kirk", "So somebody may have carried his cells from this room to Turian's.")


## REV 298: what kind of evidence is still missing for a call - the Case File CATEGORIES of the pieces
## not yet found ("ONE MORE PIECE OF PHYSICAL EVIDENCE"), never their titles, so nothing is spoiled.
static func _missing_kinds(wanted: Array) -> Array:
	var counts: Dictionary = {}
	for w in wanted:
		var id := String(w[0])
		if not Case.has(id):
			var cat := Case.get_category(id)
			counts[cat] = int(counts.get(cat, 0)) + 1
	var out: Array = []
	for cat in counts.keys():
		var n := int(counts[cat])
		out.append(("ONE MORE PIECE OF " if n == 1 else "%d MORE PIECES OF " % n) + String(cat))
	return out


## "Present these to Tuvall": the player has to bring every item in `wanted`.
## wanted is an Array of [clue id, what Kirk says]. Returns true when all are shown.
static func present_to_tuvall(room: EpisodeRoom, wanted: Array, closing: Callable) -> bool:
	var shown: Dictionary = {}
	await room.note("(Kirk opens his communicator.)", 1.6)
	await room.say("tuvall", "Commander Tuvall.")
	await room.say("kirk", "Commander. I have evidence I need you to hear.")
	while shown.size() < wanted.size():
		var labels: Array = []
		var ids: Array = []
		for w in wanted:
			if not shown.has(String(w[0])) and Case.has(String(w[0])):
				labels.append(Case.get_title(String(w[0])))
				ids.append(String(w[0]))
		if ids.is_empty():
			await room.say("kirk", "I'm not ready to make the whole case yet, Commander. I'll call back.")
			await room.note("STILL OPEN:  " + "  /  ".join(_missing_kinds(wanted)), 3.6)     # REV 298
			return false
		labels.append("End the call")
		var pick: int = await room.menu.ask("What do you tell Tuvall?", labels, "COMMUNICATOR - TUVALL", true, true)
		if pick < 0 or pick >= ids.size():
			await room.say("kirk", "I'll call back, Commander.")
			return false
		var id := String(ids[pick])
		for w in wanted:
			if String(w[0]) == id:
				await room.say("kirk", String(w[1]))
		await room.say("tuvall", "Understood.")
		shown[id] = true
	await closing.call()
	return true


## Opens whichever deduction is ready.
static func run_deduction(room: EpisodeRoom) -> void:
	match Ep1.pending_deduction():
		"hub1":
			await run_hub_deduction(room)
		"part3":
			await run_part3_deduction(room)
		"part4":
			await run_part4_deduction(room)
		"desert":
			await run_desert_deduction(room)
		"part5":
			await run_part5_deduction(room)
		"part6":
			await run_part6_deduction(room)


## Part Three: put what we can establish in order, then say what we can prove.
static func run_part3_deduction(room: EpisodeRoom) -> void:
	# REV 492 (EPISODE1_SCRIPT.md "Part Three closes"): said, not sorted
	await room.say("kirk", "Turian finds something in the archives and copies it to his datapad. He's killed. His room is searched, and the datapad's gone.")
	await room.say("mccoy", "And somebody uses that box to put Ullus outside his door.")
	await room.say("kirk", "This wasn't an argument that got out of hand.")
	await room.say("mccoy", "Somebody wanted what Turian found.")
	await room.say("kirk", "And Ullus gave them a convenient suspect.")
	await room.say("mccoy", "So who killed him?")
	await room.say("kirk", "I can't prove that. I can prove Ullus was framed.")
	await room.pause(0.6)
	await room.say("kirk", "And the rest?")
	await room.say("mccoy", "We keep digging.")
	Case.add("P3_CONCLUSION")
	Ep1.set_flag("EP1_PART3_DONE")
	Ep1.set_flag("EP1_ULLUS_AREA_UNLOCKED")
	Ep1.set_objective("VERIFY_ACCOUNT")
	MissionLog.notification_requested.emit("NEW LOCATIONS UNLOCKED: ULLUS' HALLWAY, ULLUS' ROOM")


## The first real deduction of the episode (opened from the Case File once the
## three Hub One facts are established). Gets Turian's quarters unlocked.
static func run_hub_deduction(room: EpisodeRoom) -> void:
	# REV 490 (EPISODE1_SCRIPT.md "Hub One closes"): Kirk and McCoy, wherever they are, say it
	await room.say("kirk", "Let's say it plainly, Bones. What doesn't the case against Ullus explain?")
	await room.say("mccoy", "How Turian died, for a start. And a datapad Ullus saw in his hands that never made it to the evidence room.")
	if not Case.has("DATAPAD_MISSING"):
		Case.add("DATAPAD_MISSING", true)
	await room.say("kirk", "Ullus has been in a cell since it happened. If he had it, they'd have found it.")
	await room.say("mccoy", "Then it's still out there. Or somebody's got it.")
	await room.say("kirk", "Vulcan security searched that room for evidence against Ullus.")
	await room.say("mccoy", "Maybe it's time somebody searched it for evidence about Turian.")
	Ep1.set_flag("EP1_HUB1_DEDUCTION_DONE")
	Ep1.set_flag("EP1_QUARTERS_UNLOCKED")
	Case.add("Q_DATAPAD", true)
	Ep1.set_objective("SEARCH_DATAPAD")
	MissionLog.notification_requested.emit("NEW LOCATION UNLOCKED: TURIAN'S QUARTERS")
	Ep1.unlock_otari_if_named(false)     # REV 298: Ullus already named Otari - his room opens too (objective stays)


## The Part Four deduction: what connects the disappearances, and what next.
static func run_part4_deduction(room: EpisodeRoom) -> void:
	await room.say("kirk", "One murdered ambassador. One framed Tellarite. A missing security chief. A missing Council leader. A missing datapad. And coordinates in the desert.")
	await room.say("mccoy", "The conference is where they all were. It isn't why they went missing.")
	await room.say("kirk", "No. Turian found something in those archives. That's what ties it together.")
	await room.say("mccoy", "And Ullus?")
	await room.say("kirk", "The cover, not the cause. Maybe to hide the theft, maybe to wreck the conference, maybe to keep us busy. Maybe all three.")
	Case.add("P4_CONNECTION")
	var pick3: int = await room.choose(["Let's go.", "Inform Tuvall first.", "Request transport."], "KIRK:")
	match pick3:
		0:
			await room.say("kirk", "Let's go.")
			await room.say("mccoy", "In the desert. In the heat. Naturally.")
		1:
			await room.say("kirk", "Tuvall first. I'd rather she hear this from me than from a report.")
			await room.say("mccoy", "Sensible. Annoying, but sensible.")
		_:
			await room.say("kirk", "We'll need transport.")
			await room.say("mccoy", "Good. I'm not walking it.")
	Ep1.set_flag("EP1_PART4_DONE")
	Ep1.set_flag("EP1_EXTERIOR_UNLOCKED")
	Ep1.set_objective("P4_NEXT")
	MissionLog.notification_requested.emit("NEW LOCATION UNLOCKED: EXTERIOR SHI'KAHR")


## The scuffed rock, the irregular movement and the torn restraint, side by side.
static func against_will(room: EpisodeRoom) -> void:
	if not (Case.has("SCUFFED_ROCK") and Case.has("ROUTE_INJURED") and Case.has("RESTRAINT_FRAGMENT")):
		await room.say("kirk", "There's something in this. But I want the rock, the footprints and the restraint all in front of me before I say it.")
		return
	if Case.has("AGAINST_WILL"):
		await room.say("kirk", "We've already said it. Somebody was being moved against their will.")
		return
	await room.say("mccoy", "A man running away doesn't need somebody carrying half his weight. And he doesn't wear restraints.")
	await room.say("kirk", "Four people. At least one prisoner. Straight to the ruins.")
	await room.say("mccoy", "And Darev was hurt before they ever got this far.")
	await room.say("kirk", "Whoever brought them here wasn't improvising.")
	Case.add("AGAINST_WILL")


## The Council leader's account, set against what we found in Darev's room and in the desert.
static func darev_target(room: EpisodeRoom) -> void:
	if not (Case.has("COUNCIL_TESTIMONY") and Case.has("DAREV_REMOVED") and Case.has("ROUTE_INJURED")):
		await room.say("kirk", "Their account is one thing. I want it set against what we found in Darev's room and out in the desert.")
		return
	if Case.has("DAREV_WARNED"):
		await room.say("kirk", "We know what Darev was doing. He was trying to warn them.")
		return
	await room.say("kirk", "The Council leader says Darev came to warn them. We found Darev hurt in his own room, and carried into the desert.")
	await room.say("mccoy", "Then who hurt him in his own room, Jim? Who put him in a restraint he fought for twenty kilometres?")
	await room.say("kirk", "He was hurt in his own room, before he ever reached her. Somebody got to him first.")
	await room.say("kirk", "Darev wasn't fleeing with them. He was trying to warn them.")
	await room.say("mccoy", "And somebody didn't want the warning delivered.")
	Case.add("DAREV_WARNED")
	Case.add("Q_ABDUCTION_WHY")
	await room.note("DAREV WAS ATTEMPTING TO WARN THE HIGH COUNCIL.", 3.2)


## A "select all that apply" screen. statements is an Array of
## [text, is_correct, reply_if_wrongly_ticked]. Returns when the player has
## ticked exactly the right ones.
## REV 365 (Glen: "I couldn't get out of that dialog box - maybe there should be a cancel option"):
## a NOT YET option (and Esc) backs out. Returns true once solved, false if the player backed out -
## callers stop there, and the player can come back to it.
static func select_all(room: EpisodeRoom, title: String, prompt: String, statements: Array, speaker: String = "mccoy", missing_who: String = "kirk", missing_line: String = "That's all true, but it isn't everything we can say. What else do we actually know?") -> bool:
	var ticked: Dictionary = {}
	var done := false
	while not done:
		var labels: Array = []
		for i in statements.size():
			labels.append(("[X]  " if ticked.has(i) else "[   ]  ") + String(statements[i][0]))
		labels.append("SUBMIT")
		labels.append("NOT YET")
		var pick: int = await room.menu.ask(prompt, labels, title, true, true)
		if pick < 0 or pick == statements.size() + 1:
			return false
		if pick < statements.size():
			if ticked.has(pick):
				ticked.erase(pick)
			else:
				ticked[pick] = true
			continue
		# submit
		var wrong_reply := ""
		var missing := 0
		for i in statements.size():
			var good: bool = bool(statements[i][1])
			if ticked.has(i) and not good and wrong_reply == "":
				wrong_reply = String(statements[i][2])
			if good and not ticked.has(i):
				missing += 1
		if wrong_reply != "":
			await room.say(speaker, wrong_reply)
		elif missing > 0:
			await room.say(missing_who, missing_line)
		else:
			done = true
	return true


## What the desert tells us, said plainly. Optional for entering the ruins.
## REV 268 (GAMEPLAY LOCKED): five questions. For each, the player assigns the finding that answers it
## and picks the interpretation it supports. Wrong answers cost nothing; two misses in one question
## bring a hint that narrows it down without choosing for them.
const DESERT_QUESTIONS: Array = [
	["GROUP COMPOSITION", "FOUR_MOVED",
		["A GROUP OF FOUR MOVED FROM SHI'KAHR TOWARD THE RUINS - AT LEAST ONE VULCAN AND ONE ROMULAN.", "DAREV CROSSED THE DESERT ALONE.", "A LARGE PARTY OF ROMULANS CAME THROUGH."],
		["Count the sets, Bones. One man doesn't leave four.", "Four sets. Not a crowd - and not all Romulan, either."],
		"How many sets of prints did the sensor show? And whose profiles?"],
	["CONDITION", "ROUTE_INJURED",
		["AT LEAST ONE MEMBER OF THE GROUP WAS INJURED OR PHYSICALLY COMPROMISED.", "THE GROUP WAS EXHAUSTED BY THE HEAT, NOTHING MORE.", "THE BLOOD WAS FROM AN ANIMAL."],
		["Heat doesn't bleed, Jim. Somebody was hurt.", "It was Romulan blood. Darev's."],
		"The rock shelter. Blood, and somebody taking another man's weight."],
	["COERCION", "AGAINST_WILL",
		["AT LEAST ONE WAS BEING MOVED AGAINST THEIR WILL.", "THEY ALL CAME WILLINGLY.", "THEY WERE FLEEING SOMETHING TOGETHER."],
		["People who come willingly don't fight at a narrow pass, or need restraints.", "Fleeing together doesn't leave signs of resistance."],
		"The narrow pass - the scuffing. And what kind of restraint did we find?"],
	["DETECTION-AVOIDANCE", "SENSOR_DISABLED",
		["THEY TOOK DELIBERATE STEPS TO AVOID DETECTION.", "THE DUST STORM DAMAGED THE FIELD SENSOR.", "THE SENSOR FAILED FROM AGE."],
		["A specific control junction was cut. Weather doesn't do that.", "Old equipment fails all over. This failed in one precise place."],
		"Look at how the sensor was broken - one exact junction."],
	["FOREKNOWLEDGE", "PLANNED_ROUTE",
		["SOMEONE INVOLVED KNEW THE ROUTE AND DESTINATION IN ADVANCE.", "THE GROUP WAS LOST AND WANDERED.", "THEY FOUND THE RUINS BY CHANCE."],
		["No searching. No doubling back. Nobody lost walks that straight.", "Chance doesn't walk a straight line across forty kilometres to a door nobody uses."],
		"No searching, no doubling back. What does a straight line tell you?"],
]


static func run_desert_deduction(room: EpisodeRoom) -> void:
	# REV 476: said, not filled in (the RECONSTRUCT DESERT MOVEMENT screen is gone)
	await room.say("kirk", "Let's say what the desert actually told us. Only what we can support.")
	await room.say("mccoy", "Four sets of prints from Shi'Kahr to here. At least one Vulcan, at least one Romulan.")
	await room.say("kirk", "One of them hurt - Darev's blood at the rock shelter - and somebody taking his weight.")
	await room.say("mccoy", "One of them in a restraint, fighting it all the way through the pass.")
	await room.say("kirk", "The one sensor that could have seen them, switched off at a single junction. And a dead straight line to a door nobody uses.")
	await room.say("kirk", "This wasn't a flight into the desert.")
	await room.say("mccoy", "No. Somebody brought them here.")
	await room.say("kirk", "Let's find out why.")
	Case.add("DESERT_RECONSTRUCTED")
	Ep1.set_flag("EP1_DESERT_DONE")
	if not Ep1.flag("EP1_RUINS_OPEN"):
		Ep1.set_objective("ENTER_RUINS")


static func _desert_miss(room: EpisodeRoom, qi: int, misses: Dictionary, line: String) -> void:
	if line != "":
		room.wrong_idea()
		await room.say("kirk", line)
	misses[qi] = int(misses.get(qi, 0)) + 1
	if int(misses[qi]) >= 2:
		await room.say("mccoy" if qi % 2 == 1 else "kirk", String(DESERT_QUESTIONS[qi][4]))


## Part Five's deduction, aboard the Enterprise: the whole conspiracy so far, in order.
static func run_part5_deduction(room: EpisodeRoom) -> void:
	# REV 476: told, not sorted
	await room.say("kirk", "Let's put it in order, Bones. All of it.")
	await room.say("mccoy", "Turian finds something in the archives and copies it to his datapad.")
	await room.say("kirk", "He realises it's in danger, and he gives the datapad to the one man he trusts. Darev.")
	await room.say("mccoy", "Then Turian is killed, and Ullus is framed for it.")
	await room.say("kirk", "Darev tries to warn the High Council - and he and the Council leader end up in a ruin in the desert.")
	await room.say("mccoy", "And Darev lives, and the datapad ends up in your hands.")
	await room.say("mccoy", "That's almost the whole thing, Jim.")
	await room.say("kirk", "Almost. We still don't know what Turian found.")
	await room.say("mccoy", "Or how he was killed.")
	await room.say("kirk", "And whoever knows both is somewhere we haven't looked yet.")
	Case.add("P5_CONCLUSION")
	Ep1.set_flag("EP1_PART5_DONE")
	# REV 268: Darev is already stable and analysed - Act 2 is Kirk and the datapad
	Ep1.set_objective("P6_DATAPAD")
	if room.is_mccoy():
		await room.say("mccoy", "Go on, Jim. See what Turian thought was worth dying for.")
		room.switch_to("kirk")


## Part Six, Act Five: take the case against Ullus apart - three independent pillars (REV 268).
static func run_part6_deduction(room: EpisodeRoom) -> void:
	var open_sections: Array = []
	for i in Ep1.RECON.size():
		if not Ep1.recon_category_ready(i):
			open_sections.append(String(Ep1.RECON[i][1]))
	if not open_sections.is_empty():
		await room.say("kirk", "I can't take this to Vulcan yet. There are still gaps in what we can prove.")
		return
	# REV 476: Kirk takes the case apart aloud - the three pillars, then the two supporting lines only if
	# their evidence exists (no RECONSTRUCT THE MURDER CASE screen)
	await room.say("kirk", "Let's take the case against Ullus apart. Piece by piece.")
	await room.say("kirk", "Turian died from catastrophic neural overload. The case against Ullus never explains that.")
	await room.say("kirk", "The access record doesn't reliably put Ullus at the scene. The clasp doesn't prove he wore or dropped it there, and the biological material proves earlier contact - not murder.")
	await room.say("kirk", "And while the manipulated credential trail claims Ullus was near Turian's room, an independent record places him at Serrin's office.")
	if Case.has("ULLUS_STATEMENT"):
		await room.say("kirk", "Ullus's statement relied on the same assumptions we've just dismantled.")
	if Case.has("CHRONOLOGY") or Case.has("DATAPAD_CUSTODY") or Case.has("CUSTODY_CORROBORATED"):
		await room.say("kirk", "And Turian was already responding to another threat - one connected to whatever he found in the archives.")
	Case.add("CASE_FAILS")
	Ep1.set_flag("EP1_P6_RECON_DONE")
	Ep1.set_objective("P6_VULCAN")


## One section of the reconstruction. Returns true when the player picks evidence
## that really establishes the contradiction.
static func _recon_section(room: EpisodeRoom, idx: int, removed: Dictionary) -> bool:
	var sec: Array = Ep1.RECON[idx]
	var good: Array = sec[3]
	var weak: Array = sec[4]
	var unknown: Array = sec[5]
	var core: Array = Ep1.RECON_CORE.get(String(sec[0]), [])
	var core_done: Array = []     # REV 298: which core groups have been shown so far
	var shown: Dictionary = {}    # REV 298: good cards already put forward this time (a Back starts over)
	while true:
		var ids: Array = []
		var labels: Array = []
		for group in [good, weak, unknown]:
			for id in group:
				if Case.has(String(id)) and not removed.has(String(id)) and not shown.has(String(id)):
					ids.append(String(id))
		ids.sort()
		for id in ids:
			labels.append(Case.get_title(String(id)))
		labels.append("Back")
		var pick: int = await room.menu.ask(String(sec[2]), labels, String(sec[1]), false, true)
		if pick < 0 or pick >= ids.size():
			return false
		var chosen: String = String(ids[pick])
		if good.has(chosen):
			if core.is_empty():
				await room.say("kirk", "That holds. That one's solid.")
				return true
			# REV 298: a pillar with a mandatory core (Ep1.RECON_CORE) needs every core group shown
			var group_i := -1
			for gi in core.size():
				if (core[gi] as Array).has(chosen):
					group_i = gi
			shown[chosen] = true
			if group_i < 0:
				await room.say("kirk", "That backs it up. It isn't the heart of it.")
				continue
			if not core_done.has(group_i):
				core_done.append(group_i)
			if core_done.size() >= core.size():
				await room.say("kirk", "That holds. That one's solid.")
				return true
			await room.say("kirk", "That's part of it. Not all of it.")
			continue
		removed[chosen] = true
		if chosen == "ENV_SUPPORTS":     # REV 298: backs his account, but the compensator logs mass, not identity
			await room.say("kirk", "It fits his story. It doesn't say who it was.")
		elif weak.has(chosen):
			await room.say("kirk", "Suspicion isn't proof.")
		else:
			await room.say("kirk", "We know that looks bad. We don't know what it means.")
	return false


## When both of Ullus' rooms are worked out, point the player back at the cell.
static func check_return_ullus(room: EpisodeRoom) -> void:
	# REV 493 (EPISODE1_SCRIPT.md): the hallway and the room both done -> Serrin's building opens
	if Ep1.flag("EP1_ULLUS_RETURN_READY"):
		return
	if Case.has("CLASP_PLANTED") and Case.has("DOOR_OVERRIDE"):
		Ep1.set_flag("EP1_ULLUS_ROOM_DONE")
	if not (Ep1.flag("EP1_ULLUS_HALL_DONE") and Ep1.flag("EP1_ULLUS_ROOM_DONE")):
		return
	# REV 864 (EXPANSION): and the second walker followed - FOLLOW THE SECOND WALKER
	if not Ep1.flag("EP1_WK_DONE"):
		if room.room_key == "ullus_room":
			await room.say("kirk", "That leaves our sixty-eight kilogram friend. Heading for the Romulan wing.")
		return
	Ep1.set_flag("EP1_ULLUS_RETURN_READY")
	await room.pause(0.4)
	await room.say("kirk", "His badge record doesn't hold up, the clasp never came off in a fight, his movements check out - and somebody who weighs sixty-eight kilos dropped a blank maintenance pass running away from me.")
	await room.say("mccoy", "Then let's see the lobby he says he complained in.")
	if not Ep1.flag("EP1_LOBBY_UNLOCKED"):
		Ep1.set_flag("EP1_LOBBY_UNLOCKED")
		MissionLog.notification_requested.emit("NEW LOCATION: SERRIN'S OFFICE BUILDING - LOBBY")
	Ep1.set_objective("VERIFY_ALIBI")
