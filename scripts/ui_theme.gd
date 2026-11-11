class_name UITheme
extends RefCounted
## Centralized visual style: palette, fonts and reusable style boxes.
## Purely presentational; no gameplay values live here.

const FONT_PATH := "res://assets/fonts/Nunito.ttf"

const BG_TOP := Color("fff3e3")
const BG_BOTTOM := Color("fde4ee")
const INK := Color("4a3f5c")
const INK_SOFT := Color("7a6d8a")
const SURFACE := Color("fffdfa")
const ACCENT := Color("e9718d")
const ACCENT_SOFT := Color("fde1e8")
const TITLE := Color("c2577a")
const SHADOW := Color(0.45, 0.25, 0.4, 0.14)
const NAV_IDLE := Color("a99bb8")

const PEACH := Color("ffc9a3")
const SKY := Color("bcd9f7")
const LILAC := Color("e4d8f5")
const PINK := Color("f7bfd2")
const BUTTER := Color("ffe08a")
const MINT := Color("c4ead2")

static var _fonts := {}

static func font(weight: int = 700) -> Font:
    if _fonts.has(weight):
        return _fonts[weight]
    var base: FontFile = load(FONT_PATH)
    var variation := FontVariation.new()
    variation.base_font = base
    variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
    _fonts[weight] = variation
    return variation

static func box(color: Color, radius: int = 18, border: Color = Color.TRANSPARENT, border_width: int = 0, shadow: bool = false) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    style.anti_aliasing = true
    if border_width > 0:
        style.border_color = border
        style.set_border_width_all(border_width)
    if shadow:
        style.shadow_color = SHADOW
        style.shadow_size = 8
        style.shadow_offset = Vector2(0, 3)
    return style

## Chunky "candy" button: a darker bottom lip that collapses when pressed.
static func candy(color: Color, state: String = "normal", radius: int = 14) -> StyleBoxFlat:
    var face := color
    var lip := 4
    if state == "hover":
        face = color.lightened(0.1)
    elif state == "pressed":
        face = color.darkened(0.06)
        lip = 1
    elif state == "disabled":
        face = Color("e6e0e8")
    var style := box(face, radius)
    style.border_color = (color if state != "disabled" else face).darkened(0.18)
    style.border_width_bottom = lip
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 8 + (4 - lip)
    style.content_margin_bottom = 8
    return style

static func build() -> Theme:
    var theme := Theme.new()
    theme.default_font = font(700)
    theme.default_font_size = 15
    theme.set_color("font_color", "Label", INK)
    var scroll := box(Color(0, 0, 0, 0), 4)
    scroll.content_margin_left = 3
    scroll.content_margin_right = 3
    theme.set_stylebox("scroll", "VScrollBar", scroll)
    var grabber := box(Color(0.55, 0.4, 0.6, 0.35), 4)
    grabber.content_margin_left = 3
    grabber.content_margin_right = 3
    theme.set_stylebox("grabber", "VScrollBar", grabber)
    theme.set_stylebox("grabber_highlight", "VScrollBar", grabber)
    theme.set_stylebox("grabber_pressed", "VScrollBar", grabber)
    var popup := box(SURFACE, 16, LILAC, 2, true)
    theme.set_stylebox("panel", "PopupMenu", popup)
    theme.set_color("font_color", "PopupMenu", INK)
    theme.set_color("font_hover_color", "PopupMenu", INK)
    theme.set_stylebox("hover", "PopupMenu", box(ACCENT_SOFT, 10))
    theme.set_font_size("font_size", "PopupMenu", 15)
    theme.set_constant("v_separation", "PopupMenu", 10)
    return theme

static func background_texture() -> GradientTexture2D:
    var gradient := Gradient.new()
    gradient.set_color(0, BG_TOP)
    gradient.set_color(1, BG_BOTTOM)
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.fill_from = Vector2(0, 0)
    texture.fill_to = Vector2(0, 1)
    texture.width = 8
    texture.height = 256
    return texture
