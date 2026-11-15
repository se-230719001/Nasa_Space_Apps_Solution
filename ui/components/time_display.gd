class_name TimeDisplay
extends PanelContainer
## Top-left mission day card: "Day N" plus today's sunlight in plain words.

@onready var _label: Label = %TimeLabel
@onready var _sun: Label = %SunLabel


func show_day(day: int, sun: String) -> void:
	_label.text = "Day %d" % day
	_sun.text = sun
	tooltip_text = "Mission day %d. %s today." % [day, sun]
