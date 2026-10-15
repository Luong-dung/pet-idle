class_name GameState
extends RefCounted

const UI = preload("res://scripts/ui_text.gd")
const SAVE_PATH := "user://pet_idle_save.json"
const SAVE_VERSION := 1
var balances: Dictionary = {}
var characters: Dictionary = {}
var books: Dictionary = {}
var rooms: Array = []
var collections: Dictionary = {"pet": {}, "employee": {}}
var book_purchases: Dictionary = {}
var next_id := 1
var last_timestamp := 0.0
var rng := RandomNumberGenerator.new()

static func new_game() -> GameState:
    var game := GameState.new()
    game.balances = GameData.START_BALANCES.duplicate(true)
    for system in GameData.SYSTEMS:
        game.book_purchases[system] = 0
    for n in range(1, 4):
        game.rooms.append({"id": "r%d" % n, "pet": "", "employee": "", "progress": 0.0})
    var starter := game.add_character(GameData.START_PET, 0)
    game.rooms[0]["pet"] = starter
    game.last_timestamp = Time.get_unix_time_from_system()
    game.rng.randomize()
    return game

func make_id(prefix: String) -> String:
    var result := "%s%d" % [prefix, next_id]
    next_id += 1
    return result

func add_character(identity_id: String, tier: int) -> String:
    var info := GameData.identity_info(identity_id)
    if info.is_empty() or tier < 0 or tier > 26:
        return ""
    var id := make_id("c")
    characters[id] = {"id": id, "identity": identity_id, "tier": tier, "books": [], "foreign": ""}
    collections[info["category"]][info["system"]] = true
    return id

func room_for(character_id: String) -> int:
    for i in rooms.size():
        if rooms[i]["pet"] == character_id or rooms[i]["employee"] == character_id:
            return i
    return -1

func character_ids(category: String, system: String = "", tier: int = -1) -> Array:
    if not (category in ["pet", "employee"]) or (system != "" and not (system in GameData.SYSTEMS)) or tier < -1 or tier > 26:
        return []
    var ids := []
    for id in characters:
        var character: Dictionary = characters[id]
        var info := GameData.identity_info(character["identity"])
        if info["category"] == category and (system == "" or info["system"] == system) and (tier == -1 or character["tier"] == tier):
            ids.append(id)
    ids.sort_custom(Callable(self, "_character_before"))
    return ids

func _character_before(a: String, b: String) -> bool:
    var first: Dictionary = characters[a]
    var second: Dictionary = characters[b]
    if first["tier"] != second["tier"]:
        return first["tier"] > second["tier"]
    var first_info := GameData.identity_info(first["identity"])
    var second_info := GameData.identity_info(second["identity"])
    var first_system := GameData.SYSTEMS.find(first_info["system"])
    var second_system := GameData.SYSTEMS.find(second_info["system"])
    if first_system != second_system:
        return first_system < second_system
    if first_info["index"] != second_info["index"]:
        return first_info["index"] < second_info["index"]
    return int(a.substr(1)) < int(b.substr(1))

func _reset_progress_for(character_id: String) -> void:
    var index := room_for(character_id)
    if index >= 0:
        rooms[index]["progress"] = 0.0

func assign(room_index: int, category: String, character_id: String) -> String:
    if room_index < 0 or room_index >= rooms.size() or not (category in ["pet", "employee"]):
        return UI.t("error.invalid_room_role")
    if character_id == "":
        rooms[room_index][category] = ""
        rooms[room_index]["progress"] = 0.0
        if category == "pet":
            rooms[room_index]["employee"] = ""
        return ""
    if not characters.has(character_id):
        return UI.t("error.character_not_owned")
    var info := GameData.identity_info(characters[character_id]["identity"])
    if info["category"] != category:
        return UI.t("error.wrong_role")
    if room_for(character_id) >= 0 and rooms[room_index][category] != character_id:
        return UI.t("error.already_assigned")
    if category == "employee":
        var pet_id: String = rooms[room_index]["pet"]
        if pet_id == "":
            return UI.t("error.assign_pet_first")
        var pet_info := GameData.identity_info(characters[pet_id]["identity"])
        if pet_info["system"] != info["system"]:
            return UI.t("error.employee_system")
    else:
        var employee_id: String = rooms[room_index]["employee"]
        if employee_id != "":
            var employee_info := GameData.identity_info(characters[employee_id]["identity"])
            if employee_info["system"] != info["system"]:
                rooms[room_index]["employee"] = ""
    rooms[room_index][category] = character_id
    rooms[room_index]["progress"] = 0.0
    return ""

func unlock_room() -> String:
    var cost := GameData.room_cost(rooms.size() + 1)
    if balances["gold"] < cost:
        return UI.t("error.insufficient_gold")
    balances["gold"] -= cost
    var n := rooms.size() + 1
    rooms.append({"id": "r%d" % n, "pet": "", "employee": "", "progress": 0.0})
    return ""

func matching(room: Dictionary) -> bool:
    if room["pet"] == "" or room["employee"] == "":
        return false
    var pet := GameData.identity_info(characters[room["pet"]]["identity"])
    var employee := GameData.identity_info(characters[room["employee"]]["identity"])
    return pet["system"] == employee["system"] and pet["index"] == employee["index"]

func book_count(character: Dictionary, system: String) -> int:
    var count := 0
    for book_id in character["books"]:
        if books.has(book_id) and books[book_id]["system"] == system:
            count += 1
    return count

func _book_bonus(character: Dictionary, target_system: String = "") -> float:
    if target_system == "":
        target_system = GameData.identity_info(character["identity"])["system"]
    var counts := {}
    for book_id in character["books"]:
        if books.has(book_id):
            var book = books[book_id]
            if book["system"] != target_system:
                continue
            var key: String = "%s_%s" % [book["category"], book["system"]]
            counts[key] = int(counts.get(key, 0)) + 1
    var bonus := 0.0
    for count in counts.values():
        bonus += GameData.BOOK_FULL_EFFECT * GameData.BOOK_STACK[mini(int(count), 4)]
    return bonus

func production(room: Dictionary) -> Dictionary:
    if room["pet"] == "" or not characters.has(room["pet"]):
        return {}
    var pet = characters[room["pet"]]
    var pet_info := GameData.identity_info(pet["identity"])
    var pair := matching(room)
    var output_bonus: float = _book_bonus(pet, pet_info["system"])
    if pair:
        output_bonus += 0.1
    var base_output: float = GameData.PET_OUTPUT[pet_info["index"]] * pow(1.1, pet["tier"])
    var outputs := {pet_info["system"]: base_output * (1.0 + output_bonus)}
    if pet["foreign"] != "":
        var foreign_system: String = pet["foreign"]
        outputs[foreign_system] = base_output * (0.5 + _book_bonus(pet, foreign_system))
    var cycle: float = GameData.PET_CYCLE[pet_info["index"]]
    if room["employee"] != "" and characters.has(room["employee"]):
        var employee = characters[room["employee"]]
        var reduction: float = 10.0 * pow(1.1, employee["tier"])
        var reduction_bonus: float = _book_bonus(employee, pet_info["system"])
        if employee["foreign"] != "":
            reduction_bonus += 0.5
        cycle -= reduction * (1.0 + reduction_bonus)
    if pair:
        cycle *= 0.9
    cycle = maxf(GameData.CYCLE_FLOOR, cycle)
    return {"outputs": outputs, "cycle": cycle}

func advance(seconds: float) -> void:
    if not is_finite(seconds) or seconds <= 0.0:
        return
    for room in rooms:
        var production_data := production(room)
        if production_data.is_empty():
            continue
        var total: float = float(room["progress"]) + seconds
        var cycle: float = production_data["cycle"]
        var completed := floori(total / cycle)
        room["progress"] = maxf(0.0, total - completed * cycle)
        if completed > 0:
            for system in production_data["outputs"]:
                balances[system] += completed * production_data["outputs"][system]

func catch_up(now: float) -> float:
    if not is_finite(now):
        return 0.0
    var elapsed := clampf(now - last_timestamp, 0.0, GameData.OFFLINE_CAP)
    advance(elapsed)
    last_timestamp = maxf(last_timestamp, now)
    return elapsed

func draw(banner_id: String, paid: int) -> Dictionary:
    var banner := GameData.banner(banner_id)
    if banner.is_empty() or not GameData.PACKAGES.has(paid):
        return {"error": UI.t("error.invalid_banner")}
    var cost: int = banner["price"] * paid
    if balances[banner["currency"]] < cost:
        return {"error": UI.t("error.insufficient_resource", [UI.system_name(banner["currency"])])}
    balances[banner["currency"]] -= cost
    var results := []
    for i in GameData.PACKAGES[paid]:
        var major_index := GameData.weighted_index(banner["weights"], rng.randi_range(0, 99))
        var subtier := GameData.weighted_index(GameData.SUBTIER_WEIGHTS, rng.randi_range(0, 99))
        var system: String = GameData.SYSTEMS[rng.randi_range(0, 5)]
        var identity_index := rng.randi_range(0, 2)
        var tier: int = banner["ranks"][major_index] * 3 + subtier
        var id := add_character(GameData.identity(banner["category"], system, identity_index), tier)
        results.append(id)
    return {"error": "", "ids": results, "cost": cost}

func merge(ids: Array) -> Dictionary:
    if ids.is_empty():
        return {"error": UI.t("error.choose_copies")}
    var seen := {}
    for id in ids:
        if not (id is String) or seen.has(id) or not characters.has(id):
            return {"error": UI.t("error.invalid_copy")}
        seen[id] = true
    var first = characters[ids[0]]
    var tier: int = first["tier"]
    if tier >= 26:
        return {"error": UI.t("error.max_rank")}
    var needed := 3 if tier % 3 == 2 else 2
    if ids.size() != needed:
        return {"error": UI.t("error.need_copies", [needed])}
    for id in ids:
        var current = characters[id]
        if current["identity"] != first["identity"] or current["tier"] != tier:
            return {"error": UI.t("error.copies_mismatch")}
    var room_index := -1
    for id in ids:
        room_index = room_for(id)
        if room_index >= 0:
            break
    var companion_id: String = rooms[room_index]["employee"] if room_index >= 0 and GameData.identity_info(first["identity"])["category"] == "pet" else ""
    for id in ids:
        var character = characters[id]
        for book_id in character["books"]:
            books[book_id]["equipped_by"] = ""
        for room in rooms:
            if room["pet"] == id:
                room["pet"] = ""
                room["employee"] = ""
                room["progress"] = 0.0
            elif room["employee"] == id:
                room["employee"] = ""
                room["progress"] = 0.0
        characters.erase(id)
    var result_id := add_character(first["identity"], tier + 1)
    if room_index >= 0:
        assign(room_index, GameData.identity_info(first["identity"])["category"], result_id)
        if companion_id != "" and characters.has(companion_id):
            assign(room_index, "employee", companion_id)
    return {"error": "", "id": result_id}

func merge_all_preview(category: String) -> int:
    if not (category in ["pet", "employee"]):
        return 0
    var copies := {}
    for id in character_ids(category):
        var character: Dictionary = characters[id]
        var identity: String = character["identity"]
        if not copies.has(identity):
            var tiers := []
            tiers.resize(27)
            tiers.fill(0)
            copies[identity] = tiers
        copies[identity][character["tier"]] += 1
    var count := 0
    for tiers in copies.values():
        for tier in 26:
            var needed := 3 if tier % 3 == 2 else 2
            var merges: int = int(tiers[tier]) / needed
            tiers[tier + 1] += merges
            count += merges
    return count

func merge_all(category: String) -> Dictionary:
    if not (category in ["pet", "employee"]):
        return {"error": UI.t("error.invalid_merge_category"), "count": 0}
    var count := 0
    for tier in 26:
        var needed := 3 if tier % 3 == 2 else 2
        for system in GameData.SYSTEMS:
            for index in 3:
                var identity := GameData.identity(category, system, index)
                while true:
                    var assigned := []
                    var plain := []
                    var equipped := []
                    for id in character_ids(category, system, tier):
                        var character: Dictionary = characters[id]
                        if character["identity"] != identity:
                            continue
                        if room_for(id) >= 0:
                            assigned.append(id)
                        elif character["books"].is_empty() and character["foreign"] == "":
                            plain.append(id)
                        else:
                            equipped.append(id)
                    if assigned.size() + plain.size() + equipped.size() < needed:
                        break
                    var selected := []
                    if not assigned.is_empty():
                        selected.append(assigned.pop_front())
                    elif not plain.is_empty():
                        selected.append(plain.pop_front())
                    else:
                        selected.append(equipped.pop_front())
                    for group in [plain, equipped, assigned]:
                        while selected.size() < needed and not group.is_empty():
                            selected.append(group.pop_front())
                    var result := merge(selected)
                    if result["error"] != "":
                        return {"error": result["error"], "count": count}
                    count += 1
    return {"error": "", "count": count}

func buy_book(category: String, system: String) -> Dictionary:
    if not (category in ["pet", "employee"]) or not (system in GameData.SYSTEMS):
        return {"error": UI.t("error.invalid_book")}
    var cost := GameData.book_cost(book_purchases[system])
    if balances[system] < cost:
        return {"error": UI.t("error.insufficient_resource", [UI.system_name(system)])}
    balances[system] -= cost
    book_purchases[system] += 1
    var id := make_id("b")
    books[id] = {"id": id, "category": category, "system": system, "equipped_by": ""}
    return {"error": "", "id": id, "cost": cost}

func equip_book(character_id: String, book_id: String) -> String:
    if not characters.has(character_id) or not books.has(book_id):
        return UI.t("error.character_or_book_missing")
    var character = characters[character_id]
    var book = books[book_id]
    var info := GameData.identity_info(character["identity"])
    if book["equipped_by"] != "":
        return UI.t("error.book_equipped")
    if book["category"] != info["category"]:
        return UI.t("error.book_role")
    if book["system"] != info["system"] and book["system"] != character["foreign"]:
        return UI.t("error.foreign_unlock")
    if character["books"].size() + int(character["foreign"] != "") >= GameData.slots(character["tier"]):
        return UI.t("error.no_slot")
    var system_count := book_count(character, book["system"])
    if system_count + int(book["system"] == character["foreign"]) >= 4:
        return UI.t("error.system_slot_limit")
    character["books"].append(book_id)
    book["equipped_by"] = character_id
    _reset_progress_for(character_id)
    return ""

func unequip_book(book_id: String) -> String:
    if not books.has(book_id):
        return UI.t("error.book_missing")
    var owner: String = books[book_id]["equipped_by"]
    if owner == "":
        return UI.t("error.book_not_equipped")
    if characters.has(owner):
        characters[owner]["books"].erase(book_id)
    books[book_id]["equipped_by"] = ""
    _reset_progress_for(owner)
    return ""

func equip_collection(character_id: String, system: String) -> String:
    if not characters.has(character_id):
        return UI.t("error.character_missing")
    var character = characters[character_id]
    var info := GameData.identity_info(character["identity"])
    if character["foreign"] != "":
        return UI.t("error.foreign_already_equipped")
    if system == info["system"] or not collections[info["category"]].has(system):
        return UI.t("error.foreign_locked")
    if character["books"].size() >= GameData.slots(character["tier"]):
        return UI.t("error.no_slot")
    character["foreign"] = system
    _reset_progress_for(character_id)
    return ""

func unequip_collection(character_id: String) -> String:
    if not characters.has(character_id) or characters[character_id]["foreign"] == "":
        return UI.t("error.collection_not_equipped")
    var foreign: String = characters[character_id]["foreign"]
    for book_id in characters[character_id]["books"].duplicate():
        if books[book_id]["system"] == foreign:
            unequip_book(book_id)
    characters[character_id]["foreign"] = ""
    _reset_progress_for(character_id)
    return ""

func to_dict() -> Dictionary:
    return {"version": SAVE_VERSION, "balances": balances, "characters": characters,
        "books": books, "rooms": rooms, "collections": collections,
        "book_purchases": book_purchases, "next_id": next_id, "last_timestamp": last_timestamp}

func save_game() -> String:
    var path := ProjectSettings.globalize_path(SAVE_PATH)
    var temp := path + ".tmp"
    var file := FileAccess.open(temp, FileAccess.WRITE)
    if file == null:
        return UI.t("error.save_open")
    file.store_string(JSON.stringify(to_dict()))
    file.flush()
    file.close()
    if FileAccess.file_exists(path):
        DirAccess.copy_absolute(path, path + ".bak")
    var error := DirAccess.rename_absolute(temp, path)
    return "" if error == OK else UI.t("error.save_replace", [error])

static func load_game() -> GameState:
    var game := _read_save(SAVE_PATH)
    if game == null:
        game = _read_save(SAVE_PATH + ".bak")
        if game != null:
            DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".bak"), ProjectSettings.globalize_path(SAVE_PATH))
    if game == null:
        return new_game()
    game.catch_up(Time.get_unix_time_from_system())
    game.rng.randomize()
    return game

static func _read_save(path: String) -> GameState:
    if not FileAccess.file_exists(path):
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK:
        return null
    return from_dict(parser.data)

static func from_dict(data: Variant) -> GameState:
    if not (data is Dictionary) or data.get("version") != SAVE_VERSION:
        return null
    for key in ["balances", "characters", "books", "rooms", "collections", "book_purchases", "next_id", "last_timestamp"]:
        if not data.has(key):
            return null
    if not (data["balances"] is Dictionary and data["characters"] is Dictionary and data["books"] is Dictionary and data["rooms"] is Array and data["collections"] is Dictionary and data["book_purchases"] is Dictionary):
        return null
    if data["rooms"].size() < 3 or not _whole_number(data["next_id"]) or data["next_id"] < 1 or not (data["last_timestamp"] is float or data["last_timestamp"] is int):
        return null
    var game := GameState.new()
    game.balances = data["balances"].duplicate(true)
    game.characters = data["characters"].duplicate(true)
    game.books = data["books"].duplicate(true)
    game.rooms = data["rooms"].duplicate(true)
    game.collections = data["collections"].duplicate(true)
    game.book_purchases = data["book_purchases"].duplicate(true)
    game.next_id = int(data["next_id"])
    game.last_timestamp = float(data["last_timestamp"])
    if not is_finite(game.last_timestamp) or game.last_timestamp < 0:
        return null
    for system in GameData.SYSTEMS:
        if not game.balances.has(system) or not (game.balances[system] is float or game.balances[system] is int) or not is_finite(float(game.balances[system])) or game.balances[system] < 0:
            return null
        if not game.book_purchases.has(system) or not _whole_number(game.book_purchases[system]) or game.book_purchases[system] < 0:
            return null
        game.book_purchases[system] = int(game.book_purchases[system])
    for category in ["pet", "employee"]:
        if not game.collections.has(category) or not (game.collections[category] is Dictionary):
            return null
        for system in game.collections[category]:
            if not (system in GameData.SYSTEMS) or game.collections[category][system] != true:
                return null
    var highest_id := 0
    for id in game.characters:
        var character = game.characters[id]
        if not (id is String) or not id.begins_with("c") or not id.substr(1).is_valid_int():
            return null
        highest_id = maxi(highest_id, int(id.substr(1)))
        if not (character is Dictionary) or not character.has_all(["identity", "tier", "books", "foreign"]):
            return null
        if not (character["identity"] is String) or GameData.identity_info(character["identity"]).is_empty():
            return null
        if not _whole_number(character["tier"]) or character["tier"] < 0 or character["tier"] > 26:
            return null
        character["tier"] = int(character["tier"])
        var info := GameData.identity_info(character["identity"])
        if not game.collections[info["category"]].has(info["system"]):
            return null
    var assigned := {}
    var room_ids := {}
    for room in game.rooms:
        if not (room is Dictionary) or not room.has_all(["id", "pet", "employee", "progress"]):
            return null
        if not (room["id"] is String) or room["id"] == "" or room_ids.has(room["id"]):
            return null
        room_ids[room["id"]] = true
        if not (room["progress"] is float or room["progress"] is int) or not is_finite(float(room["progress"])) or room["progress"] < 0:
            return null
        for role in ["pet", "employee"]:
            var id = room[role]
            if not (id is String):
                return null
            if id != "":
                if assigned.has(id) or not game.characters.has(id):
                    return null
                assigned[id] = true
                var info := GameData.identity_info(game.characters[id].get("identity", ""))
                if info.is_empty() or info["category"] != role:
                    return null
        if room["employee"] != "":
            if room["pet"] == "":
                return null
            var pet_info := GameData.identity_info(game.characters[room["pet"]]["identity"])
            var employee_info := GameData.identity_info(game.characters[room["employee"]]["identity"])
            if pet_info["system"] != employee_info["system"]:
                return null
    var equipped := {}
    for id in game.characters:
        var character = game.characters[id]
        if not (character is Dictionary) or not character.has_all(["identity", "tier", "books", "foreign"]):
            return null
        var info := GameData.identity_info(character["identity"])
        if info.is_empty() or not (character["books"] is Array) or not (character["foreign"] is String):
            return null
        if character["books"].size() > 8 or character["books"].size() + int(character["foreign"] != "") > GameData.slots(character["tier"]):
            return null
        if character["foreign"] != "" and (character["foreign"] == info["system"] or not game.collections[info["category"]].has(character["foreign"])):
            return null
        var native_count := 0
        var foreign_count := int(character["foreign"] != "")
        for book_id in character["books"]:
            if equipped.has(book_id) or not game.books.has(book_id):
                return null
            equipped[book_id] = id
            var book = game.books[book_id]
            if not (book is Dictionary):
                return null
            if book.get("category") != info["category"] or book.get("equipped_by") != id:
                return null
            if book.get("system") == info["system"]:
                native_count += 1
            elif book.get("system") == character["foreign"]:
                foreign_count += 1
            else:
                return null
        if native_count > 4 or foreign_count > 4:
            return null
    for id in game.books:
        var book = game.books[id]
        if not (id is String) or not id.begins_with("b") or not id.substr(1).is_valid_int():
            return null
        highest_id = maxi(highest_id, int(id.substr(1)))
        if not (book is Dictionary) or not book.has_all(["id", "category", "system", "equipped_by"]):
            return null
        if not (book["equipped_by"] is String) or not (book["category"] in ["pet", "employee"]) or not (book["system"] in GameData.SYSTEMS):
            return null
        if book.get("equipped_by", "") != "" and equipped.get(id, "") != book["equipped_by"]:
            return null
    if game.next_id <= highest_id:
        return null
    return game

static func _whole_number(value: Variant) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))
