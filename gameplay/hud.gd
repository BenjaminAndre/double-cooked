class_name Hud
extends CanvasLayer
## The night's clock and room mood (top right), and the end-of-night banner.
## Online, a client also shows when its night no longer matches the host's.

## How long a notice (e.g. "replay saved") stays on screen, in seconds.
const NOTICE_TIME := 4.0

@export var night: Night

var _status: Label
## The room mood, as a dial.
var _gauge: MoodGauge
## Red warning once this client has drifted from the host.
var _desync: Label
var _notice: Label
var _notice_left := 0.0
## Centered panel shown once the night is over.
var _banner: PanelContainer
var _title: Label
var _recap: Label
var _next: Label


func _ready() -> void:
    var corner := VBoxContainer.new()
    corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
    corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    corner.alignment = BoxContainer.ALIGNMENT_END
    add_child(corner)
    _status = _label(24, corner)
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _gauge = MoodGauge.new()
    _gauge.size_flags_horizontal = Control.SIZE_SHRINK_END
    corner.add_child(_gauge)
    _desync = _label(24, corner)
    _desync.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _desync.add_theme_color_override("font_color", Color(1, 0.3, 0.25))
    _notice = _label(20, corner)
    _notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    night.notice.connect(_show_notice)
    _banner = PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0.75)
    style.set_content_margin_all(24)
    style.set_corner_radius_all(8)
    _banner.add_theme_stylebox_override("panel", style)
    add_child(_banner)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 16)
    _banner.add_child(column)
    _title = _label(40, column)
    _recap = _label(22, column)
    _next = _label(28, column)


func _process(delta: float) -> void:
    var sim := night.simulation
    if not sim:
        return
    _set_text(_status, clock(sim.clock_minutes()) \
            + (" · fermé" if sim.tick >= sim.rules.night_ticks and sim.outcome == &"" else ""))
    _gauge.mood = float(sim.crowd.mood) / sim.rules.riot
    _set_text(_desync, desync_text(night.desyncs))
    _notice_left = maxf(_notice_left - delta, 0.0)
    _notice.visible = _notice_left > 0.0
    _banner.visible = sim.outcome != &""
    if _banner.visible:
        var next := "Entrée : nouvelle nuit"
        if night.role == Night.Role.HOST:
            next = "Entrée ou L : relancer la nuit"
        elif night.role == Night.Role.CLIENT:
            next = "En attente de l'hôte..."
        next += "\nF3 : télécharger le replay"
        _set_text(_title, title(sim))
        _set_text(_recap, recap(sim))
        _set_text(_next, next)
        # Recentre once the panel has taken the size of its text.
        _banner.reset_size()
        _banner.position = (_banner.get_viewport_rect().size - _banner.size) / 2


## Empty while in sync. Points at F3, so the tester can send the night that went wrong.
static func desync_text(desyncs: int) -> String:
    if desyncs == 0:
        return ""
    return "Désynchro avec l'hôte (%d) · F3 : replay" % desyncs


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
    if sim.players.size() > 1:
        var players := []
        for slot in sim.players.size():
            players.append("P%d : %d bousculades, %d K.O., %d relevés" \
                    % [slot + 1, stats.bumps[slot], stats.knockouts[slot], stats.revives[slot]])
        lines.append_array(players)
        var most: int = stats.knockouts.max()
        if most > 0:
            lines.append("Le plus souvent au tapis : P%d" % (stats.knockouts.find(most) + 1))
    return "\n".join(lines)


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
