extends Resource
class_name DialogueTopicData
## A KOTOR/adventure-style topic entry — a data-driven state, not a
## full-sentence RPG menu line. States: new / continuing / exhausted / hidden
## / reactivated, matching the project-wide dialogue-topic model.

enum State { NEW, CONTINUING, EXHAUSTED, HIDDEN, REACTIVATED }

@export var id: String = ""
@export var label: String = ""
@export var state: State = State.NEW
@export var lines: Array[DialogueLineData] = []
## Topics may be purely flavour (no progression effect) — true for every
## topic documented in CONV_PRO_002's "Available Topics" list.
@export var progression_topic: bool = false
## Optional: the topic starts HIDDEN and appears (as NEW) the first time this
## GameState condition is true, e.g. "CLUE_PRO_SCORE == TRUE".
@export var unlock_condition: String = ""
## Case File clue ids given to the player after this topic's lines have played.
@export var grants_clues: Array[String] = []
## REV 97 (optional): the full sentence the protagonist says when this topic is chosen. In the
## letterboxed conversation mode its subtitle is the choice text, and it plays before `lines`.
## Topics without one show `label` and play `lines` as before.
@export var response_line: DialogueLineData = null
## REV 108: an ANSWER to the character's question ("Not yet.") rather than a question you ask:
## once said, it leaves the menu (you can't give the same answer twice). Questions you ask stay
## on the menu, greyed once asked, so they can be heard again.
@export var one_time: bool = false
## REV 475: the topic leaves the menu while this GameState condition is true (e.g. "Show me once
## more" once Spock has bowled for McCoy). "" = never hidden this way.
@export var hide_condition: String = ""
## REV 475: when valid, called as the topic is chosen to give the lines to play (an Array of
## DialogueLineData) instead of `lines` - for answers that depend on where the player is ("Any
## ideas, Jim?"). Not saved; the hotspot sets it up in code.
var lines_provider: Callable = Callable()
