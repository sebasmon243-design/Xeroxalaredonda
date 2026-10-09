-- Vehicle Presets para YimMenuV2 (GTA V Enhanced)
-- Spawnea un vehiculo por nombre, aplica pintura/rines/mejoras y guarda/carga presets en .json.
--
-- Instalacion (todo dentro de %appdata%\YimMenuV2\scripts\):
--   scripts\vehicle_presets.lua    -> %appdata%\YimMenuV2\scripts\vehicle_presets.lua
--   scripts\vehicle_presets\*.json -> %appdata%\YimMenuV2\scripts\vehicle_presets\
--
-- YimMenuV2 descarga el script ante cualquier error de Lua, asi que todo lo que puede
-- fallar va dentro de pcall. script.yield y las funciones "latentes" de YimMenu
-- (Vehicle.create, request_control) se llaman fuera de pcall, en el callback del boton.
--
-- Importante: en YimMenuV2 una funcion latente que espera MAS DE UN frame corrompe la pila
-- de Lua (el menu deja de dibujarse y el juego puede cerrarse). Por eso el modelo se carga
-- aqui con script.yield antes de Vehicle.create, y el control de red se pide con
-- request_control(0) (un solo intento, sin esperas) repetido en un bucle propio.

local TITLE = "Vehicle Presets"

if not natives.are_natives_loaded() then
    natives.load_natives()
end

-- Ids de mod de vehiculo (SET_VEHICLE_MOD / GET_VEHICLE_MOD)
local MOD_ENGINE, MOD_BRAKES, MOD_TRANSMISSION = 11, 12, 13
local MOD_SUSPENSION, MOD_ARMOR = 15, 16
local MOD_FRONT_WHEELS, MOD_REAR_WHEELS = 23, 24
local TOGGLE_TURBO = 18

-- Configuracion actual (lo que se ve en el menu, se spawnea, se guarda y se carga)
local cfg = {
    model = "adder",
    r = 255, g = 0, b = 0,        -- color primario RGB
    r2 = 0, g2 = 0, b2 = 0,       -- color secundario RGB
    wheel_type = 7,               -- 0 Sport, 1 Muscle, 2 Lowrider, 3 SUV, 4 Offroad, 5 Tuner, 7 High End...
    wheel_index = 0,              -- -1 = rines de serie
    engine = 3, brakes = 2, transmission = 2, suspension = 3, armor = 4,
    turbo = 1,                    -- 1 = con turbo, 0 = sin turbo
}

-- Orden de los campos numericos en el .json y etiquetas del menu
local NUM_FIELDS = {
    { "r", "Primario R" }, { "g", "Primario G" }, { "b", "Primario B" },
    { "r2", "Secundario R" }, { "g2", "Secundario G" }, { "b2", "Secundario B" },
    { "wheel_type", "Tipo de rin" }, { "wheel_index", "Indice de rin" },
    { "engine", "Motor" }, { "brakes", "Frenos" }, { "transmission", "Transmision" },
    { "suspension", "Suspension" }, { "armor", "Blindaje" }, { "turbo", "Turbo (0/1)" },
}

local preset_name = ""
local preset_list = {}

---------------------------------------------------------------- utilidades

local function notify_error(msg) notify.error(TITLE, msg) end
local function notify_ok(msg) notify.success(TITLE, msg) end

-- Ejecuta fn protegida: un error se muestra como aviso en vez de descargar el script.
-- No usar con funciones que esperan frames (Vehicle.create, script.yield).
local function try(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if not ok then
        pcall(log.warn, TITLE .. ": " .. tostring(a))
        pcall(notify.error, TITLE, "Error: " .. tostring(a))
        return false
    end
    return true, a, b
end

local function clamp(v, lo, hi)
    v = math.floor(tonumber(v) or 0)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Nombre de archivo seguro: letras, numeros, "_" y "-"
local function valid_name(name)
    return type(name) == "string" and name:match("^[%w_%-]+$") ~= nil
end

-- Nombre de modelo ("adder") o hash numerico ("-1216765807")
local function valid_model(model)
    return type(model) == "string" and model:match("^%-?[%w_]+$") ~= nil
end

-- Los natives de hash aceptan el nombre como texto o el hash como numero
local function model_arg(model)
    return tonumber(model) or model
end

---------------------------------------------------------------- archivos .json

local PRESET_DIR = ""

local function preset_path(name)
    return PRESET_DIR .. "/" .. name .. ".json"
end

local function refresh_list()
    local list = {}
    for _, path in ipairs(FileMgr.FindFiles(PRESET_DIR, ".json")) do
        local name = path:match("([^/\\]+)%.json$")
        if name then list[#list + 1] = name end
    end
    table.sort(list)
    preset_list = list
end

try(function()
    PRESET_DIR = FileMgr.GetMenuRootPath() .. "/vehicle_presets"
    FileMgr.CreateDir(PRESET_DIR)
    refresh_list()
end)

local function save_preset(name)
    local lines = { '  "model": "' .. cfg.model .. '"' }
    for _, f in ipairs(NUM_FIELDS) do
        lines[#lines + 1] = '  "' .. f[1] .. '": ' .. string.format("%d", math.floor(cfg[f[1]]))
    end
    return FileMgr.WriteFileContent(preset_path(name), "{\n" .. table.concat(lines, ",\n") .. "\n}\n")
end

-- Lee un JSON plano: "clave": "texto"  o  "clave": numero
local function load_preset(name)
    if not FileMgr.DoesFileExist(preset_path(name)) then return false end
    local text = FileMgr.ReadFileContent(preset_path(name)) or ""

    local model = text:match('"model"%s*:%s*"([^"]*)"')
    if model and valid_model(model) then cfg.model = model:lower() end
    for k, v in text:gmatch('"([%w_]+)"%s*:%s*(%-?%d+)') do
        if k ~= "model" and cfg[k] ~= nil then cfg[k] = math.floor(tonumber(v)) end
    end
    return true
end

---------------------------------------------------------------- vehiculo

-- Pone el mod al nivel pedido, limitado al maximo que tiene ese vehiculo (-1 = de serie)
local function set_mod_level(veh, mod_type, wanted)
    local max_index = VEHICLE.GET_NUM_VEHICLE_MODS(veh, mod_type) - 1
    VEHICLE.SET_VEHICLE_MOD(veh, mod_type, clamp(wanted, -1, max_index), false)
end

local function apply_mods(veh)
    VEHICLE.SET_VEHICLE_MOD_KIT(veh, 0)
    VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(veh, clamp(cfg.r, 0, 255), clamp(cfg.g, 0, 255), clamp(cfg.b, 0, 255))
    VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(veh, clamp(cfg.r2, 0, 255), clamp(cfg.g2, 0, 255), clamp(cfg.b2, 0, 255))

    VEHICLE.SET_VEHICLE_WHEEL_TYPE(veh, clamp(cfg.wheel_type, 0, 12))
    set_mod_level(veh, MOD_FRONT_WHEELS, cfg.wheel_index)
    set_mod_level(veh, MOD_REAR_WHEELS, cfg.wheel_index) -- motos

    set_mod_level(veh, MOD_ENGINE, cfg.engine)
    set_mod_level(veh, MOD_BRAKES, cfg.brakes)
    set_mod_level(veh, MOD_TRANSMISSION, cfg.transmission)
    set_mod_level(veh, MOD_SUSPENSION, cfg.suspension)
    set_mod_level(veh, MOD_ARMOR, cfg.armor)
    VEHICLE.TOGGLE_VEHICLE_MOD(veh, TOGGLE_TURBO, cfg.turbo == 1)
end

local function current_vehicle()
    return PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
end

-- Lee un int que el native escribe en un puntero
local function read_rgb(getter, veh)
    local pr, pg, pb = memory.allocate(8), memory.allocate(8), memory.allocate(8)
    local ok, err = pcall(getter, veh, pr, pg, pb)
    local r, g, b = pr:get_int(), pg:get_int(), pb:get_int()
    memory.free(pr); memory.free(pg); memory.free(pb)
    if not ok then error(err, 0) end
    return r, g, b
end

-- Copia la configuracion del vehiculo en el que estas a cfg
local function capture(veh)
    local hash = ENTITY.GET_ENTITY_MODEL(veh)
    local name = (VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(hash) or ""):lower()
    -- El nombre visible no siempre coincide con el modelo; si no coincide guardamos el hash
    if valid_model(name) and util.joaat(name) == hash then cfg.model = name else cfg.model = tostring(hash) end

    cfg.r, cfg.g, cfg.b = read_rgb(VEHICLE.GET_VEHICLE_CUSTOM_PRIMARY_COLOUR, veh)
    cfg.r2, cfg.g2, cfg.b2 = read_rgb(VEHICLE.GET_VEHICLE_CUSTOM_SECONDARY_COLOUR, veh)
    cfg.wheel_type = VEHICLE.GET_VEHICLE_WHEEL_TYPE(veh)
    cfg.wheel_index = VEHICLE.GET_VEHICLE_MOD(veh, MOD_FRONT_WHEELS)
    cfg.engine = VEHICLE.GET_VEHICLE_MOD(veh, MOD_ENGINE)
    cfg.brakes = VEHICLE.GET_VEHICLE_MOD(veh, MOD_BRAKES)
    cfg.transmission = VEHICLE.GET_VEHICLE_MOD(veh, MOD_TRANSMISSION)
    cfg.suspension = VEHICLE.GET_VEHICLE_MOD(veh, MOD_SUSPENSION)
    cfg.armor = VEHICLE.GET_VEHICLE_MOD(veh, MOD_ARMOR)
    cfg.turbo = VEHICLE.IS_TOGGLE_MOD_ON(veh, TOGGLE_TURBO) and 1 or 0
end

---------------------------------------------------------------- acciones (botones)

-- Evita que dos pulsaciones seguidas lancen dos spawns/aplicaciones a la vez
local busy = false

-- Espera a que el modelo este cargado usando script.yield (fuera de pcall)
local function stream_model(m)
    for _ = 1, 100 do -- ~5 s
        if STREAMING.HAS_MODEL_LOADED(m) then return true end
        STREAMING.REQUEST_MODEL(m)
        script.yield(50)
    end
    return STREAMING.HAS_MODEL_LOADED(m)
end

-- Pide control de red con intentos sueltos (request_control(0) nunca espera frames)
local function take_control(veh)
    for _ = 1, 60 do -- ~3 s
        if veh:has_control() then return true end
        veh:request_control(0)
        script.yield(50)
    end
    return veh:has_control()
end

local function do_spawn()
    local ok, m = try(function()
        local m = valid_model(cfg.model) and model_arg(cfg.model)
        if not m or not STREAMING.IS_MODEL_IN_CDIMAGE(m) or not STREAMING.IS_MODEL_A_VEHICLE(m) then
            notify_error("Modelo invalido: " .. tostring(cfg.model))
            return nil
        end
        return m
    end)
    if not ok or not m then return end

    local name = cfg.model
    if not stream_model(m) then
        notify_error("El modelo tardo demasiado en cargar: " .. name)
        return
    end

    local ok2, pos, heading = try(function()
        local ped = PLAYER.PLAYER_PED_ID()
        -- Delante del jugador, a la distancia del largo del vehiculo (como el spawner de YimMenu)
        local mn, mx = Vector3.new(), Vector3.new()
        MISC.GET_MODEL_DIMENSIONS(m, mn, mx)
        local dist = math.max(6.0, (mx.y - mn.y) + 2.0)
        return ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(ped, 0.0, dist, 0.0), ENTITY.GET_ENTITY_HEADING(ped)
    end)
    if not ok2 or not pos then return end

    -- El modelo ya esta cargado, asi que Vehicle.create no espera frames
    local veh = Vehicle.create(m, pos, heading)
    if not veh or not veh:is_valid() then
        notify_error("No se pudo crear el vehiculo: " .. name)
        return
    end

    if try(function()
        local handle = veh:get_handle()
        apply_mods(handle)
        PED.SET_PED_INTO_VEHICLE(PLAYER.PLAYER_PED_ID(), handle, -1)
    end) then
        notify_ok("Spawneado: " .. name)
    end
end

local function do_apply()
    local ok, handle = try(current_vehicle)
    if not ok then return end
    if handle == 0 then notify_error("No estas en un vehiculo") return end

    if not take_control(Vehicle.new(handle)) then
        notify_error("No se pudo obtener el control del vehiculo (puede ser de otro jugador)")
        return
    end

    if try(apply_mods, handle) then notify_ok("Mods aplicados") end
end

local function action_spawn()
    if busy then notify_error("Espera a que termine la accion anterior") return end
    busy = true
    do_spawn()
    busy = false
end

local function action_apply()
    if busy then notify_error("Espera a que termine la accion anterior") return end
    busy = true
    do_apply()
    busy = false
end

local function action_capture()
    try(function()
        local handle = current_vehicle()
        if handle == 0 then notify_error("No estas en un vehiculo") return end
        capture(handle)
        notify_ok("Configuracion leida: " .. cfg.model)
    end)
end

local function action_save()
    try(function()
        if not valid_name(preset_name) then notify_error("Nombre invalido (usa letras, numeros, _ o -)") return end
        if not valid_model(cfg.model) then notify_error("Modelo invalido: " .. tostring(cfg.model)) return end
        if save_preset(preset_name) then
            refresh_list()
            notify_ok("Guardado: " .. preset_name .. ".json")
        else
            notify_error("No se pudo guardar " .. preset_name .. ".json")
        end
    end)
end

local function action_load()
    try(function()
        if not valid_name(preset_name) then notify_error("Escribe o elige el nombre de un preset") return end
        if load_preset(preset_name) then
            notify_ok("Cargado: " .. preset_name .. ".json")
        else
            notify_error("No existe: " .. preset_name .. ".json")
        end
    end)
end

---------------------------------------------------------------- interfaz

-- Los ids de comando son globales en YimMenuV2; un sufijo por carga evita
-- "command already exists" si la instancia anterior aun no se ha destruido al recargar
local UID = "_" .. tostring(util.time())
local function cmd(name) return "vehpresets_" .. name .. UID end

local function build_ui()
    local sub = menu.get_submenu(TITLE)
    local cat = sub:add_category("Presets")

    local config_group = cat:add_group("Vehiculo")
    -- Se dibuja cada frame: solo ImGui, sin natives ni esperas
    config_group:imgui(function()
        cfg.model = ImGui.InputText("Modelo", cfg.model)
        for _, f in ipairs(NUM_FIELDS) do
            cfg[f[1]] = ImGui.InputInt(f[2], cfg[f[1]])
        end
    end)

    local actions = cat:add_group("Acciones")
    actions:add_button(cmd("spawn"), "Spawnear", "Spawnea el vehiculo con esta configuracion", action_spawn)
    actions:add_button(cmd("apply"), "Aplicar al vehiculo actual", "Aplica pintura, rines y mejoras al vehiculo en el que estas", action_apply)
    actions:add_button(cmd("capture"), "Leer vehiculo actual", "Copia la configuracion del vehiculo en el que estas", action_capture)

    local files = cat:add_group("Presets (.json)")
    files:imgui(function()
        preset_name = ImGui.InputText("Nombre del preset", preset_name)
        ImGui.Text("Guardados en scripts\\vehicle_presets\\")
        for _, name in ipairs(preset_list) do
            if ImGui.Selectable(name, name == preset_name) then preset_name = name end
        end
    end)
    files:add_button(cmd("save"), "Guardar preset", "Guarda la configuracion como <nombre>.json", action_save)
    files:add_button(cmd("load"), "Cargar preset", "Carga <nombre>.json en la configuracion", action_load)
    files:add_button(cmd("refresh"), "Actualizar lista", "Vuelve a leer la carpeta vehicle_presets", function() try(refresh_list) end)
end

-- Al recargar, la instancia anterior del script puede seguir viva un momento. Si su submenu
-- "Vehicle Presets" aun existe, colgarse de el haria que desaparezca al destruirse la
-- instancia vieja, asi que se espera (max ~10 s) a que se vaya antes de crear el menu.
if menu.find_submenu(TITLE) then
    script.run_in_callback(function()
        for _ = 1, 200 do
            if not menu.find_submenu(TITLE) then break end
            script.yield(50)
        end
        build_ui()
    end)
else
    build_ui()
end
