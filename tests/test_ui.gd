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
    check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "tall portrait screens use expanded canvas")
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
    var pet_id: String = main.game.add_character("pet_crystal_0", 0)
    var employee_id: String = main.game.add_character("employee_gold_0", 0)
    main._change_page("characters")
    await process_frame
    check(main.character_tabs.visible and main.character_tabs.get_parent() != main.content_scroll, "character tabs stay outside scroll")
    check(main.character_tabs.get_global_rect().end.y <= main.content_scroll.get_global_rect().position.y + 1.0, "tabs remain above scrolling list")
    check(main._character_ids("pet").has(pet_id) and not main._character_ids("pet").has(employee_id), "pet category filter")
    check(_has_text_containing(main.body, GameData.identity_info(main.game.characters[pet_id]["identity"])["name"]), "pet card rendered")
    check(_has_text_containing(main.body, "◆ " + UI.system_name("crystal")), "pet card shows resource icon and name")
    check(_has_text(main.body, UI.t("category.pet")), "pet tab content rendered")
    main._select_character_category("employee")
    await process_frame
    check(main._character_ids("employee") == [employee_id], "employee category filter")
    check(_has_text_containing(main.body, GameData.identity_info(main.game.characters[employee_id]["identity"])["name"]), "employee card rendered immediately")
    check(_has_text_containing(main.body, "✦ " + UI.system_name("gold")), "employee card shows resource icon and name")
    check(not _has_text_containing(main.body, GameData.identity_info(main.game.characters[pet_id]["identity"])["name"]), "employee tab excludes pets")
    main.game.characters.erase(employee_id)
    main._render()
    await process_frame
    check(_has_text(main.body, UI.t("characters.empty_employee")), "empty employee state")
    check(main.content_scroll.scroll_deadzone >= 10, "main touch scroll deadzone")
    var all_scrolls := []
    for node in _descendants(main):
        if node is ScrollContainer:
            all_scrolls.append(node)
    check(all_scrolls.size() == 1, "single page scroll container")
    for node in _descendants(main.body):
        if node is Button:
            check(node.mouse_filter == Control.MOUSE_FILTER_PASS and node.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE, "card button passes swipes and activates on release")
            break
    main._choose_character(0, "pet")
    check(main.overlay.visible and main.overlay.get_child_count() > 0, "assignment dialog opens")
    await process_frame
    var popup_scrolls := []
    for node in _descendants(main.overlay):
        if node is ScrollContainer:
            popup_scrolls.append(node)
    check(popup_scrolls.size() == 1 and popup_scrolls[0].scroll_deadzone >= 10, "popup touch scroll deadzone")
    check(_has_text_containing(main.overlay, "◆ " + UI.system_name("crystal")), "selection dialog shows resource name and icon")
    check(not _has_text_containing(main.overlay, GameData.EMPLOYEE_NAMES[0][0]), "pet selection excludes employees")
    main._close_overlay()
    check(not main.overlay.visible, "assignment dialog closes")
    main.game.add_character("employee_gold_0", 0)
    main._choose_character(0, "employee")
    await process_frame
    check(_has_text_containing(main.overlay, "✦ " + UI.system_name("gold")), "employee selection shows resource name and icon")
    check(not _has_text_containing(main.overlay, GameData.identity_info(main.game.characters[pet_id]["identity"])["name"]), "employee selection excludes pets")
    main._close_overlay()
    main._show_character(pet_id)
    await process_frame
    check(_has_text_containing(main.overlay, "◆ " + UI.system_name("crystal")), "character detail shows resource name and icon")
    main._close_overlay()
    main._change_page("gacha")
    await process_frame
    check(_has_text_containing(main.body, UI.t("gacha.systems", [main._system_label("gold")])), "gacha banners describe available systems")
    main._change_page("characters")
    main.game.add_character("pet_crystal_0", 0)
    main._merge_prompt(pet_id)
    await process_frame
    check(_has_text_containing(main.overlay, "◆ " + UI.system_name("crystal")), "merge dialog shows resource name and icon")
    main._close_overlay()
    main.game.balances["gold"] = 1000.0
    main._pull_gacha("normal_pet", 1)
    await process_frame
    check(_has_text_containing(main.overlay, UI.t("category.pet") + " · "), "gacha result shows category")
    var result_has_system := false
    for system in GameData.SYSTEMS:
        result_has_system = result_has_system or _has_text_containing(main.overlay, main._system_label(system))
    check(result_has_system, "gacha result shows resource name and icon")
    var popup_overflow := []
    for node in _descendants(main.overlay):
        if node is Control and node.visible and node.get_global_rect().size.x > 0:
            var rect: Rect2 = node.get_global_rect()
            if rect.position.x < -1.0 or rect.end.x > viewport_size.x + 1.0:
                popup_overflow.append("%s %s" % [node.name, rect])
    check(popup_overflow.is_empty(), "portrait popup horizontal bounds: " + str(popup_overflow))
    main._close_overlay()
    var producing_pet: String = main.game.add_character("pet_gold_0", 3)
    check(main.game.assign(0, "pet", producing_pet) == "" and main.game.equip_collection(producing_pet, "crystal") == "", "UI fixture produces two resources")
    main._change_page("rooms")
    await process_frame
    check(_has_text_containing(main.body, "✦ " + UI.system_name("gold")) and _has_text_containing(main.body, "◆ " + UI.system_name("crystal")), "room lists both output resources")
    for index in 24:
        main.game.add_character("pet_gold_0", 0)
    main._change_page("characters")
    main._select_character_category("pet")
    await process_frame
    await process_frame
    var card_button: Button = null
    for node in _descendants(main.body):
        if node is Button:
            card_button = node
            break
    if card_button != null:
        var start := card_button.get_global_rect().get_center()
        var received_drag := [false]
        main.content_scroll.gui_input.connect(func(event):
            if event is InputEventScreenDrag:
                received_drag[0] = true)
        var press := InputEventScreenTouch.new()
        press.index = 0
        press.position = start
        press.pressed = true
        root.push_input(press)
        await process_frame
        var previous := start
        for step in 6:
            var drag := InputEventScreenDrag.new()
            drag.index = 0
            drag.position = start + Vector2(0, -20 * (step + 1))
            drag.relative = drag.position - previous
            previous = drag.position
            root.push_input(drag)
            await process_frame
        var release := InputEventScreenTouch.new()
        release.index = 0
        release.position = previous
        release.pressed = false
        root.push_input(release)
        await process_frame
        check(received_drag[0], "touch drag over card button reaches scroll container")
        check(not main.overlay.visible, "swipe over card button does not tap")
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

func _has_text_containing(node: Node, expected: String) -> bool:
    for child in _descendants(node):
        if (child is Label or child is Button) and child.text.contains(expected):
            return true
    return false
