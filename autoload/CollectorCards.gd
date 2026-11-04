extends Node
## CollectorCards — the COLLECTION screen's data: the collector cards.
##
## REV 742 (Glen, 31 Oct): cards are FLOATING, SPINNING cards hidden round the rooms - walk through one to collect it
## (core/props/FloatingCard.gd, placed by each room with EpisodeRoom.float_card). "Cards shouldn't unlock by having an
## item in your inventory or by talking to someone" - the old automatic person/item cards are gone. 5-8 per episode.
## Kept in its own file (user://collection.cfg), so the collection belongs to the player rather than to one save slot.
##
## To add a card: add a row to CARDS, place it in its room with float_card(id, where), and add a stand-in front to
## tools/make_collector_cards.py (Glen's own art replaces it: assets/ui/cards/front_<id>.png).
## A card's "name" is the person's FULL name ("Montgomery Scott") on purpose - that's the card's flavour.

signal card_unlocked(card: Dictionary)
signal notification_requested(message: String)

const SAVE_PATH := "user://collection.cfg"
const CARD_DIR := "res://assets/ui/cards/"

## id, episode, name, kind, blurb (where it was found - shown once you have it).
const CARDS := [
	# Episode 3 (EPISODE3_SCRIPT.md 3.15 introduced the character cards). Kirk's, Spock's and McCoy's wait for
	# Episode 5 (their quarters are locked).
	{"id": "card_scotty", "episode": 3, "name": "Montgomery Scott", "kind": "CHIEF ENGINEER", "blurb": "Found in his quarters, over the Flying Scotsman."},
	{"id": "card_uhura", "episode": 3, "name": "Nyota Uhura", "kind": "COMMUNICATIONS", "blurb": "Found in her quarters, by the mirror."},
	{"id": "card_sulu", "episode": 3, "name": "Hikaru Sulu", "kind": "HELMSMAN", "blurb": "Found in his cabin, by the fencing foils."},
	{"id": "card_chekov", "episode": 3, "name": "Pavel Chekov", "kind": "NAVIGATOR", "blurb": "Found on the bridge, by his station. For luck."},
	{"id": "card_kyle", "episode": 3, "name": "Lieutenant Kyle", "kind": "TRANSPORTER CHIEF", "blurb": "Found in Transporter Room 1, by his locker."},
	{"id": "card_chapel", "episode": 3, "name": "Christine Chapel", "kind": "HEAD NURSE", "blurb": "Found in Sickbay, over the plomeek soup."},
	{"id": "card_giotto", "episode": 3, "name": "Lt. Cmdr. Giotto", "kind": "CHIEF OF SECURITY", "blurb": "Found in the evidence locker. Confiscated. Still confiscated."},
	# REV 764 (Glen's bug list VF-003): an optional find behind Deck 7's red mesh armoury door
	{"id": "card_phaser_rifle", "episode": 3, "name": "Phaser Rifle", "kind": "ARMOURY", "blurb": "Found in the Deck 7 armoury, on the rifle rack."},
]

var _unlocked: Dictionary = {}   # id -> true


func _ready() -> void:
	_load()


func total() -> int:
	return CARDS.size()


func unlocked_count() -> int:
	return _unlocked.size()


func is_unlocked(card_id: String) -> bool:
	return _unlocked.has(card_id)


func card(card_id: String) -> Dictionary:
	for c in CARDS:
		if String(c["id"]) == card_id:
			return c
	return {}


## The card's front picture (Glen's art, or the stand-in), or null.
func front(card_id: String) -> Texture2D:
	var path := CARD_DIR + "front_%s.png" % card_id
	return load(path) if ResourceLoader.exists(path) else null


## REV 767 (Glen's A&BC-style cards: each has its own printed back): back_<id>.png when the card has one, else the
## shared Vulcan emblem back (card_back.png).
func back(card_id: String = "") -> Texture2D:
	if card_id != "":
		var own := CARD_DIR + "back_%s.png" % card_id
		if ResourceLoader.exists(own):
			return load(own)
	var path := CARD_DIR + "card_back.png"
	return load(path) if ResourceLoader.exists(path) else null


func unlock(card_id: String) -> void:
	if _unlocked.has(card_id):
		return
	var c := card(card_id)
	if c.is_empty():
		return
	_unlocked[card_id] = true
	_save()
	card_unlocked.emit(c)
	# the HUD's notice card plays the notice sound; the floating card plays its own chime
	notification_requested.emit("NEW COLLECTOR CARD: %s" % String(c["name"]).to_upper())


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for id in cfg.get_value("cards", "unlocked", []):
		if not card(String(id)).is_empty():      # REV 742: drop the retired automatic cards from old collections
			_unlocked[String(id)] = true


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("cards", "unlocked", _unlocked.keys())
	cfg.save(SAVE_PATH)
