extends Resource
class_name HintLineData
## A conditional, state-gated hint (NOT a conversation-count, attempt-count,
## or failure-count unlock — explicitly ruled out project-wide, including by
## the v1.2 master doc's "Implementation Authority — Conversation Hints"
## note). `condition` is a GameState.evaluate_condition() expression. Hints
## are checked in array order each time the owning conversation starts; the
## first whose condition is currently true plays in full. A hint that sets a
## variable normally has its own condition read that same variable, so it
## naturally stops re-firing without needing separate "consumed" state; a
## hint that reflects already-discovered knowledge (e.g. Kirk/Spock's
## post-discovery assistance) is allowed to set nothing at all.

@export var condition: String = ""
## Almost always one line; some hints (e.g. post-discovery assistance) are a
## short two-line exchange, so this is an array rather than a single line.
@export var lines: Array[DialogueLineData] = []
## REV 144: a hint is the character's greeting for the current state, so when
## one matches it REPLACES the conversation's generic opening line (before,
## both played back to back: Spock asked "Have you reached a conclusion?" and
## then answered himself). Set true only for a hint written as a follow-up to
## the opening line, to keep both.
@export var follows_opening: bool = false
