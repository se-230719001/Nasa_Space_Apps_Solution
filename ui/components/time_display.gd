class_name TimeDisplay
extends PanelContainer
## Top-left HUD clock. Static for now: nothing advances it. A future game-time
## system only needs to set `seconds` (or call set_time) to drive it.

@export var seconds := 0:
	set(v):
		seconds = maxi(v, 0)
		_refresh()

@onready var _label: Label = %TimeLabel


func _ready() -> void:
	_refresh()


func set_time(total_seconds: int) -> void:
	seconds = total_seconds


func _refresh() -> void:
	if not is_node_ready():
		return
	_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	tooltip_text = "Mission time"
