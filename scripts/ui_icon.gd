class_name UIIcon
extends Control
## Original procedural vector icons (navigation and resource coins).
## Drawn in code so no external or copyrighted art is required.

var kind := "rooms":
    set(value):
        kind = value
        queue_redraw()
var color := Color("e9718d"):
    set(value):
        color = value
        queue_redraw()

func _init() -> void:
    custom_minimum_size = Vector2(26, 26)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
    var s: float = minf(size.x, size.y)
    var c := size / 2.0
    match kind:
        "rooms": _house(c, s)
        "characters": _paw(c, s)
        "gacha": _star(c, s * 0.5, s * 0.22, 5, color)
        "shop": _bag(c, s)
        "collection": _book(c, s)
        "help": _help(c, s)
        _:
            if kind.begins_with("coin:"):
                _coin(c, s, kind.substr(5))

func _house(c: Vector2, s: float) -> void:
    var w := s * 0.72
    var roof := PackedVector2Array([c + Vector2(-w * 0.62, -s * 0.02), c + Vector2(0, -s * 0.44), c + Vector2(w * 0.62, -s * 0.02)])
    draw_colored_polygon(roof, color)
    draw_rect(Rect2(c + Vector2(-w * 0.42, -s * 0.06), Vector2(w * 0.84, s * 0.46)), color)
    draw_rect(Rect2(c + Vector2(-s * 0.09, s * 0.12), Vector2(s * 0.18, s * 0.28)), Color.WHITE)

func _paw(c: Vector2, s: float) -> void:
    draw_circle(c + Vector2(0, s * 0.14), s * 0.24, color)
    draw_circle(c + Vector2(-s * 0.3, -s * 0.06), s * 0.11, color)
    draw_circle(c + Vector2(s * 0.3, -s * 0.06), s * 0.11, color)
    draw_circle(c + Vector2(-s * 0.13, -s * 0.3), s * 0.11, color)
    draw_circle(c + Vector2(s * 0.13, -s * 0.3), s * 0.11, color)

func _star(c: Vector2, outer: float, inner: float, points: int, fill: Color) -> void:
    var poly := PackedVector2Array()
    for i in points * 2:
        var radius := outer if i % 2 == 0 else inner
        var angle := -PI / 2.0 + i * PI / points
        poly.append(c + Vector2(cos(angle), sin(angle)) * radius)
    draw_colored_polygon(poly, fill)

func _bag(c: Vector2, s: float) -> void:
    draw_arc(c + Vector2(0, -s * 0.16), s * 0.17, PI, TAU, 16, color, s * 0.08, true)
    var body := PackedVector2Array([c + Vector2(-s * 0.36, -s * 0.14), c + Vector2(s * 0.36, -s * 0.14),
        c + Vector2(s * 0.42, s * 0.4), c + Vector2(-s * 0.42, s * 0.4)])
    draw_colored_polygon(body, color)
    draw_circle(c + Vector2(0, s * 0.12), s * 0.07, Color.WHITE)

func _book(c: Vector2, s: float) -> void:
    draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.36), Vector2(s * 0.38, s * 0.7)), color)
    draw_rect(Rect2(c + Vector2(s * 0.02, -s * 0.36), Vector2(s * 0.38, s * 0.7)), color.darkened(0.12))
    for i in 3:
        var y := -s * 0.2 + i * s * 0.14
        draw_line(c + Vector2(-s * 0.32, y), c + Vector2(-s * 0.1, y), Color(1, 1, 1, 0.8), maxf(1.0, s * 0.05))
    _star(c + Vector2(s * 0.21, -s * 0.02), s * 0.13, s * 0.06, 5, Color.WHITE)

func _help(c: Vector2, s: float) -> void:
    draw_circle(c, s * 0.44, color)
    var font := UITheme.font(900)
    var size_px := int(s * 0.62)
    var text_size := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
    draw_string(font, c + Vector2(-text_size.x / 2.0, font.get_ascent(size_px) * 0.5 - s * 0.02), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color.WHITE)

func _coin(c: Vector2, s: float, system: String) -> void:
    var index := GameData.SYSTEMS.find(system)
    var base: Color = GameData.SYSTEM_COLORS[index] if index >= 0 else color
    draw_circle(c + Vector2(0, s * 0.05), s * 0.46, base.darkened(0.22))
    draw_circle(c, s * 0.46, base)
    var w := Color.WHITE
    match index:
        0: _star(c, s * 0.27, s * 0.12, 5, w)
        1: draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.28), c + Vector2(s * 0.2, 0), c + Vector2(0, s * 0.28), c + Vector2(-s * 0.2, 0)]), w)
        2:
            for i in 5:
                var angle := -PI / 2.0 + i * TAU / 5.0
                draw_circle(c + Vector2(cos(angle), sin(angle)) * s * 0.14, s * 0.1, w)
            draw_circle(c, s * 0.08, base.lightened(0.4))
        3: _star(c, s * 0.3, s * 0.08, 4, w)
        4:
            for i in 8:
                var angle := i * TAU / 8.0
                draw_line(c, c + Vector2(cos(angle), sin(angle)) * s * 0.27, w, s * 0.1)
            draw_circle(c, s * 0.18, w)
            draw_circle(c, s * 0.08, base)
        5:
            draw_circle(c + Vector2(-s * 0.1, -s * 0.05), s * 0.12, w)
            draw_circle(c + Vector2(s * 0.1, -s * 0.05), s * 0.12, w)
            draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.215, 0), c + Vector2(s * 0.215, 0), c + Vector2(0, s * 0.24)]), w)
