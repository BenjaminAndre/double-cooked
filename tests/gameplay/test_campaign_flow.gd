extends GutTest
## A campaign played through the real game scene (GDD §4.2): a night held leads to the next,
## a lost one ends the campaign, keeps the record and goes back to the lobby.

const GAME_SCENE := preload("res://game.tscn")
const RECORD_PATH := "user://test_campaign.cfg"

var night: Night


func before_each() -> void:
    DirAccess.remove_absolute(RECORD_PATH)
    var game := GAME_SCENE.instantiate()
    night = game.get_node("Night")
    night.looks_path = RECORD_PATH
    add_child_autofree(game)


func after_each() -> void:
    DirAccess.remove_absolute(RECORD_PATH)


func test_a_night_held_leads_to_the_next_one() -> void:
    night.play_local(1, 1)
    assert_eq(night.campaign_night, 1)
    assert_eq(night.simulation.rules.menu, Campaign.menu_for(1))
    night.simulation._end(&"won", &"closing")
    night.continue_after_night()
    assert_false(night.in_lobby)
    assert_eq(night.campaign_night, 2)
    assert_eq(night.simulation.rules.night_number, 2)
    assert_eq(night.simulation.rules.menu, Campaign.menu_for(2))


func test_a_lost_night_keeps_the_record_and_goes_back_to_the_lobby() -> void:
    night.play_local(1, 3)
    var sim := night.simulation
    sim.crowd.mood = sim.rules.riot
    await wait_until(func() -> bool: return sim.outcome == &"lost", 2.0)
    await wait_process_frames(1)
    assert_true(night.new_record)
    assert_eq(night.campaign_record().night, 3)
    assert_eq(night.campaign_record().colors, [sim.players[0].color])
    night.continue_after_night()
    assert_true(night.in_lobby)
    assert_eq(night.campaign_night, 0)
    # A shorter campaign doesn't beat it.
    night.play_local(1, 2)
    night.simulation.crowd.mood = night.simulation.rules.riot
    await wait_until(func() -> bool: return night.simulation.outcome == &"lost", 2.0)
    assert_false(night.new_record)
    assert_eq(night.campaign_record().night, 3)


func test_a_single_night_goes_back_to_the_lobby_even_when_held() -> void:
    night.play_local(1)
    assert_eq(night.campaign_night, 0)
    assert_eq(night.simulation.rules.menu, Menu.FULL_MENU)
    night.simulation._end(&"won", &"closing")
    night.continue_after_night()
    assert_true(night.in_lobby)
