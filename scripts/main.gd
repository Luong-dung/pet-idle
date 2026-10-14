extends Control

const PortraitScript = preload("res://scripts/portrait.gd")

var game: GameState
var page := "rooms"
var body: VBoxContainer
var balances_panel: GridContainer
var overlay: ColorRect
var status: Label
var timer := 0.0
var autosave_timer := 0.0
const BG := Color("fff8ee")
const INK := Color("414052")
const SOFT := Color("fffdf9")
const ACCENT := Color("ef8f9a")

func _ready() -> void:
    game = GameState.load_game()
    _save()
    get_tree().root.min_size = Vector2i(360, 640)
    _build_shell()
    _render()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
        if game != null:
            _sync_and_save()
    elif what == NOTIFICATION_APPLICATION_RESUMED and game != null:
        game.catch_up(Time.get_unix_time_from_system())
        _save()
        _render()

func _process(delta: float) -> void:
    if game == null:
        return
    timer += delta
    autosave_timer += delta
    if timer >= 1.0:
        game.catch_up(Time.get_unix_time_from_system())
        timer = 0.0
        _render()
    if autosave_timer >= 15.0:
        autosave_timer = 0.0
        _save()

func _style(color: Color, radius: int = 16) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style

func _label(value: String, size: int = 15, color: Color = INK) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _button(value: String, method: String, args: Array = [], color: Color = ACCENT) -> Button:
    var button := Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(0, 44)
    button.add_theme_stylebox_override("normal", _style(color, 12))
    button.add_theme_stylebox_override("hover", _style(color.lightened(0.08), 12))
    button.add_theme_stylebox_override("pressed", _style(color.darkened(0.1), 12))
    button.add_theme_color_override("font_color", INK)
    button.add_theme_color_override("font_hover_color", INK)
    button.add_theme_font_size_override("font_size", 14)
    button.pressed.connect(Callable(self, method).bindv(args))
    return button

func _card(parent: Node, color: Color = SOFT) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _style(color))
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 5)
    panel.add_child(box)
    return box

func _row(parent: Node) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    parent.add_child(row)
    return row

func _portrait(identity_id: String) -> Control:
    var portrait = PortraitScript.new()
    portrait.identity_id = identity_id
    return portrait

func _build_shell() -> void:
    var background := ColorRect.new()
    background.color = BG
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 8)
    add_child(root)
    var header := VBoxContainer.new()
    header.add_theme_constant_override("separation", 3)
    root.add_child(header)
    var title := _label("✿ PET IDLE", 28, Color("b55f78"))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_child(title)
    var title_tween := create_tween().set_loops()
    title_tween.tween_property(title, "modulate:a", 0.72, 1.5)
    title_tween.tween_property(title, "modulate:a", 1.0, 1.5)
    balances_panel = GridContainer.new()
    balances_panel.columns = 2
    header.add_child(balances_panel)
    var nav := GridContainer.new()
    nav.columns = 3
    root.add_child(nav)
    for item in [["Rooms", "rooms"], ["Characters", "characters"], ["Gacha", "gacha"],
            ["Book Shop", "shop"], ["Collection", "collection"], ["Help", "help"]]:
        var button := _button(item[0], "_change_page", [item[1]], Color("e9dfef"))
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        nav.add_child(button)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    root.add_child(scroll)
    body = VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 8)
    scroll.add_child(body)
    status = _label("", 13, Color("a55262"))
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(status)
    overlay = ColorRect.new()
    overlay.color = Color(0.16, 0.13, 0.21, 0.73)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.visible = false
    add_child(overlay)

func _render() -> void:
    if body == null:
        return
    for child in balances_panel.get_children():
        child.queue_free()
    for i in GameData.SYSTEMS.size():
        var system: String = GameData.SYSTEMS[i]
        var item := _label("%s %s  %s" % [GameData.SYSTEM_ICONS[i], GameData.SYSTEM_NAMES[i], _amount(game.balances[system])], 13, GameData.SYSTEM_COLORS[i].darkened(0.35))
        item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        balances_panel.add_child(item)
    for child in body.get_children():
        child.queue_free()
    match page:
        "rooms": _render_rooms()
        "characters": _render_characters()
        "gacha": _render_gacha()
        "shop": _render_shop()
        "collection": _render_collection()
        "help": _render_help()

func _amount(value: float) -> String:
    if value >= 1000000:
        return "%.2fm" % (value / 1000000.0)
    if value >= 10000:
        return "%.1fk" % (value / 1000.0)
    return "%.1f" % value

func _character_name(id: String) -> String:
    if id == "" or not game.characters.has(id):
        return "Empty"
    var character = game.characters[id]
    var info := GameData.identity_info(character["identity"])
    return "%s  [%s]" % [info["name"], GameData.rank_name(character["tier"])]

func _render_rooms() -> void:
    body.add_child(_label("Your little workshop", 21))
    for i in game.rooms.size():
        var room = game.rooms[i]
        var box := _card(body, Color("fce9e4") if i % 2 == 0 else Color("e8f0ed"))
        box.add_child(_label("ROOM %02d" % (i + 1), 18))
        var actors := _row(box)
        if room["pet"] != "":
            actors.add_child(_portrait(game.characters[room["pet"]]["identity"]))
        if room["employee"] != "":
            actors.add_child(_portrait(game.characters[room["employee"]]["identity"]))
        var actor_names := VBoxContainer.new()
        actor_names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        actors.add_child(actor_names)
        actor_names.add_child(_label("Pet: " + _character_name(room["pet"])))
        actor_names.add_child(_label("Helper: " + _character_name(room["employee"])))
        var production_data := game.production(room)
        if not production_data.is_empty():
            var remaining: float = maxf(0.0, production_data["cycle"] - room["progress"])
            box.add_child(_label("+%s %s / %.1fs  •  next in %.1fs" % [_amount(production_data["output"]), production_data["system"], production_data["cycle"], remaining], 13))
            var progress := ProgressBar.new()
            progress.custom_minimum_size.y = 12
            progress.max_value = production_data["cycle"]
            progress.value = room["progress"]
            progress.show_percentage = false
            box.add_child(progress)
        else:
            box.add_child(_label("Assign a pet to start production", 13))
        var row := _row(box)
        row.add_child(_button("Choose pet", "_choose_character", [i, "pet"], Color("f7c8a5")))
        row.add_child(_button("Helper", "_choose_character", [i, "employee"], Color("c5dcf4")))
    body.add_child(_button("Unlock room · %s gold" % _amount(GameData.room_cost(game.rooms.size() + 1)), "_unlock_room", [], Color("f5d98c")))

func _render_characters() -> void:
    body.add_child(_label("Characters · %d owned" % game.characters.size(), 21))
    for id in game.characters:
        var character = game.characters[id]
        var info := GameData.identity_info(character["identity"])
        var color: Color = GameData.SYSTEM_COLORS[GameData.SYSTEMS.find(info["system"])].lightened(0.73)
        var box := _card(body, color)
        var actor_row := _row(box)
        actor_row.add_child(_portrait(character["identity"]))
        var details := VBoxContainer.new()
        details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        actor_row.add_child(details)
        details.add_child(_label("%s %s · %s" % ["Pet" if info["category"] == "pet" else "Helper", info["name"], GameData.rank_name(character["tier"])], 16))
        details.add_child(_label("%s · %d/%d slots · %s" % [GameData.SYSTEM_NAMES[GameData.SYSTEMS.find(info["system"])], character["books"].size() + int(character["foreign"] != ""), GameData.slots(character["tier"]), "Room %d" % (game.room_for(id) + 1) if game.room_for(id) >= 0 else "Unassigned"], 12))
        var row := _row(box)
        row.add_child(_button("Details", "_show_character", [id], Color("c7dbea")))
        if character["tier"] < 26:
            row.add_child(_button("Merge", "_merge_prompt", [id], Color("f2c5d5")))

func _render_gacha() -> void:
    body.add_child(_label("Wish meadow", 21))
    body.add_child(_label("Normal: F 35%, E 28%, D 20%, C 12%, B 5%\nVIP: S 90%, SS 10%\nSubtiers: − 60%, plain 30%, + 10%", 13))
    for banner_id in ["normal_pet", "normal_employee", "vip_pet", "vip_employee"]:
        var banner := GameData.banner(banner_id)
        var box := _card(body, Color("ebe7f6") if banner["currency"] == "crystal" else Color("fff0d7"))
        box.add_child(_label(banner_id.replace("_", " ").capitalize(), 18))
        box.add_child(_label("%s %s per paid pull · 10→11 · 100→111" % [_amount(banner["price"]), banner["currency"]], 13))
        var row := _row(box)
        for paid in [1, 10, 100]:
            var button := _button("×%d" % paid, "_pull_gacha", [banner_id, paid], Color("f7c9a7"))
            button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            row.add_child(button)

func _render_shop() -> void:
    body.add_child(_label("Skill book shop", 21))
    body.add_child(_label("PROVISIONAL: books cost their own system resource. Four identical books grant the full effect. Pet books boost output; helper books boost cooldown reduction.", 13))
    body.add_child(_label("Identical copies in 1/2/3/4 slots: 10% / 30% / 60% / 100% of full effect.", 13))
    for i in GameData.SYSTEMS.size():
        var system: String = GameData.SYSTEMS[i]
        var box := _card(body, GameData.SYSTEM_COLORS[i].lightened(0.72))
        box.add_child(_label(GameData.SYSTEM_NAMES[i] + " · next " + _amount(GameData.book_cost(game.book_purchases[system])), 16))
        var row := _row(box)
        row.add_child(_button("Pet book", "_buy_book", ["pet", system], Color("f7c8a5")))
        row.add_child(_button("Helper book", "_buy_book", ["employee", system], Color("c5dcf4")))
    body.add_child(_label("Owned books: %d" % game.books.size(), 14))
    for book_id in game.books:
        var book = game.books[book_id]
        var owner: String = book["equipped_by"]
        body.add_child(_label("%s · %s %s · %s" % [book_id, book["system"], book["category"], _character_name(owner) if owner != "" else "Available"], 12))

func _render_collection() -> void:
    body.add_child(_label("Collection", 21))
    body.add_child(_label("First acquisition unlocks each system forever, separately for pets and helpers.", 13))
    for category in ["pet", "employee"]:
        var box := _card(body, Color("f9e7ec") if category == "pet" else Color("e4eff8"))
        box.add_child(_label("PETS" if category == "pet" else "HELPERS", 18))
        for i in GameData.SYSTEMS.size():
            var system: String = GameData.SYSTEMS[i]
            box.add_child(_label("%s %s  %s" % [GameData.SYSTEM_ICONS[i], GameData.SYSTEM_NAMES[i], "Unlocked" if game.collections[category].has(system) else "Locked"], 14))
    body.add_child(_label("A foreign collection skill uses one slot. Pet: +50% output. Helper: +50% innate cooldown reduction (provisional formula).", 13))

func _render_help() -> void:
    var box := _card(body)
    box.add_child(_label("How to play", 21))
    box.add_child(_label("Your first pet produces gold. Spend gold to unlock rooms or draw more pets and helpers. Helpers of the same system shorten cycles; matching pairs add output and speed. Merge 2/2/3 identical copies to climb ranks. Buy and equip books after reaching E rank. Acquire a pet or helper of another system to unlock a foreign collection skill. Progress saves locally and earns up to 24 hours while away.", 15))

func _change_page(target: String) -> void:
    page = target
    _render()

func _feedback(message: String) -> void:
    status.text = message
    var feedback_tween := create_tween()
    feedback_tween.tween_property(status, "modulate:a", 0.5, 0.1)
    feedback_tween.tween_property(status, "modulate:a", 1.0, 0.2)
    _render()

func _save() -> void:
    var error := game.save_game()
    if error != "":
        status.text = error

func _sync_and_save() -> void:
    game.catch_up(Time.get_unix_time_from_system())
    _save()

func _unlock_room() -> void:
    _sync_and_save()
    var error := game.unlock_room()
    if error == "":
        _save()
    _feedback("Room unlocked!" if error == "" else error)

func _choose_character(room_index: int, category: String) -> void:
    var options := []
    if game.rooms[room_index][category] != "":
        options.append({"label": "Remove assignment", "method": "_assign", "args": [room_index, category, ""]})
    for id in game.characters:
        var info := GameData.identity_info(game.characters[id]["identity"])
        if info["category"] != category:
            continue
        var label := _character_name(id)
        if game.room_for(id) >= 0 and game.rooms[room_index][category] != id:
            label += " · assigned"
        options.append({"label": label, "method": "_assign", "args": [room_index, category, id]})
    _show_options("Choose " + category, options)

func _assign(room_index: int, category: String, id: String) -> void:
    _close_overlay()
    _sync_and_save()
    var error := game.assign(room_index, category, id)
    if error == "":
        _save()
    _feedback("Assignment updated" if error == "" else error)

func _pull_gacha(banner_id: String, paid: int) -> void:
    _sync_and_save()
    var result := game.draw(banner_id, paid)
    if result["error"] != "":
        _feedback(result["error"])
        return
    _save()
    var lines := []
    for id in result["ids"]:
        lines.append(_character_name(id))
    _show_options("Draw results · %d new" % result["ids"].size(), [{"label": "Close", "method": "_close_overlay", "args": []}], "\n".join(lines))
    _feedback("Draw complete!")

func _buy_book(category: String, system: String) -> void:
    _sync_and_save()
    var result := game.buy_book(category, system)
    if result["error"] == "":
        _save()
    _feedback("Book purchased" if result["error"] == "" else result["error"])

func _merge_prompt(id: String) -> void:
    if not game.characters.has(id):
        return
    var character = game.characters[id]
    var matching_ids := []
    for other_id in game.characters:
        if game.characters[other_id]["identity"] == character["identity"] and game.characters[other_id]["tier"] == character["tier"]:
            matching_ids.append(other_id)
    var needed := 3 if character["tier"] % 3 == 2 else 2
    if matching_ids.size() < needed:
        _feedback("Need %d identical %s copies (%d owned)" % [needed, GameData.rank_name(character["tier"]), matching_ids.size()])
        return
    matching_ids.erase(id)
    matching_ids.push_front(id)
    _show_options("Merge %d copies into %s" % [needed, GameData.rank_name(character["tier"] + 1)], [
        {"label": "Merge · return books and clear affected rooms", "method": "_merge", "args": [matching_ids.slice(0, needed)]}
    ])

func _merge(ids: Array) -> void:
    _close_overlay()
    _sync_and_save()
    var result := game.merge(ids)
    if result["error"] == "":
        _save()
    _feedback("Merged into " + _character_name(result["id"]) if result["error"] == "" else result["error"])

func _show_character(id: String) -> void:
    if not game.characters.has(id):
        return
    var character = game.characters[id]
    var info := GameData.identity_info(character["identity"])
    var options := []
    var details := "System: %s\nRank: %s · slots %d\nNative books: %d/4\nForeign skill: %s\n" % [info["system"], GameData.rank_name(character["tier"]), GameData.slots(character["tier"]), game.book_count(character, info["system"]), character["foreign"] if character["foreign"] != "" else "none"]
    if character["foreign"] != "":
        details += "Foreign slots: %d/4 (includes collection skill)\nForeign books affect only their own resource system.\n" % (game.book_count(character, character["foreign"]) + 1)
    if info["category"] == "pet":
        details += "Book stack bonus: +%.0f%% output\n" % (game._book_bonus(character) * 100.0)
    else:
        details += "Book stack bonus: +%.0f%% reduction\n" % (game._book_bonus(character) * 100.0)
    for book_id in game.books:
        var book = game.books[book_id]
        if book["equipped_by"] == "" and book["category"] == info["category"] and (book["system"] == info["system"] or book["system"] == character["foreign"]):
            options.append({"label": "Equip %s book %s" % [book["system"], book_id], "method": "_equip_book", "args": [id, book_id]})
    for book_id in character["books"]:
        options.append({"label": "Unequip book " + book_id, "method": "_unequip_book", "args": [book_id]})
    if character["foreign"] == "":
        for system in GameData.SYSTEMS:
            if system != info["system"] and game.collections[info["category"]].has(system):
                options.append({"label": "Equip %s collection skill" % system, "method": "_equip_collection", "args": [id, system]})
    else:
        options.append({"label": "Unequip collection skill", "method": "_unequip_collection", "args": [id]})
    _show_options(_character_name(id), options, details)

func _equip_book(character_id: String, book_id: String) -> void:
    _close_overlay()
    _sync_and_save()
    var error := game.equip_book(character_id, book_id)
    if error == "":
        _save()
    _feedback("Book equipped" if error == "" else error)

func _unequip_book(book_id: String) -> void:
    _close_overlay()
    _sync_and_save()
    var error := game.unequip_book(book_id)
    if error == "":
        _save()
    _feedback("Book returned" if error == "" else error)

func _equip_collection(character_id: String, system: String) -> void:
    _close_overlay()
    _sync_and_save()
    var error := game.equip_collection(character_id, system)
    if error == "":
        _save()
    _feedback("Collection skill equipped" if error == "" else error)

func _unequip_collection(character_id: String) -> void:
    _close_overlay()
    _sync_and_save()
    var error := game.unequip_collection(character_id)
    if error == "":
        _save()
    _feedback("Collection skill removed" if error == "" else error)

func _show_options(title: String, options: Array, details: String = "") -> void:
    for child in overlay.get_children():
        child.queue_free()
    overlay.visible = true
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 45)
    margin.add_theme_constant_override("margin_bottom", 45)
    overlay.add_child(margin)
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _style(SOFT, 20))
    margin.add_child(panel)
    var box := VBoxContainer.new()
    panel.add_child(box)
    box.add_child(_label(title, 20))
    if details != "":
        box.add_child(_label(details, 13))
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(scroll)
    var choices := VBoxContainer.new()
    choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(choices)
    for option in options:
        choices.add_child(_button(option["label"], option["method"], option["args"], Color("e8dff0")))
    box.add_child(_button("Close", "_close_overlay", [], Color("f6c6c9")))

func _close_overlay() -> void:
    overlay.visible = false
