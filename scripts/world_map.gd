class_name WorldMap
extends Control
## Top-down low-poly 3D island showing every room as an open-roof diorama.
## Presentation only: it reads GameState and reports taps; it never mutates gameplay data.

signal room_tapped(index: int)

const UI = preload("res://scripts/ui_text.gd")
const ROOM_SPACING := 6.0
const ROOM_SIZE := 4.6
const COLUMNS := 2
const CAMERA_DISTANCE := 19.0
const CAMERA_PITCH := deg_to_rad(56.0)
const TAP_SLOP := 12.0
const MAX_RENDER_SCALE := 2.5
const FLOOR_COLORS := [Color("ffc19e"), Color("a8e2c0"), Color("cdb8f2"), Color("ffe08a")]

var viewport: SubViewport
var screen: TextureRect
var camera: Camera3D
var world: Node3D
var terrain: Node3D
var rooms_root: Node3D
var selection: Node3D
var hint: Label

var selected := 0
var focus := Vector3.ZERO
var target_focus := Vector3.ZERO
var _signature := ""
var _rows := -1
var _room_nodes: Array = []
var _last_progress: Array = []
var _actors: Array = []
var _pops: Array = []
var _clouds: Array = []
var _materials := {}
var _time := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragged := false

func _init() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    custom_minimum_size = Vector2(0, 220)

func _ready() -> void:
    viewport = SubViewport.new()
    viewport.own_world_3d = true
    viewport.transparent_bg = false
    viewport.msaa_3d = Viewport.MSAA_4X
    viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
    viewport.size = Vector2i(360, 300)
    add_child(viewport)
    screen = TextureRect.new()
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    screen.stretch_mode = TextureRect.STRETCH_SCALE
    screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
    screen.texture = viewport.get_texture()
    add_child(screen)
    _build_world()
    _build_hint()
    resized.connect(_fit_viewport)
    _fit_viewport()

func _build_hint() -> void:
    var chip := PanelContainer.new()
    var style := UITheme.box(Color(1, 1, 1, 0.82), 14)
    style.content_margin_top = 4
    style.content_margin_bottom = 4
    style.content_margin_left = 10
    style.content_margin_right = 10
    chip.add_theme_stylebox_override("panel", style)
    chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    chip.position = Vector2(10, 10)
    add_child(chip)
    hint = Label.new()
    hint.text = UI.t("rooms.map_hint")
    hint.add_theme_font_size_override("font_size", 11)
    hint.add_theme_color_override("font_color", UITheme.INK_SOFT)
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    chip.add_child(hint)

## Render at the device's physical resolution so the 3D view stays crisp on phones.
func _fit_viewport() -> void:
    if viewport == null or size.x < 1 or size.y < 1:
        return
    var scale_factor: float = clampf(get_viewport().get_final_transform().get_scale().x, 1.0, MAX_RENDER_SCALE)
    viewport.size = Vector2i(maxi(1, int(size.x * scale_factor)), maxi(1, int(size.y * scale_factor)))

func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
    var key := "%s:%.2f" % [color.to_html(), emission]
    if _materials.has(key):
        return _materials[key]
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.85
    if color.a < 1.0:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    if emission > 0.0:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = emission
    _materials[key] = material
    return material

func _mesh(parent: Node3D, mesh: Mesh, color: Color, position: Vector3, scale_value: Vector3 = Vector3.ONE, shadows := true) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = _material(color)
    instance.position = position
    instance.scale = scale_value
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(instance)
    return instance

func _box(parent: Node3D, size_value: Vector3, color: Color, position: Vector3, shadows := true) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size_value
    return _mesh(parent, mesh, color, position, Vector3.ONE, shadows)

func _sphere(parent: Node3D, radius: float, color: Color, position: Vector3, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 20
    mesh.rings = 10
    return _mesh(parent, mesh, color, position, scale_value)

func _cylinder(parent: Node3D, top: float, bottom: float, height: float, color: Color, position: Vector3) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = top
    mesh.bottom_radius = bottom
    mesh.height = height
    mesh.radial_segments = 16
    return _mesh(parent, mesh, color, position)

func _label3d(parent: Node3D, text: String, position: Vector3, font_size: int = 48, color: Color = UITheme.INK) -> Label3D:
    var label := Label3D.new()
    label.text = text
    label.font = UITheme.font(900)
    label.font_size = font_size
    label.pixel_size = 0.01
    label.outline_size = 14
    label.outline_modulate = Color.WHITE
    label.modulate = color
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.position = position
    label.no_depth_test = true
    label.render_priority = 2
    parent.add_child(label)
    return label

func _build_world() -> void:
    world = Node3D.new()
    viewport.add_child(world)
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("8fd8f2")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("fff4ea")
    environment.ambient_light_energy = 0.3
    var env_node := WorldEnvironment.new()
    env_node.environment = environment
    world.add_child(env_node)
    var sun := DirectionalLight3D.new()
    sun.rotation = Vector3(deg_to_rad(-58), deg_to_rad(-38), 0)
    sun.light_energy = 0.72
    sun.light_color = Color("fff1dc")
    sun.shadow_enabled = true
    sun.shadow_opacity = 0.55
    sun.shadow_blur = 1.5
    sun.directional_shadow_max_distance = 45.0
    world.add_child(sun)
    camera = Camera3D.new()
    camera.keep_aspect = Camera3D.KEEP_WIDTH
    camera.fov = 52.0
    world.add_child(camera)
    var water := PlaneMesh.new()
    water.size = Vector2(400, 400)
    _mesh(world, water, Color("7fcbec"), Vector3(0, -0.9, -40), Vector3.ONE, false)
    terrain = Node3D.new()
    world.add_child(terrain)
    rooms_root = Node3D.new()
    world.add_child(rooms_root)
    selection = Node3D.new()
    world.add_child(selection)
    var edge := ROOM_SIZE / 2.0 + 0.32
    for bar in [[Vector3(edge * 2.0 + 0.2, 0.12, 0.2), Vector3(0, 0, -edge)], [Vector3(edge * 2.0 + 0.2, 0.12, 0.2), Vector3(0, 0, edge)],
            [Vector3(0.2, 0.12, edge * 2.0 + 0.2), Vector3(-edge, 0, 0)], [Vector3(0.2, 0.12, edge * 2.0 + 0.2), Vector3(edge, 0, 0)]]:
        var piece := _box(selection, bar[0], Color("ff6f96"), bar[1], false)
        piece.material_override = _material(Color("ff6f96"), 0.9)
    for i in 3:
        var cloud := Node3D.new()
        world.add_child(cloud)
        for j in 3:
            _sphere(cloud, 0.9 - j * 0.15, Color(1, 1, 1, 0.92), Vector3(j * 0.9 - 0.9, 0, 0), Vector3(1, 0.55, 0.8))
        cloud.position = Vector3(-10 + i * 9, 7.5, -4 - i * 7)
        _clouds.append(cloud)
    _update_camera(true)

static func slot_position(index: int) -> Vector3:
    var col := index % COLUMNS
    var row := index / COLUMNS
    return Vector3((col - 0.5) * ROOM_SPACING, 0, -row * ROOM_SPACING)

func _build_terrain(rows: int) -> void:
    for child in terrain.get_children():
        child.queue_free()
    var depth := rows * ROOM_SPACING + 8.0
    var center_z := -(rows - 1) * ROOM_SPACING / 2.0
    _box(terrain, Vector3(17.0, 1.0, depth + 0.6), Color("c9a27a"), Vector3(0, -0.62, center_z), false)
    _box(terrain, Vector3(16.4, 0.5, depth), Color("86cc6e"), Vector3(0, -0.25, center_z), false)
    _box(terrain, Vector3(1.3, 0.04, depth - 1.0), Color("ecd29f"), Vector3(0, 0.01, center_z), false)
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var z := 3.0
    while z > -depth + 4.0:
        for side in [-1, 1]:
            var pos := Vector3(side * rng.randf_range(6.6, 7.6), 0, z + rng.randf_range(-0.8, 0.8))
            if rng.randf() < 0.7:
                _tree(pos, rng)
            else:
                _bush(pos, rng)
        z -= 3.0
    for i in rows * 6:
        var pos := Vector3(rng.randf_range(-7.8, 7.8), 0.05, rng.randf_range(-depth + 5.0, 3.5))
        if absf(pos.x) > 0.9 and absf(absf(pos.x) - 3.0) > 2.5:
            _sphere(terrain, 0.12, [Color("ffffff"), Color("ffb3c7"), Color("ffe27a")][i % 3], pos)

func _tree(pos: Vector3, rng: RandomNumberGenerator) -> void:
    var height := rng.randf_range(1.0, 1.5)
    _cylinder(terrain, 0.14, 0.18, height, Color("a67853"), pos + Vector3(0, height / 2.0, 0))
    var leaf: Color = [Color("6cc28a"), Color("82d29b"), Color("5fb67f")][rng.randi() % 3]
    _cylinder(terrain, 0.0, 0.95, 1.5, leaf, pos + Vector3(0, height + 0.55, 0))
    _cylinder(terrain, 0.0, 0.7, 1.1, leaf.lightened(0.1), pos + Vector3(0, height + 1.25, 0))

func _bush(pos: Vector3, rng: RandomNumberGenerator) -> void:
    var green := Color("7fcf8c")
    _sphere(terrain, 0.55, green, pos + Vector3(0, 0.35, 0), Vector3(1.2, 0.8, 1.0))
    _sphere(terrain, 0.4, green.lightened(0.1), pos + Vector3(0.45, 0.3, 0.2))
    if rng.randf() < 0.5:
        _sphere(terrain, 0.1, Color("ff8fa3"), pos + Vector3(0.1, 0.78, 0.35))

## Rebuilds dioramas only when room count or assignments change; otherwise updates progress.
func sync(game: GameState, selected_index: int) -> void:
    if viewport == null:
        return
    selected = selected_index
    var parts := [str(game.rooms.size())]
    for room in game.rooms:
        parts.append("%s/%s" % [_identity(game, room["pet"]), _identity(game, room["employee"])])
    var signature := "|".join(parts)
    var rows := int(ceil((game.rooms.size() + 1) / float(COLUMNS)))
    if rows != _rows:
        _rows = rows
        _build_terrain(rows)
    if signature != _signature:
        _signature = signature
        _rebuild_rooms(game)
    for i in game.rooms.size():
        var room: Dictionary = game.rooms[i]
        var data := game.production(room)
        var node: Dictionary = _room_nodes[i]
        var ratio := 0.0
        if not data.is_empty():
            ratio = clampf(room["progress"] / maxf(data["cycle"], 0.001), 0.0, 1.0)
            if room["progress"] + 0.01 < _last_progress[i]:
                _pop(i, data)
        _last_progress[i] = room["progress"]
        if node.has("fill"):
            node["fill"].scale.x = maxf(ratio, 0.001)
            node["fill"].position.x = -1.4 + 1.4 * ratio
    var target := slot_position(clampi(selected, 0, game.rooms.size()))
    selection.position = target + Vector3(0, 0.08, 0)

func _identity(game: GameState, id: String) -> String:
    return game.characters[id]["identity"] if id != "" and game.characters.has(id) else ""

func _rebuild_rooms(game: GameState) -> void:
    for child in rooms_root.get_children():
        child.queue_free()
    _room_nodes.clear()
    _actors.clear()
    _last_progress.clear()
    for i in game.rooms.size():
        _room_nodes.append(_build_room(i, game.rooms[i], game))
        _last_progress.append(game.rooms[i]["progress"])
    _build_plot(game.rooms.size())

func _build_room(index: int, room: Dictionary, game: GameState) -> Dictionary:
    var node := Node3D.new()
    node.position = slot_position(index)
    rooms_root.add_child(node)
    var floor_color: Color = FLOOR_COLORS[index % FLOOR_COLORS.size()]
    var half := ROOM_SIZE / 2.0
    _box(node, Vector3(ROOM_SIZE + 0.3, 0.3, ROOM_SIZE + 0.3), Color("f7efe6"), Vector3(0, 0.12, 0))
    _box(node, Vector3(ROOM_SIZE, 0.08, ROOM_SIZE), floor_color, Vector3(0, 0.3, 0))
    var wall := Color("f6ebe0")
    var trim := floor_color.darkened(0.25)
    _box(node, Vector3(ROOM_SIZE + 0.3, 1.5, 0.25), wall, Vector3(0, 1.0, -half - 0.02))
    _box(node, Vector3(ROOM_SIZE + 0.3, 0.14, 0.32), trim, Vector3(0, 1.8, -half - 0.02))
    var side := -1 if index % COLUMNS == 0 else 1
    _box(node, Vector3(0.25, 1.5, ROOM_SIZE + 0.3), wall, Vector3(side * (half + 0.02), 1.0, 0))
    _box(node, Vector3(0.32, 0.14, ROOM_SIZE + 0.3), trim, Vector3(side * (half + 0.02), 1.8, 0))
    _box(node, Vector3(0.9, 0.7, 0.05), Color("bfe6ff"), Vector3(-0.9, 1.1, -half + 0.12))
    _box(node, Vector3(0.9, 0.7, 0.05), Color("bfe6ff"), Vector3(0.9, 1.1, -half + 0.12))
    var rug := CylinderMesh.new()
    rug.top_radius = 1.05
    rug.bottom_radius = 1.05
    rug.height = 0.04
    rug.radial_segments = 28
    var producing: bool = room["pet"] != "" and game.characters.has(room["pet"])
    var pet_system := ""
    if producing:
        pet_system = GameData.identity_info(game.characters[room["pet"]]["identity"])["system"]
    var rug_color: Color = GameData.SYSTEM_COLORS[GameData.SYSTEMS.find(pet_system)].lightened(0.35) if producing else Color("f4e6ee")
    _mesh(node, rug, rug_color, Vector3(-0.5, 0.36, 0.5), Vector3.ONE, false)
    _box(node, Vector3(0.9, 0.5, 0.6), Color("d9a57b"), Vector3(1.35, 0.6, -1.4))
    _sphere(node, 0.22, Color("8fd18f"), Vector3(-1.75, 0.6, -1.7))
    _cylinder(node, 0.18, 0.14, 0.3, Color("e48f6b"), Vector3(-1.75, 0.48, -1.7))
    var result := {"node": node}
    _label3d(node, UI.t("rooms.room_number", [index + 1]), Vector3(0, 0.75, half + 0.45), 40, UITheme.TITLE)
    if producing:
        _box(node, Vector3(2.9, 0.22, 0.12), Color("5b4f6b"), Vector3(0, 2.0, -half + 0.05), false)
        var fill := _box(node, Vector3(2.8, 0.16, 0.14), GameData.SYSTEM_COLORS[GameData.SYSTEMS.find(pet_system)], Vector3(0, 2.0, -half + 0.08), false)
        fill.material_override = _material(GameData.SYSTEM_COLORS[GameData.SYSTEMS.find(pet_system)], 0.35)
        result["fill"] = fill
        var pet := _pet_model(game.characters[room["pet"]]["identity"])
        pet.position = Vector3(-0.5, 0.38, 0.5)
        pet.scale = Vector3.ONE * 1.45
        node.add_child(pet)
        _actors.append({"node": pet, "base": pet.position.y, "phase": index * 1.7, "kind": "pet"})
    else:
        var plus := _label3d(node, "+", Vector3(-0.5, 0.9, 0.5), 96, Color("c9bcd6"))
        plus.outline_size = 0
    if room["employee"] != "" and game.characters.has(room["employee"]):
        var employee := _employee_model(game.characters[room["employee"]]["identity"])
        employee.position = Vector3(1.1, 0.34, 0.6)
        employee.scale = Vector3.ONE * 1.35
        node.add_child(employee)
        _actors.append({"node": employee, "base": employee.position.y, "phase": index * 1.3 + 0.5, "kind": "employee"})
    return result

func _build_plot(index: int) -> void:
    var node := Node3D.new()
    node.position = slot_position(index)
    rooms_root.add_child(node)
    _box(node, Vector3(ROOM_SIZE, 0.1, ROOM_SIZE), Color("d8c09b"), Vector3(0, 0.05, 0), false)
    var half := ROOM_SIZE / 2.0
    for i in 5:
        var t := -half + i * ROOM_SIZE / 4.0
        for post in [Vector3(t, 0, -half), Vector3(t, 0, half), Vector3(-half, 0, t), Vector3(half, 0, t)]:
            _box(node, Vector3(0.16, 0.7, 0.16), Color("f7e7cf"), post + Vector3(0, 0.35, 0))
    for rail in [[Vector3(ROOM_SIZE, 0.1, 0.08), Vector3(0, 0.5, -half)], [Vector3(ROOM_SIZE, 0.1, 0.08), Vector3(0, 0.5, half)],
            [Vector3(0.08, 0.1, ROOM_SIZE), Vector3(-half, 0.5, 0)], [Vector3(0.08, 0.1, ROOM_SIZE), Vector3(half, 0.5, 0)]]:
        _box(node, rail[0], Color("f7e7cf"), rail[1])
    _box(node, Vector3(0.12, 1.3, 0.12), Color("a67853"), Vector3(0, 0.65, 0))
    _box(node, Vector3(1.4, 0.8, 0.1), Color("ffe08a"), Vector3(0, 1.35, 0.05))
    _label3d(node, UI.t("rooms.plot_sign", [_amount(GameData.room_cost(index + 1))]), Vector3(0, 2.35, 0), 44, Color("8a5a1e"))

func _amount(value: float) -> String:
    if value >= 1000000:
        return ("%.2f" % (value / 1000000.0)).replace(".", ",") + " tr"
    return str(int(value))

func _pet_model(identity_id: String) -> Node3D:
    var info := GameData.identity_info(identity_id)
    var base: Color = GameData.SYSTEM_COLORS[GameData.SYSTEMS.find(info["system"])]
    var light := base.lightened(0.45)
    var root := Node3D.new()
    _sphere(root, 0.5, base, Vector3(0, 0.45, 0), Vector3(1.0, 0.85, 0.9))
    _sphere(root, 0.3, light, Vector3(0, 0.38, 0.28), Vector3(1.0, 0.9, 0.6))
    _sphere(root, 0.42, base, Vector3(0, 1.05, 0.08))
    match int(info["index"]):
        0:
            for side in [-1, 1]:
                var ear := _cylinder(root, 0.0, 0.16, 0.36, base.darkened(0.1), Vector3(side * 0.24, 1.48, 0.05))
                ear.rotation.z = -side * 0.35
        1:
            for side in [-1, 1]:
                var ear := _sphere(root, 0.17, base.darkened(0.2), Vector3(side * 0.42, 1.0, 0.05), Vector3(0.6, 1.4, 0.9))
                ear.rotation.z = side * 0.3
        _:
            for side in [-1, 1]:
                var ear := _sphere(root, 0.12, base.lightened(0.15), Vector3(side * 0.16, 1.6, 0.0), Vector3(0.9, 2.6, 0.8))
                ear.rotation.z = -side * 0.15
    for side in [-1, 1]:
        _sphere(root, 0.065, Color("3d3347"), Vector3(side * 0.15, 1.1, 0.45))
        _sphere(root, 0.07, Color("ffb2c1"), Vector3(side * 0.26, 0.97, 0.4), Vector3(1.0, 0.6, 0.5))
    _sphere(root, 0.05, Color("d37585"), Vector3(0, 1.0, 0.5))
    _sphere(root, 0.15, light, Vector3(0, 0.45, -0.48))
    var accent: Color = [Color("f6d774"), Color("c1a8ee"), Color("f3a6c5")][int(info["index"])]
    _sphere(root, 0.1, accent, Vector3(0.22, 1.42, 0.2))
    return root

func _employee_model(identity_id: String) -> Node3D:
    var info := GameData.identity_info(identity_id)
    var base: Color = GameData.SYSTEM_COLORS[GameData.SYSTEMS.find(info["system"])]
    var hair: Color = [Color("5b4033"), Color("2f2a3a"), Color("c98a4b")][int(info["index"])]
    var root := Node3D.new()
    _cylinder(root, 0.26, 0.36, 0.75, base, Vector3(0, 0.4, 0))
    _box(root, Vector3(0.3, 0.32, 0.05), Color("fff7e8"), Vector3(0, 0.5, 0.31))
    _sphere(root, 0.32, Color("f7dac1"), Vector3(0, 1.05, 0))
    _sphere(root, 0.34, hair, Vector3(0, 1.16, -0.05), Vector3(1.0, 0.75, 1.0))
    for side in [-1, 1]:
        _sphere(root, 0.05, Color("3d3347"), Vector3(side * 0.11, 1.03, 0.29))
    _sphere(root, 0.09, base.lightened(0.3), Vector3(0.24, 1.36, 0.05))
    return root

func _pop(index: int, data: Dictionary) -> void:
    if index >= _room_nodes.size():
        return
    var parts := []
    for system in GameData.SYSTEMS:
        if data["outputs"].has(system):
            parts.append("+%s %s" % [_amount(data["outputs"][system]), GameData.SYSTEM_ICONS[GameData.SYSTEMS.find(system)]])
    var system_color: Color = GameData.SYSTEM_COLORS[GameData.SYSTEMS.find(data["outputs"].keys()[0])] if not data["outputs"].is_empty() else UITheme.ACCENT
    var label := _label3d(_room_nodes[index]["node"], " ".join(parts), Vector3(-0.5, 2.2, 0.5), 44, system_color.darkened(0.3))
    _pops.append({"node": label, "age": 0.0})

func _process(delta: float) -> void:
    if not is_visible_in_tree():
        return
    _time += delta
    for actor in _actors:
        var node: Node3D = actor["node"]
        if not is_instance_valid(node):
            continue
        if actor["kind"] == "pet":
            node.position.y = actor["base"] + absf(sin(_time * 3.2 + actor["phase"])) * 0.18
            node.rotation.y = sin(_time * 1.1 + actor["phase"]) * 0.35
        else:
            node.rotation.z = sin(_time * 2.0 + actor["phase"]) * 0.06
            node.rotation.y = sin(_time * 0.7 + actor["phase"]) * 0.4
    for pop in _pops.duplicate():
        pop["age"] += delta
        var label: Label3D = pop["node"]
        if not is_instance_valid(label) or pop["age"] > 1.6:
            if is_instance_valid(label):
                label.queue_free()
            _pops.erase(pop)
            continue
        label.position.y += delta * 0.9
        label.modulate.a = 1.0 - pop["age"] / 1.6
        label.outline_modulate.a = label.modulate.a
    for cloud in _clouds:
        cloud.position.x += delta * 0.35
        if cloud.position.x > 12.0:
            cloud.position.x = -12.0
    var pulse := 1.0 + sin(_time * 4.0) * 0.02
    selection.scale = Vector3(pulse, 1.0, pulse)
    _update_camera(false, delta)

func _update_camera(immediate: bool, delta: float = 0.0) -> void:
    var max_back := -maxf(0.0, (_rows - 1) * ROOM_SPACING)
    target_focus.z = clampf(target_focus.z, max_back, 0.0)
    target_focus.x = clampf(target_focus.x, -2.5, 2.5)
    focus = target_focus if immediate else focus.lerp(target_focus, clampf(delta * 10.0, 0.0, 1.0))
    var offset := Vector3(0, sin(CAMERA_PITCH), cos(CAMERA_PITCH)) * CAMERA_DISTANCE
    camera.position = focus + offset + Vector3(0, 0, -1.5)
    camera.look_at(focus + Vector3(0, 0, -1.5), Vector3.UP)

func focus_on(index: int) -> void:
    target_focus.z = slot_position(index).z + ROOM_SPACING * 0.4

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _pressing = true
            _dragged = false
            _press_pos = event.position
        elif _pressing:
            _pressing = false
            if not _dragged:
                var index := pick(event.position)
                if index >= 0:
                    room_tapped.emit(index)
        accept_event()
    elif event is InputEventMouseMotion and _pressing:
        if event.position.distance_to(_press_pos) > TAP_SLOP:
            _dragged = true
        if _dragged:
            var units_per_px := 14.0 / maxf(size.x, 1.0)
            target_focus.z -= event.relative.y * units_per_px * 1.4
            target_focus.x -= event.relative.x * units_per_px
        accept_event()

## Converts a local control position into a slot index (rooms, then the unlock plot), or -1.
func pick(local_position: Vector2) -> int:
    if camera == null or size.x < 1 or size.y < 1:
        return -1
    var pixel := local_position / size * Vector2(viewport.size)
    var origin := camera.project_ray_origin(pixel)
    var direction := camera.project_ray_normal(pixel)
    if absf(direction.y) < 0.0001:
        return -1
    var t := (0.3 - origin.y) / direction.y
    if t < 0:
        return -1
    var hit := origin + direction * t
    var col := int(round(hit.x / ROOM_SPACING + 0.5))
    var row := int(round(-hit.z / ROOM_SPACING))
    if col < 0 or col >= COLUMNS or row < 0:
        return -1
    var center := slot_position(row * COLUMNS + col)
    if absf(hit.x - center.x) > ROOM_SIZE / 2.0 + 0.3 or absf(hit.z - center.z) > ROOM_SIZE / 2.0 + 0.3:
        return -1
    var index := row * COLUMNS + col
    return index if index <= _room_nodes.size() else -1
