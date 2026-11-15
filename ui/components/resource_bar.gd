@tool
class_name ResourceBar
extends HBoxContainer
## Compact HUD resource meter: icon + label + bar. Status is shown by color AND a
## status icon, so it never relies on color alone (style guide §13.2).

enum Status { HEALTHY, WARNING, CRITICAL }

const STATUS_ICONS := {
	Status.WARNING: preload("res://assets/sprites/icons/warning.png"),
	Status.CRITICAL: preload("res://assets/sprites/icons/critical.png"),
}

@export var resource_name := "Power":
	set(v):
		resource_name = v
		_refresh()
@export var icon: Texture2D:
	set(v):
		icon = v
		_refresh()
@export_range(0, 100) var value := 70.0:
	set(v):
		value = clampf(v, 0.0, 100.0)
		_refresh()
@export var status := Status.HEALTHY:
	set(v):
		status = v
		_refresh()
## Theme variation used while healthy (water is cyan, the rest are green).
@export var healthy_variation := &"BarHealthy":
	set(v):
		healthy_variation = v
		_refresh()
## Text shown next to the name. Empty = show the value as a percentage.
@export var display_text := "":
	set(v):
		display_text = v
		_refresh()

@onready var _icon: TextureRect = %Icon
@onready var _label: Label = %Name
@onready var _bar: ProgressBar = %Bar
@onready var _status_icon: TextureRect = %StatusIcon
@onready var _value_label: Label = %Value


func _ready() -> void:
	_refresh()


## Animates the bar to a new value (style guide §10.4: don't change silently).
func animate_to(new_value: float, new_status: Status, duration := 0.6) -> void:
	status = new_status
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "value", new_value, duration)


func _refresh() -> void:
	if not is_node_ready():
		return
	_icon.texture = icon
	_label.text = resource_name
	_bar.value = value
	match status:
		Status.HEALTHY:
			_bar.theme_type_variation = healthy_variation
		Status.WARNING:
			_bar.theme_type_variation = &"BarWarning"
		Status.CRITICAL:
			_bar.theme_type_variation = &"BarCritical"
	_status_icon.texture = STATUS_ICONS.get(status)
	_status_icon.visible = status != Status.HEALTHY
	var shown := display_text if not display_text.is_empty() else "%d%%" % roundi(value)
	_value_label.text = shown
	tooltip_text = "%s: %s" % [resource_name, shown]
