class_name Icons
## Small icons drawn in code, shown on Sprite3Ds. Text glyphs like ▼ or ♥ aren't in Godot's
## default font: they only show where the system has a font for them, so never on the Web
## build. Each icon is drawn once, white, and tinted by the sprite's modulate.

const SIZE := 64
## Drawn at 4 times the size then shrunk, for smooth edges.
const OVERSAMPLE := 4

static var _cache := {}


## A heart, for health.
static func heart() -> Texture2D:
    return _draw_icon(&"heart", func(p: Vector2) -> bool:
        # The classic implicit heart curve, on [-1.2, 1.2] with the point at the bottom.
        var x := p.x * 1.25
        var y := -p.y * 1.25 + 0.25
        return pow(x * x + y * y - 1.0, 3.0) - x * x * y * y * y <= 0.0)


## A triangle pointing down, for the throw target.
static func arrow_down() -> Texture2D:
    return _draw_icon(&"arrow_down", func(p: Vector2) -> bool:
        var y := (p.y + 0.8) / 1.6
        return y >= 0.0 and y <= 1.0 and absf(p.x) <= 0.9 * (1.0 - y))


## A five-pointed star, for a stunned player: the edge runs straight from each tip (radius
## 0.95) to the notch between two tips (radius 0.4).
static func star() -> Texture2D:
    return _draw_icon(&"star", func(p: Vector2) -> bool:
        var sector := TAU / 5
        # 0 at a tip (the first one points up), 1 at a notch.
        var from_tip := absf(fposmod(p.angle() + PI / 2 + sector / 2, sector) - sector / 2) / (sector / 2)
        return p.length() <= lerpf(0.95, 0.4, from_tip))


static func _draw_icon(icon_name: StringName, inside: Callable) -> Texture2D:
    if not _cache.has(icon_name):
        var big := SIZE * OVERSAMPLE
        var image := Image.create(big, big, false, Image.FORMAT_RGBA8)
        for y in big:
            for x in big:
                var p := Vector2(x + 0.5, y + 0.5) / big * 2.0 - Vector2.ONE
                if inside.call(p):
                    image.set_pixel(x, y, Color.WHITE)
        image.resize(SIZE, SIZE, Image.INTERPOLATE_CUBIC)
        _cache[icon_name] = ImageTexture.create_from_image(image)
    return _cache[icon_name]
