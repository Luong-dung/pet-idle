extends SceneTree

var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("FAIL: " + message)

func near(a: float, b: float, message: String) -> void:
    check(absf(a - b) < 0.0001, message + " (%.6f vs %.6f)" % [a, b])

func _initialize() -> void:
    call_deferred("_run_and_quit")

func _run_and_quit() -> void:
    run_tests()
    print("GAME TESTS: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)

func run_tests() -> void:
    var identity_names := {}
    for category in ["pet", "employee"]:
        for system in GameData.SYSTEMS:
            for index in 3:
                var info := GameData.identity_info(GameData.identity(category, system, index))
                check(not info.is_empty(), "roster identity exists")
                check(not identity_names.has(info["name"]), "roster names unique")
                identity_names[info["name"]] = true
    check(identity_names.size() == 36, "18 pets and 18 employees")
    var g := GameState.new_game()
    check(g.rooms.size() == 3, "three free rooms")
    check(g.characters.size() == 1 and g.rooms[0]["pet"] != "", "starter pet enables production")
    for n in range(4, 9):
        check(GameData.room_cost(n) == [2000, 2400, 2880, 3456, 4148][n - 4], "room cost %d" % n)
    check(g.unlock_room() != "" and g.rooms.size() == 3, "cannot unlock without gold")
    g.balances["gold"] = 2000.0
    check(g.unlock_room() == "" and g.rooms.size() == 4 and g.balances["gold"] == 0, "room purchase exact cost")
    var pet0: String = g.rooms[0]["pet"]
    check(g.assign(1, "pet", pet0) != "", "no duplicate room assignment")
    var gold_employee := g.add_character("employee_gold_0", 0)
    var crystal_employee := g.add_character("employee_crystal_0", 0)
    check(g.assign(0, "employee", crystal_employee) != "", "wrong system employee rejected")
    check(g.assign(1, "employee", gold_employee) != "", "employee needs pet")
    var solo := g.production(g.rooms[0])
    near(solo["outputs"]["gold"], 100.0, "pet alone output")
    check(solo["outputs"].size() == 1, "native room has one resource")
    near(solo["cycle"], 100.0, "pet alone cycle")
    check(g.assign(0, "employee", gold_employee) == "", "same system employee accepted")
    var paired := g.production(g.rooms[0])
    near(paired["outputs"]["gold"], 110.0, "matching output +10 percent")
    near(paired["cycle"], 81.0, "employee then matching cycle")
    g.advance(80.0)
    near(g.balances["gold"], 0.0, "incomplete cycle credits nothing")
    near(g.rooms[0]["progress"], 80.0, "partial cycle retained")
    g.advance(1.0)
    near(g.balances["gold"], 110.0, "completed cycle credits")
    near(g.rooms[0]["progress"], 0.0, "completed cycle resets progress")
    g.last_timestamp = 1000.0
    near(g.catch_up(1000.0 + 30.0 * 3600.0), 86400.0, "offline cap")
    var credited: float = g.balances["gold"]
    near(g.catch_up(1000.0 + 30.0 * 3600.0), 0.0, "repeat resume no extra time")
    near(g.balances["gold"], credited, "repeat resume no extra credit")
    near(g.catch_up(1000.0), 0.0, "negative clock difference ignored")

    check(GameData.rank_name(0) == "F-" and GameData.rank_name(26) == "SSS+", "27 tier endpoints")
    check(GameData.rank_name(14) == "B+" and GameData.rank_name(15) == "A-", "B to A transition")
    check(GameData.rank_name(23) == "SS+" and GameData.rank_name(24) == "SSS-", "SS to SSS transition")
    for tier in 27:
        check(GameData.slots(tier) == tier / 3, "skill slot tier %d" % tier)
    var high_pet := g.add_character("pet_gold_1", 26)
    near(g.production({"pet": high_pet, "employee": "", "progress": 0.0})["outputs"]["gold"], 50.0 * pow(1.1, 26), "rank scales output per tier")
    near(g.production({"pet": high_pet, "employee": "", "progress": 0.0})["cycle"], 60.0, "rank does not scale pet cycle")
    var m1 := g.add_character("pet_gold_1", 0)
    var m2 := g.add_character("pet_gold_1", 0)
    check(g.merge([m1])["error"] != "", "merge needs two at minus")
    var merged := g.merge([m1, m2])
    check(merged["error"] == "" and g.characters[merged["id"]]["tier"] == 1, "minus merge")
    var plus_a := g.add_character("pet_gold_1", 2)
    var plus_b := g.add_character("pet_gold_1", 2)
    var plus_c := g.add_character("pet_gold_1", 2)
    check(g.merge([plus_a, plus_b])["error"] != "", "plus merge needs three")
    check(g.merge([plus_a, plus_b, plus_c])["error"] == "" , "plus to next major minus")
    check(g.merge([high_pet, high_pet])["error"] != "", "same instance cannot merge twice")
    check(g.merge([high_pet, m1])["error"] != "", "missing consumed copy rejected")
    var rank_game := GameState.new_game()
    var b_copies := []
    var ss_copies := []
    for n in 3:
        b_copies.append(rank_game.add_character("pet_gold_1", 14))
        ss_copies.append(rank_game.add_character("pet_gold_2", 23))
    var a_result := rank_game.merge(b_copies)
    var sss_result := rank_game.merge(ss_copies)
    check(a_result["error"] == "" and rank_game.characters[a_result["id"]]["tier"] == 15, "B+ merges to A-")
    check(sss_result["error"] == "" and rank_game.characters[sss_result["id"]]["tier"] == 24, "SS+ merges to SSS-")
    check(rank_game.merge([rank_game.add_character("pet_gold_0", 26), rank_game.add_character("pet_gold_0", 26), rank_game.add_character("pet_gold_0", 26)])["error"] != "", "SSS+ cannot merge")

    var query_game := GameState.new_game()
    var low_crystal := query_game.add_character("pet_crystal_0", 1)
    var high_crystal := query_game.add_character("pet_crystal_0", 20)
    var top_gold := query_game.add_character("pet_gold_1", 26)
    var query_employee := query_game.add_character("employee_gold_0", 24)
    check(query_game.character_ids("pet")[0] == top_gold and query_game.character_ids("pet")[1] == high_crystal, "inventory sorts highest rank first")
    check(query_game.character_ids("pet", "crystal") == [high_crystal, low_crystal], "system filter retains descending rank")
    check(query_game.character_ids("pet", "crystal", 20) == [high_crystal], "exact tier and system filter")
    check(query_game.character_ids("employee") == [query_employee], "category filter excludes pets")
    check(query_game.character_ids("pet", "unknown").is_empty() and query_game.character_ids("pet", "", 27).is_empty(), "invalid filters return no copies")
    var query_clone := GameState.from_dict(JSON.parse_string(JSON.stringify(query_game.to_dict())))
    check(query_clone.character_ids("pet", "crystal") == [high_crystal, low_crystal], "sorted filtering survives save round trip")

    var bulk := GameState.new_game()
    for n in 11:
        bulk.add_character("pet_gold_0", 0)
    var employee_a := bulk.add_character("employee_gold_0", 0)
    var employee_b := bulk.add_character("employee_gold_0", 0)
    check(bulk.merge_all_preview("pet") == 10 and bulk.merge_all_preview("employee") == 1, "batch preview includes cascading merges per category")
    check(bulk.merge_all_preview("bad") == 0 and bulk.merge_all("bad")["error"] != "", "invalid batch category rejected")
    var bulk_result := bulk.merge_all("pet")
    check(bulk_result["error"] == "" and bulk_result["count"] == 10, "batch merge cascades F- to E-")
    var bulk_pet: String = bulk.rooms[0]["pet"]
    check(bulk_pet != "" and bulk.characters[bulk_pet]["identity"] == "pet_gold_0" and bulk.characters[bulk_pet]["tier"] == 3, "batch merge preserves assigned upgraded pet")
    check(bulk.character_ids("pet").size() == 1 and bulk.characters.has(employee_a) and bulk.characters.has(employee_b), "batch merge leaves employee inventory alone")
    check(bulk.merge_all_preview("pet") == 0 and bulk.merge_all("pet")["count"] == 0, "batch merge is idempotent without copies")
    check(bulk.merge_all("employee")["count"] == 1, "employee batch merge remains separate")
    check(GameState.from_dict(JSON.parse_string(JSON.stringify(bulk.to_dict()))) != null, "batch merge leaves a valid save")

    var equipped_game := GameState.new_game()
    var working_pet := equipped_game.add_character("pet_gold_1", 3)
    var spare_pet := equipped_game.add_character("pet_gold_1", 3)
    var working_employee := equipped_game.add_character("employee_gold_1", 0)
    check(equipped_game.assign(1, "pet", working_pet) == "" and equipped_game.assign(1, "employee", working_employee) == "", "batch fixture has working matching pair")
    equipped_game.balances["gold"] = 1000.0
    var equipped_book: String = equipped_game.buy_book("pet", "gold")["id"]
    check(equipped_game.equip_book(spare_pet, equipped_book) == "", "batch fixture has equipped spare")
    check(equipped_game.merge_all_preview("pet") == 1 and equipped_game.merge_all("pet")["count"] == 1, "batch merges equipped duplicate")
    check(equipped_game.books[equipped_book]["equipped_by"] == "", "batch returns equipped book")
    check(equipped_game.rooms[1]["pet"] != "" and equipped_game.rooms[1]["employee"] == working_employee and equipped_game.characters[equipped_game.rooms[1]["pet"]]["tier"] == 4, "batch preserves compatible room pair")
    check(GameState.from_dict(JSON.parse_string(JSON.stringify(equipped_game.to_dict()))) != null, "equipped batch save remains valid")

    var manual_room := GameState.new_game()
    var manual_spare := manual_room.add_character("pet_gold_1", 0)
    var manual_assigned := manual_room.add_character("pet_gold_1", 0)
    var manual_employee := manual_room.add_character("employee_gold_1", 0)
    check(manual_room.assign(1, "pet", manual_assigned) == "" and manual_room.assign(1, "employee", manual_employee) == "", "manual merge fixture has assigned pair")
    var manual_result := manual_room.merge([manual_spare, manual_assigned])
    check(manual_result["error"] == "" and manual_room.rooms[1]["pet"] == manual_result["id"] and manual_room.rooms[1]["employee"] == manual_employee, "manual merge preserves assigned pair regardless of copy order")
    var capped := GameState.new_game()
    for n in 3:
        capped.add_character("pet_gold_2", 26)
    check(capped.merge_all_preview("pet") == 0 and capped.merge_all("pet")["count"] == 0, "batch merge respects maximum rank")

    for banner_id in ["normal_pet", "normal_employee", "vip_pet", "vip_employee"]:
        var banner := GameData.banner(banner_id)
        var weight_sum := 0
        for weight in banner["weights"]:
            weight_sum += weight
        check(weight_sum == 100, banner_id + " major odds sum")
        check(not (5 in banner["ranks"]) and not (8 in banner["ranks"]), banner_id + " excludes A/SSS")
        check(banner["price"] == (1000 if banner["currency"] == "gold" else 30000), banner_id + " fixed price")
    check(GameData.NORMAL_WEIGHTS == [35, 28, 20, 12, 5], "normal exact odds")
    check(GameData.VIP_WEIGHTS == [90, 10] and GameData.SUBTIER_WEIGHTS == [60, 30, 10], "VIP and subtier exact odds")
    check(GameData.PACKAGES == {1: 1, 10: 11, 100: 111}, "bonus package counts")
    check(GameData.weighted_index([35, 28, 20, 12, 5], 34) == 0 and GameData.weighted_index([35, 28, 20, 12, 5], 35) == 1, "odds boundaries")
    var package_game := GameState.new_game()
    package_game.balances["gold"] = 10000.0
    var ten_draw := package_game.draw("normal_employee", 10)
    check(ten_draw["error"] == "" and ten_draw["ids"].size() == 11 and package_game.balances["gold"] == 0, "10 paid gives 11 total")
    check(g.draw("vip_pet", 1)["error"] != "", "insufficient crystal rejects draw")
    g.balances["gold"] = 100000.0
    g.rng.seed = 42
    var draw_result := g.draw("normal_pet", 100)
    check(draw_result["error"] == "" and draw_result["ids"].size() == 111 and g.balances["gold"] == 0, "100 paid gives 111 total at fixed cost")
    for id in draw_result["ids"]:
        check(g.characters[id]["tier"] / 3 in GameData.NORMAL_RANKS, "normal draw eligible rank")

    var e_pet := g.add_character("pet_gold_2", 3)
    var e_emp := g.add_character("employee_gold_2", 3)
    var foreign_pet := g.add_character("pet_crystal_2", 0)
    check(g.collections["pet"].has("crystal") and not g.collections["employee"].has("fashion"), "independent collections")
    check(g.equip_collection(e_pet, "crystal") == "", "foreign collection equip")
    check(g.equip_collection(e_pet, "crystal") != "", "collection buff cannot stack")
    var foreign_output: Dictionary = g.production({"pet": e_pet, "employee": "", "progress": 0.0})["outputs"]
    near(foreign_output["gold"], 20.0 * pow(1.1, 3), "foreign collection leaves native production alone")
    near(foreign_output["crystal"], 20.0 * pow(1.1, 3) * 0.5, "foreign collection produces its own resource")
    check(foreign_output.size() == 2, "two resource systems only")
    check(g.equip_collection(foreign_pet, "gold") != "", "F rank has zero slots")
    check(g.equip_collection(e_emp, "crystal") == "", "employee collection independently unlocked")
    check(g.equip_collection(e_emp, "fashion") != "", "locked employee collection rejected")
    check(g.unequip_collection(e_pet) == "", "collection unequip")
    g.balances["gold"] = 10000.0
    var book_result := g.buy_book("pet", "gold")
    check(book_result["error"] == "" and book_result["cost"] == 1000, "first book price")
    check(GameData.book_cost(1) == 1100 and GameData.book_cost(2) == 1210, "book price ceiling growth")
    var book_id: String = book_result["id"]
    check(g.assign(1, "pet", e_pet) == "", "pet assigned for equipment timing test")
    g.rooms[1]["progress"] = 10.0
    check(g.equip_book(e_pet, book_id) == "", "equip owned native book")
    near(g.rooms[1]["progress"], 0.0, "equipment change resets partial cycle")
    check(g.equip_book(e_pet, book_id) != "", "book cannot be equipped twice")
    near(g._book_bonus(g.characters[e_pet]), 0.1, "one book 10 percent full effect")
    check(g.equip_book(e_emp, book_id) != "", "pet book cannot equip employee")
    check(g.unequip_book(book_id) == "" and g.books[book_id]["equipped_by"] == "", "unequip returns book")
    var book_ids := []
    for n in 4:
        var result := g.buy_book("pet", "gold")
        check(result["error"] == "", "buy book %d" % n)
        book_ids.append(result["id"])
    var s_pet := g.add_character("pet_gold_2", 18)
    for n in 4:
        check(g.equip_book(s_pet, book_ids[n]) == "", "equip copy %d" % n)
        near(g._book_bonus(g.characters[s_pet]), GameData.BOOK_STACK[n + 1], "stack schedule %d" % (n + 1))
    check(g.equip_book(s_pet, book_id) != "", "four per system maximum")
    var duplicate := g.add_character("pet_gold_2", 18)
    check(g.merge([s_pet, duplicate])["error"] == "", "merge equipped character")
    for id in book_ids:
        check(g.books[id]["equipped_by"] == "", "merge returns equipped book")
    var sss_pet := g.add_character("pet_gold_2", 24)
    check(g.equip_collection(sss_pet, "crystal") == "", "SSS foreign system unlocked")
    for id in book_ids:
        check(g.equip_book(sss_pet, id) == "", "SSS equips four native books")
    g.balances["crystal"] = 10000.0
    var foreign_books := []
    for n in 3:
        var foreign_result := g.buy_book("pet", "crystal")
        check(foreign_result["error"] == "", "foreign system book purchase")
        foreign_books.append(foreign_result["id"])
        check(g.equip_book(sss_pet, foreign_result["id"]) == "", "foreign book occupies collection system slot")
    check(g.characters[sss_pet]["books"].size() + 1 == 8, "SSS 4+4 slot split")
    near(g._book_bonus(g.characters[sss_pet]), 1.0, "foreign books do not alter native output")
    var split_outputs: Dictionary = g.production({"pet": sss_pet, "employee": "", "progress": 0.0})["outputs"]
    var split_base: float = 20.0 * pow(1.1, 24)
    near(split_outputs["gold"], split_base * 2.0, "gold books increase only gold output")
    near(split_outputs["crystal"], split_base * 1.1, "crystal books increase only crystal output")
    check(g.equip_book(sss_pet, g.buy_book("pet", "crystal")["id"]) != "", "foreign system capped at four occupied slots")
    check(g.unequip_collection(sss_pet) == "", "unequipping collection returns foreign books")
    for id in foreign_books:
        check(g.books[id]["equipped_by"] == "", "foreign book returned with collection skill")

    var multi := GameState.new_game()
    var multi_pet := multi.add_character("pet_gold_0", 3)
    multi.add_character("pet_crystal_0", 0)
    check(multi.assign(0, "pet", multi_pet) == "", "ranked pet assigned for multiple resources")
    check(multi.equip_collection(multi_pet, "crystal") == "", "crystal collection enables second resource")
    var multi_production := multi.production(multi.rooms[0])
    near(multi_production["outputs"]["gold"], 100.0 * pow(1.1, 3), "native gold output unchanged")
    near(multi_production["outputs"]["crystal"], 50.0 * pow(1.1, 3), "crystal output half base")
    var multi_copy := GameState.from_dict(JSON.parse_string(JSON.stringify(multi.to_dict())))
    check(multi_copy != null and multi_copy.characters[multi_pet]["foreign"] == "crystal", "multi-resource equipment survives save round trip")
    multi_copy.last_timestamp = 1000.0
    near(multi_copy.catch_up(1200.0), 200.0, "offline time counted once")
    near(multi_copy.balances["gold"], 2.0 * multi_production["outputs"]["gold"], "offline credits native gold")
    near(multi_copy.balances["crystal"], 2.0 * multi_production["outputs"]["crystal"], "offline credits foreign crystal")
    var multi_gold: float = multi_copy.balances["gold"]
    var multi_crystal: float = multi_copy.balances["crystal"]
    near(multi_copy.catch_up(1200.0), 0.0, "multi-resource resume idempotent")
    near(multi_copy.balances["gold"], multi_gold, "repeat offline does not credit gold")
    near(multi_copy.balances["crystal"], multi_crystal, "repeat offline does not credit crystal")
    var multi_employee := multi_copy.add_character("employee_gold_0", 0)
    check(multi_copy.assign(0, "employee", multi_employee) == "", "matching employee may join multi-resource pet")
    var paired_outputs: Dictionary = multi_copy.production(multi_copy.rooms[0])["outputs"]
    near(paired_outputs["gold"], multi_production["outputs"]["gold"] * 1.1, "matching pair increases native system only")
    near(paired_outputs["crystal"], multi_production["outputs"]["crystal"], "employee creates no foreign output bonus")
    check(multi_copy.assign(0, "employee", multi_copy.add_character("employee_crystal_0", 0)) != "", "foreign resource does not permit mismatched employee")

    var employee_game := GameState.new_game()
    employee_game.balances["gold"] = 10000.0
    var ranked_employee := employee_game.add_character("employee_gold_0", 12)
    check(employee_game.assign(0, "employee", ranked_employee) == "", "ranked employee assigned")
    for n in 4:
        var employee_book := employee_game.buy_book("employee", "gold")
        check(employee_book["error"] == "", "employee book purchase")
        check(employee_game.equip_book(ranked_employee, employee_book["id"]) == "", "employee book equip")
    near(employee_game.production(employee_game.rooms[0])["cycle"], maxf(1.0, (100.0 - 10.0 * pow(1.1, 12) * 2.0) * 0.9), "employee books amplify reduction, then pair time")

    var clone := GameState.from_dict(g.to_dict())
    check(clone != null and clone.characters.size() == g.characters.size(), "state round trip")
    check(GameState.from_dict({"version": 1}) == null, "malformed state rejected")
    var bad := g.to_dict().duplicate(true)
    bad["balances"]["gold"] = -1.0
    check(GameState.from_dict(bad) == null, "negative balance rejected")
    bad = g.to_dict().duplicate(true)
    bad["next_id"] = 1
    check(GameState.from_dict(bad) == null, "ID collision save rejected")
    bad = g.to_dict().duplicate(true)
    bad["collections"]["pet"].erase("gold")
    check(GameState.from_dict(bad) == null, "missing permanent collection rejected")
    bad = g.to_dict().duplicate(true)
    bad["rooms"][1]["pet"] = bad["rooms"][0]["pet"]
    check(GameState.from_dict(bad) == null, "duplicate room assignment in save rejected")
    var json_clone := GameState.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
    check(json_clone != null, "JSON save round trip")
    g.last_timestamp = Time.get_unix_time_from_system()
    var save_error := g.save_game()
    check(save_error == "", "atomic save file write")
    if save_error == "":
        check(g.save_game() == "", "backup save file write")
        var loaded := GameState.load_game()
        check(loaded.characters.size() == g.characters.size() and loaded.rooms.size() == g.rooms.size(), "load persisted inventory and rooms")
        var first_balance: float = loaded.balances["gold"]
        var loaded_again := GameState.load_game()
        check(loaded_again.balances["gold"] >= first_balance and loaded_again.balances["gold"] - first_balance < 0.001, "repeated load does not duplicate production")
    var broken := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
    if broken != null:
        broken.store_string("{bad JSON")
        broken.close()
        var recovered := GameState.load_game()
        check(recovered.characters.size() == g.characters.size(), "corrupt primary recovers from backup")
    else:
        check(false, "could not write malformed save fixture")
