class_name SoundBoard
extends Node
## The game's sound (the artist's DLC 1 pack, mixed as their guide says:
## docs/art/DLC1/README_Audio.md). It only listens: to the night's events, tick by tick
## (Night.stepped), and to what changed since the last tick for what has no event (a basket
## dropped, an item picked up, a step). One player per sound, with its bus, volume, voices,
## cooldown and pitch variation; the frying and fire loops shared, louder with two or more; the
## theme in a loop, ducked under announcements and jingles. Muting is kept on this browser.

const DIR := "res://art/sounds/%s.wav"
const MUSIC := preload("res://art/sounds/MainTheme.mp3")
const MUSIC_DB := -6.0
## The buses (the guide's §3): each under SFX but Music.
const BUSES: Array[StringName] = [&"Music", &"SFX", &"SFX_Alert", &"SFX_Stinger", &"SFX_Feedback", &"SFX_Action",
        &"SFX_Loops"]
## The guide's §7 table: name -> [bus, volume_db, voices, cooldown ms, pitch ±].
const TABLE := {
    &"afsca_arrive": [&"SFX_Alert", -8.0, 2, 0, 0.0], &"can_impact": [&"SFX_Alert", -2.0, 2, 0, 0.03],
    &"can_warning": [&"SFX_Alert", -8.0, 2, 0, 0.0], &"event_announce": [&"SFX_Alert", -8.5, 1, 0, 0.0],
    &"fire_ignite": [&"SFX_Alert", -4.0, 2, 150, 0.03], &"fridge_blackout": [&"SFX_Alert", -7.0, 2, 0, 0.0],
    &"gauge_warning": [&"SFX_Alert", -10.0, 3, 200, 0.0], &"halftime_horn": [&"SFX_Alert", -6.0, 2, 0, 0.0],
    &"heart_lost": [&"SFX_Alert", -6.0, 1, 0, 0.0], &"player_stun": [&"SFX_Alert", -4.0, 2, 0, 0.0],
    &"sdf_arrive": [&"SFX_Alert", -5.5, 2, 0, 0.0],
    &"closing_bell": [&"SFX_Stinger", -6.5, 1, 0, 0.0], &"day_start": [&"SFX_Stinger", -7.5, 1, 0, 0.0],
    &"day_win": [&"SFX_Stinger", -5.5, 1, 0, 0.0], &"game_over": [&"SFX_Stinger", -8.5, 1, 0, 0.0],
    &"medal": [&"SFX_Stinger", -5.5, 1, 0, 0.0], &"star_earned": [&"SFX_Stinger", -5.0, 1, 0, 0.0],
    &"beer_give": [&"SFX_Feedback", -11.0, 3, 100, 0.03], &"burp": [&"SFX_Feedback", -13.0, 3, 0, 0.0],
    &"can_bounce": [&"SFX_Feedback", -6.5, 3, 0, 0.0], &"can_throw": [&"SFX_Feedback", -10.0, 3, 0, 0.0],
    &"cook_ready": [&"SFX_Feedback", -8.0, 3, 0, 0.0], &"customer_angry": [&"SFX_Feedback", -11.0, 3, 0, 0.0],
    &"customer_arrive": [&"SFX_Feedback", -8.0, 2, 700, 0.02],
    &"customer_sleep": [&"SFX_Feedback", -8.5, 3, 0, 0.0], &"customer_wake": [&"SFX_Feedback", -12.0, 3, 0, 0.0],
    &"drink_gulp": [&"SFX_Feedback", -12.5, 2, 100, 0.03], &"event_fail": [&"SFX_Feedback", -10.5, 3, 0, 0.0],
    &"event_success": [&"SFX_Feedback", -10.0, 3, 0, 0.0],
    &"extinguisher_pickup": [&"SFX_Feedback", -9.5, 3, 0, 0.0],
    &"extinguisher_spray": [&"SFX_Feedback", -12.0, 1, 0, 0.0], &"fat_up": [&"SFX_Feedback", -9.0, 3, 0, 0.0],
    &"fire_out": [&"SFX_Feedback", -6.5, 3, 0, 0.0], &"fire_spread": [&"SFX_Feedback", -9.0, 2, 150, 0.03],
    &"fridge_restore": [&"SFX_Feedback", -9.5, 3, 0, 0.0], &"gauge_alert": [&"SFX_Feedback", -15.5, 3, 150, 0.0],
    &"group_cheer": [&"SFX_Feedback", -6.0, 3, 0, 0.0], &"heart_gain": [&"SFX_Feedback", -10.0, 3, 0, 0.0],
    &"order_served": [&"SFX_Feedback", -8.0, 3, 100, 0.02], &"order_wrong": [&"SFX_Feedback", -13.5, 3, 0, 0.0],
    &"sdf_calmed": [&"SFX_Feedback", -12.0, 3, 0, 0.0], &"slip": [&"SFX_Feedback", -12.0, 3, 0, 0.0],
    &"throw_beer": [&"SFX_Feedback", -9.0, 3, 0, 0.0],
    &"basket_eject": [&"SFX_Action", -17.0, 2, 100, 0.04], &"beer_take": [&"SFX_Action", -14.5, 2, 80, 0.04],
    &"bread_pick": [&"SFX_Action", -15.0, 2, 80, 0.05], &"coke_take": [&"SFX_Action", -13.5, 4, 0, 0.0],
    &"eat_bite": [&"SFX_Action", -14.5, 2, 100, 0.04], &"eat_burnt": [&"SFX_Action", -14.0, 4, 0, 0.0],
    &"fridge_open": [&"SFX_Action", -15.0, 4, 0, 0.0], &"fridge_regen": [&"SFX_Action", -17.0, 1, 500, 0.0],
    &"fry_drop": [&"SFX_Action", -13.5, 4, 0, 0.0], &"item_pick": [&"SFX_Action", -19.0, 2, 60, 0.04],
    &"meat_drop": [&"SFX_Action", -14.0, 4, 0, 0.0], &"order_bubble": [&"SFX_Action", -18.5, 3, 120, 0.04],
    &"sauce_squirt": [&"SFX_Action", -14.5, 2, 100, 0.04], &"score_pop": [&"SFX_Action", -15.5, 4, 0, 0.0],
    &"step_a": [&"SFX_Action", -18.0, 2, 160, 0.04], &"step_b": [&"SFX_Action", -18.0, 2, 160, 0.04],
    &"trash_flap": [&"SFX_Action", -17.5, 4, 0, 0.0], &"ui_click": [&"SFX_Action", -18.5, 2, 40, 0.0],
    &"ui_confirm": [&"SFX_Action", -16.5, 4, 0, 0.0], &"veg_add": [&"SFX_Action", -13.5, 2, 80, 0.05],
    &"fire_loop": [&"SFX_Loops", -20.5, 1, 0, 0.0], &"fry_sizzle_loop": [&"SFX_Loops", -21.5, 1, 0, 0.0],
    &"meat_sizzle_loop": [&"SFX_Loops", -21.0, 1, 0, 0.0],
}
const LOOPS: Array[StringName] = [&"fry_sizzle_loop", &"meat_sizzle_loop", &"fire_loop"]
## How often a fryer's alert or warning beeps while it blinks (ms).
const GAUGE_EVERY := 400

var night: Night
var muted := false:
    set(value):
        muted = value
        AudioServer.set_bus_mute(0, value)
        _save_muted()

var _players := {}
var _last := {}
var _music: AudioStreamPlayer
var _duck: Tween
## The night as it was after the last tick, for what has no event.
var _items: Array = []
var _nodes := PackedInt32Array()
var _frying := []
var _beers := []
var _stages := PackedInt32Array()
var _asleep := {}
var _menus := PackedInt32Array()
var _choices := PackedInt32Array()
var _gauge_next := {}
var _step_left := true
var _closed := false
## Ticks voiced this frame: a guest catching up steps hundreds at once, and stays quiet.
var _frame := -1
var _voiced := 0
const VOICED_PER_FRAME := 4


func _init(p_night: Night) -> void:
    night = p_night
    name = "SoundBoard"
    process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
    ensure_buses()
    for sound: StringName in TABLE:
        var entry: Array = TABLE[sound]
        var player := AudioStreamPlayer.new()
        player.stream = load(DIR % sound)
        player.bus = entry[0]
        player.volume_db = entry[1]
        player.max_polyphony = entry[2]
        add_child(player)
        _players[sound] = player
    _music = AudioStreamPlayer.new()
    _music.stream = MUSIC
    _music.bus = &"Music"
    add_child(_music)
    night.stepped.connect(_on_stepped)
    night.began.connect(_on_began)
    muted = _load_muted()


## The buses of the guide's §3, once: a limiter on Master, Music and SFX under it, the five SFX
## groups under SFX.
static func ensure_buses() -> void:
    if AudioServer.get_bus_index(&"SFX") >= 0:
        return
    if AudioServer.get_bus_effect_count(0) == 0:
        var limiter := AudioEffectHardLimiter.new()
        limiter.ceiling_db = -1.0
        AudioServer.add_bus_effect(0, limiter)
    for bus in BUSES:
        AudioServer.add_bus()
        var index := AudioServer.bus_count - 1
        AudioServer.set_bus_name(index, bus)
        AudioServer.set_bus_send(index, &"Master" if bus in [&"Music", &"SFX"] else &"SFX")
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), MUSIC_DB)


## Plays a sound now or after delay_ms, within its cooldown; extra_db on top of its volume.
func play(sound: StringName, delay_ms := 0, extra_db := 0.0) -> void:
    if delay_ms > 0:
        get_tree().create_timer(delay_ms / 1000.0).timeout.connect(play.bind(sound, 0, extra_db))
        return
    var entry: Array = TABLE[sound]
    var now := Time.get_ticks_msec()
    if now - int(_last.get(sound, -100000)) < entry[3]:
        return
    _last[sound] = now
    var player: AudioStreamPlayer = _players[sound]
    player.volume_db = entry[1] + extra_db
    player.pitch_scale = 1.0 + randf_range(-entry[4], entry[4])
    player.play()


## The sounds for one of the night's events, as [name, delay ms] (the guide's §6).
static func for_event(event: Dictionary) -> Array:
    match event.type:
        &"served", &"boss_served":
            return [[&"order_served", 0]]
        &"refused":
            return [[&"order_wrong", 0]]
        &"angry", &"walk_out":
            return [[&"customer_angry", 0]]
        &"arrival":
            return [[&"customer_arrive", 0], [&"order_bubble", 350]]
        &"beer_thrown":
            return [[&"throw_beer", 0]]
        &"beer_gift":
            return [[&"beer_give", 0]]
        &"asleep":
            return [[&"beer_give", 0], [&"customer_sleep", 400]]
        &"beer_drunk":
            return [[&"drink_gulp", 0]]
        &"revived":
            return [[&"drink_gulp", 0], [&"heart_gain", 300]]
        &"can_thrown":
            return [[&"can_throw", 0], [&"can_warning", 0]]
        &"can_hit":
            return [[&"can_impact", 0], [&"player_stun", 0]]
        &"hurt":
            return [[&"heart_lost", 50]]
        &"fire_started":
            return [[&"fire_ignite", 0]]
        &"fire_spread":
            return [[&"fire_spread", 0]]
        &"fire_out":
            return [[&"fire_out", 0]]
        &"spraying":
            return [[&"extinguisher_spray", 0]]
        &"trashed":
            return [[&"trash_flap", 0]]
        &"points":
            return [[&"score_pop", 120]]
        &"fridge_fixed":
            return [[&"fridge_restore", 0]]
        &"boss_arrived":
            return [[&"event_announce", 0], [&"sdf_arrive", 1200]]
        &"boss_drank":
            return [[&"sdf_calmed", 0]]
        &"inspection_over":
            return [[&"event_success" if event.passed else &"event_fail", 0]]
        &"group_left":
            return [[&"event_success", 300], [&"group_cheer", 600]] if event.served else [[&"event_fail", 0]]
        &"slipped":
            return [[&"slip", 0]]
        &"shot":
            return [[&"can_throw", 0]]
        &"car_crash":
            return [[&"can_impact", 0], [&"can_bounce", 300]]
        &"tutorial_step":
            return [[&"ui_confirm", 0]]
        &"night_event":
            var then: Dictionary = {NightEvents.AFSCA: &"afsca_arrive", NightEvents.AFSCA_SURPRISE: &"afsca_arrive",
                    NightEvents.DIABLES_ROUGES: &"halftime_horn"}
            var sounds := [[&"event_announce", 0]]
            if event.kind == NightEvents.PANNE_FRIGO:
                sounds.append([&"fridge_blackout", 0])
            elif then.has(event.kind):
                sounds.append([then[event.kind], 1300])
            return sounds
    return []


func _on_began() -> void:
    _forget()
    _closed = false
    if not _music.playing:
        _music.volume_db = -40.0
        _music.play()
        create_tween().tween_property(_music, "volume_db", 0.0, 1.0)
    if not night.in_lobby:
        play(&"day_start")
        _duck_music(-10.0, 1.2)


func _on_stepped(events: Array[Dictionary]) -> void:
    var sim := night.simulation
    if Engine.get_process_frames() != _frame:
        _frame = Engine.get_process_frames()
        _voiced = 0
    _voiced += 1
    if _voiced > VOICED_PER_FRAME:
        _remember(sim)
        return
    for event in events:
        for sound: Array in for_event(event):
            play(sound[0], sound[1])
        match event.type:
            &"night_event", &"boss_arrived":
                _duck_music(-6.0, 1.5)
            &"fattened":
                _eaten(event.slot)
            &"night_over":
                _night_over(sim)
    if _items.size() != sim.players.size() or _frying.size() != sim.stations.size():
        _remember(sim)
        return
    _compare(sim)
    _remember(sim)


## What changed since the last tick, with no event of its own.
func _compare(sim: Simulation) -> void:
    var steps := 0
    for slot in sim.players.size():
        var player := sim.players[slot]
        var was: Array = _items[slot]
        var item := player.item
        if player.node != _nodes[slot]:
            steps += 1
        if was[0] == &"" and item:
            _picked(sim, player, item)
        elif item and was[0] == item.kind:
            if was[1] == &"" and item.sauce != &"":
                play(&"sauce_squirt")
            if not was[2] and item.veg:
                play(&"veg_add")
        if player.menu != _menus[slot]:
            if player.menu != SimLevel.NONE:
                play(&"fridge_open" if sim.stations[player.menu].kind == &"frigo" else &"ui_click")
        elif player.menu != SimLevel.NONE and player.menu_choice != _choices[slot]:
            play(&"ui_click")
        var stage := sim.rules.fat_stage(player.bmi)
        if stage > _stages[slot]:
            play(&"fat_up", 500)
    # Steps quieter with more players, and every other one at four (the guide's §5.5).
    for step in steps:
        _step_left = not _step_left
        if sim.players.size() < 4 or _step_left:
            play(&"step_a" if _step_left else &"step_b", 0, -3.0 * maxi(sim.players.size() - 2, 0))
    var counts := {&"fry_sizzle_loop": 0, &"meat_sizzle_loop": 0, &"fire_loop": 0}
    var now := Time.get_ticks_msec()
    for index in sim.stations.size():
        var station := sim.stations[index]
        if station.frying and not _frying[index]:
            play(&"meat_drop" if station.kind == &"cuisson_viande" else &"fry_drop")
        if station.frying and station.basket:
            counts[&"meat_sizzle_loop" if station.kind == &"cuisson_viande" else &"fry_sizzle_loop"] += 1
            var window := Fryer.window(station)
            if station.cook == window.x:
                play(&"cook_ready")
            var alert := CookingBubble.alert_for(station.cook, window)
            if alert != CookingBubble.Alert.NONE and now >= int(_gauge_next.get(index, 0)):
                _gauge_next[index] = now + GAUGE_EVERY
                play(&"gauge_warning" if alert == CookingBubble.Alert.WARNING else &"gauge_alert")
        if station.burning:
            counts[&"fire_loop"] += 1
        if station.kind == &"frigo" and _total(station) > _beers[index]:
            play(&"fridge_regen")
    for loop: StringName in LOOPS:
        _set_loop(loop, counts[loop])
    for customer in sim.crowd.line:
        if _asleep.has(customer.id) and customer.asleep == 0:
            play(&"customer_wake")
    if not _closed and sim.night_tick() >= sim.rules.night_ticks and not night.in_lobby:
        _closed = true
        play(&"closing_bell")
        _duck_music(-10.0, 3.0)


## Something came into a player's hand.
func _picked(sim: Simulation, player: SimPlayer, item: SimItem) -> void:
    var at := sim.level.node_stations[player.node] if not player.is_moving() else SimLevel.NONE
    var kind := sim.stations[at].kind if at != SimLevel.NONE else &""
    if item.kind == Simulation.EXTINGUISHER:
        play(&"extinguisher_pickup")
    elif item.kind in Menu.BEERS:
        play(&"beer_take", 120)
    elif item.kind in Menu.DRINKS:
        play(&"coke_take", 120)
    elif item.kind in Menu.BREADS:
        play(&"bread_pick")
    elif kind in Simulation.FRYERS:
        play(&"basket_eject")
        play(&"item_pick", 80)
    else:
        play(&"item_pick")


## A player ate or drank (fattened): a bite, a burnt bite, or a gulp and maybe a burp.
func _eaten(slot: int) -> void:
    if slot >= _items.size():
        return
    var was: StringName = _items[slot][0]
    if was in Menu.DRINKS:
        play(&"drink_gulp")
        if was in Menu.BEERS and randi() % 3 == 0:
            play(&"burp", 400)
    elif String(was).contains("brul"):
        play(&"eat_burnt")
    else:
        play(&"eat_bite")


func _night_over(sim: Simulation) -> void:
    _set_loops_off()
    if sim.outcome != &"won":
        play(&"game_over")
        _duck_music(-10.0, 2.0)
        return
    play(&"day_win")
    var earned := Hud.stars(sim).count(true) if not sim.rules.score_attack else 0
    for star in earned:
        play(&"star_earned", 900 + 500 * star)
    if sim.rules.score_attack and Hud.medal(sim) != "":
        play(&"medal", 1400)
    _duck_music(-10.0, 3.0)


func _set_loop(loop: StringName, active: int) -> void:
    var player: AudioStreamPlayer = _players[loop]
    if active == 0:
        if player.playing:
            player.stop()
        return
    player.volume_db = TABLE[loop][1] + (2.0 if active >= 2 else 0.0)
    if not player.playing:
        player.play()


func _set_loops_off() -> void:
    for loop in LOOPS:
        _set_loop(loop, 0)


## Music lower for a while (an announcement, a jingle), then back.
func _duck_music(amount: float, hold: float) -> void:
    var bus := AudioServer.get_bus_index(&"Music")
    if _duck:
        _duck.kill()
    _duck = create_tween()
    var set_volume := func(volume: float) -> void: AudioServer.set_bus_volume_db(bus, volume)
    _duck.tween_method(set_volume, AudioServer.get_bus_volume_db(bus), MUSIC_DB + amount, 0.1)
    _duck.tween_interval(hold)
    _duck.tween_method(set_volume, MUSIC_DB + amount, MUSIC_DB, 0.8)


func _remember(sim: Simulation) -> void:
    _items.clear()
    _nodes.clear()
    _stages.clear()
    _menus.clear()
    _choices.clear()
    for player in sim.players:
        var item := player.item
        _items.append([item.kind if item else &"", item.sauce if item else &"", item.veg if item else false])
        _nodes.append(player.node)
        _stages.append(sim.rules.fat_stage(player.bmi))
        _menus.append(player.menu)
        _choices.append(player.menu_choice)
    _frying.clear()
    _beers.clear()
    for station in sim.stations:
        _frying.append(station.frying)
        _beers.append(_total(station))
    _asleep.clear()
    for customer in sim.crowd.line:
        if customer.asleep > 0:
            _asleep[customer.id] = true


## A new night: nothing to compare with yet, nothing left sizzling.
func _forget() -> void:
    _items.clear()
    _frying.clear()
    _set_loops_off()


func _load_muted() -> bool:
    var config := ConfigFile.new()
    if night.looks_path == "" or config.load(night.looks_path) != OK:
        return false
    return bool(config.get_value("settings", "muted", false))


func _save_muted() -> void:
    if not night or night.looks_path == "":
        return
    var config := ConfigFile.new()
    config.load(night.looks_path)
    config.set_value("settings", "muted", muted)
    config.save(night.looks_path)


## All the drinks left in a FRIGO.
static func _total(station: SimStation) -> int:
    var total := 0
    for count: int in station.stock.values():
        total += count
    return total
