class_name PetPortrait
extends Control

var identity_id := "pet_gold_0":
    set(value):
        identity_id = value
        queue_redraw()

func _init() -> void:
    custom_minimum_size = Vector2(64, 64)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
    var info := GameData.identity_info(identity_id)
    if info.is_empty():
        return
    var origin := (size - Vector2(64, 64)) / 2.0
    var base: Color = GameData.SYSTEM_COLORS[GameData.SYSTEMS.find(info["system"])]
    var outline := Color("565062")
    var shade := base.darkened(0.2)
    var light := base.lightened(0.45)
    _pixel(origin, 2, 2, 60, 60, base.lightened(0.67))
    _pixel(origin, 7, 48, 50, 8, base.lightened(0.53))
    if info["category"] == "pet":
        match info["index"]:
            0:
                _pixel(origin, 9, 9, 16, 24, outline)
                _pixel(origin, 39, 9, 16, 24, outline)
                _pixel(origin, 13, 12, 8, 18, light)
                _pixel(origin, 43, 12, 8, 18, light)
            1:
                _pixel(origin, 6, 22, 14, 24, outline)
                _pixel(origin, 44, 22, 14, 24, outline)
                _pixel(origin, 10, 26, 8, 16, shade)
                _pixel(origin, 46, 26, 8, 16, shade)
            2:
                _pixel(origin, 13, 4, 12, 29, outline)
                _pixel(origin, 39, 4, 12, 29, outline)
                _pixel(origin, 16, 7, 6, 21, Color("ffbed0"))
                _pixel(origin, 42, 7, 6, 21, Color("ffbed0"))
        _pixel(origin, 8, 22, 48, 32, outline)
        _pixel(origin, 11, 25, 42, 26, base)
        _pixel(origin, 15, 27, 34, 8, light)
        _pixel(origin, 18, 36, 6, 7, outline)
        _pixel(origin, 40, 36, 6, 7, outline)
        _pixel(origin, 20, 37, 2, 2, Color.WHITE)
        _pixel(origin, 42, 37, 2, 2, Color.WHITE)
        _pixel(origin, 30, 42, 4, 3, Color("d37585"))
        _pixel(origin, 14, 44, 5, 3, Color("f3a0aa"))
        _pixel(origin, 45, 44, 5, 3, Color("f3a0aa"))
    else:
        _pixel(origin, 13, 9, 38, 43, outline)
        _pixel(origin, 16, 16, 32, 27, Color("f7dac1"))
        _pixel(origin, 13, 10, 38, 12, shade)
        _pixel(origin, 18, 7, 28, 8, shade)
        _pixel(origin, 9, 44, 46, 11, base)
        _pixel(origin, 16, 31, 5, 5, outline)
        _pixel(origin, 43, 31, 5, 5, outline)
        _pixel(origin, 20, 32, 2, 2, Color.WHITE)
        _pixel(origin, 45, 32, 2, 2, Color.WHITE)
        _pixel(origin, 28, 40, 8, 2, Color("b46775"))
        _pixel(origin, 29, 46, 6, 6, Color("f7e4a2"))
    var accent: Color = [Color("f6d774"), Color("c1a8ee"), Color("f3a6c5")][info["index"]]
    _pixel(origin, 46, 8, 10, 10, outline)
    _pixel(origin, 48, 10, 6, 6, accent)

func _pixel(origin: Vector2, x: int, y: int, w: int, h: int, color: Color) -> void:
    draw_rect(Rect2(origin + Vector2(x, y), Vector2(w, h)), color)
