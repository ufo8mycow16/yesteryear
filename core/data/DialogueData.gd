extends Resource
class_name DialogueData
## One conversation (CONV_PRO_xxx).

@export var id: String = ""
@export var opening_line: DialogueLineData
@export var topics: Array[DialogueTopicData] = []
@export var hints: Array[HintLineData] = []
