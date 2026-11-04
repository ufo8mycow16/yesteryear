extends RefCounted
class_name Ep3Calls
## Episode 3's communicator traffic (EPISODE3_SCRIPT.md) - one place for every call that reaches Scotty or
## Kyle wherever they are, and the calls the player makes:
##   STORY CALLS  that move the story on, played as the player arrives somewhere or as a scene ends
##                (Ep3.after_arrival / after_scene): Scotty suggests Kyle check his room (3.11), Giotto's
##                call about Pell (3.12), Uhura's junction (3.13), Smokey (3.15), Romaine (3.14's last),
##                Vulcan's answer (3.27), the bay (3.28).
##   THE LIVING SHIP (3.14): short calls between leads, each ending on a choice - never in the middle of a
##                puzzle or a conversation, never twice in a row, only as the player moves about.
##   THE PLAYER'S CALLS: the communicator (EpisodeRoom.open_communicator -> Ep3.calls): the other lead (the
##                partner's hint chain - "by communicator when apart"), Uhura (the message to Vulcan can be
##                sent from anywhere), Giotto.

static var _busy := false


## The next story call due here, or "" (in priority order).
static func due(room: EpisodeRoom, arriving: bool) -> String:
	var scotty := Ep3.played() == "scotty"
	var here := room.room_key
	if not scotty:
		return ""
	# 3.30: any other deck while she's slowing - "Sir - the BRIDGE, please!" (every time)
	if arriving and Ep3.flag("EP3_SLOWING") and not Ep3.flag("EP3_DROPPED_OUT") and here != "bridge":
		return "bridge_please"
	# 3.32: the game suggests the switch once
	if Ep3.flag("EP3_BAY_EMPTY") and not Ep3.flag("EP3_KYLE_CHECK") and here != "transporter":
		return "kyle_check"
	if Ep3.flag("EP3_D6_SIGHTING") and not Ep3.flag("EP3_TR_SUGGESTED") and here != "transporter":
		return "tr_suggest"
	if Ep3.flag("EP3_D6_SIGHTING") and Ep3.flag("EP3_SCHEDULE_SEEN") and not Ep3.flag("EP3_PELL_CALL"):
		return "pell"
	if Ep3.flag("EP3_PELL_FREE") and not Ep3.flag("EP3_UHURA_JUNCTION"):
		return "uhura_junction"
	if Ep3.flag("EP3_MESSAGE_SENT") and not Ep3.flag("EP3_SMOKEY_ASKED") and arriving:
		return "smokey"
	if arriving and Ep3.flag("EP3_MATRIX_DOWN") and not Ep3.flag("EP3_CALL_ROMAINE"):
		var played := 0
		for k in ["EP3_CALL_DESALLE", "EP3_CALL_CHAPEL", "EP3_CALL_GIOTTO", "EP3_CALL_SULU"]:
			if Ep3.flag(k):
				played += 1
		if Ep3.flag("EP3_COMMS_BACK") and Ep3.flag("EP3_MESSAGE_SENT") and Ep3.flag("EP3_PELL_FREE") and played >= 2 \
				and String(Ep3.value("EP3_LAST_CALL", "")) != "":
			return "romaine"
		if String(Ep3.value("EP3_LAST_CALL", "")) != "":
			Ep3.set_value("EP3_LAST_CALL", "")     # never twice in a row: this arrival is a quiet one
			return ""
		if Ep3.flag("EP3_D6_SIGHTING") and not Ep3.flag("EP3_CALL_DESALLE"):
			return "desalle"
		if Ep3.flag("EP3_SCHEDULE_SEEN") and not Ep3.flag("EP3_CALL_CHAPEL"):
			return "chapel"
		if Ep3.flag("EP3_PELL_FREE") and not Ep3.flag("EP3_CALL_GIOTTO"):
			return "giotto"
		if Ep3.flag("EP3_LISTENER_OFF") and not Ep3.flag("EP3_CALL_SULU"):
			return "sulu"
	if Ep3.flag("EP3_ENGINES_STABLE") and not Ep3.flag("EP3_REPLY_CALL"):
		return "reply"
	if Ep3.flag("EP3_VULCAN_REPLY") and not Ep3.flag("EP3_BAY_CALL") and here != "bridge" and arriving:
		return "bay"
	return ""


static func play_due(room: EpisodeRoom, arriving: bool) -> void:
	if _busy:
		return
	var key := due(room, arriving)
	if key == "":
		return
	_busy = true
	if not room._busy:
		room._begin_scene()
	await room.pause(0.4)
	SfxManager.ui("open")     # (a communicator chirp - a TOS sound can replace it)
	await room.pause(0.3)
	match key:
		"tr_suggest": await _tr_suggest(room)
		"pell": await _pell(room)
		"uhura_junction": await uhura_junction(room)
		"smokey": await _smokey(room)
		"desalle": await _desalle(room)
		"chapel": await _chapel(room)
		"giotto": await _giotto(room)
		"sulu": await _sulu(room)
		"romaine": await _romaine(room)
		"reply": await reply_call(room)
		"bay": await _bay(room)
		"bridge_please": await room.say("chekov", "Sir - the BRIDGE, please!")
		"kyle_check": await _kyle_check(room)
	if key in ["desalle", "chapel", "giotto", "sulu"]:
		Ep3.set_value("EP3_LAST_CALL", key)
	_busy = false


# ---- story calls ------------------------------------------------------------------------------------

## 3.11 - the game suggests the switch once.
static func _tr_suggest(room: EpisodeRoom) -> void:
	Ep3.set_flag("EP3_TR_SUGGESTED")
	await room.say("scotty", "Mister Kyle, is your room still yours?")
	await room.say("kyle", "Checking, sir.")
	# REV 741 (Glen: story first): the game takes you to Kyle - no "press TAB" card
	Ep3.hand_over(room, "kyle")


## 3.32 - "Mister Scott, I want to check something in my room."
static func _kyle_check(room: EpisodeRoom) -> void:
	Ep3.set_flag("EP3_KYLE_CHECK")
	await room.say("kyle", "Mister Scott, I want to check something in my room.")
	await room.say("scotty", "Go on, laddie.")
	Ep3.hand_over(room, "kyle")


## 3.12 - Giotto: one of the crew's shut in his cabin.
static func _pell(room: EpisodeRoom) -> void:
	Ep3.set_flag("EP3_PELL_CALL")
	await room.say("giotto", "Security to Mister Scott. One of the crew's shut in his cabin on Deck Six - the door keeps locking itself. He's banging on it. We can't get it open, and I need my people on the search.")
	await room.say("scotty", "I'll see to him.")


## 3.13 - Uhura's call comes as Pell's door opens (one thread lands on the other). Rooms play it at that
## moment; it's also a due call in case it was missed.
static func uhura_junction(room: EpisodeRoom) -> void:
	if Ep3.flag("EP3_UHURA_JUNCTION"):
		return
	Ep3.set_flag("EP3_UHURA_JUNCTION")
	await room.say("uhura", "Mister Scott - I've found what's sitting on the array. Something's listening to every channel and eating what I send. I can't get a word to Vulcan.")
	await room.say("scotty", "Where?")
	await room.say("uhura", "The comms relay junction - Deck Five, by the officers' lounge.")
	await room.say("scotty", "...Same place. That's no coincidence.")


## 3.15 - Smokey (Uhura's personal favour; her cabin unlocks).
static func _smokey(room: EpisodeRoom) -> void:
	Ep3.set_flag("EP3_SMOKEY_ASKED")
	await room.say("uhura", "Mister Scott - one personal favour? Smokey hasn't been fed since this started. My cabin, Deck Five. She's the only one, Mister Scott, I promise.")
	await room.say("scotty", "Aye, lass. I'll see she's fed.")


## 3.14's last call - the bridge into Act Three.
static func _romaine(room: EpisodeRoom) -> void:
	Ep3.set_flag("EP3_CALL_ROMAINE")
	await room.say("romaine", "Mister Scott? Lieutenant Romaine, in the computer core. You'll want to see this.")
	await room.pause(0.5)
	await room.say("romaine", "...Montgomery.")
	await room.pause(0.7)
	await room.say("scotty", "...On my way.")


## 3.27 - Uhura, as the engines settle.
static func reply_call(room: EpisodeRoom) -> void:
	if Ep3.flag("EP3_REPLY_CALL"):
		return
	Ep3.set_flag("EP3_REPLY_CALL")
	await room.say("uhura", "Mister Scott - Vulcan's answered.")
	await room.pause(0.4)
	await room.say("uhura", "You'll want to hear it up here.")


## 3.28 - the sweep reaches Deck 7.
static func _bay(room: EpisodeRoom) -> void:
	Ep3.set_flag("EP3_BAY_CALL")
	await room.say("giotto", "Security to bridge! Sensors are back on Seven. Three unidentified life signs - Cargo Bay Two.")
	await room.say("scotty", "Seal it.")
	await room.say("giotto", "...It's already sealed, sir. Every door round that bay just locked itself.")
	await room.say("scotty", "Did it now. That'll be their own wee trap, doing what it's told.", {"emotion": "happy"})
	await room.say("kyle", "Ninety seconds on, ninety off - only now it's them on the wrong side.")


# ---- 3.14: the living ship ----------------------------------------------------------------------------

static func _desalle(room: EpisodeRoom) -> void:
	Ep3.set_flag("EP3_CALL_DESALLE")
	await room.say("desalle", "Mister Scott, the intermix is running hot. It's holding. I wanted ye to know.")
	var pick: int = await room.choose(["I'll be down.", "Keep an eye on it.", "How hot?"], "SCOTT:")
	match pick:
		0:
			await room.say("scotty", "I'll be down.")
			await room.say("desalle", "Aye, sir.")
		1:
			await room.say("scotty", "Keep an eye on it.")
			await room.say("desalle", "Both eyes, sir.")
		_:
			await room.say("scotty", "How hot?")
			await room.say("desalle", "Hot enough I've stopped touching things.")


static func _chapel(room: EpisodeRoom) -> void:
	Ep3.set_flag("EP3_CALL_CHAPEL")
	await room.say("chapel", "Mister Scott - Ambassador Turian's preservation field is on its own power. I've checked it twice. It can't be switched off from outside.")
	var pick: int = await room.choose(["Thank ye, Nurse.", "Is anybody with ye?"], "SCOTT:")
	if pick == 1:
		await room.say("scotty", "Is anybody with ye?")
		await room.say("chapel", "One security officer and a hypospray. I'm not sure which they should be more afraid of.")
	else:
		await room.say("scotty", "Thank ye, Nurse.")


static func _giotto(room: EpisodeRoom) -> void:
	Ep3.set_flag("EP3_CALL_GIOTTO")
	await room.say("giotto", "I can take Deck Five or Deck Seven next, sir. Not both.")
	var pick: int = await room.choose(["Five.", "Seven."], "SCOTT:")
	await room.say("scotty", "Five." if pick == 0 else "Seven.")
	await room.say("giotto", "Aye, sir.")
	Ep3.set_value("EP3_GIOTTO_DECK", "5" if pick == 0 else "7")


static func _sulu(room: EpisodeRoom) -> void:
	Ep3.set_flag("EP3_CALL_SULU")
	await room.say("sulu", "Mister Scott - she's still pulling against me. Every few minutes she tries to take the wheel back.")
	var pick: int = await room.choose(["Let her pull. Just don't let go.", "Ye're doing fine, Mister Sulu."], "SCOTT:")
	if pick == 0:
		await room.say("scotty", "Let her pull. Just don't let go.")
		await room.say("sulu", "I won't, sir.")
	else:
		await room.say("scotty", "Ye're doing fine, Mister Sulu.")
		await room.say("sulu", "...Thank you, sir.")
		if Ep3.flag("EP3_CHEKOV_PRAISED"):
			await room.say("chekov", "He said that to me too.")


# ---- 3.13: the message to Vulcan (on the bridge, or by comm from anywhere) ----------------------------

static func message(room: EpisodeRoom) -> void:
	if Ep3.flag("EP3_MESSAGE_SENT"):
		await room.say("uhura", "It's on its way, Mister Scott. It'll take time to get there - and longer to come back.")
		return
	await room.say("uhura", "I've drafted it, Mister Scott. 'The Vulcan computer team were Romulan impostors. They escaped custody and hijacked the Enterprise. Mister Scott has partial control. Enterprise will return as soon as the fugitives are recovered.'")
	var pick: int = await room.choose(["Send it as it is.", "Add: 'Request instructions for Captain Kirk.'", "Add: 'Tell the Captain we're managing.'"], "SCOTT:")
	match pick:
		1:
			await room.say("scotty", "Add: 'Request instructions for Captain Kirk.'")
			await room.say("uhura", "Added.")
			Ep3.set_value("EP3_MESSAGE_TONE", "instructions")
		2:
			await room.say("scotty", "Add: 'Tell the Captain we're managing.'")
			await room.say("uhura", "Are we, sir?")
			await room.say("scotty", "We will be by the time it gets there.")
			Ep3.set_value("EP3_MESSAGE_TONE", "managing")
		_:
			await room.say("scotty", "Send it as it is.")
			await room.say("uhura", "Sending.")
			Ep3.set_value("EP3_MESSAGE_TONE", "plain")
	await room.say("uhura", "Sent. It'll take time to get there - and longer to come back.")
	await room.say("scotty", "Then we keep busy.")
	Ep3.set_flag("EP3_MESSAGE_SENT")


# ---- the player's own calls ---------------------------------------------------------------------------

## [[label, Callable], ...] for the communicator. Rooms add their own in front (Ep3 rooms' communicator_calls).
static func calls(room: EpisodeRoom) -> Array:
	var out: Array = []
	var me := Ep3.played()
	if Ep3.flag("EP3_KYLE_MET"):
		if me == "scotty":
			out.append(["Mister Kyle", func() -> void: await _call_partner(room, "kyle")])
		else:
			out.append(["Mister Scott", func() -> void: await _call_partner(room, "scotty")])
	if me == "scotty" and Ep3.flag("EP3_COMMS_BACK") and not Ep3.flag("EP3_MESSAGE_SENT"):
		out.append(["Bridge - Lieutenant Uhura (the message to Vulcan)", func() -> void:
			await room.say("scotty", "Scott to bridge. Uhura - let's get that message off.")
			await message(room)])
	if me == "scotty" and Ep3.flag("EP3_DECK7_OPEN") and not Ep3.flag("EP3_COMPLETE"):
		out.append(["Security - Commander Giotto", func() -> void: await _call_giotto(room)])
	return out


static func _call_partner(room: EpisodeRoom, who: String) -> void:
	if who == "kyle":
		await room.say("scotty", "Scott to Kyle.")
	else:
		await room.say("kyle", "Kyle to Mister Scott.")
	await room.say(who, "Kyle here, sir." if who == "kyle" else "Scott here. Go ahead, laddie.")
	# 3.32: Kyle asking for the isolator / reporting the blip
	if who == "scotty" and Ep3.flag("EP3_SHIELD_BLIP") and not Ep3.flag("EP3_KYLE_HAS_ISOLATOR"):
		await room.say("kyle", "Mister Scott, I need the Romulan isolator.")
		await room.say("scotty", "Take it - and don't touch anything that zaps.")
		await room.note("(Mister Scott sends it down with Ensign Ross.)", 2.2)
		Ep3.set_flag("EP3_KYLE_HAS_ISOLATOR")
		Ep3.sync_items()
		return
	# 3.21: Kyle remembers the manual (REV 716: on data cards - no paper aboard)
	if who == "kyle" and Ep3.flag("EP3_PRINTER_JAMMED") and not Ep3.flag("EP3_FORM_IDEA") and not Ep3.flag("EP3_HAS_FORM"):
		await kyle_remembers(room)
		return
	if not await room.partner_hint():
		await room.say(who, "Nothing new here, sir. I'll call if there is." if who == "kyle" else "Keep at it, laddie.")


## 3.21 - "Sir - there's a blank form in the back of my transporter manual."
static func kyle_remembers(room: EpisodeRoom) -> void:
	Ep3.set_flag("EP3_FORM_IDEA")
	await room.say("kyle", "Sir - there's a blank requisition card in the back of my transporter manual. The card set. I keep a card set.")
	await room.say("scotty", "Of course ye do.")


static func _call_giotto(room: EpisodeRoom) -> void:
	await room.say("scotty", "Scott to Giotto. Anything?")
	if Ep3.flag("EP3_BAY_EMPTY"):
		await room.say("giotto", "Deck by deck, sir, from the bottom. Nothing yet.")
	elif Ep3.flag("EP3_BAY_SURROUNDED"):
		await room.say("giotto", "They're still in there, sir. Not moving.")
	elif Ep3.flag("EP3_SWEEP_STARTED"):
		await room.say("giotto", "Watching the sweep, sir. A deck at a time.")
	elif Ep3.flag("EP3_MATRIX_DOWN"):
		await room.say("giotto", "Doors that shouldn't be locked, sir. Lights going out where we're looking. We're always a step behind.")
	else:
		await room.say("giotto", "Still searching Seven, sir.")


# ---- 3.24: LIVE - the second (on the walk down to Engineering - a Deck 6 corridor, the lift doors just closing
# behind him; Engineering plays it on arrival if the walk didn't go through Deck 6) ------------------------

static func live_two(room: EpisodeRoom, on_deck6: bool) -> void:
	if Ep3.flag("EP3_LIVE_2"):
		return
	Ep3.set_flag("EP3_LIVE_2")
	if on_deck6:
		await room.note("(Twenty metres ahead, a door slams shut by itself - nobody near it on Scotty's side.)", 2.4)
	else:
		await room.note("(On the way down - a corridor, the lift doors just closing behind him - twenty metres ahead, a door slams shut by itself. Nobody near it on his side.)", 3.0)
	await room.pause(0.6)
	await room.say("scotty", "That one's not for me.", {"emotion": "smile"})
	await room.say("giotto", "Mister Scott - a door on Six just locked with nobody near it.")
	await room.say("scotty", "Somebody was near it, laddie. Just not us.")
	await room.pause(0.4)
	await room.say("giotto", "...Sensors came back on Six a minute ago. Three blips by that door - then nothing. They've gone somewhere the sweep hasn't reached yet.")


# ---- 3.23: the audio log (in Auxiliary Control - better - or from the computer core's console) ----------

static func audio_log(room: EpisodeRoom, here: bool) -> void:
	await room.note("(Three voices - Varel, Kovek, Tovan. Heard, not seen. The camera holds on the empty chair turned toward the door.)", 2.6)
	await room.say("kovek", "The Matrix was never built for this. It was built to open doors, not to fly a starship. Their architecture fights it at every step.")
	await room.say("varel", "Then it will have to learn.")
	await room.say("tovan", "The engines are past her limits. She is shaking herself apart.")
	await room.say("kovek", "If she fails before we arrive -")
	await room.say("varel", "She will not fail. Keep her whole. We may need her yet.")
	if Ep3.flag("VAR_EP2_VAREL_CREDENTIALS"):
		await room.say("tovan", "Their first officer read every line of our credentials.")
		await room.say("varel", "And found them in order. Because we made them so.")
	if Ep3.flag("VAR_EP2_KOVEK_THANKED"):
		await room.pause(0.5)
		await room.say("kovek", "...He thanked me. The Vulcan.")
		await room.say("varel", "Then he was courteous. Be grateful he was not curious.")
		await room.pause(0.8)
	await room.say("kovek", "And if the engineer finds the Matrix?")
	await room.say("varel", "Then he will find a box.")
	await room.pause(0.4)
	await room.say("varel", "\"When you steal the enemy's sword, learn quickly how to wield it.\"")
	await room.note("(Recording ends.)", 1.4)
	await room.pause(1.0)
	await room.say("scotty", "\"Past her limits.\"", {"emotion": "worried"})
	await room.pause(0.4)
	await room.say("scotty", "My engines.")
	if here:
		await room.say("scotty", "Ye heard them, ye wee box. Learn quickly.")
	Ep3.set_flag("EP3_AUDIO_LOG")
	Ep3.refresh_tracker()
