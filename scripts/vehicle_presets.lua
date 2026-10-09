-- Vehicle Presets para YimMenuV2 (GTA V Enhanced)
-- Spawnea un vehiculo por nombre, aplica pintura/rines/mejoras y guarda/carga presets en .json.
--
-- Instalacion (todo dentro de %appdata%\YimMenuV2\scripts\):
--   scripts\vehicle_presets.lua    -> %appdata%\YimMenuV2\scripts\vehicle_presets.lua
--   scripts\vehicle_presets\*.json -> %appdata%\YimMenuV2\scripts\vehicle_presets\
--   scripts\vehicle_presets\garaje\ -> %appdata%\YimMenuV2\scripts\vehicle_presets\garaje\ (vehiculos del modpack)
--
-- La prueba del garaje (Garaje > Prueba automatica) escribe en scripts\vehicle_presets\:
--   prueba_garaje.txt (resultado de cada vehiculo), resumen_prueba.txt y garaje_ok\ (los que funcionan).
--
-- YimMenuV2 descarga el script ante cualquier error de Lua, asi que todo lo que puede
-- fallar va dentro de pcall. Las funciones que esperan varios frames (Vehicle.create,
-- script.yield) se llaman fuera de pcall, directamente en el callback del boton.

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
    if not FileMgr.DoesFileExist(preset_path(name)) then return false, "No existe: " .. name .. ".json" end
    local text = FileMgr.ReadFileContent(preset_path(name)) or ""

    -- Sin un modelo valido el preset no sirve: no se toca cfg
    local model = text:match('"model"%s*:%s*"([^"]*)"')
    if not model or not valid_model(model) then return false, "Modelo invalido en " .. name .. ".json" end
    cfg.model = model:lower()
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

-- Pide el modelo hasta que carga o pasan `timeout_ms` (espera frames: fuera de pcall).
-- Vehicle.create solo espera ~30 frames, poco para un modelo pesado con el disco ocupado.
local function load_model(model, timeout_ms)
    local waited = 0
    while true do
        local ok, loaded = pcall(function()
            if STREAMING.HAS_MODEL_LOADED(model) then return true end
            STREAMING.REQUEST_MODEL(model)
            return false
        end)
        if not ok then return false end
        if loaded then return true end
        if waited >= timeout_ms then return false end
        script.yield(50)
        waited = waited + 50
    end
end

-- Carga el modelo, crea el vehiculo en `pos` y le aplica `apply_fn(handle)` (espera frames: fuera de pcall).
-- Devuelve el Vehicle (nil si no se creo) y, si algo fallo, el tipo de fallo y su detalle.
local function create_vehicle(model, pos, heading, apply_fn)
    if not load_model(model, 10000) then
        pcall(STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED, model)
        return nil, "NO_CARGA", "el modelo no cargo en 10 s"
    end
    local veh = Vehicle.create(model, pos, heading)
    if not veh or not veh:is_valid() then
        pcall(STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED, model)
        return nil, "NO_SPAWN", "el juego no creo el vehiculo"
    end
    local ok, err = pcall(apply_fn, veh:get_handle())
    if not ok then return veh, "PARCIAL", "error al aplicar mejoras: " .. tostring(err) end
    return veh
end

---------------------------------------------------------------- acciones (botones)

-- Spawnea `model` delante del jugador, le aplica `apply_fn(handle)` y lo mete dentro.
-- Se llama desde un boton (Vehicle.create espera frames).
local function spawn_with(model, label, apply_fn)
    local ok, pos, heading = try(function()
        if not STREAMING.IS_MODEL_IN_CDIMAGE(model) or not STREAMING.IS_MODEL_A_VEHICLE(model) then
            notify_error("Modelo invalido: " .. tostring(label))
            return nil
        end
        local ped = PLAYER.PLAYER_PED_ID()
        -- 6 m delante del jugador para no aparecer dentro de otro vehiculo
        return ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(ped, 0.0, 6.0, 0.0), ENTITY.GET_ENTITY_HEADING(ped)
    end)
    if not ok or not pos then return end

    local veh, _, detail = create_vehicle(model, pos, heading, apply_fn)
    if not veh then
        notify_error("No se pudo crear el vehiculo: " .. tostring(label) .. " (" .. detail .. ")")
        return
    end
    if detail then
        pcall(log.warn, TITLE .. ": " .. detail)
        notify_error(detail)
    end

    if try(function() PED.SET_PED_INTO_VEHICLE(PLAYER.PLAYER_PED_ID(), veh:get_handle(), -1) end) and not detail then
        notify_ok("Spawneado: " .. tostring(label))
    end
end

local function action_spawn()
    if not valid_model(cfg.model) then notify_error("Modelo invalido: " .. tostring(cfg.model)) return end
    spawn_with(model_arg(cfg.model), cfg.model, apply_mods)
end

local function action_apply()
    local handle = 0
    if not try(function() handle = current_vehicle() end) then return end
    if handle == 0 then notify_error("No estas en un vehiculo") return end

    -- Pedir control de red si el vehiculo no es nuestro (espera frames: fuera de pcall).
    -- request_control no devuelve nada, asi que se vuelve a comprobar despues.
    local veh = Vehicle.new(handle)
    local _, has = try(function() return veh:has_control() end)
    if not has then
        veh:request_control()
        _, has = try(function() return veh:has_control() end)
        if not has then notify_error("No se pudo tomar el control del vehiculo") return end
    end

    if try(apply_mods, handle) then notify_ok("Mods aplicados") end
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
        local loaded, err = load_preset(preset_name)
        if loaded then
            notify_ok("Cargado: " .. preset_name .. ".json")
        else
            notify_error(err)
        end
    end)
end

---------------------------------------------------------------- garaje (vehiculos guardados)
-- scripts\vehicle_presets\garaje\<carpeta>\<nombre>.json en el formato de vehiculo guardado de
-- YimMenuV2 (el mismo que usa su menu "Saved Vehicles"). Solo se leen, nunca se escriben.

-- Lector de JSON minimo: objetos, listas, textos, numeros, true/false/null
local function json_decode(text)
    local pos = 1
    local value

    local function fail(msg) error("JSON invalido (" .. msg .. ") en la posicion " .. pos, 0) end
    local function skip() pos = text:find("[^ \t\r\n]", pos) or #text + 1 end

    local function str()
        local out = {}
        pos = pos + 1
        while true do
            local c = text:sub(pos, pos)
            if c == "" then fail("texto sin cerrar") end
            if c == '"' then pos = pos + 1 return table.concat(out) end
            if c == "\\" then
                local e = text:sub(pos + 1, pos + 1)
                local map = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
                if e == "u" then
                    local code = tonumber(text:sub(pos + 2, pos + 5), 16) or 63
                    out[#out + 1] = code < 128 and string.char(code) or "?"
                    pos = pos + 6
                else
                    out[#out + 1] = map[e] or e
                    pos = pos + 2
                end
            else
                out[#out + 1] = c
                pos = pos + 1
            end
        end
    end

    function value()
        skip()
        local c = text:sub(pos, pos)
        if c == "{" then
            local obj = {}
            pos = pos + 1
            skip()
            if text:sub(pos, pos) == "}" then pos = pos + 1 return obj end
            while true do
                skip()
                if text:sub(pos, pos) ~= '"' then fail("se esperaba una clave") end
                local k = str()
                skip()
                if text:sub(pos, pos) ~= ":" then fail("se esperaba ':'") end
                pos = pos + 1
                obj[k] = value()
                skip()
                local d = text:sub(pos, pos)
                pos = pos + 1
                if d == "}" then return obj end
                if d ~= "," then fail("se esperaba ',' o '}'") end
            end
        elseif c == "[" then
            local arr = {}
            pos = pos + 1
            skip()
            if text:sub(pos, pos) == "]" then pos = pos + 1 return arr end
            while true do
                arr[#arr + 1] = value()
                skip()
                local d = text:sub(pos, pos)
                pos = pos + 1
                if d == "]" then return arr end
                if d ~= "," then fail("se esperaba ',' o ']'") end
            end
        elseif c == '"' then
            return str()
        elseif text:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
        elseif text:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
        elseif text:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil
        else
            local num = text:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", pos)
            if not num or num == "" then fail("valor desconocido") end
            pos = pos + #num
            return tonumber(num) or fail("numero")
        end
    end

    local result = value()
    skip()
    if pos <= #text then fail("texto de sobra") end
    return result
end

-- Slots de mod en el orden de YimMenuV2 (indice = slot de SET_VEHICLE_MOD)
local MOD_NAMES = {
    [0] = "MOD_SPOILERS", "MOD_FRONTBUMPER", "MOD_REARBUMPER", "MOD_SIDESKIRT", "MOD_EXHAUST", "MOD_FRAME",
    "MOD_GRILLE", "MOD_HOOD", "MOD_FENDER", "MOD_RIGHTFENDER", "MOD_ROOF", "MOD_ENGINE", "MOD_BRAKES",
    "MOD_TRANSMISSION", "MOD_HORNS", "MOD_SUSPENSION", "MOD_ARMOR", "", "MOD_TURBO", "", "MOD_TIRESMOKE", "",
    "MOD_XENONHEADLIGHTS", "MOD_FRONTWHEEL", "MOD_REARWHEEL", "MOD_PLATEHOLDER", "MOD_VANITYPLATES",
    "MOD_TRIMDESIGN", "MOD_ORNAMENTS", "MOD_DASHBOARD", "MOD_DIALDESIGN", "MOD_DOORSPEAKERS", "MOD_SEATS",
    "MOD_STEERINGWHEELS", "MOD_COLUMNSHIFTERLEVERS", "MOD_PLAQUES", "MOD_SPEAKERS", "MOD_TRUNK", "MOD_HYDRAULICS",
    "MOD_ENGINEBLOCK", "MOD_AIRFILTER", "MOD_STRUTS", "MOD_ARCHCOVER", "MOD_AERIALS", "MOD_TRIM", "MOD_TANK",
    "MOD_WINDOWS", "", "MOD_LIVERY",
}
local SLOT_TIRESMOKE, SLOT_XENON = 20, 22

local function int(v) return type(v) == "number" and math.floor(v) or nil end
local function rgb3(v)
    if type(v) ~= "table" then return nil end
    local r, g, b = int(v[1]), int(v[2]), int(v[3])
    if r and g and b then return clamp(r, 0, 255), clamp(g, 0, 255), clamp(b, 0, 255) end
end

-- Igual que SavedVehicles::SpawnFromJson de YimMenuV2
local function apply_saved(veh, j)
    local model = j.vehicle_model_hash
    VEHICLE.SET_VEHICLE_MOD_KIT(veh, 0)

    if int(j.primary_color) and int(j.secondary_color) then
        VEHICLE.SET_VEHICLE_COLOURS(veh, int(j.primary_color), int(j.secondary_color))
    end
    local r, g, b = rgb3(j.custom_primary_color)
    if r then VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(veh, r, g, b) end
    r, g, b = rgb3(j.custom_secondary_color)
    if r then VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(veh, r, g, b) end

    if int(j.vehicle_window_tint) then VEHICLE.SET_VEHICLE_WINDOW_TINT(veh, int(j.vehicle_window_tint)) end
    if int(j.pearlescent_color) and int(j.wheel_color) then
        VEHICLE.SET_VEHICLE_EXTRA_COLOURS(veh, int(j.pearlescent_color), int(j.wheel_color))
    end
    if j.tire_can_burst ~= nil then VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(veh, j.tire_can_burst == 1 or j.tire_can_burst == true) end
    if int(j.wheel_type) then VEHICLE.SET_VEHICLE_WHEEL_TYPE(veh, int(j.wheel_type)) end
    if int(j.vehicle_livery) then VEHICLE.SET_VEHICLE_LIVERY(veh, int(j.vehicle_livery)) end

    if VEHICLE.IS_THIS_MODEL_A_CAR(model) or VEHICLE.IS_THIS_MODEL_A_BIKE(model) then
        r, g, b = rgb3(j.neon_color)
        if r then VEHICLE.SET_VEHICLE_NEON_COLOUR(veh, r, g, b) end
        if type(j.neon_lights) == "table" then
            for i = 0, 3 do VEHICLE.SET_VEHICLE_NEON_ENABLED(veh, i, j.neon_lights[i + 1] == true) end
        end
        if type(j.plate_text) == "string" then VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(veh, j.plate_text:sub(1, 8)) end
        if int(j.plate_text_index) then VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX(veh, int(j.plate_text_index)) end
        if j.drift_tires ~= nil then VEHICLE.SET_DRIFT_TYRES(veh, j.drift_tires == 1 or j.drift_tires == true) end
        if int(j.interior_color) then VEHICLE.SET_VEHICLE_EXTRA_COLOUR_5(veh, int(j.interior_color)) end
        if int(j.dash_color) then VEHICLE.SET_VEHICLE_EXTRA_COLOUR_6(veh, int(j.dash_color)) end
    end

    for slot = 0, #MOD_NAMES do
        local v = MOD_NAMES[slot] ~= "" and j[MOD_NAMES[slot]] or nil
        if type(v) == "table" and int(v[1]) then
            VEHICLE.SET_VEHICLE_MOD(veh, slot, int(v[1]), int(v[2]) == 1)
        elseif v == "TOGGLE" then
            if slot == SLOT_TIRESMOKE then
                r, g, b = rgb3(j.tire_smoke_color)
                if r then VEHICLE.SET_VEHICLE_TYRE_SMOKE_COLOR(veh, r, g, b) end
            elseif slot == SLOT_XENON and int(j.headlight_color) then
                VEHICLE.SET_VEHICLE_XENON_LIGHT_COLOR_INDEX(veh, int(j.headlight_color))
            end
            VEHICLE.TOGGLE_VEHICLE_MOD(veh, slot, true)
        end
    end

    -- Lista de pares [extra, encendido]
    if type(j.vehicle_extras) == "table" then
        for _, e in ipairs(j.vehicle_extras) do
            if type(e) == "table" and int(e[1]) then VEHICLE.SET_VEHICLE_EXTRA(veh, int(e[1]), e[2] ~= 1 and e[2] ~= true) end
        end
    end
end

local GARAGE_DIR = ""
local garage = {}          -- carpeta -> lista de { name, lower, path }
local garage_folders = {}  -- nombres de carpeta ordenados
local garage_folder = ""
local garage_filter = ""
local garage_pick = nil    -- entrada elegida

local function refresh_garage()
    local by_folder, folders = {}, {}
    for _, path in ipairs(FileMgr.FindFiles(GARAGE_DIR, ".json", true)) do
        local folder, name = path:match("([^/\\]+)[/\\]([^/\\]+)%.json$")
        if folder and name then
            if folder == "garaje" then folder = "(sin carpeta)" end
            if not by_folder[folder] then by_folder[folder] = {} folders[#folders + 1] = folder end
            local list = by_folder[folder]
            list[#list + 1] = { name = name, lower = name:lower(), path = path }
        end
    end
    table.sort(folders, function(a, b) return a:lower() < b:lower() end)
    for _, list in pairs(by_folder) do table.sort(list, function(a, b) return a.lower < b.lower end) end
    garage, garage_folders, garage_pick = by_folder, folders, nil
    if not garage[garage_folder] then garage_folder = folders[1] or "" end
end

try(function()
    GARAGE_DIR = FileMgr.GetMenuRootPath() .. "/vehicle_presets/garaje"
    FileMgr.CreateDir(GARAGE_DIR)
    refresh_garage()
end)

local function action_garage_spawn()
    local entry = garage_pick
    if not entry then notify_error("Elige un vehiculo del garaje") return end
    local ok, j = try(function()
        local j = json_decode(FileMgr.ReadFileContent(entry.path))
        if type(j) ~= "table" or not int(j.vehicle_model_hash) then error("falta vehicle_model_hash", 0) end
        return j
    end)
    if not ok or not j then return end
    spawn_with(int(j.vehicle_model_hash), entry.name, function(handle) apply_saved(handle, j) end)
end

---------------------------------------------------------------- prueba del garaje
-- Crea cada vehiculo del garaje como "Spawnear del garaje" (pero 40 m delante, congelado y sin
-- colision), comprueba que existe y que tiene sus mejoras, y lo borra. Solo en modo historia.
-- Cada resultado se anade al momento a prueba_garaje.txt: si el juego se cierra a mitad, la prueba
-- sigue donde iba, y un vehiculo con el que el juego se cierra dos veces queda como CRASH.
-- Mientras exista probar_garaje.flag la prueba se lanza (o se retoma) sola al cargar el script.

local TEST_LOG = PRESET_DIR .. "/prueba_garaje.txt"
local TEST_FLAG = PRESET_DIR .. "/probar_garaje.flag"
local TEST_SUMMARY = PRESET_DIR .. "/resumen_prueba.txt"
local TEST_OK_DIR = PRESET_DIR .. "/garaje_ok"
local TEST_FAILS = { ROTO = true, NO_EXISTE = true, NO_CARGA = true, NO_SPAWN = true, CRASH = true }
local TEST_HELP = {
    "OK        = spawnea con todas sus mejoras",
    "PARCIAL   = spawnea, pero alguna mejora no se aplica en ese modelo",
    "NO_EXISTE = el modelo no esta en tu juego",
    "NO_CARGA  = el modelo no cargo en 10 s",
    "NO_SPAWN  = el juego no creo el vehiculo",
    "CRASH     = el juego se cerro dos veces probando este vehiculo",
    "ROTO      = el .json no se puede leer",
}
local test = { requested = false, running = false, stop = false, status = "Sin empezar" }

-- Linea "ESTADO|carpeta/nombre|detalle"
local function test_write(state, rel, detail)
    local line = state .. "|" .. rel .. "|" .. tostring(detail or ""):gsub("[\r\n|]", " ") .. "\n"
    pcall(FileMgr.WriteFileContent, TEST_LOG, line, true)
end

-- Resultado de cada vehiculo ya probado y cuantas veces se empezo a probar
local function test_read_log()
    local done, tries = {}, {}
    local ok, text = pcall(function()
        return FileMgr.DoesFileExist(TEST_LOG) and FileMgr.ReadFileContent(TEST_LOG) or ""
    end)
    for line in (ok and text or ""):gmatch("[^\r\n]+") do
        local state, rel, detail = line:match("^([%u_]+)|([^|]*)|(.*)$")
        if state == "PROBANDO" then
            tries[rel] = (tries[rel] or 0) + 1
        elseif state then
            done[rel] = { state = state, detail = detail }
        end
    end
    return done, tries
end

local function test_can_run()
    local ok, online = pcall(network.is_session_started)
    if not ok or online then return false, "En linea: la prueba espera a que estes en modo historia" end
    local ok2, ready = pcall(function()
        local ped = PLAYER.PLAYER_PED_ID()
        return PLAYER.IS_PLAYER_PLAYING(PLAYER.PLAYER_ID()) and ENTITY.DOES_ENTITY_EXIST(ped)
            and not PED.IS_PED_DEAD_OR_DYING(ped, true) and not DLC.GET_IS_LOADING_SCREEN_ACTIVE()
            and not STREAMING.IS_PLAYER_SWITCH_IN_PROGRESS()
    end)
    if not ok2 or not ready then return false, "Esperando a que el jugador este listo" end
    return true
end

-- Espera al modo historia con el jugador listo (espera frames). false si se pidio parar.
local function test_wait_ready()
    while not test.stop do
        local ok, why = test_can_run()
        if ok then return true end
        test.status = why
        script.yield(2000)
    end
    return false
end

-- Todos los .json del garaje, ordenados por modelo para cargar cada modelo una sola vez (espera frames)
local function test_collect()
    local entries = {}
    local ok, paths = try(FileMgr.FindFiles, GARAGE_DIR, ".json", true)
    if not ok then return entries end
    for i, path in ipairs(paths) do
        local rel = path:gsub("\\", "/"):match("vehicle_presets/garaje/(.+)%.json$")
        if rel then
            local e = { rel = rel, path = path }
            local okj, j = pcall(function() return json_decode(FileMgr.ReadFileContent(path)) end)
            if okj and type(j) == "table" and int(j.vehicle_model_hash) then
                e.j, e.model = j, int(j.vehicle_model_hash)
            else
                e.err = okj and "falta vehicle_model_hash" or tostring(j)
            end
            entries[#entries + 1] = e
        end
        if i % 50 == 0 then script.yield() end
    end
    table.sort(entries, function(a, b)
        if (a.model or -1) ~= (b.model or -1) then return (a.model or -1) < (b.model or -1) end
        return a.rel < b.rel
    end)
    return entries
end

-- Mejoras del .json que el vehiculo no tiene despues de aplicarlas
local function test_missing_mods(veh, j)
    local out = {}
    for slot = 0, #MOD_NAMES do
        local v = MOD_NAMES[slot] ~= "" and j[MOD_NAMES[slot]] or nil
        if type(v) == "table" and int(v[1]) and int(v[1]) >= 0 then
            if VEHICLE.GET_VEHICLE_MOD(veh, slot) ~= int(v[1]) then
                out[#out + 1] = string.format("%s=%d (max %d)", MOD_NAMES[slot], int(v[1]), VEHICLE.GET_NUM_VEHICLE_MODS(veh, slot) - 1)
            end
        elseif v == "TOGGLE" and not VEHICLE.IS_TOGGLE_MOD_ON(veh, slot) then
            out[#out + 1] = MOD_NAMES[slot]
        end
    end
    return out
end

-- Prueba un vehiculo y devuelve su estado y detalle (espera frames: fuera de pcall)
local function test_one(e)
    if not e.j then return "ROTO", e.err end
    local ok, pos = pcall(function()
        if not STREAMING.IS_MODEL_IN_CDIMAGE(e.model) or not STREAMING.IS_MODEL_A_VEHICLE(e.model) then return nil end
        -- 40 m delante: lejos del jugador incluso con los aviones grandes
        return ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(PLAYER.PLAYER_PED_ID(), 0.0, 40.0, 0.0)
    end)
    if not ok then return "NO_SPAWN", tostring(pos) end
    if not pos then return "NO_EXISTE", "el modelo " .. e.model .. " no esta en tu juego" end

    local veh, state, detail = create_vehicle(e.model, pos, 0.0, function(handle)
        ENTITY.FREEZE_ENTITY_POSITION(handle, true)
        ENTITY.SET_ENTITY_COLLISION(handle, false, false)
        apply_saved(handle, e.j)
    end)
    if not veh then return state, detail end

    -- GET_VEHICLE_MOD solo dice que se pidio la pieza: esperar a que las piezas carguen y se
    -- dibujen, para que un vehiculo que cierra el juego lo haga mientras es el que se prueba
    local streamed, waited = false, 0
    while waited < 5000 do
        local okw, ready = pcall(function()
            local handle = veh:get_handle()
            return not ENTITY.DOES_ENTITY_EXIST(handle) or VEHICLE.HAVE_VEHICLE_MODS_STREAMED_IN(handle)
        end)
        if not okw or ready then streamed = okw and ready break end
        script.yield(100)
        waited = waited + 100
    end
    script.yield(500)

    local okc, alive, missing = pcall(function()
        local handle = veh:get_handle()
        if not ENTITY.DOES_ENTITY_EXIST(handle) then return false end
        return true, test_missing_mods(handle, e.j)
    end)
    pcall(function() veh:delete() end)
    script.yield(250) -- el resultado se apunta cuando el juego ya borro el vehiculo

    if not okc then return "PARCIAL", "error al comprobar: " .. tostring(alive) end
    if not alive then return "NO_SPAWN", "el vehiculo desaparecio al crearse" end
    if state then return state, detail end
    if not streamed then return "PARCIAL", "las piezas de las mejoras no cargaron en 5 s" end
    if #missing > 0 then return "PARCIAL", "mejoras que no aplican: " .. table.concat(missing, ", ") end
    return "OK", ""
end

-- Copia los que funcionan a garaje_ok\ con las mismas carpetas (espera frames)
local function test_copy_ok(entries, done)
    try(function()
        for _, p in ipairs(FileMgr.FindFiles(TEST_OK_DIR, ".json", true)) do FileMgr.DeleteFile(p) end
    end)
    for i, e in ipairs(entries) do
        local r = done[e.rel]
        if r and not TEST_FAILS[r.state] then
            try(function()
                local dest = TEST_OK_DIR .. "/" .. e.rel .. ".json"
                FileMgr.CreateDir(dest:match("^(.*)/[^/]*$"))
                FileMgr.WriteFileContent(dest, FileMgr.ReadFileContent(e.path))
            end)
        end
        if i % 50 == 0 then script.yield() end
    end
end

-- Escribe resumen_prueba.txt y devuelve cuantos funcionan y cuantos no
local function test_summary(entries, done)
    local counts, fails, partial = {}, {}, {}
    for _, e in ipairs(entries) do
        local r = done[e.rel]
        if r then
            counts[r.state] = (counts[r.state] or 0) + 1
            if TEST_FAILS[r.state] then
                fails[#fails + 1] = r.state .. " | " .. e.rel .. " | " .. r.detail
            elseif r.state == "PARCIAL" then
                partial[#partial + 1] = e.rel .. " | " .. r.detail
            end
        end
    end
    local works = (counts.OK or 0) + (counts.PARCIAL or 0)
    local lines = {
        "Prueba del garaje en YimMenuV2",
        "Vehiculos: " .. #entries,
        "Funcionan: " .. works .. " (OK " .. (counts.OK or 0) .. ", PARCIAL " .. (counts.PARCIAL or 0)
            .. "), copiados a scripts\\vehicle_presets\\garaje_ok\\",
        "No funcionan: " .. #fails,
        "",
    }
    for _, h in ipairs(TEST_HELP) do lines[#lines + 1] = h end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "== No funcionan =="
    for _, l in ipairs(fails) do lines[#lines + 1] = l end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "== Funcionan, pero alguna mejora no se aplica =="
    for _, l in ipairs(partial) do lines[#lines + 1] = l end
    pcall(FileMgr.WriteFileContent, TEST_SUMMARY, table.concat(lines, "\n") .. "\n")
    return works, #fails
end

-- Recorre todo el garaje (espera frames: se llama desde el bucle de fondo)
local function run_test()
    test.running, test.stop = true, false
    pcall(FileMgr.WriteFileContent, TEST_FLAG, "La prueba del garaje se retoma sola mientras exista este archivo.\n")
    local stopped = not test_wait_ready()
    if not stopped then
        test.status = "Leyendo el garaje"
        local entries = test_collect()
        local done, tries = test_read_log()
        for i, e in ipairs(entries) do
            if not done[e.rel] then
                if (tries[e.rel] or 0) >= 2 then
                    done[e.rel] = { state = "CRASH", detail = "el juego se cerro dos veces probando este vehiculo" }
                    test_write("CRASH", e.rel, done[e.rel].detail)
                elseif test.stop or not test_wait_ready() then
                    stopped = true
                    break
                else
                    test.status = string.format("Probando %d/%d: %s", i, #entries, e.rel)
                    test_write("PROBANDO", e.rel)
                    local state, detail = test_one(e)
                    done[e.rel] = { state = state, detail = detail or "" }
                    test_write(state, e.rel, detail)
                    script.yield()
                end
            end
        end
        if not stopped then
            test.status = "Copiando los que funcionan a garaje_ok"
            test_copy_ok(entries, done)
            local works, fails = test_summary(entries, done)
            test.status = string.format("Terminada: %d funcionan, %d no (ver resumen_prueba.txt)", works, fails)
            notify_ok(test.status)
        end
    end
    if stopped then test.status = "Detenida; 'Probar todo el garaje' sigue donde iba" end
    pcall(FileMgr.DeleteFile, TEST_FLAG)
    test.running, test.requested = false, false
end

-- Bucle de fondo: lanza la prueba al pulsar el boton o si existe probar_garaje.flag
script.run_in_callback(function()
    while true do
        local ok, flag = pcall(FileMgr.DoesFileExist, TEST_FLAG)
        if test.requested or (ok and flag) then run_test() end
        script.yield(2000)
    end
end)

---------------------------------------------------------------- interfaz

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
actions:add_button("vehpresets_spawn", "Spawnear", "Spawnea el vehiculo con esta configuracion", action_spawn)
actions:add_button("vehpresets_apply", "Aplicar al vehiculo actual", "Aplica pintura, rines y mejoras al vehiculo en el que estas", action_apply)
actions:add_button("vehpresets_capture", "Leer vehiculo actual", "Copia la configuracion del vehiculo en el que estas", action_capture)

local files = cat:add_group("Presets (.json)")
files:imgui(function()
    preset_name = ImGui.InputText("Nombre del preset", preset_name)
    ImGui.Text("Guardados en scripts\\vehicle_presets\\")
    for _, name in ipairs(preset_list) do
        if ImGui.Selectable(name, name == preset_name) then preset_name = name end
    end
end)
files:add_button("vehpresets_save", "Guardar preset", "Guarda la configuracion como <nombre>.json", action_save)
files:add_button("vehpresets_load", "Cargar preset", "Carga <nombre>.json en la configuracion", action_load)
files:add_button("vehpresets_refresh", "Actualizar lista", "Vuelve a leer la carpeta vehicle_presets", function() try(refresh_list) end)

local garage_cat = sub:add_category("Garaje")
local garage_group = garage_cat:add_group("Vehiculos del modpack")
-- Se dibuja cada frame: solo ImGui, sin natives ni esperas
garage_group:imgui(function()
    if ImGui.BeginCombo("Carpeta", garage_folder) then
        for _, folder in ipairs(garage_folders) do
            if ImGui.Selectable(folder .. " (" .. #garage[folder] .. ")", folder == garage_folder) and folder ~= garage_folder then
                garage_folder, garage_pick = folder, nil
            end
        end
        ImGui.EndCombo()
    end
    garage_filter = ImGui.InputText("Buscar", garage_filter)
    ImGui.Text("Elegido: " .. (garage_pick and garage_pick.name or "-"))

    local needle = garage_filter:lower()
    if ImGui.BeginChild("vehpresets_garage_list", 0, 300, true) then
        for _, entry in ipairs(garage[garage_folder] or {}) do
            if needle == "" or entry.lower:find(needle, 1, true) then
                if ImGui.Selectable(entry.name, entry == garage_pick) then garage_pick = entry end
            end
        end
    end
    ImGui.EndChild()
end)
garage_group:add_button("vehpresets_garage_spawn", "Spawnear del garaje", "Spawnea el vehiculo elegido con todas sus mejoras", action_garage_spawn)
garage_group:add_button("vehpresets_garage_refresh", "Actualizar garaje", "Vuelve a leer la carpeta vehicle_presets\\garaje", function() try(refresh_garage) end)

local test_group = garage_cat:add_group("Prueba automatica")
test_group:imgui(function()
    ImGui.Text("Estado: " .. test.status)
    ImGui.Text("Resultado en scripts\\vehicle_presets\\resumen_prueba.txt")
end)
test_group:add_button("vehpresets_test_start", "Probar todo el garaje", "Spawnea y borra cada vehiculo del garaje (solo en modo historia)", function()
    if test.running then notify_error("La prueba ya esta en marcha") return end
    test.requested, test.status = true, "Empezando..."
end)
test_group:add_button("vehpresets_test_stop", "Detener prueba", "Para al terminar el vehiculo actual", function()
    if test.running then test.stop, test.status = true, "Deteniendo..." end
end)
test_group:add_button("vehpresets_test_reset", "Borrar resultados", "La proxima prueba empieza desde el principio", function()
    if test.running then notify_error("Deten la prueba primero") return end
    try(function()
        FileMgr.DeleteFile(TEST_LOG)
        FileMgr.DeleteFile(TEST_SUMMARY)
    end)
    test.status = "Resultados borrados"
end)
