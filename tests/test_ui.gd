extends SceneTree

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
    var nav_count := 0
    for node in _descendants(main):
        if node is Button and node.custom_minimum_size.y >= 44:
            nav_count += 1
    check(nav_count >= 8, "touch sized buttons")
    for page in ["characters", "gacha", "shop", "collection", "help", "rooms"]:
        main._change_page(page)
        await process_frame
        check(main.body.get_child_count() > 0, page + " renders")
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
