class_name CustomersView
extends Node3D
## Shows the line of customers in front of the counter. This node's position is the front of
## the line; the first places follow line_points (inside, along the counter, then the door, in
## the artist's scene), the rest queue up along line_step from the last one. Customers cross the
## front wall only through the door. The first SimRules.visible_orders customers
## show a ticket with their order and patience (GDD §6.2).

## The customers, as paper cut-outs; which one comes follows the customer id, so every peer
## sees the same.
const CUSTOMERS := "res://art/textures/Character%02d.png"
const CUSTOMER_KINDS := 5
## The boss: the drunk baraki, or a drunk Santa every other night (the artist's variant).
const BOSS_PICTURES: Array[Texture2D] = [preload("res://art/textures/DrunkCharacter01.png"),
        preload("res://art/textures/DrunkCharacter02.png")]
## Now and then, people drinking their own beer on the pavement, just for the atmosphere: for
## DRINKERS_EVERY ticks at a time, some of EventCharacter07 to 09, or nobody.
const DRINKERS_EVERY := 40 * Simulation.TICK_RATE
const DRINKERS_AT := Vector3(-1.0, 0, 2.3)
## The colleagues (NightEvents.COLLEGUES): their leader queues, the others wait outside with a
## can, around COLLEAGUES_AT (relative to this node).
const LEADER := "res://art/textures/EventCharacter01.png"
const COLLEAGUE := "res://art/textures/EventCharacter%02d.png"
const COLLEAGUES_AT := Vector3(2.5, 0, -3.4)
## Over a customer put to sleep by one beer too many (GDD §6.2): the artist's Zzz, bobbing.
const ASLEEP := preload("res://art/textures/EtatZzzz.png")
const ASLEEP_HEIGHT := 1.75
## How fast customers walk to their place in line, as a fraction of the distance per second.
const SHUFFLE_SPEED := 8.0
## How fast they walk round to the door, in metres per second.
const WALK_SPEED := 3.0
## Tickets are drawn on screen under their customer (clear of the counter), and pushed apart so
## they never overlap.
const TICKET_GAP_BELOW := 6.0
const TICKET_GAP := 8.0
## Order pictures, in pixels: bigger for the customer at the counter; a sauce is smaller.
const FRONT_ICON := 44
const BACK_ICON := 34
const SAUCE_SCALE := 0.75
const BAR_SIZE := Vector2(80, 14)
## The boss: the drunk baraki, the same size as everyone (the artist's rule), on a red ticket with
## a dot per order (SimCrowd.Result: to come, served, missed).
const BOSS_TICKET := Color(1.0, 0.55, 0.5)
## A refused dish flashes the ticket in this colour.
const REFUSED := Color(1.0, 0.35, 0.3)
## The points popping up: size, how far they rise, for how long.
const POINTS_SIZE := 64
const POINTS_RISE := 60.0
const POINTS_TIME := 1.2
const DOT_SIZE := 14
const DOT_COLORS := [Color.BLACK, Color(0.3, 0.85, 0.35), Color(0.95, 0.2, 0.15)]

@export var night: Night
@export var line_step := Vector3(-0.45, 0, 0)
## The first places in line, from the front (0, 0, 0), relative to this node; empty: a straight
## line along line_step. The first inside_places of them are inside, behind the front wall.
@export var line_points := PackedVector3Array()
@export var inside_places := 0
## The doorway, for whoever crosses the front wall; INF: there is no wall to go round.
@export var door := Vector3.INF
## Where customers come from and go to, relative to the front of the line.
@export var entrance := Vector3(-6, 0, 0)
@export var exit := Vector3(2.5, 0, -1)

## Customer id -> its figure.
var _figures := {}
var _leaving: Array[Node3D] = []
var _tickets: Array[PanelContainer] = []
## The boss's drink, on a ticket of its own.
var _drink_ticket: PanelContainer
var _layer: CanvasLayer
## The colleagues waiting outside, while their leader is in line.
var _colleagues: Array[Node3D] = []
var _drinkers: Array[Node3D] = []


func _ready() -> void:
    night.began.connect(clear)
    night.points_scored.connect(pop_points)
    _layer = CanvasLayer.new()
    add_child(_layer)


func _process(delta: float) -> void:
    if not night.simulation:
        return
    var crowd := night.simulation.crowd
    var present := {}
    for index in crowd.line.size():
        var customer := crowd.line[index]
        present[customer.id] = true
        if not _figures.has(customer.id):
            _figures[customer.id] = _new_figure(customer)
        var figure: Node3D = _figures[customer.id]
        _walk(figure, place(index), index < inside_places, delta)
        _show_asleep(figure, customer.asleep > 0)
    for id in _figures.keys():
        if not present.has(id):
            _leaving.append(_figures[id])
            _figures.erase(id)
    for figure in _leaving.duplicate():
        _walk(figure, exit, false, delta, true)
        if figure.position.is_equal_approx(exit):
            _leaving.erase(figure)
            figure.queue_free()
    _show_colleagues(crowd.line.any(func(customer: SimCrowd.Customer) -> bool: return customer.group))
    _show_drinkers(night.simulation.tick if not night.in_lobby else -1)
    _show_tickets(crowd)


func _show_asleep(figure: Node3D, asleep: bool) -> void:
    var zzz := figure.get_node_or_null("Zzz") as Sprite3D
    if asleep and not zzz:
        zzz = Sprite3D.new()
        zzz.name = "Zzz"
        zzz.texture = ASLEEP
        zzz.pixel_size = 0.5 / ASLEEP.get_width()
        zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        zzz.no_depth_test = true
        zzz.position.y = ASLEEP_HEIGHT
        figure.add_child(zzz)
    if zzz:
        zzz.visible = asleep
        zzz.position.y = ASLEEP_HEIGHT + sin(Time.get_ticks_msec() * 0.004) * 0.05


## Where the customer at this place in line stands, relative to this node.
func place(index: int) -> Vector3:
    if line_points.is_empty():
        return line_step * index
    if index < line_points.size():
        return line_points[index]
    return line_points[-1] + line_step * (index - line_points.size() + 1)


## Takes a figure towards target (shuffling up, or steady when leaving), round by the door when
## it is on the other side of the front wall: inside tells which side target is.
func _walk(figure: Node3D, target: Vector3, inside: bool, delta: float, steady := false) -> void:
    var from := figure.position
    _step(figure, target, inside, delta, steady)
    if figure is PaperFigure:
        (figure as PaperFigure).face(figure.position - from, get_viewport().get_camera_3d())


func _step(figure: Node3D, target: Vector3, inside: bool, delta: float, steady: bool) -> void:
    if door != Vector3.INF and figure.get_meta(&"inside", false) != inside:
        figure.position = figure.position.move_toward(door, WALK_SPEED * delta)
        if figure.position.distance_to(door) < 0.05:
            figure.set_meta(&"inside", inside)
        return
    if steady:
        figure.position = figure.position.move_toward(target, WALK_SPEED * delta)
    else:
        figure.position = figure.position.lerp(target, minf(1.0, SHUFFLE_SPEED * delta))


## Points scored at the Nuit unique: the artist's "+n" rising from the till and fading.
func pop_points(points: int) -> void:
    var camera := get_viewport().get_camera_3d()
    var path := "res://art/textures/UX_Score%d.png" % points
    if not camera or not ResourceLoader.exists(path):
        return
    var pop := ArtUi.picture(load(path), POINTS_SIZE)
    _layer.add_child(pop)
    var over_till := camera.unproject_position(global_position + Vector3.UP * PaperFigure.HEIGHT)
    pop.position = over_till - pop.custom_minimum_size / 2
    var tween := pop.create_tween().set_parallel()
    tween.tween_property(pop, "position:y", pop.position.y - POINTS_RISE, POINTS_TIME)
    tween.tween_property(pop, "modulate:a", 0.0, POINTS_TIME).set_delay(POINTS_TIME / 2)
    tween.chain().tween_callback(pop.queue_free)


## The customer at the front refused what they were handed: their ticket flashes red.
func flash_refused() -> void:
    if _tickets.is_empty() or not _tickets[0].visible:
        return
    var ticket := _tickets[0]
    ticket.modulate = REFUSED
    ticket.create_tween().tween_property(ticket, "modulate", Color.WHITE, 0.5)


## What is left of the group's order: [the pictures of each kind of line, then for each picture
## how many of that line it starts (0 for its sauce)].
func _group_lines(leader: SimCrowd.Customer) -> Array:
    var keys := []
    var times := []
    for key in leader.orders:
        var at := keys.find(key)
        if at < 0:
            keys.append(key)
            times.append(1)
        else:
            times[at] += 1
    var kinds: Array[StringName] = []
    var counts := []
    for index in keys.size():
        var pictures := ItemIcons.order(keys[index])
        for part in pictures.size():
            kinds.append(pictures[part])
            counts.append(times[index] if part == 0 else 0)
    return [kinds, counts]


## The beer drinkers on the pavement for this tick of the night (-1: none), the same on every
## peer since it only follows the tick.
func _show_drinkers(tick: int) -> void:
    if _drinkers.is_empty():
        for index in 3:
            var drinker := PaperFigure.new(load(COLLEAGUE % (index + 7)))
            drinker.position = DRINKERS_AT + Vector3(index * 0.6, 0, (index % 2) * 0.35)
            drinker.set_mirrored(index != 1)
            add_child(drinker)
            _drinkers.append(drinker)
    var roll := hash(tick / DRINKERS_EVERY) if tick >= 0 else 0
    # One window out of three is empty; otherwise one to three of them.
    var count := 0 if roll % 3 == 0 else 1 + (roll / 3) % 3
    for index in _drinkers.size():
        _drinkers[index].visible = index < count


## The leader's colleagues, standing outside with their cans while he is in line.
func _show_colleagues(shown: bool) -> void:
    if shown and _colleagues.is_empty():
        for index in 5:
            var colleague := PaperFigure.new(load(COLLEAGUE % (index + 2)))
            colleague.position = COLLEAGUES_AT + Vector3((index % 2) * 0.5, 0, -index * 0.45)
            colleague.set_mirrored(index % 2 == 1)
            add_child(colleague)
            _colleagues.append(colleague)
    for colleague in _colleagues:
        colleague.visible = shown


## Forgets every figure, e.g. when a new night starts.
func clear() -> void:
    for figure in _figures.values() + _leaving:
        figure.queue_free()
    _figures.clear()
    _leaving.clear()


## Each ticket sits under its customer on screen; a ticket that would overlap the previous one
## is pushed along the line, so the order of the tickets always matches the line. A ticket
## shows the order (dish, then sauce) and the customer's patience. The boss's ticket also shows
## his three orders as dots, and his drink comes on a ticket of its own right after it.
## Tickets never leave the screen: the row slides left or up by whatever overflows.
func _show_tickets(crowd: SimCrowd) -> void:
    var camera := get_viewport().get_camera_3d()
    var screen := get_viewport().get_visible_rect().size
    var shown := mini(crowd.line.size(), crowd.rules.visible_orders)
    while _tickets.size() < shown:
        _tickets.append(_new_ticket())
    if not _drink_ticket:
        _drink_ticket = _new_ticket()
    var previous_right := -INF
    var lowest := 0.0
    var placed: Array[PanelContainer] = []
    _drink_ticket.visible = false
    for index in _tickets.size():
        var ticket := _tickets[index]
        ticket.visible = index < shown and camera != null
        if not ticket.visible:
            continue
        var customer := crowd.line[index]
        var figure: Node3D = _figures[customer.id]
        var icon_size := FRONT_ICON if index == 0 else BACK_ICON
        var full := crowd.boss_patience() if customer.boss else maxi(customer.full_patience, crowd.rules.patience)
        # The group's leader shows what is left of their order, one picture a line, ×n.
        if customer.group:
            var lines := _group_lines(customer)
            _fill(ticket, lines[0], BACK_ICON, float(customer.patience) / full, false, lines[1])
        else:
            _fill(ticket, ItemIcons.order(customer.order), icon_size, float(customer.patience) / full, customer.boss)
        _show_dots(ticket, customer)
        var anchor := camera.unproject_position(figure.global_position)
        var left := maxf(maxf(anchor.x - ticket.size.x / 2, previous_right + TICKET_GAP), TICKET_GAP)
        ticket.position = Vector2(left, anchor.y + TICKET_GAP_BELOW)
        previous_right = left + ticket.size.x
        lowest = maxf(lowest, ticket.position.y + ticket.size.y)
        placed.append(ticket)
        if customer.boss and customer.drink != &"":
            _drink_ticket.visible = true
            _fill(_drink_ticket, ItemIcons.order(customer.drink), icon_size,
                    float(customer.drink_patience) / crowd.rules.boss_drink_patience, true)
            _drink_ticket.position = Vector2(previous_right + TICKET_GAP, ticket.position.y)
            previous_right += TICKET_GAP + _drink_ticket.size.x
            placed.append(_drink_ticket)
    var overflow := Vector2(maxf(previous_right + TICKET_GAP - screen.x, 0), maxf(lowest + TICKET_GAP - screen.y, 0))
    for ticket in placed:
        ticket.position -= overflow


## The order as the artist's pictures (dish, then sauce), rebuilt only when it changes: each
## change relayouts the ticket. The boss's tickets are tinted red.
func _fill(ticket: PanelContainer, kinds: Array[StringName], icon_size: int, patience: float,
        boss: bool, counts: Array = []) -> void:
    var column := ticket.get_child(0)
    var icons: HBoxContainer = column.get_child(0)
    var shown := [kinds, icon_size, counts]
    if ticket.get_meta(&"order", []) != shown:
        ticket.set_meta(&"order", shown)
        for child in icons.get_children():
            child.free()
        for index in kinds.size():
            var kind := kinds[index]
            # The dish, then its sauce, smaller; several lines (counts) each start with "n×".
            var main: bool = index == 0 if counts.is_empty() else counts[index] > 0
            if not counts.is_empty() and counts[index] > 1:
                var count := Label.new()
                count.text = "%d×" % counts[index]
                count.add_theme_color_override("font_color", ArtUi.INK)
                count.add_theme_font_size_override("font_size", 18)
                icons.add_child(count)
            var side: float = icon_size if main else icon_size * SAUCE_SCALE
            icons.add_child(ArtUi.picture(ItemIcons.picture(kind), side, ItemIcons.tint(kind)))
        ticket.reset_size()
    if ticket.get_meta(&"boss", false) != boss:
        ticket.set_meta(&"boss", boss)
        ticket.self_modulate = BOSS_TICKET if boss else Color.WHITE
    var bar: ArtBar = column.get_child(2)
    bar.show_fraction(patience)


## The boss's orders as dots: black to come, ringed for the current one, green once
## served, red once missed.
func _show_dots(ticket: PanelContainer, customer: SimCrowd.Customer) -> void:
    var dots: HBoxContainer = ticket.get_child(0).get_child(1)
    var state := [Array(customer.results), customer.current()] if customer.boss else []
    if ticket.get_meta(&"dots", []) == state:
        return
    ticket.set_meta(&"dots", state)
    dots.visible = customer.boss
    for child in dots.get_children():
        child.free()
    if not customer.boss:
        ticket.reset_size()
        return
    for index in customer.results.size():
        var dot := Panel.new()
        dot.custom_minimum_size = Vector2.ONE * DOT_SIZE
        var style := StyleBoxFlat.new()
        style.set_corner_radius_all(DOT_SIZE / 2)
        style.bg_color = DOT_COLORS[customer.results[index]]
        if index == customer.current():
            style.set_border_width_all(2)
            style.border_color = ArtUi.INK
        dot.add_theme_stylebox_override("panel", style)
        dots.add_child(dot)
    ticket.reset_size()


func _new_ticket() -> PanelContainer:
    var ticket := ArtUi.panel(ArtUi.order_bubble())
    var column := VBoxContainer.new()
    ticket.add_child(column)
    var icons := HBoxContainer.new()
    icons.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_child(icons)
    var dots := HBoxContainer.new()
    dots.alignment = BoxContainer.ALIGNMENT_CENTER
    dots.visible = false
    column.add_child(dots)
    column.add_child(ArtBar.new(BAR_SIZE.x, BAR_SIZE.y))
    _layer.add_child(ticket)
    return ticket


func _new_figure(customer: SimCrowd.Customer) -> Node3D:
    var picture: Texture2D = load(CUSTOMERS % (customer.id % CUSTOMER_KINDS + 1))
    if customer.boss:
        picture = BOSS_PICTURES[customer.id % BOSS_PICTURES.size()]
    elif customer.group:
        picture = load(LEADER)
    var figure := PaperFigure.new(picture)
    figure.position = entrance
    add_child(figure)
    return figure
