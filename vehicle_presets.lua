-- Vehicle Presets para YimMenu (Lua)
-- Spawnea un vehiculo por nombre, aplica pintura/rines/mejoras y guarda/carga presets.
-- Instalar: copiar a %appdata%\YimMenu\scripts\ y recargar scripts desde el menu.

local PRESET_DIR = (os.getenv("APPDATA") or ".") .. "\\YimMenu\\vehicle_presets\\"
pcall(os.execute, 'mkdir "' .. PRESET_DIR .. '" >nul 2>&1')

-- Ids de mod de vehiculo (SET_VEHICLE_MOD)
local MOD = { ENGINE = 11, BRAKES = 12, TRANSMISSION = 13, SUSPENSION = 15, ARMOR = 16 }
local TOGGLE_TURBO = 18

-- Estado actual de la interfaz / preset
local cfg = {
    model = "adder",
    r = 255, g = 0, b = 0,        -- color primario
    r2 = 0, g2 = 0, b2 = 0,       -- color secundario
    wheel_type = 7,               -- 7 = High End, 0 = Sport, 3 = Muscle...
    wheel_index = 0,
    engine = 3, brakes = 2, transmission = 2, suspension = 3, armor = 4,
    turbo = 1,
}
local last_vehicle = 0

---------------------------------------------------------------- guardado
local NUM_KEYS = { "r","g","b","r2","g2","b2","wheel_type","wheel_index",
                   "engine","brakes","transmission","suspension","armor","turbo" }

local function save_preset(name)
    local f = io.open(PRESET_DIR .. name .. ".json", "w")
    if not f then return false end
    local lines = { '  "model": "' .. cfg.model .. '"' }
    for _, k in ipairs(NUM_KEYS) do
        lines[#lines + 1] = '  "' .. k .. '": ' .. tostring(cfg[k])
    end
    f:write("{\n" .. table.concat(lines, ",\n") .. "\n}\n")
    f:close()
    return true
end

local function load_preset(name)
    local f = io.open(PRESET_DIR .. name .. ".json", "r")
    if not f then return false end
    local text = f:read("*a")
    f:close()
    -- JSON plano: "clave": "texto" o "clave": numero
    for k, v in text:gmatch('"(%w+)"%s*:%s*"([^"]*)"') do
        if k == "model" then cfg.model = v end
    end
    for k, v in text:gmatch('"(%w+)"%s*:%s*(-?%d+)') do
        if cfg[k] ~= nil then cfg[k] = tonumber(v) end
    end
    return true
end

---------------------------------------------------------------- vehiculo
local function apply_mods(veh)
    VEHICLE.SET_VEHICLE_MOD_KIT(veh, 0)
    VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(veh, cfg.r, cfg.g, cfg.b)
    VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(veh, cfg.r2, cfg.g2, cfg.b2)
    VEHICLE.SET_VEHICLE_WHEEL_TYPE(veh, cfg.wheel_type)
    VEHICLE.SET_VEHICLE_MOD(veh, 23, cfg.wheel_index, false) -- rines delanteros
    VEHICLE.SET_VEHICLE_MOD(veh, 24, cfg.wheel_index, false) -- rines traseros (motos)
    -- nivel de mejora: valor pedido, limitado al maximo que admite el vehiculo
    local function lvl(mod_type, wanted)
        local n = VEHICLE.GET_NUM_VEHICLE_MODS(veh, mod_type)
        VEHICLE.SET_VEHICLE_MOD(veh, mod_type, math.min(wanted, n - 1), false)
    end
    lvl(MOD.ENGINE, cfg.engine)
    lvl(MOD.BRAKES, cfg.brakes)
    lvl(MOD.TRANSMISSION, cfg.transmission)
    lvl(MOD.SUSPENSION, cfg.suspension)
    lvl(MOD.ARMOR, cfg.armor)
    VEHICLE.TOGGLE_VEHICLE_MOD(veh, TOGGLE_TURBO, cfg.turbo == 1)
end

local function spawn_vehicle(s)
    local hash = joaat(cfg.model)
    if not STREAMING.IS_MODEL_IN_CDIMAGE(hash) or not STREAMING.IS_MODEL_A_VEHICLE(hash) then
        gui.show_error("Vehicle Presets", "Modelo invalido: " .. cfg.model)
        return
    end
    STREAMING.REQUEST_MODEL(hash)
    while not STREAMING.HAS_MODEL_LOADED(hash) do s:yield() end

    local ped = PLAYER.PLAYER_PED_ID()
    local pos = ENTITY.GET_ENTITY_COORDS(ped, true)
    local heading = ENTITY.GET_ENTITY_HEADING(ped)
    local veh = VEHICLE.CREATE_VEHICLE(hash, pos.x, pos.y, pos.z, heading, true, false, false)
    if veh == 0 then gui.show_error("Vehicle Presets", "No se pudo crear el vehiculo") return end

    apply_mods(veh)
    PED.SET_PED_INTO_VEHICLE(ped, veh, -1)
    STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(hash)
    last_vehicle = veh
end

-- Lee la configuracion del vehiculo actual del jugador
local function capture_current()
    local veh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
    if veh == 0 then gui.show_error("Vehicle Presets", "No estas en un vehiculo") return end
    cfg.model = VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL
        and (HUD.GET_FILENAME_FOR_AUDIO_CONVERSATION(
             VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(ENTITY.GET_ENTITY_MODEL(veh))) or cfg.model)
        or cfg.model
    local _, r, g, b = VEHICLE.GET_VEHICLE_CUSTOM_PRIMARY_COLOUR(veh, 0, 0, 0)
    if r then cfg.r, cfg.g, cfg.b = r, g, b end
    cfg.wheel_type = VEHICLE.GET_VEHICLE_WHEEL_TYPE(veh)
    cfg.wheel_index = VEHICLE.GET_VEHICLE_MOD(veh, 23)
    cfg.engine = VEHICLE.GET_VEHICLE_MOD(veh, MOD.ENGINE)
    cfg.brakes = VEHICLE.GET_VEHICLE_MOD(veh, MOD.BRAKES)
    cfg.transmission = VEHICLE.GET_VEHICLE_MOD(veh, MOD.TRANSMISSION)
    cfg.suspension = VEHICLE.GET_VEHICLE_MOD(veh, MOD.SUSPENSION)
    cfg.armor = VEHICLE.GET_VEHICLE_MOD(veh, MOD.ARMOR)
    cfg.turbo = VEHICLE.IS_TOGGLE_MOD_ON(veh, TOGGLE_TURBO) and 1 or 0
end

---------------------------------------------------------------- interfaz
local tab = gui.add_tab("Vehicle Presets")
local model_in = tab:add_input_text("Modelo (ej: adder, zentorno)")
local name_in  = tab:add_input_text("Nombre del preset")
local ints = {}
local function int_field(label, key)
    ints[key] = tab:add_input_int(label)
    ints[key]:set_value(cfg[key])
end
tab:add_text("Pintura primaria / secundaria (0-255)")
int_field("R", "r"); int_field("G", "g"); int_field("B", "b")
int_field("R2", "r2"); int_field("G2", "g2"); int_field("B2", "b2")
tab:add_text("Rines y mejoras")
int_field("Tipo de rin (0-12)", "wheel_type"); int_field("Indice de rin", "wheel_index")
int_field("Motor", "engine"); int_field("Frenos", "brakes")
int_field("Transmision", "transmission"); int_field("Suspension", "suspension")
int_field("Blindaje", "armor"); int_field("Turbo (0/1)", "turbo")

local function ui_to_cfg()
    local m = model_in:get_value()
    if m and m ~= "" then cfg.model = m:lower() end
    for k, f in pairs(ints) do cfg[k] = f:get_value() end
end
local function cfg_to_ui()
    model_in:set_value(cfg.model)
    for k, f in pairs(ints) do f:set_value(cfg[k]) end
end
cfg_to_ui()

tab:add_button("Spawnear", function()
    ui_to_cfg()
    script.run_in_fiber(spawn_vehicle)
end)
tab:add_sameline()
tab:add_button("Aplicar al vehiculo actual", function()
    ui_to_cfg()
    script.run_in_fiber(function()
        local veh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
        if veh ~= 0 then apply_mods(veh) end
    end)
end)
tab:add_separator()
tab:add_button("Guardar preset", function()
    ui_to_cfg()
    local n = name_in:get_value()
    if n == "" then gui.show_error("Vehicle Presets", "Escribe un nombre") return end
    gui.show_message("Vehicle Presets", save_preset(n) and "Guardado" or "Error al guardar")
end)
tab:add_sameline()
tab:add_button("Cargar preset", function()
    local n = name_in:get_value()
    if load_preset(n) then cfg_to_ui() gui.show_message("Vehicle Presets", "Cargado: " .. n)
    else gui.show_error("Vehicle Presets", "No existe: " .. n) end
end)
tab:add_sameline()
tab:add_button("Leer vehiculo actual", function()
    script.run_in_fiber(function() capture_current() cfg_to_ui() end)
end)
