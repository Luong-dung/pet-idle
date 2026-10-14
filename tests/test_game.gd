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
    near(solo["output"], 100.0, "pet alone output")
    near(solo["cycle"], 100.0, "pet alone cycle")
    check(g.assign(0, "employee", gold_employee) == "", "same system employee accepted")
    var paired := g.production(g.rooms[0])
    near(paired["output"], 110.0, "matching output +10 percent")
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
    near(g.production({"pet": high_pet, "employee": "", "progress": 0.0})["output"], 50.0 * pow(1.1, 26), "rank scales output per tier")
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
    near(g.production({"pet": e_pet, "employee": "", "progress": 0.0})["output"], 20.0 * pow(1.1, 3) * 1.5, "foreign pet buff")
    check(g.equip_collection(foreign_pet, "gold") != "", "F rank has zero slots")
    check(g.equip_collection(e_emp, "crystal") == "", "employee collection independently unlocked")
    check(g.equip_collection(e_emp, "fashion") != "", "locked employee collection rejected")
    check(g.unequip_collection(e_pet) == "", "collection unequip")
    g.balances["gold"] = 10000.0
    var book_result := g.buy_book("pet", "gold")
    check(book_result["error"] == "" and book_result["cost"] == 1000, "first book price")
    check(GameData.book_cost(1) == 1100 and GameData.book_cost(2) == 1210, "book price ceiling growth")
    var book_id: String = book_result["id"]
    check(g.equip_book(e_pet, book_id) == "", "equip owned native book")
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

    var clone := GameState.from_dict(g.to_dict())
    check(clone != null and clone.characters.size() == g.characters.size(), "state round trip")
    check(GameState.from_dict({"version": 1}) == null, "malformed state rejected")
    var bad := g.to_dict().duplicate(true)
    bad["balances"]["gold"] = -1.0
    check(GameState.from_dict(bad) == null, "negative balance rejected")
    var json_clone := GameState.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
    check(json_clone != null, "JSON save round trip")
    g.last_timestamp = Time.get_unix_time_from_system()
    var save_error := g.save_game()
    check(save_error == "", "atomic save file write")
    if save_error == "":
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
        check(recovered.rooms.size() == 3 and recovered.characters.size() == 1, "corrupt save recovers new game")
    else:
        check(false, "could not write malformed save fixture")
