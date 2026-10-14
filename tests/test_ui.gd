extends SceneTree

const UI = preload("res://scripts/ui_text.gd")

var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("UI FAIL: " + message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    main.game = GameState.new_game()
    main._render()
    await process_frame
    await process_frame
    check(ProjectSettings.get_setting("display/window/size/viewport_width") == 432 and ProjectSettings.get_setting("display/window/size/viewport_height") == 768, "portrait project viewport")
    check(root.size.x >= 360 and root.size.y >= 640 and root.size.y > root.size.x, "portrait runtime layout")
    check(main.body.get_child_count() >= 2, "rooms populated")
    var font: Font = main.get_theme_default_font()
    check(font != null, "default UI font exists")
    if font != null:
        var missing := {}
        var displayed_texts: Array = UI.VI.values()
        displayed_texts.append_array(GameData.SYSTEM_NAMES)
        for names in GameData.PET_NAMES:
            displayed_texts.append_array(names)
        for names in GameData.EMPLOYEE_NAMES:
            displayed_texts.append_array(names)
        for translated in displayed_texts:
            for index in translated.length():
                var codepoint: int = translated.unicode_at(index)
                if codepoint >= 0x00c0 and codepoint <= 0x1eff and not font.has_char(codepoint):
                    missing[String.chr(codepoint)] = true
        check(missing.is_empty(), "Vietnamese glyph coverage: " + str(missing.keys()))
    var nav_count := 0
    for node in _descendants(main):
        if node is Button and node.custom_minimum_size.y >= 44:
            nav_count += 1
    check(nav_count >= 8, "touch sized buttons")
    # canvas_items keeps the 432px logical canvas while scaling it to phone pixels.
    var viewport_size: Vector2 = main.size
    var overflow := []
    var button_overflow := []
    var titles := {"characters": "characters.title", "gacha": "gacha.title", "shop": "shop.title",
        "collection": "collection.title", "help": "help.title", "rooms": "rooms.title"}
    for page in ["characters", "gacha", "shop", "collection", "help", "rooms"]:
        main._change_page(page)
        await process_frame
        check(main.body.get_child_count() > 0, page + " renders")
        check(_has_text(main.body, UI.t(titles[page]).split(" · ")[0]), page + " Vietnamese title")
        for node in _descendants(main):
            if node is Control and node.visible and node != main.overlay and node.get_global_rect().size.x > 0:
                var rect: Rect2 = node.get_global_rect()
                if rect.position.x < -1.0 or rect.end.x > viewport_size.x + 1.0:
                    overflow.append("%s: %s %s" % [page, node.name, rect])
                if node is Button:
                    var button: Button = node
                    var button_font := button.get_theme_font("font")
                    var button_size := button.get_theme_font_size("font_size")
                    var text_width := button_font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button_size).x
                    if text_width > button.size.x - 24.0 + 1.0:
                        button_overflow.append("%s: %s (%.1f > %.1f)" % [page, button.text, text_width, button.size.x - 24.0])
    check(overflow.is_empty(), "horizontal overflow at %s: %s" % [viewport_size, overflow.slice(0, 5)])
    check(button_overflow.is_empty(), "button text clipping: " + str(button_overflow.slice(0, 5)))
    check(main.game.assign(-1, "pet", "") == UI.t("error.invalid_room_role"), "assignment error translated")
    check(main.game.draw("vip_pet", 1)["error"] == UI.t("error.insufficient_resource", [UI.system_name("crystal")]), "gacha error translated")
    check(main.game.buy_book("pet", "gold")["error"] == UI.t("error.insufficient_resource", [UI.system_name("gold")]), "shop error translated")
    main._choose_character(0, "pet")
    check(main.overlay.visible and main.overlay.get_child_count() > 0, "assignment dialog opens")
    main._close_overlay()
    check(not main.overlay.visible, "assignment dialog closes")
    print("UI TESTS: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _descendants(node: Node) -> Array:
    var result := []
    for child in node.get_children():
        result.append(child)
        result.append_array(_descendants(child))
    return result

func _has_text(node: Node, expected: String) -> bool:
    for child in _descendants(node):
        if child is Label and child.text.begins_with(expected):
            return true
    return false
