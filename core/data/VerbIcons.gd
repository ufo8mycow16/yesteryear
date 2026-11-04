extends RefCounted
class_name VerbIcons
## REV 148: the ONE table that turns a hotspot's verb into what the radial menu shows - its
## on-screen word and its icon (Glen's 28-icon set in assets/ui/verbs/, see
## docs/design/RADIAL_VERB_ICONS.md).
##
## An icon is a FAMILY of action, not one word: the door icon reads OPEN, CLOSE or ENTER; the
## wrench REPAIR, ADJUST or BYPASS; the hand-with-object USE, PLACE or GIVE. Hotspots keep
## supplying plain verb words ("TALK", "OPERATE", "PICK UP BALL"); the first word(s) pick the
## family here, so a new verb only needs a line in WORDS, never a change to the menu.
##
## A hotspot can relabel any verb it supplies with Hotspot.verb_labels ({"USE": "OPEN"}), and pick
## the icon outright with Hotspot.verb_icon_overrides ({"ANSWER": "press"}).
## A verb written with a leading "!" ("!UNLOCK") is shown but greyed out with the prohibited badge:
## the player knows the action exists but can't do it yet. Use sparingly.

const DIR := "res://assets/ui/verbs/"

## family -> icon file. Numbers follow Glen's sheet (left to right, top to bottom).
const FILES := {
	"talk": "01_talk.png", "examine": "02_examine.png", "take": "03_take.png",
	"door": "04_door.png", "computer": "05_computer.png", "tricorder": "06_tricorder.png",
	"bowl": "07_bowl.png", "search": "08_search.png", "repair": "09_repair.png",
	"configure": "10_configure.png", "medical": "11_medical.png", "phaser": "12_phaser.png",
	"aim": "13_aim.png", "use": "14_use.png", "press": "15_press.png", "pull": "16_pull.png",
	"walk": "17_walk.png", "person": "18_person.png", "group": "19_group.png",
	"skip": "20_skip.png", "back": "21_back.png", "key": "22_key.png",
	"id_card": "23_id_card.png", "documents": "24_documents.png", "book": "25_book.png",
	"info": "26_info.png", "disabled": "27_disabled.png", "discard": "28_discard.png",
}

## Leading verb word(s) -> family. Longest match wins ("PICK UP" before "PICK").
const WORDS := {
	"TALK": "talk", "SPEAK": "talk", "ASK": "talk", "HAIL": "talk", "CALL": "talk", "CONTACT": "talk",
	"EXAMINE": "examine", "LOOK": "examine", "INSPECT": "examine", "OBSERVE": "examine", "VIEW": "examine",
	"PICK UP": "take", "TAKE": "take", "COLLECT": "take", "GRAB": "take",
	"OPEN": "door", "CLOSE": "door", "ENTER": "door", "LEAVE": "door", "EXIT": "door",
	"OPERATE": "computer", "ACCESS": "computer", "LOG ON": "computer", "LOG IN": "computer",
	"QUERY": "computer", "TYPE": "computer",
	"SCAN": "tricorder",
	"BOWL": "bowl",
	"SEARCH": "search", "RUMMAGE": "search", "FEEL": "search",
	"REPAIR": "repair", "FIX": "repair", "WORK ON": "repair", "BYPASS": "repair",
	"DISMANTLE": "repair", "REWIRE": "repair",
	"CONFIGURE": "configure", "ADJUST": "configure", "SET": "configure", "TUNE": "configure",
	"CALIBRATE": "configure",
	"TREAT": "medical", "HEAL": "medical", "MEDICAL": "medical", "DIAGNOSE": "medical",
	"PHASER": "phaser", "FIRE": "phaser", "STUN": "phaser", "SHOOT": "phaser",
	"AIM": "aim", "TARGET": "aim",
	"USE": "use", "GIVE": "use", "PLACE": "use", "PUT": "use", "INSERT": "use", "SHOW": "use",
	"PRESS": "press", "PUSH": "press", "ACTIVATE": "press", "ANSWER": "press", "TOUCH": "press",
	"SWITCH": "press", "RING": "press",
	"MELD": "press",     # REV 505 (Episode 2): Spock's hand on Turian - the touch icon until Glen makes a meld hand
	"PULL": "pull", "LIFT": "pull", "EXTRACT": "pull", "RAISE": "pull",
	"GO": "walk", "WALK": "walk", "CLIMB": "walk", "DESCEND": "walk", "FOLLOW": "walk",
	"INTERACT": "person", "GREET": "person",
	"CREW": "group", "PARTY": "group", "GATHER": "group",
	"CONTINUE": "skip", "SKIP": "skip",
	"BACK": "back", "CANCEL": "back", "RETURN": "back",
	"UNLOCK": "key", "LOCK": "key",
	"IDENTIFY": "id_card", "PRESENT": "id_card", "AUTHORIZE": "id_card",
	"READ": "documents", "REVIEW": "documents", "STUDY": "documents",
	"RESEARCH": "book", "BROWSE": "book", "CONSULT": "book", "LOG": "book",
	"INFO": "info", "DETAILS": "info",
	"DISCARD": "discard", "DELETE": "discard", "DROP": "discard", "CLEAR": "discard",
}

## Verbs that are always the quieter, second-rank choice in the arc (and listed last).
const SECONDARY := ["EXAMINE", "LOOK"]

## For a bare "USE" a hotspot hasn't relabelled (Episode 1 rooms still author many of these):
## the thing's own name suggests the real action. First match wins; no match keeps USE.
const USE_BY_NAME := [
	[["terminal", "console", "computer", "viewer", "library", "panel display", "station"], "ACCESS"],
	[["door", "hatch", "locker", "cabinet", "drawer", "chest", "gate"], "OPEN"],
	[["lever"], "PULL"],
	[["button", "switch", "keypad", "control", "intercom", "communicator", "panel"], "PRESS"],
	[["ladder", "stairs", "steps", "exit", "corridor", "path"], "GO"],
]

static var _cache := {}


## What the menu shows for `verb` on `hotspot`: {label, family, icon (Texture2D or null),
## secondary (bool), disabled (bool)}.
static func present(hotspot: Object, verb: String) -> Dictionary:
	var disabled := verb.begins_with("!")
	var token := verb.substr(1) if disabled else verb
	var label := token
	var labels: Dictionary = {}
	var icons: Dictionary = {}
	if hotspot != null:
		var l: Variant = hotspot.get("verb_labels")
		if l is Dictionary:
			labels = l
		var i: Variant = hotspot.get("verb_icon_overrides")
		if i is Dictionary:
			icons = i
	if labels.has(token):
		label = String(labels[token])
	elif token == "LOOK":
		label = "EXAMINE"
	elif token == "USE" and hotspot != null:
		label = use_label_for(String(hotspot.get("display_name")))
	var family := String(icons.get(token, family_of(label)))
	return {
		"label": label,
		"family": family,
		"icon": icon(family),
		"secondary": SECONDARY.has(token),
		"disabled": disabled,
	}


static func family_of(label: String) -> String:
	var up := label.strip_edges().to_upper()
	var best := ""
	for word in WORDS.keys():
		var w := String(word)
		if (up == w or up.begins_with(w + " ")) and w.length() > best.length():
			best = w
	return String(WORDS[best]) if best != "" else "use"


static func use_label_for(display_name: String) -> String:
	var name := display_name.to_lower()
	for rule in USE_BY_NAME:
		for key in rule[0]:
			if name.contains(String(key)):
				return String(rule[1])
	return "USE"


static func icon(family: String) -> Texture2D:
	if _cache.has(family):
		return _cache[family]
	var tex: Texture2D = null
	var path := DIR + String(FILES.get(family, FILES["use"]))
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		# Not imported yet (a fresh checkout before the editor has run): read the PNG directly.
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_cache[family] = tex
	return tex


## Primary verbs first in the order the hotspot gave them, EXAMINE/LOOK last.
static func ordered(verbs: Array) -> Array[String]:
	var first: Array[String] = []
	var last: Array[String] = []
	for v in verbs:
		var t := String(v).trim_prefix("!")
		if SECONDARY.has(t):
			last.append(String(v))
		else:
			first.append(String(v))
	first.append_array(last)
	return first
