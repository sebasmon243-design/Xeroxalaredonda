-- Vehicle Presets para YimMenu (Lua)
-- Spawnea un vehiculo por nombre, aplica pintura/rines/mejoras y guarda/carga presets en .json.
--
-- Instalacion:
--   scripts\vehicle_presets.lua            -> %appdata%\YimMenu\scripts\
--   scripts_config\vehicle_presets.lua\    -> %appdata%\YimMenu\scripts_config\
--
-- YimMenu restringe io.open a %appdata%\YimMenu\scripts_config\<nombre del script>\
-- (para este script: scripts_config\vehicle_presets.lua\), asi que los presets
-- se leen y guardan ahi, un archivo <nombre>.json por vehiculo.

local TITLE = "Vehicle Presets"

-- Ids de mod de vehiculo (SET_VEHICLE_MOD / GET_VEHICLE_MOD)
local MOD_ENGINE, MOD_BRAKES, MOD_TRANSMISSION = 11, 12, 13
local MOD_SUSPENSION, MOD_ARMOR = 15, 16
local MOD_FRONT_WHEELS, MOD_REAR_WHEELS = 23, 24
local TOGGLE_TURBO = 18

-- Configuracion actual (lo que se spawnea, guarda y carga)
local cfg = {
    model = "adder",
    r = 255, g = 0, b = 0,        -- color primario RGB
    r2 = 0, g2 = 0, b2 = 0,       -- color secundario RGB
    wheel_type = 7,               -- 0 Sport, 1 Muscle, 2 Lowrider, 3 SUV, 4 Offroad, 5 Tuner, 7 High End...
    wheel_index = 0,              -- -1 = rines de serie
    engine = 3, brakes = 2, transmission = 2, suspension = 3, armor = 4,
    turbo = 1,                    -- 1 = con turbo, 0 = sin turbo
}

-- Orden de los campos numericos al escribir el .json
local NUM_KEYS = { "r", "g", "b", "r2", "g2", "b2", "wheel_type", "wheel_index",
                   "engine", "brakes", "transmission", "suspension", "armor", "turbo" }

---------------------------------------------------------------- utilidades

local function notify_error(msg) gui.show_error(TITLE, msg) end
local function notify_ok(msg) gui.show_success(TITLE, msg) end

-- Solo letras, numeros, "_" y "-": evita rutas raras fuera de la carpeta de config
local function valid_name(name)
    return type(name) == "string" and name:match("^[%w_%-]+$") ~= nil
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Acepta un nombre de modelo ("adder") o un hash numerico ("3078201489")
local function model_hash(model)
    local n = tonumber(model)
    if n then return math.floor(n) end
    return joaat(model)
end

---------------------------------------------------------------- guardado (.json)

local function save_preset(name)
    local f = io.open(name .. ".json", "w")
    if not f then return false end
    local lines = { '  "model": "' .. cfg.model .. '"' }
    for _, k in ipairs(NUM_KEYS) do
        lines[#lines + 1] = '  "' .. k .. '": ' .. string.format("%d", cfg[k])
    end
    f:write("{\n" .. table.concat(lines, ",\n") .. "\n}\n")
    f:close()
    return true
end

-- Lee un JSON plano: "clave": "texto"  o  "clave": numero
local function load_preset(name)
    if not io.exists(name .. ".json") then return false end
    local f = io.open(name .. ".json", "r")
    if not f then return false end
    local text = f:read("a") or ""
    f:close()

    local model = text:match('"model"%s*:%s*"([^"]*)"')
    if model and model ~= "" then cfg.model = model:lower() end
    for k, v in text:gmatch('"([%w_]+)"%s*:%s*(-?%d+)') do
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

    VEHICLE.SET_VEHICLE_WHEEL_TYPE(veh, cfg.wheel_type)
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

local function spawn_vehicle(script)
    local hash = model_hash(cfg.model)
    if not STREAMING.IS_MODEL_IN_CDIMAGE(hash) or not STREAMING.IS_MODEL_A_VEHICLE(hash) then
        notify_error("Modelo invalido: " .. cfg.model)
        return
    end

    STREAMING.REQUEST_MODEL(hash)
    local waited = 0
    while not STREAMING.HAS_MODEL_LOADED(hash) do
        if waited >= 5000 then
            notify_error("El modelo tardo demasiado en cargar: " .. cfg.model)
            return
        end
        script:sleep(100)
        waited = waited + 100
    end

    local ped = PLAYER.PLAYER_PED_ID()
    local pos = ENTITY.GET_ENTITY_COORDS(ped, true)
    local heading = ENTITY.GET_ENTITY_HEADING(ped)
    local veh = VEHICLE.CREATE_VEHICLE(hash, pos.x, pos.y, pos.z, heading, true, false, false)
    STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(hash)
    if veh == 0 then
        notify_error("No se pudo crear el vehiculo")
        return
    end

    apply_mods(veh)
    PED.SET_PED_INTO_VEHICLE(ped, veh, -1)
    notify_ok("Spawneado: " .. cfg.model)
end

-- Copia la configuracion del vehiculo en el que estas a cfg
local function capture_current()
    local veh = current_vehicle()
    if veh == 0 then
        notify_error("No estas en un vehiculo")
        return false
    end

    local hash = ENTITY.GET_ENTITY_MODEL(veh)
    local name = (VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(hash) or ""):lower()
    -- El nombre visible no siempre coincide con el modelo; si no coincide guardamos el hash
    if name ~= "" and joaat(name) == hash then cfg.model = name else cfg.model = tostring(hash) end

    cfg.r, cfg.g, cfg.b = VEHICLE.GET_VEHICLE_CUSTOM_PRIMARY_COLOUR(veh, 0, 0, 0)
    cfg.r2, cfg.g2, cfg.b2 = VEHICLE.GET_VEHICLE_CUSTOM_SECONDARY_COLOUR(veh, 0, 0, 0)
    cfg.wheel_type = VEHICLE.GET_VEHICLE_WHEEL_TYPE(veh)
    cfg.wheel_index = VEHICLE.GET_VEHICLE_MOD(veh, MOD_FRONT_WHEELS)
    cfg.engine = VEHICLE.GET_VEHICLE_MOD(veh, MOD_ENGINE)
    cfg.brakes = VEHICLE.GET_VEHICLE_MOD(veh, MOD_BRAKES)
    cfg.transmission = VEHICLE.GET_VEHICLE_MOD(veh, MOD_TRANSMISSION)
    cfg.suspension = VEHICLE.GET_VEHICLE_MOD(veh, MOD_SUSPENSION)
    cfg.armor = VEHICLE.GET_VEHICLE_MOD(veh, MOD_ARMOR)
    cfg.turbo = VEHICLE.IS_TOGGLE_MOD_ON(veh, TOGGLE_TURBO) and 1 or 0
    return true
end

---------------------------------------------------------------- interfaz

local tab = gui.add_tab(TITLE)

tab:add_text("Presets en: scripts_config\\vehicle_presets.lua\\<nombre>.json")
local model_in = tab:add_input_string("Modelo (ej: adder, zentorno)")
local name_in = tab:add_input_string("Nombre del preset")

local ints = {}
local function int_field(label, key)
    ints[key] = tab:add_input_int(label)
end
tab:add_separator()
tab:add_text("Pintura primaria (0-255)")
int_field("Primario R", "r"); int_field("Primario G", "g"); int_field("Primario B", "b")
tab:add_text("Pintura secundaria (0-255)")
int_field("Secundario R", "r2"); int_field("Secundario G", "g2"); int_field("Secundario B", "b2")
tab:add_text("Rines (tipo 0-12, indice -1 = de serie)")
int_field("Tipo de rin", "wheel_type"); int_field("Indice de rin", "wheel_index")
tab:add_text("Mejoras (-1 = de serie; se limitan al maximo del vehiculo)")
int_field("Motor", "engine"); int_field("Frenos", "brakes")
int_field("Transmision", "transmission"); int_field("Suspension", "suspension")
int_field("Blindaje", "armor"); int_field("Turbo (0/1)", "turbo")

local function ui_to_cfg()
    local m = model_in:get_value()
    if m and m ~= "" then cfg.model = m:lower() end
    for k, field in pairs(ints) do cfg[k] = math.floor(tonumber(field:get_value()) or cfg[k]) end
end

local function cfg_to_ui()
    model_in:set_value(cfg.model)
    for k, field in pairs(ints) do field:set_value(cfg[k]) end
end

cfg_to_ui()

-- Ejecuta fn sin que un error descargue el script (YimMenu lo descarga ante cualquier error)
local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            log.warning(tostring(err))
            notify_error("Error: " .. tostring(err))
        end
    end
end

tab:add_separator()
tab:add_button("Spawnear", safe(function()
    ui_to_cfg()
    script.run_in_fiber(safe(spawn_vehicle))
end))
tab:add_sameline()
tab:add_button("Aplicar al vehiculo actual", safe(function()
    ui_to_cfg()
    script.run_in_fiber(safe(function()
        local veh = current_vehicle()
        if veh == 0 then notify_error("No estas en un vehiculo") return end
        apply_mods(veh)
        notify_ok("Mods aplicados")
    end))
end))
tab:add_sameline()
tab:add_button("Leer vehiculo actual", safe(function()
    script.run_in_fiber(safe(function()
        if capture_current() then
            cfg_to_ui()
            notify_ok("Configuracion leida: " .. cfg.model)
        end
    end))
end))

tab:add_separator()
tab:add_button("Guardar preset", safe(function()
    ui_to_cfg()
    local n = name_in:get_value()
    if not valid_name(n) then notify_error("Nombre invalido (usa letras, numeros, _ o -)") return end
    if save_preset(n) then notify_ok("Guardado: " .. n .. ".json") else notify_error("No se pudo guardar " .. n) end
end))
tab:add_sameline()
tab:add_button("Cargar preset", safe(function()
    local n = name_in:get_value()
    if not valid_name(n) then notify_error("Nombre invalido (usa letras, numeros, _ o -)") return end
    if load_preset(n) then
        cfg_to_ui()
        notify_ok("Cargado: " .. n .. ".json")
    else
        notify_error("No existe: " .. n .. ".json")
    end
end))
