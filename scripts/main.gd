extends Control

const PortraitScript = preload("res://scripts/portrait.gd")
const UI = preload("res://scripts/ui_text.gd")

var game: GameState
var page := "rooms"
var body: VBoxContainer
var content_scroll: ScrollContainer
var character_tabs: HBoxContainer
var character_filters: HBoxContainer
var character_category := "pet"
var character_system_filter := ""
var character_tier_filter := -1
var picker_room := -1
var picker_category := ""
var picker_system_filter := ""
var picker_tier_filter := -1
var balances_panel: GridContainer
var overlay: ColorRect
var status: Label
var timer := 0.0
var autosave_timer := 0.0
var touch_active := false
var pending_touch_render := false
const BG := Color("fff8ee")
const INK := Color("414052")
const SOFT := Color("fffdf9")
const ACCENT := Color("ef8f9a")

func _ready() -> void:
    game = GameState.load_game()
    _save()
    get_tree().root.min_size = Vector2i(360, 640)
    get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
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
        if page == "rooms" and touch_active:
            pending_touch_render = true
            _render_balances()
        elif page == "rooms":
            _render()
        else:
            _render_balances()
    if autosave_timer >= 15.0:
        autosave_timer = 0.0
        _save()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        touch_active = event.pressed
        if not touch_active and pending_touch_render and game != null:
            pending_touch_render = false
            call_deferred("_render")

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
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _button(value: String, method: String, args: Array = [], color: Color = ACCENT) -> Button:
    var button := Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(0, 44)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.mouse_filter = Control.MOUSE_FILTER_PASS
    button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
    button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    button.clip_text = true
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
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
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
    for item in [["nav.rooms", "rooms"], ["nav.characters", "characters"], ["nav.gacha", "gacha"],
            ["nav.shop", "shop"], ["nav.collection", "collection"], ["nav.help", "help"]]:
        var button := _button(UI.t(item[0]), "_change_page", [item[1]], Color("e9dfef"))
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        nav.add_child(button)
    character_tabs = HBoxContainer.new()
    character_tabs.add_theme_constant_override("separation", 6)
    root.add_child(character_tabs)
    character_filters = HBoxContainer.new()
    character_filters.add_theme_constant_override("separation", 6)
    root.add_child(character_filters)
    content_scroll = ScrollContainer.new()
    content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    content_scroll.scroll_deadzone = 12
    root.add_child(content_scroll)
    body = VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 8)
    content_scroll.add_child(body)
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
    _render_balances()
    for child in body.get_children():
        child.queue_free()
    character_tabs.visible = page == "characters"
    character_filters.visible = character_tabs.visible
    if character_tabs.visible:
        _render_character_tabs()
        _render_character_filters()
    match page:
        "rooms": _render_rooms()
        "characters": _render_characters()
        "gacha": _render_gacha()
        "shop": _render_shop()
        "collection": _render_collection()
        "help": _render_help()

func _render_balances() -> void:
    for child in balances_panel.get_children():
        child.queue_free()
    for i in GameData.SYSTEMS.size():
        var system: String = GameData.SYSTEMS[i]
        var item := _label("%s %s  %s" % [GameData.SYSTEM_ICONS[i], UI.system_name(system), _amount(game.balances[system])], 13, GameData.SYSTEM_COLORS[i].darkened(0.35))
        item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        balances_panel.add_child(item)

func _amount(value: float) -> String:
    if value >= 1000000:
        return ("%.2f" % (value / 1000000.0)).replace(".", ",") + " tr"
    if value >= 10000:
        return ("%.1f" % (value / 1000.0)).replace(".", ",") + " nghìn"
    return ("%.1f" % value).replace(".", ",")

func _character_name(id: String) -> String:
    if id == "" or not game.characters.has(id):
        return UI.t("common.empty")
    var character = game.characters[id]
    var info := GameData.identity_info(character["identity"])
    return "%s  [%s]" % [info["name"], GameData.rank_name(character["tier"])]

func _system_label(system: String) -> String:
    var index := GameData.SYSTEMS.find(system)
    return "%s %s" % [GameData.SYSTEM_ICONS[index], UI.system_name(system)] if index >= 0 else UI.t("common.none")

func _character_ids(category: String, system: String = "", tier: int = -1) -> Array:
    return game.character_ids(category, system, tier)

func _filter_option() -> OptionButton:
    var option := OptionButton.new()
    option.custom_minimum_size.y = 44
    option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    option.mouse_filter = Control.MOUSE_FILTER_PASS
    option.add_theme_stylebox_override("normal", _style(Color("e9dfef"), 12))
    option.add_theme_stylebox_override("hover", _style(Color("f1e9f5"), 12))
    option.add_theme_color_override("font_color", INK)
    option.add_theme_font_size_override("font_size", 13)
    return option

func _add_filter_controls(row: HBoxContainer, system: String, tier: int, system_method: String, tier_method: String) -> void:
    var systems := _filter_option()
    systems.add_item(UI.t("filter.all_systems"))
    for value in GameData.SYSTEMS:
        systems.add_item(_system_label(value))
    systems.select(GameData.SYSTEMS.find(system) + 1)
    systems.item_selected.connect(Callable(self, system_method))
    row.add_child(systems)
    var ranks := _filter_option()
    ranks.add_item(UI.t("filter.all_ranks"))
    for value in 27:
        ranks.add_item(GameData.rank_name(value))
    ranks.select(tier + 1)
    ranks.item_selected.connect(Callable(self, tier_method))
    row.add_child(ranks)

func _render_character_tabs() -> void:
    for child in character_tabs.get_children():
        child.queue_free()
    for category in ["pet", "employee"]:
        var button := _button(UI.t("characters.tab", [UI.category_name(category), _character_ids(category).size()]), "_select_character_category", [category], Color("f7c8a5") if category == character_category else Color("e9dfef"))
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        character_tabs.add_child(button)

func _render_character_filters() -> void:
    for child in character_filters.get_children():
        child.queue_free()
    _add_filter_controls(character_filters, character_system_filter, character_tier_filter, "_set_character_system_filter", "_set_character_tier_filter")

func _set_character_system_filter(index: int) -> void:
    character_system_filter = "" if index == 0 else GameData.SYSTEMS[index - 1]
    content_scroll.scroll_vertical = 0
    _render()

func _set_character_tier_filter(index: int) -> void:
    character_tier_filter = index - 1
    content_scroll.scroll_vertical = 0
    _render()

func _select_character_category(category: String) -> void:
    if category == character_category:
        return
    character_category = category
    character_system_filter = ""
    character_tier_filter = -1
    content_scroll.scroll_vertical = 0
    _render()

func _render_rooms() -> void:
    body.add_child(_label(UI.t("rooms.title"), 21))
    for i in game.rooms.size():
        var room = game.rooms[i]
        var box := _card(body, Color("fce9e4") if i % 2 == 0 else Color("e8f0ed"))
        box.add_child(_label(UI.t("rooms.room_number", [i + 1]), 18))
        var actors := _row(box)
        if room["pet"] != "":
            actors.add_child(_portrait(game.characters[room["pet"]]["identity"]))
        if room["employee"] != "":
            actors.add_child(_portrait(game.characters[room["employee"]]["identity"]))
        var actor_names := VBoxContainer.new()
        actor_names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        actors.add_child(actor_names)
        var pet_name := _character_name(room["pet"])
        var employee_name := _character_name(room["employee"])
        if room["pet"] != "":
            pet_name += " · " + _system_label(GameData.identity_info(game.characters[room["pet"]]["identity"])["system"])
        if room["employee"] != "":
            employee_name += " · " + _system_label(GameData.identity_info(game.characters[room["employee"]]["identity"])["system"])
        actor_names.add_child(_label(UI.t("rooms.pet", [pet_name])))
        actor_names.add_child(_label(UI.t("rooms.employee", [employee_name])))
        var production_data := game.production(room)
        if not production_data.is_empty():
            var remaining: float = maxf(0.0, production_data["cycle"] - room["progress"])
            box.add_child(_label(UI.t("rooms.cycle", [_amount(production_data["cycle"]), _amount(remaining)]), 13))
            for system in GameData.SYSTEMS:
                if production_data["outputs"].has(system):
                    box.add_child(_label(UI.t("rooms.output", [_amount(production_data["outputs"][system]), _system_label(system)]), 13))
            var progress := ProgressBar.new()
            progress.custom_minimum_size.y = 12
            progress.max_value = production_data["cycle"]
            progress.value = room["progress"]
            progress.show_percentage = false
            box.add_child(progress)
        else:
            box.add_child(_label(UI.t("rooms.assign_hint"), 13))
        var row := _row(box)
        row.add_child(_button(UI.t("rooms.choose_pet"), "_choose_character", [i, "pet"], Color("f7c8a5")))
        row.add_child(_button(UI.t("rooms.choose_employee"), "_choose_character", [i, "employee"], Color("c5dcf4")))
    body.add_child(_button(UI.t("rooms.unlock", [_amount(GameData.room_cost(game.rooms.size() + 1))]), "_unlock_room", [], Color("f5d98c")))

func _render_characters() -> void:
    var all_ids := _character_ids(character_category)
    var ids := _character_ids(character_category, character_system_filter, character_tier_filter)
    body.add_child(_label(UI.t("characters.title", [ids.size(), all_ids.size()]), 21))
    var merge_count := game.merge_all_preview(character_category)
    var merge_button := _button(UI.t("merge.all_button", [UI.category_name(character_category), merge_count]), "_merge_all_prompt", [character_category], Color("f2c5d5"))
    merge_button.disabled = merge_count == 0
    body.add_child(merge_button)
    var identity_counts := {}
    var tier_counts := {}
    for id in all_ids:
        var owned: Dictionary = game.characters[id]
        var identity: String = owned["identity"]
        var key := "%s:%d" % [identity, owned["tier"]]
        identity_counts[identity] = int(identity_counts.get(identity, 0)) + 1
        tier_counts[key] = int(tier_counts.get(key, 0)) + 1
    if ids.is_empty():
        var empty_key := "characters.empty_pet" if character_category == "pet" else "characters.empty_employee"
        body.add_child(_label(UI.t(empty_key if all_ids.is_empty() else "characters.empty_filter"), 15))
    for id in ids:
        var character = game.characters[id]
        var info := GameData.identity_info(character["identity"])
        var color: Color = GameData.SYSTEM_COLORS[GameData.SYSTEMS.find(info["system"])].lightened(0.73)
        var box := _card(body, color)
        var actor_row := _row(box)
        actor_row.add_child(_portrait(character["identity"]))
        var details := VBoxContainer.new()
        details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        actor_row.add_child(details)
        details.add_child(_label(UI.t("characters.name_rank", [UI.category_name(info["category"]), info["name"], GameData.rank_name(character["tier"])]), 16))
        var room_text := UI.t("common.room", [game.room_for(id) + 1]) if game.room_for(id) >= 0 else UI.t("common.unassigned")
        details.add_child(_label(UI.t("characters.summary", [_system_label(info["system"]), character["books"].size() + int(character["foreign"] != ""), GameData.slots(character["tier"]), room_text]), 12))
        var copy_key := "%s:%d" % [character["identity"], character["tier"]]
        var copies_key := "characters.copies_max" if character["tier"] == 26 else "characters.copies"
        var copies_values := [identity_counts[character["identity"]], tier_counts[copy_key]]
        if character["tier"] < 26:
            copies_values.append(3 if character["tier"] % 3 == 2 else 2)
        details.add_child(_label(UI.t(copies_key, copies_values), 12))
        var row := _row(box)
        row.add_child(_button(UI.t("characters.details"), "_show_character", [id], Color("c7dbea")))
        if character["tier"] < 26:
            row.add_child(_button(UI.t("characters.merge"), "_merge_prompt", [id], Color("f2c5d5")))

func _render_gacha() -> void:
    body.add_child(_label(UI.t("gacha.title"), 21))
    body.add_child(_label(UI.t("gacha.rates"), 13))
    for banner_id in ["normal_pet", "normal_employee", "vip_pet", "vip_employee"]:
        var banner := GameData.banner(banner_id)
        var box := _card(body, Color("ebe7f6") if banner["currency"] == "crystal" else Color("fff0d7"))
        box.add_child(_label(UI.t("gacha.banner." + banner_id), 18))
        box.add_child(_label(UI.t("gacha.price", [_amount(banner["price"]), _system_label(banner["currency"])]), 13))
        var systems := []
        for system in GameData.SYSTEMS:
            systems.append(_system_label(system))
        box.add_child(_label(UI.t("gacha.systems", [", ".join(systems)]), 12))
        var row := _row(box)
        for paid in [1, 10, 100]:
            var button := _button(UI.t("gacha.package", [paid]), "_pull_gacha", [banner_id, paid], Color("f7c9a7"))
            button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            row.add_child(button)

func _render_shop() -> void:
    body.add_child(_label(UI.t("shop.title"), 21))
    body.add_child(_label(UI.t("shop.provisional"), 13))
    body.add_child(_label(UI.t("shop.stacks"), 13))
    for i in GameData.SYSTEMS.size():
        var system: String = GameData.SYSTEMS[i]
        var box := _card(body, GameData.SYSTEM_COLORS[i].lightened(0.72))
        box.add_child(_label(UI.t("shop.next_price", [_system_label(system), _amount(GameData.book_cost(game.book_purchases[system]))]), 16))
        var row := _row(box)
        row.add_child(_button(UI.t("shop.pet_book"), "_buy_book", ["pet", system], Color("f7c8a5")))
        row.add_child(_button(UI.t("shop.employee_book"), "_buy_book", ["employee", system], Color("c5dcf4")))
    body.add_child(_label(UI.t("shop.owned", [game.books.size()]), 14))
    for book_id in game.books:
        var book = game.books[book_id]
        var owner: String = book["equipped_by"]
        body.add_child(_label(UI.t("shop.book_entry", [book_id, UI.category_name(book["category"]), _system_label(book["system"]), _character_name(owner) if owner != "" else UI.t("common.available")]), 12))

func _render_collection() -> void:
    body.add_child(_label(UI.t("collection.title"), 21))
    body.add_child(_label(UI.t("collection.intro"), 13))
    for category in ["pet", "employee"]:
        var box := _card(body, Color("f9e7ec") if category == "pet" else Color("e4eff8"))
        box.add_child(_label(UI.t("collection.pets" if category == "pet" else "collection.employees"), 18))
        for i in GameData.SYSTEMS.size():
            var system: String = GameData.SYSTEMS[i]
            box.add_child(_label(UI.t("collection.entry", [GameData.SYSTEM_ICONS[i], UI.system_name(system), UI.t("common.unlocked" if game.collections[category].has(system) else "common.locked")]), 14))
    body.add_child(_label(UI.t("collection.effect"), 13))

func _render_help() -> void:
    var box := _card(body)
    box.add_child(_label(UI.t("help.title"), 21))
    box.add_child(_label(UI.t("help.body"), 15))

func _change_page(target: String) -> void:
    page = target
    content_scroll.scroll_vertical = 0
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
    _feedback(UI.t("room.unlocked") if error == "" else error)

func _choose_character(room_index: int, category: String) -> void:
    if picker_room != room_index or picker_category != category:
        picker_room = room_index
        picker_category = category
        picker_system_filter = ""
        picker_tier_filter = -1
    var options := []
    if game.rooms[room_index][category] != "":
        options.append({"label": UI.t("assignment.remove"), "method": "_assign", "args": [room_index, category, ""]})
    var ids := _character_ids(category, picker_system_filter, picker_tier_filter)
    for id in ids:
        var info := GameData.identity_info(game.characters[id]["identity"])
        var label := "%s · %s" % [_character_name(id), _system_label(info["system"])]
        if game.room_for(id) >= 0 and game.rooms[room_index][category] != id:
            label += " · " + UI.t("common.assigned")
        options.append({"label": label, "method": "_assign", "args": [room_index, category, id]})
    _show_options(UI.t("assignment.choose", [UI.category_name(category)]), options, UI.t("assignment.empty_filter") if ids.is_empty() else "", true)

func _set_picker_system_filter(index: int) -> void:
    picker_system_filter = "" if index == 0 else GameData.SYSTEMS[index - 1]
    _choose_character(picker_room, picker_category)

func _set_picker_tier_filter(index: int) -> void:
    picker_tier_filter = index - 1
    _choose_character(picker_room, picker_category)

func _assign(room_index: int, category: String, id: String) -> void:
    _close_overlay()
    _sync_and_save()
    var error := game.assign(room_index, category, id)
    if error == "":
        _save()
    _feedback(UI.t("assignment.updated") if error == "" else error)

func _pull_gacha(banner_id: String, paid: int) -> void:
    _sync_and_save()
    var result := game.draw(banner_id, paid)
    if result["error"] != "":
        _feedback(result["error"])
        return
    _save()
    var lines := []
    for id in result["ids"]:
        var info := GameData.identity_info(game.characters[id]["identity"])
        lines.append("%s · %s · %s" % [UI.category_name(info["category"]), _character_name(id), _system_label(info["system"])])
    _show_options(UI.t("gacha.results", [result["ids"].size()]), [{"label": UI.t("common.close"), "method": "_close_overlay", "args": []}], "\n".join(lines))
    _feedback(UI.t("gacha.complete"))

func _buy_book(category: String, system: String) -> void:
    _sync_and_save()
    var result := game.buy_book(category, system)
    if result["error"] == "":
        _save()
    _feedback(UI.t("book.purchased") if result["error"] == "" else result["error"])

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
        _feedback(UI.t("merge.need_owned", [needed, GameData.rank_name(character["tier"]), matching_ids.size()]))
        return
    matching_ids.erase(id)
    matching_ids.push_front(id)
    var info := GameData.identity_info(character["identity"])
    _show_options(UI.t("merge.title", [needed, GameData.rank_name(character["tier"] + 1)]), [
        {"label": UI.t("merge.confirm"), "method": "_merge", "args": [matching_ids.slice(0, needed)]}
    ], UI.t("merge.identity", [info["name"], _system_label(info["system"])]) + "\n" + UI.t("merge.warning"))

func _merge(ids: Array) -> void:
    _close_overlay()
    _sync_and_save()
    var result := game.merge(ids)
    if result["error"] == "":
        _save()
    _feedback(UI.t("merge.complete", [_character_name(result["id"])]) if result["error"] == "" else result["error"])

func _merge_all_prompt(category: String) -> void:
    var count := game.merge_all_preview(category)
    if count == 0:
        _feedback(UI.t("merge.all_none"))
        return
    _show_options(UI.t("merge.all_title", [UI.category_name(category), count]), [
        {"label": UI.t("merge.all_confirm"), "method": "_merge_all", "args": [category]}
    ], UI.t("merge.all_warning"))

func _merge_all(category: String) -> void:
    _close_overlay()
    _sync_and_save()
    var result := game.merge_all(category)
    if result["count"] > 0:
        _save()
    _feedback(UI.t("merge.all_complete", [result["count"]]) if result["error"] == "" else result["error"])

func _show_character(id: String) -> void:
    if not game.characters.has(id):
        return
    var character = game.characters[id]
    var info := GameData.identity_info(character["identity"])
    var options := []
    var details := UI.t("detail.main", [_system_label(info["system"]), GameData.rank_name(character["tier"]), GameData.slots(character["tier"]), game.book_count(character, info["system"]), _system_label(character["foreign"]) if character["foreign"] != "" else UI.t("common.none")])
    if character["foreign"] != "":
        details += UI.t("detail.foreign", [game.book_count(character, character["foreign"]) + 1])
        if info["category"] == "pet":
            details += UI.t("detail.foreign_pet_bonus", [game._book_bonus(character, character["foreign"]) * 100.0])
        else:
            details += UI.t("detail.foreign_employee")
    if info["category"] == "pet":
        details += UI.t("detail.pet_bonus", [game._book_bonus(character) * 100.0])
    else:
        details += UI.t("detail.employee_bonus", [game._book_bonus(character) * 100.0])
    for book_id in game.books:
        var book = game.books[book_id]
        if book["equipped_by"] == "" and book["category"] == info["category"] and (book["system"] == info["system"] or book["system"] == character["foreign"]):
            options.append({"label": UI.t("detail.equip_book", [_system_label(book["system"]), book_id]), "method": "_equip_book", "args": [id, book_id]})
    for book_id in character["books"]:
        options.append({"label": UI.t("detail.unequip_book", [book_id]), "method": "_unequip_book", "args": [book_id]})
    if character["foreign"] == "":
        for system in GameData.SYSTEMS:
            if system != info["system"] and game.collections[info["category"]].has(system):
                options.append({"label": UI.t("detail.equip_collection", [_system_label(system)]), "method": "_equip_collection", "args": [id, system]})
    else:
        options.append({"label": UI.t("detail.unequip_collection"), "method": "_unequip_collection", "args": [id]})
    _show_options(_character_name(id), options, details)

func _equip_book(character_id: String, book_id: String) -> void:
    _close_overlay()
    _sync_and_save()
    var error := game.equip_book(character_id, book_id)
    if error == "":
        _save()
    _feedback(UI.t("book.equipped") if error == "" else error)

func _unequip_book(book_id: String) -> void:
    _close_overlay()
    _sync_and_save()
    var error := game.unequip_book(book_id)
    if error == "":
        _save()
    _feedback(UI.t("book.returned") if error == "" else error)

func _equip_collection(character_id: String, system: String) -> void:
    _close_overlay()
    _sync_and_save()
    var error := game.equip_collection(character_id, system)
    if error == "":
        _save()
    _feedback(UI.t("collection.equipped") if error == "" else error)

func _unequip_collection(character_id: String) -> void:
    _close_overlay()
    _sync_and_save()
    var error := game.unequip_collection(character_id)
    if error == "":
        _save()
    _feedback(UI.t("collection.removed") if error == "" else error)

func _show_options(title: String, options: Array, details: String = "", show_picker_filters: bool = false) -> void:
    for child in overlay.get_children():
        overlay.remove_child(child)
        child.queue_free()
    overlay.visible = true
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.mouse_filter = Control.MOUSE_FILTER_PASS
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 45)
    margin.add_theme_constant_override("margin_bottom", 45)
    overlay.add_child(margin)
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _style(SOFT, 20))
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
    margin.add_child(panel)
    var box := VBoxContainer.new()
    panel.add_child(box)
    box.add_child(_label(title, 20))
    if show_picker_filters:
        var filters := HBoxContainer.new()
        filters.add_theme_constant_override("separation", 6)
        box.add_child(filters)
        _add_filter_controls(filters, picker_system_filter, picker_tier_filter, "_set_picker_system_filter", "_set_picker_tier_filter")
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.scroll_deadzone = 12
    box.add_child(scroll)
    var choices := VBoxContainer.new()
    choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(choices)
    if details != "":
        choices.add_child(_label(details, 13))
    for option in options:
        var option_button := _button(option["label"], option["method"], option["args"], Color("e8dff0"))
        option_button.custom_minimum_size.y = 56
        choices.add_child(option_button)
    box.add_child(_button(UI.t("common.close"), "_close_overlay", [], Color("f6c6c9")))

func _close_overlay() -> void:
    overlay.visible = false
