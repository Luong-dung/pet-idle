class_name GameData
extends RefCounted

const SYSTEMS := ["gold", "crystal", "essence", "knowledge", "components", "fashion"]
const SYSTEM_NAMES := ["Vàng", "Tinh thể", "Tinh hoa", "Tri thức", "Linh kiện", "Thời trang"]
const SYSTEM_ICONS := ["✦", "◆", "❀", "✧", "⚙", "✿"]
const SYSTEM_COLORS := [Color("f4b942"), Color("8b8ce9"), Color("ec88bd"), Color("64b9dc"), Color("9cc78c"), Color("dc9dc9")]
const PET_NAMES := [
    ["Mèo Mật", "Cún Nắng", "Thỏ Đồng"],
    ["Cá Sao", "Cáo Pha Lê", "Rồng Tím"],
    ["Bướm Hồng", "Hươu Hoa", "Gấu Mây"],
    ["Cú Sách", "Sóc Mực", "Mèo Kính"],
    ["Chồn Máy", "Rùa Bánh Răng", "Cún Robot"],
    ["Thỏ Nơ", "Cáo Lụa", "Gấu Váy"]
]
const EMPLOYEE_NAMES := [
    ["An Mật", "Bình Nắng", "Chi Đồng"],
    ["Duyên Sao", "Em Pha Lê", "Giang Tím"],
    ["Hà Hồng", "Khoa Hoa", "Linh Mây"],
    ["Mai Sách", "Nam Mực", "Oanh Kính"],
    ["Phúc Máy", "Quân Bánh Răng", "Sơn Robot"],
    ["Thảo Nơ", "Uyên Lụa", "Vân Váy"]
]
const PET_OUTPUT := [100.0, 50.0, 20.0]
const PET_CYCLE := [100.0, 60.0, 30.0]
const RANK_MAJOR := ["F", "E", "D", "C", "B", "A", "S", "SS", "SSS"]
const SUBTIER := ["-", "", "+"]
const NORMAL_RANKS := [0, 1, 2, 3, 4]
const NORMAL_WEIGHTS := [35, 28, 20, 12, 5]
const VIP_RANKS := [6, 7]
const VIP_WEIGHTS := [90, 10]
const SUBTIER_WEIGHTS := [60, 30, 10]
const PACKAGES := {1: 1, 10: 11, 100: 111}
const START_PET := "pet_gold_0" # PROVISIONAL bootstrap.
const START_BALANCES := {"gold": 0.0, "crystal": 0.0, "essence": 0.0, "knowledge": 0.0, "components": 0.0, "fashion": 0.0}
const CYCLE_FLOOR := 1.0 # PROVISIONAL safety guard, not a balance rule.
const OFFLINE_CAP := 86400.0
const BOOK_BASE_COST := 1000
const BOOK_COST_GROWTH := 1.1
const BOOK_STACK := [0.0, 0.1, 0.3, 0.6, 1.0]
# PROVISIONAL: one book type per system/category; a full stack gives +100% pet output or employee reduction.
const BOOK_FULL_EFFECT := 1.0

static func identity(category: String, system: String, index: int) -> String:
    return "%s_%s_%d" % [category, system, index]

static func identity_info(identity_id: String) -> Dictionary:
    var parts := identity_id.split("_")
    if parts.size() != 3 or not (parts[0] in ["pet", "employee"]) or not (parts[1] in SYSTEMS):
        return {}
    if not parts[2].is_valid_int():
        return {}
    var idx := int(parts[2])
    if idx < 0 or idx > 2:
        return {}
    var sys_idx := SYSTEMS.find(parts[1])
    return {"category": parts[0], "system": parts[1], "index": idx,
        "name": PET_NAMES[sys_idx][idx] if parts[0] == "pet" else EMPLOYEE_NAMES[sys_idx][idx]}

static func rank_name(tier: int) -> String:
    if tier < 0 or tier > 26:
        return "?"
    return RANK_MAJOR[tier / 3] + SUBTIER[tier % 3]

static func slots(tier: int) -> int:
    return clampi(tier / 3, 0, 8)

static func room_cost(room_number: int) -> int:
    if room_number <= 3:
        return 0
    # Bound huge values before float overflow; these rooms are unbuyable in practice.
    if room_number > 100:
        return 9223372036854775807
    return int(ceil(2000.0 * pow(1.2, room_number - 4)))

static func book_cost(purchases: int) -> int:
    if purchases < 0 or purchases > 300:
        return 9223372036854775807
    var cost := BOOK_BASE_COST
    for i in purchases:
        if cost > 838488366986797800:
            return 9223372036854775807
        cost = (cost * 11 + 9) / 10 # Exact integer ceil of the next 10% increase.
    return cost

static func banner(banner_id: String) -> Dictionary:
    match banner_id:
        "normal_pet": return {"category": "pet", "currency": "gold", "price": 1000, "ranks": NORMAL_RANKS, "weights": NORMAL_WEIGHTS}
        "normal_employee": return {"category": "employee", "currency": "gold", "price": 1000, "ranks": NORMAL_RANKS, "weights": NORMAL_WEIGHTS}
        "vip_pet": return {"category": "pet", "currency": "crystal", "price": 30000, "ranks": VIP_RANKS, "weights": VIP_WEIGHTS}
        "vip_employee": return {"category": "employee", "currency": "crystal", "price": 30000, "ranks": VIP_RANKS, "weights": VIP_WEIGHTS}
        _: return {}

static func weighted_index(weights: Array, roll: int) -> int:
    var total := 0
    for weight in weights:
        total += int(weight)
    if roll < 0 or roll >= total:
        return -1
    for i in weights.size():
        roll -= int(weights[i])
        if roll < 0:
            return i
    return -1
