extends GutTest
## The fryers' bubble (CookingBubble): its cursor enters the artist's green band exactly when
## the food is ready, and its alerts come at the end of the green and in the red.

const WINDOW := Vector2i(100, 300)
const FIRE := 500


func test_the_cursor_meets_the_bands_at_the_window() -> void:
    assert_almost_eq(CookingBubble.progress(0, WINDOW, FIRE), 0.0, 0.001)
    assert_almost_eq(CookingBubble.progress(WINDOW.x, WINDOW, FIRE), CookingBubble.READY_FROM, 0.001)
    assert_almost_eq(CookingBubble.progress(WINDOW.y, WINDOW, FIRE), CookingBubble.READY_UNTIL, 0.001)
    assert_almost_eq(CookingBubble.progress(FIRE, WINDOW, FIRE), 1.0, 0.001)
    assert_almost_eq(CookingBubble.progress(FIRE + 50, WINDOW, FIRE), 1.0, 0.001, "never past the end")
    assert_almost_eq(CookingBubble.progress(200, WINDOW, FIRE),
            (CookingBubble.READY_FROM + CookingBubble.READY_UNTIL) / 2, 0.001, "halfway through the green")


func test_the_siren_comes_in_the_last_second_of_green_then_the_warning() -> void:
    assert_eq(CookingBubble.alert_for(WINDOW.x, WINDOW), CookingBubble.Alert.NONE)
    assert_eq(CookingBubble.alert_for(WINDOW.y - Simulation.TICK_RATE - 1, WINDOW), CookingBubble.Alert.NONE)
    assert_eq(CookingBubble.alert_for(WINDOW.y - Simulation.TICK_RATE, WINDOW), CookingBubble.Alert.ALERT)
    assert_eq(CookingBubble.alert_for(WINDOW.y, WINDOW), CookingBubble.Alert.ALERT)
    assert_eq(CookingBubble.alert_for(WINDOW.y + 1, WINDOW), CookingBubble.Alert.WARNING)
