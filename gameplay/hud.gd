class_name Hud
extends CanvasLayer
## The night's clock and room mood (top right), and the end-of-night banner.
## Online, a client also shows when its night no longer matches the host's.

## How long a notice (e.g. "replay saved") stays on screen, in seconds.
const NOTICE_TIME := 4.0
## Seconds without a tick from the host before a client says so.
const SILENCE_WARNING := 2.0
## How long an announcement stays, in seconds, and the size of a star on the banner.
const ANNOUNCE_TIME := 3.5
const STAR_SIZE := 64

@export var night: Night

var _status: Label
## The room mood, as the artist's bar (bottom right).
var _mood: MoodBar
## Red warning once this client has drifted from the host.
var _desync: Label
var _notice: Label
var _notice_left := 0.0
## A big announcement in the dialogue frame, e.g. the boss walking in.
var _announce: PanelContainer
var _announce_text: Label
var _announce_left := 0.0
## The logo over the lobby, until someone takes a step.
var _logo: TextureRect
## Centered notebook shown once the night is over.
var _banner: PanelContainer
var _title: Label
var _stars: HBoxContainer
## Rich text: players show as a block of their colour.
var _recap: RichTextLabel
## The clock and warnings: hidden in the lobby.
var _corner: VBoxContainer
var _next: Label


func _ready() -> void:
    var corner := VBoxContainer.new()
    _corner = corner
    corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
    corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    corner.alignment = BoxContainer.ALIGNMENT_END
    add_child(corner)
    # The clock on the artist's frame: its face on the left, the time on the dark part.
    var clock_frame := ArtUi.panel(ArtUi.frame("Time", Vector4(80, 20, 20, 20), 10))
    clock_frame.get_theme_stylebox("panel").content_margin_left = 84
    clock_frame.size_flags_horizontal = Control.SIZE_SHRINK_END
    corner.add_child(clock_frame)
    _status = _label(30, clock_frame)
    _desync = _label(24, corner)
    _desync.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _desync.add_theme_color_override("font_color", Color(1, 0.3, 0.25))
    _notice = _label(20, corner)
    _notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _mood = MoodBar.new()
    _mood.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
    _mood.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    _mood.grow_vertical = Control.GROW_DIRECTION_BEGIN
    add_child(_mood)
    night.notice.connect(_show_notice)
    night.announced.connect(_show_announcement)
    night.began.connect(_on_began)
    _announce = ArtUi.panel(ArtUi.frame("FrameTextInfo", Vector4(100, 20, 20, 20), 16))
    _announce.get_theme_stylebox("panel").content_margin_left = 110
    _announce.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
    _announce.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _announce.custom_minimum_size = Vector2(360, 120)
    _announce.visible = false
    add_child(_announce)
    _announce_text = _label(34, _announce)
    _announce_text.add_theme_color_override("font_color", ArtUi.INK)
    _announce_text.remove_theme_constant_override("outline_size")
    _logo = ArtUi.picture(load("res://art/logo/Logo.png"), 0)
    # In the corner, clear of the stations.
    _logo.custom_minimum_size = Vector2(300, 186)
    _logo.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
    _logo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    _logo.visible = false
    add_child(_logo)
    _banner = ArtUi.panel(ArtUi.notebook())
    add_child(_banner)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    _banner.add_child(column)
    _title = _ink_label(40, column)
    _stars = HBoxContainer.new()
    _stars.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_child(_stars)
    for index in 3:
        _stars.add_child(ArtUi.picture(ArtUi.texture("StarEmpty"), STAR_SIZE))
    _recap = RichTextLabel.new()
    _recap.bbcode_enabled = true
    _recap.fit_content = true
    _recap.autowrap_mode = TextServer.AUTOWRAP_OFF
    _recap.add_theme_font_size_override("normal_font_size", 22)
    _recap.add_theme_color_override("default_color", ArtUi.INK)
    column.add_child(_recap)
    _next = _ink_label(28, column)


func _process(delta: float) -> void:
    var sim := night.simulation
    if not sim:
        return
    _corner.visible = not night.in_lobby
    _mood.visible = not night.in_lobby
    if _logo.visible and _anyone_moving():
        _logo.visible = false
    _set_text(_status, clock(sim.clock_minutes()) \
            + (" · fermé" if sim.tick >= sim.rules.night_ticks and sim.outcome == &"" else ""))
    _mood.mood = float(sim.crowd.mood) / sim.rules.riot
    var warnings := PackedStringArray()
    if sim.outcome == &"":
        warnings.append(silence_text(night.host_silence()))
    warnings.append(desync_text(night.desyncs))
    _set_text(_desync, "\n".join(warnings).strip_edges())
    _notice_left = maxf(_notice_left - delta, 0.0)
    _notice.visible = _notice_left > 0.0
    _announce_left = maxf(_announce_left - delta, 0.0)
    _announce.visible = _announce_left > 0.0
    _banner.visible = sim.outcome != &""
    if _banner.visible:
        var next := "Entrée : retour à la salle"
        if night.role == Night.Role.HOST:
            next = "Entrée : tout le monde en salle"
        elif night.role == Night.Role.CLIENT:
            next = "En attente de l'hôte..."
        next += "\nF3 : télécharger le replay"
        _set_text(_title, title(sim))
        _show_stars(stars(sim))
        var recap_text := "[center]%s[/center]" % recap(sim)
        if _recap.text != recap_text:
            _recap.text = recap_text
        _set_text(_next, next)
        # Recentre once the panel has taken the size of its text.
        _banner.reset_size()
        _banner.position = (_banner.get_viewport_rect().size - _banner.size) / 2


## The end-of-night stars (docs/ART_PLAN.md): held until closing; the room still in the green
## (under half the riot); every order of the boss served. A lost night has none.
static func stars(sim: Simulation) -> Array[bool]:
    if sim.outcome != &"won":
        return [false, false, false]
    var boss_orders := sim.rules.boss_orders
    return [true, sim.crowd.mood * 2 < sim.rules.riot,
            boss_orders > 0 and sim.stats.boss_came and sim.stats.boss_served == boss_orders]


func _show_stars(earned: Array[bool]) -> void:
    for index in earned.size():
        var star: TextureRect = _stars.get_child(index)
        var picture := ArtUi.texture("Star" if earned[index] else "StarEmpty")
        if star.texture != picture:
            star.texture = picture


func _show_announcement(text: String) -> void:
    _announce_text.text = text
    _announce_left = ANNOUNCE_TIME


func _on_began() -> void:
    _logo.visible = night.in_lobby


func _anyone_moving() -> bool:
    for slot in night.local_slots():
        if night.simulation.players[slot].is_moving():
            return true
    return false


func _ink_label(size: int, parent: Node) -> Label:
    var label := _label(size, parent)
    label.add_theme_color_override("font_color", ArtUi.INK)
    label.remove_theme_constant_override("outline_size")
    return label


## Empty while in sync. Points at F3, so the tester can send the night that went wrong.
static func desync_text(desyncs: int) -> String:
    if desyncs == 0:
        return ""
    return "Désynchro avec l'hôte (%d) · F3 : replay" % desyncs


## Empty unless the host has been silent for a while during a night.
static func silence_text(seconds: float) -> String:
    if seconds < SILENCE_WARNING:
        return ""
    return "L'hôte ne répond plus (%d s)" % int(seconds)


func _show_notice(text: String) -> void:
    _notice.text = text
    _notice_left = NOTICE_TIME


static func title(sim: Simulation) -> String:
    match sim.outcome_reason:
        &"closing":
            return "Fermeture ! Vous avez tenu la nuit."
        &"crew_down":
            return "Toute l'équipe est K.O. à %s." % clock(sim.clock_minutes())
    return "Émeute ! La nuit s'arrête à %s." % clock(sim.clock_minutes())


## The end-of-night fun stats (GDD §4).
static func recap(sim: Simulation) -> String:
    var stats := sim.stats
    var lines := ["Clients servis : %d · Repartis furieux : %d · Partis sans rien : %d" \
            % [stats.served, stats.angry, stats.walk_outs],
            "Bières offertes : %d · Canettes reçues : %d · Incendies : %d" \
            % [stats.beers, stats.cans_hit, stats.fires]]
    if stats.boss_came:
        lines.append("Commandes du boss servies : %d sur %d" % [stats.boss_served, sim.rules.boss_orders])
    if sim.players.size() > 1:
        var players := []
        for slot in sim.players.size():
            players.append("%s  %d bousculades, %d K.O., %d relevés" % [swatch(sim.players[slot].color),
                    stats.bumps[slot], stats.knockouts[slot], stats.revives[slot]])
        lines.append_array(players)
        var most: int = stats.knockouts.max()
        if most > 0:
            lines.append("Le plus souvent au tapis : %s" % swatch(sim.players[stats.knockouts.find(most)].color))
    return "\n".join(lines)


## A player as a small block of their colour, in BBCode (no glyph needed, see Icons).
static func swatch(color: int) -> String:
    return "[bgcolor=#%s]%s[/bgcolor]" % [Looks.tint(color).to_html(false), " ".repeat(4)]


## "HH:MM" for minutes since 18:00.
static func clock(minutes: int) -> String:
    return "%02d:%02d" % [(18 + minutes / 60) % 24, minutes % 60]


## Only when it changes: each change relayouts the label.
func _set_text(label: Label, text: String) -> void:
    if label.text != text:
        label.text = text


func _label(size: int, parent: Node = self) -> Label:
    var label := Label.new()
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_constant_override("outline_size", 8)
    label.add_theme_color_override("font_outline_color", Color.BLACK)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    parent.add_child(label)
    return label
