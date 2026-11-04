extends RefCounted
class_name LinePools
## REV 160 (CLAUDE.md item 20, INTERACTION_MODEL.md "Refusal pools"): what the controlled character
## says when something doesn't work, and when a scan finds nothing. Data only, per character, so
## Kirk's and Spock's pools drop in beside McCoy's.
##
## Which line is used, first match wins:
##   1. OVERRIDES  - a particular item on a particular target ("Tempting.")
##   2. ITEM_LINES - that item on anything it doesn't work on ("I'm not throwing it at that.")
##   3. POOLS      - the character's own pool for the category
## A pool rotates through all its lines in a shuffled order and never says the same line twice in a
## row. The line plays as a voice when a recording exists (POOL_SPEECH_ROOT/<character>/<id>.mp3),
## as a subtitle either way. Every line id here is in the recording script for Glen.
##
## Categories:
##   "wrong_item"     - an item used on something it does nothing to
##   "nothing_useful" - USE on something that has nothing to offer right now
##   "cant_operate"   - a control or device the character can't work
##   "unreachable"    - somewhere the character can't get to
##   "nothing_unusual"- a tricorder scan that finds nothing (a scan still worked: no "invalid" sound)
##   "compare_miss"   - REV 299: two Case File clues that say nothing together (EpisodeRoom._shrug);
##                      never names a clue, never hints which one is missing
##   "compare_half"   - REV 299: one of the two DOES matter, just not with the other (non-spoiling)
##
## REV 299: Kirk, Spock and Nurse Chapel have full pools now (Kirk practical/command, Spock precise,
## Chapel clinical) - each new line is in the recording script by its id; no existing id was reused.

const POOL_SPEECH_ROOT := "res://assets/audio/speech/pools/"

const POOLS := {
	"mccoy": {
		"wrong_item": [
			["MCCOY_REF_0001", "What the hell am I supposed to do with that?"],
			["MCCOY_REF_0002", "I'm a doctor, not a handyman."],
			["MCCOY_REF_0003", "Now what would that accomplish?"],
			["MCCOY_REF_0004", "That's about as useful as a Vulcan at a pie-eating contest."],
			["MCCOY_REF_0005", "I've had better ideas after a bottle of Saurian brandy."],
			["MCCOY_REF_0006", "No. Just... no."],
			["MCCOY_REF_0007", "Jim might try that. I'm not Jim."],
			["MCCOY_REF_0008", "If that works, I'll eat my tricorder."],
		],
		"nothing_useful": [
			["MCCOY_REF_0101", "Nothing doing."],
			["MCCOY_REF_0102", "That's not getting me anywhere."],
			["MCCOY_REF_0103", "Doesn't help. Doesn't hurt either."],
		],
		"cant_operate": [
			["MCCOY_REF_0201", "I'd need an engineer for that. Or a miracle."],
			["MCCOY_REF_0202", "Scotty would know. I don't."],
			["MCCOY_REF_0203", "It doesn't want to cooperate, and frankly neither do I."],
		],
		"unreachable": [
			["MCCOY_REF_0301", "Can't get there from here."],
			["MCCOY_REF_0302", "I'm not climbing over that."],
		],
		"nothing_unusual": [
			["MCCOY_SCN_0001", "Normal readings. Disappointingly normal."],
			["MCCOY_SCN_0002", "Nothing. Not a blessed thing."],
			["MCCOY_SCN_0003", "Clean as a whistle."],
			["MCCOY_SCN_0004", "The tricorder says it's fine. I'll take its word for it."],
			["MCCOY_SCN_0005", "Nothing out of the ordinary. Which, around here, is unusual."],
			["MCCOY_SCN_0006", "No readings worth mentioning."],
		],
		"compare_miss": [
			["MCCOY_CMP_0001", "I can't make those two say anything to each other. Not yet."],
			["MCCOY_CMP_0002", "Apples and oranges, Jim."],
			["MCCOY_CMP_0003", "That's like comparing a pulse with a weather report."],
			["MCCOY_CMP_0004", "If there's a connection, it's hiding from me."],
			["MCCOY_CMP_0005", "Nope. Nothing there."],
			["MCCOY_CMP_0006", "Two symptoms. Different diseases."],
		],
		"compare_half": [
			["MCCOY_CMP_0101", "One of those matters. Just not with the other."],
			["MCCOY_CMP_0102", "There's something to that one. Wrong partner, though."],
			["MCCOY_CMP_0103", "Hang on to that. It's going to mean something."],
		],
	},
	"kirk": {
		"wrong_item": [
			["KIRK_REF_0001", "That's not going to accomplish anything."],
			["KIRK_REF_0002", "Not one of my better ideas."],
			["KIRK_REF_0003", "No. That's not the way in."],
			["KIRK_REF_0004", "I'd be guessing. A starship captain shouldn't guess."],
			["KIRK_REF_0005", "Wrong tool for the job."],
			["KIRK_REF_0006", "Bones would have something to say about that."],
			["KIRK_REF_0007", "Think it through, Jim."],
			["KIRK_REF_0008", "That won't get us any closer."],
		],
		"nothing_useful": [
			["KIRK_REF_0101", "Nothing there for us."],
			["KIRK_REF_0102", "A dead end."],
			["KIRK_REF_0103", "Not now. There are more important things."],
		],
		"cant_operate": [
			["KIRK_REF_0201", "Locked out. I'd need the access codes."],
			["KIRK_REF_0202", "That's Scotty's territory, not mine."],
			["KIRK_REF_0203", "I won't force it. Not on Vulcan."],
		],
		"unreachable": [
			["KIRK_REF_0301", "I can't get to it from here."],
			["KIRK_REF_0302", "There's no way through."],
		],
		"nothing_unusual": [
			["KIRK_SCN_0001", "Nothing unusual."],
			["KIRK_SCN_0002", "Readings are normal."],
			["KIRK_SCN_0003", "Nothing worth logging."],
		],
		"compare_miss": [
			["KIRK_CMP_0001", "Those two don't tell us anything together. Not yet."],
			["KIRK_CMP_0002", "No connection. Not that I can see."],
			["KIRK_CMP_0003", "Different questions. Neither answers the other."],
			["KIRK_CMP_0004", "We're reaching. Let's not."],
			["KIRK_CMP_0005", "Put those side by side and they're still strangers."],
			["KIRK_CMP_0006", "That's two facts, not an answer."],
		],
		"compare_half": [
			["KIRK_CMP_0101", "That one matters. Not with that."],
			["KIRK_CMP_0102", "There's something there - but that isn't what it goes with."],
			["KIRK_CMP_0103", "Keep that one in mind. We don't have its partner yet."],
		],
	},
	"spock": {
		"wrong_item": [
			["SPOCK_REF_0001", "I fail to see how that would be useful."],
			["SPOCK_REF_0002", "Illogical."],
			["SPOCK_REF_0003", "The probability of success is negligible."],
			["SPOCK_REF_0004", "That would accomplish nothing of value."],
			["SPOCK_REF_0005", "An interesting hypothesis. It is also incorrect."],
			["SPOCK_REF_0006", "The two have no functional relationship."],
			["SPOCK_REF_0007", "I would advise against it."],
			["SPOCK_REF_0008", "There is no logical purpose in that."],
		],
		"nothing_useful": [
			["SPOCK_REF_0101", "There is nothing further to be learned here."],
			["SPOCK_REF_0102", "That yields no useful data."],
			["SPOCK_REF_0103", "Irrelevant to the present problem."],
		],
		"cant_operate": [
			["SPOCK_REF_0201", "The system requires an authorisation I do not possess."],
			["SPOCK_REF_0202", "It is beyond my ability to operate without proper access."],
			["SPOCK_REF_0203", "Forcing the mechanism would be unwise."],
		],
		"unreachable": [
			["SPOCK_REF_0301", "It is not accessible from this position."],
			["SPOCK_REF_0302", "There is no route to it."],
		],
		"nothing_unusual": [
			["SPOCK_SCN_0001", "Readings are within normal parameters."],
			["SPOCK_SCN_0002", "No anomalies detected."],
			["SPOCK_SCN_0003", "Nothing of significance."],
		],
		"compare_miss": [
			["SPOCK_CMP_0001", "The two facts are unrelated."],
			["SPOCK_CMP_0002", "No logical connection exists between them."],
			["SPOCK_CMP_0003", "Juxtaposition is not correlation."],
			["SPOCK_CMP_0004", "Together they establish nothing."],
		],
		"compare_half": [
			["SPOCK_CMP_0101", "One of these is significant. Its counterpart is not before us."],
			["SPOCK_CMP_0102", "A relevant fact, paired with an irrelevant one."],
		],
	},
	"chapel": {
		"wrong_item": [
			["CHAPEL_REF_0001", "That won't help."],
			["CHAPEL_REF_0002", "Doctor McCoy would have my head."],
			["CHAPEL_REF_0003", "That's not what it's for."],
			["CHAPEL_REF_0004", "No. Not that."],
		],
		"nothing_useful": [
			["CHAPEL_REF_0101", "Nothing there."],
			["CHAPEL_REF_0102", "It can wait."],
		],
		"cant_operate": [
			["CHAPEL_REF_0201", "That isn't my department."],
		],
		"unreachable": [
			["CHAPEL_REF_0301", "I can't reach it from here."],
		],
		"nothing_unusual": [
			["CHAPEL_SCN_0001", "Normal readings."],
			["CHAPEL_SCN_0002", "Nothing out of the ordinary."],
		],
	},
}

## item id -> lines that item says on anything it doesn't work on (before the character's pool).
## Keyed by character, since a line is in someone's voice.
const ITEM_LINES := {
	"mccoy": {
		"INV_PRO_001": [   # the bowling ball
			["MCCOY_REF_1001", "I'm not throwing it at that."],
			["MCCOY_REF_1002", "The ball goes down the lane, McCoy. Not there."],
		],
	},
}

## "character|item id|hotspot id" -> one line (or a few, rotated) for that exact combination.
const OVERRIDES := {
	"mccoy|INV_PRO_001|HOT_PRO_006": [["MCCOY_REF_2001", "Tempting."]],                               # the ball, on Spock
	"mccoy|INV_PRO_001|HOT_PRO_005": [["MCCOY_REF_2002", "Jim would never let me hear the end of it."]],   # the ball, on Kirk
	"mccoy|INV_PRO_001|HOT_PRO_012": [["MCCOY_REF_2003", "He's only the steward. Leave him out of it."]],  # the ball, on Pell
}

## Whose voice says a line, from its id ("MCCOY_REF_0001" -> "mccoy").
static func speaker_of(id: String) -> String:
	return id.split("_")[0].to_lower()


# ---- rotation ---------------------------------------------------------------------------------
static var _bags := {}     # pool key -> remaining indices (shuffled)
static var _last := {}     # pool key -> index said last


## The next line for a pool: a shuffled pass through all of it, never repeating the last line said.
static func next_from(key: String, lines: Array) -> Array:
	if lines.is_empty():
		return []
	if lines.size() == 1:
		return lines[0]
	var bag: Array = _bags.get(key, [])
	if bag.is_empty():
		for i in lines.size():
			bag.append(i)
		bag.shuffle()
		# the new pass must not start with the line that ended the last one
		if int(bag[0]) == int(_last.get(key, -1)):
			bag.append(bag.pop_front())
	var i := int(bag.pop_front())
	_bags[key] = bag
	_last[key] = i
	return lines[i]


## The line to say, as [id, text], or [] if there is none for this character and category.
static func pick(character: String, category: String, item_id: String = "", hotspot_id: String = "") -> Array:
	if item_id != "" and hotspot_id != "":
		var k := "%s|%s|%s" % [character, item_id, hotspot_id]
		if OVERRIDES.has(k):
			return next_from("ov:" + k, OVERRIDES[k])
	if item_id != "" and category == "wrong_item":
		var per: Dictionary = ITEM_LINES.get(character, {})
		if per.has(item_id):
			return next_from("item:%s|%s" % [character, item_id], per[item_id])
	var pools: Dictionary = POOLS.get(character, {})
	if not pools.has(category):
		pools = POOLS["mccoy"] if character == "" else {}
	if not pools.has(category):
		return []
	return next_from("pool:%s|%s" % [character, category], pools[category])


## Every line here, as [id, text] - for the recording script.
static func all_lines() -> Array:
	var out: Array = []
	for who in POOLS:
		for cat in POOLS[who]:
			out.append_array(POOLS[who][cat])
	for who in ITEM_LINES:
		for item in ITEM_LINES[who]:
			out.append_array(ITEM_LINES[who][item])
	for k in OVERRIDES:
		out.append_array(OVERRIDES[k])
	return out
