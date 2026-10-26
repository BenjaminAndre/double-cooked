extends GutTest
## One finger on a phone (GDD §9.4): swipes, taps, holds and double taps become commands.

const C := Simulation.Command
const HEIGHT := 1000.0

var touch: TouchInput


func before_each() -> void:
    touch = TouchInput.new()


func test_a_swipe_is_a_step_that_way() -> void:
    _down(Vector2(500, 500), 0)
    assert_eq(_drag(Vector2(500 + _swipe(), 510), 50), [C.MOVE_RIGHT])
    assert_eq(_drag(Vector2(500 + _swipe(), 510 - _swipe()), 80), [C.MOVE_UP], "a second swipe from there")
    assert_eq(_drag(Vector2(500 + _swipe(), 510 - _swipe() * 1.5), 90), [], "not yet a whole swipe further")
    assert_eq(_up(Vector2(500, 500), 100), [], "lifting after a swipe does nothing")


func test_holding_after_a_swipe_keeps_walking_while_the_path_is_short() -> void:
    _down(Vector2(500, 500), 0)
    _drag(Vector2(500, 500 + _swipe()), 50)
    assert_eq(touch.update(50 + TouchInput.WALK_REPEAT_MSEC), [C.MOVE_DOWN])
    touch.context.path = 3
    assert_eq(touch.update(50 + 3 * TouchInput.WALK_REPEAT_MSEC), [], "steps still queued: wait")
    _up(Vector2(500, 500 + _swipe()), 500)
    touch.context.path = 0
    assert_eq(touch.update(800), [], "the finger is up")


func test_a_tap_interacts_at_once() -> void:
    _down(Vector2(300, 300), 0)
    assert_eq(_up(Vector2(302, 301), 80), [C.INTERACT, C.RELEASE])


func test_holding_still_presses_interact_until_the_finger_lifts() -> void:
    _down(Vector2(300, 300), 0)
    assert_eq(touch.update(TouchInput.HOLD_MSEC - 1), [])
    assert_eq(touch.update(TouchInput.HOLD_MSEC), [C.INTERACT], "aiming starts")
    assert_eq(_drag(Vector2(300 - _swipe(), 300), 500), [C.MOVE_LEFT], "another target")
    assert_eq(touch.update(900), [], "no walking while aiming")
    assert_eq(_up(Vector2(300, 300), 1000), [C.RELEASE], "thrown")


func test_holding_in_a_menu_closes_it() -> void:
    touch.context.menu = true
    _down(Vector2(300, 300), 0)
    assert_eq(touch.update(TouchInput.HOLD_MSEC), [C.CANCEL])
    assert_eq(_up(Vector2(300, 300), 600), [])


func test_holding_something_edible_a_tap_waits_for_a_second_one() -> void:
    touch.context.edible = true
    _down(Vector2(300, 300), 0)
    assert_eq(_up(Vector2(300, 300), 60), [], "it may be a double tap")
    assert_eq(touch.update(60 + TouchInput.DOUBLE_TAP_MSEC), [C.INTERACT, C.RELEASE], "it wasn't")
    _down(Vector2(300, 300), 1000)
    _up(Vector2(300, 300), 1050)
    _down(Vector2(300, 300), 1120)
    assert_eq(_up(Vector2(300, 300), 1170), [C.EAT])
    assert_eq(touch.update(2000), [], "the first tap was part of it")


func test_only_the_first_finger_counts() -> void:
    _down(Vector2(300, 300), 0)
    var second := InputEventScreenTouch.new()
    second.index = 1
    second.pressed = true
    second.position = Vector2(800, 300)
    assert_eq(touch.read(second, 10, HEIGHT), [])
    assert_eq(_up(Vector2(300, 300), 60), [C.INTERACT, C.RELEASE])


func _swipe() -> float:
    return TouchInput.SWIPE * HEIGHT + 1


func _down(at: Vector2, now: int) -> Array[int]:
    var event := InputEventScreenTouch.new()
    event.pressed = true
    event.position = at
    return touch.read(event, now, HEIGHT)


func _up(at: Vector2, now: int) -> Array[int]:
    var event := InputEventScreenTouch.new()
    event.pressed = false
    event.position = at
    return touch.read(event, now, HEIGHT)


func _drag(at: Vector2, now: int) -> Array[int]:
    var event := InputEventScreenDrag.new()
    event.position = at
    return touch.read(event, now, HEIGHT)


func test_in_a_menu_one_swipe_moves_the_selection_by_one() -> void:
    touch.context.menu = true
    _down(Vector2(500, 500), 0)
    assert_eq(_drag(Vector2(500 + _swipe(), 500), 50), [C.MOVE_RIGHT])
    assert_eq(_drag(Vector2(500 + 3 * _swipe(), 500), 80), [], "the finger lifts before the next")
    assert_eq(touch.update(1000), [], "and holding doesn't repeat")
    _up(Vector2(500 + 3 * _swipe(), 500), 1100)
    _down(Vector2(500, 500), 1200)
    assert_eq(_drag(Vector2(500, 500 + _swipe()), 1250), [C.MOVE_DOWN])
