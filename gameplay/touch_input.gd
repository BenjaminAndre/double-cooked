class_name TouchInput
extends RefCounted
## One finger on a phone (GDD §9.4), turned into the same Simulation commands as the keys:
## - a swipe is one step that way; held at the end of the swipe, the player keeps walking; in a
##   station menu, one swipe moves the selection by one, whatever the finger does next;
## - a tap is interact (a press and a release at once);
## - holding still presses interact until the finger lifts: aiming a beer or the gun (swiping
##   meanwhile changes the target), or, with a station menu open, closing it;
## - a double tap eats or drinks. Only while holding something edible does a tap wait
##   DOUBLE_TAP_MSEC for a second one; otherwise it acts at once.
## Only the first finger counts. Times are in milliseconds, given by the caller (tests).

const C := Simulation.Command
## A swipe: this far, as a share of the screen's height.
const SWIPE := 0.10
## Holding still this long is a hold, not a tap.
const HOLD_MSEC := 350
const DOUBLE_TAP_MSEC := 180
## Walking on while the finger stays down after a swipe: one more step this often, at most.
const WALK_REPEAT_MSEC := 110

## What the player is doing, to read gestures the right way: "menu" (a station menu is open),
## "edible" (holding something to eat or drink), "path" (steps still queued).
var context := {"menu": false, "edible": false, "path": 0}

var _down := false
var _finger := -1
var _anchor := Vector2.ZERO
var _since := 0
var _moved := false
var _holding := false
var _walk := -1
var _walk_next := 0
## A tap waiting to see if a second one follows, -1 if none.
var _tap_at := -1


## The commands for a touch event (InputEventScreenTouch / InputEventScreenDrag); screen_height
## sets how far a swipe is.
func read(event: InputEvent, now: int, screen_height: float) -> Array[int]:
    var commands: Array[int] = []
    var touch := event as InputEventScreenTouch
    if touch:
        if touch.pressed and not _down:
            _down = true
            _finger = touch.index
            _anchor = touch.position
            _since = now
            _moved = false
            _holding = false
            _walk = -1
        elif not touch.pressed and _down and touch.index == _finger:
            _down = false
            if _holding:
                if not context.menu:
                    commands.append(C.RELEASE)
            elif not _moved:
                commands.append_array(_tap(now))
        return commands
    var drag := event as InputEventScreenDrag
    # In a menu, one option per swipe: the finger lifts before the next.
    if drag and _down and drag.index == _finger and not (context.menu and _moved):
        var delta := drag.position - _anchor
        if delta.length() >= SWIPE * screen_height:
            var direction: int
            if absf(delta.x) > absf(delta.y):
                direction = C.MOVE_RIGHT if delta.x > 0 else C.MOVE_LEFT
            else:
                direction = C.MOVE_DOWN if delta.y > 0 else C.MOVE_UP
            commands.append(direction)
            _anchor = drag.position
            _moved = true
            _walk = direction
            _walk_next = now + WALK_REPEAT_MSEC
    return commands


## The commands that come with time: a hold, walking on, a lone tap once no second one came.
func update(now: int) -> Array[int]:
    var commands: Array[int] = []
    if _tap_at >= 0 and now - _tap_at >= DOUBLE_TAP_MSEC:
        _tap_at = -1
        commands.append_array([C.INTERACT, C.RELEASE])
    if not _down:
        return commands
    if not _moved and not _holding and now - _since >= HOLD_MSEC:
        _holding = true
        commands.append(C.CANCEL if context.menu else C.INTERACT)
    elif _moved and not _holding and not context.menu and _walk >= 0 and now >= _walk_next \
            and context.path <= 1:
        commands.append(_walk)
        _walk_next = now + WALK_REPEAT_MSEC
    return commands


func _tap(now: int) -> Array[int]:
    if _tap_at >= 0:
        _tap_at = -1
        return [C.EAT]
    if context.edible and not context.menu:
        _tap_at = now
        return []
    return [C.INTERACT, C.RELEASE]
