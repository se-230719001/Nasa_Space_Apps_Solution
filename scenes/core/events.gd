extends Node
## Autoload "Events": the contract between gameplay code and the audio layer.
##
## Gameplay/UI code only EMITS these ("this happened"); it never plays sounds.
## The audio layer (scenes/audio/) only LISTENS and decides what to play.
## So the two sides never edit each other's files.
##
## Rules (see CLAUDE.md): append-only. Add new signals at the bottom with a
## one-line comment; never rename, remove or change the arguments of one that
## exists, because the other side may already depend on it.

## The player moved to a different part of the game (&"outpost", &"explore").
signal screen_changed(screen: StringName)
## Any HUD button was pressed. `id` is the button's node name (e.g. &"BuildButton").
signal button_pressed(id: StringName)
## The build confirmation popup opened / closed without building.
signal build_popup_opened(module_id: StringName)
signal build_cancelled(module_id: StringName)
## A module was confirmed and is being placed in the world.
signal build_confirmed(module_id: StringName)
## A resource value changed by `delta` percentage points (&"power", &"water", ...).
signal resource_changed(resource: StringName, delta: float)
## A checklist task was completed.
signal task_completed(task_id: StringName)
## The mascot started a new message. `kind` is &"info", &"warning" or &"success".
signal mascot_said(kind: StringName)
## The mascot typed another letter or two of its message (typewriter beat).
signal mascot_typed
