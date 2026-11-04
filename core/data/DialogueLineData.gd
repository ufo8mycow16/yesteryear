extends Resource
class_name DialogueLineData
## One recorded line. filename is the stable dialogue-line ID (e.g.
## "SPOCK_PRO_0007.mp3") and must never be renamed or reused once allocated.

@export var character_folder: String = ""  # "mccoy" | "kirk" | "spock" | "uhura"
@export var speaker_display_name: String = ""
@export var filename: String = ""
@export_multiline var subtitle: String = ""
## Variables set the moment this line plays (e.g. {"VAR_PRO_SPOCK_HINT": true}).
@export var variables_set: Dictionary = {}
## Which audio bus plays this line. "Dialogue" (default) for anyone speaking
## in the same room as the player; "Intercom" for a voice coming over a comm
## channel (e.g. Uhura hailing from the bridge) — that bus applies a
## band-limiting EQ + light compression so it reads as a radio/intercom
## voice instead of a clean in-room voice. See default_bus_layout.tres.
@export var audio_bus: String = "Dialogue"

## REV 97, for the conversation camera (all optional; empty = worked out automatically):
## who the line is said to (a speaker id such as "kirk"),
@export var target_id: String = ""
## an emotion from the speaker's CharacterFaceProfile ("worried", "angry" ...),
@export var emotion: String = ""
## and a framing: CU, MCU, MS, OTS, TWO (both people in frame) or WIDE. REV 293: TWO was missing from this
## list though ConversationPresenter has always accepted it.
@export var shot: String = ""
## REV 129: a move the speaker makes with the line (optional): "shrug", "point", "think", "nod",
## "head_shake", "look_behind". Talking gestures happen anyway; this is for the ones that mean something.
@export var gesture: String = ""
