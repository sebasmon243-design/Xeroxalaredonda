# Vehicle Presets (YimMenu, Lua)

Script de YimMenu para spawnear un vehiculo por nombre, aplicarle pintura, rines y nivel de mejora,
y guardar/cargar esa configuracion como un archivo `.json` por vehiculo.

## Estructura

Las carpetas del repo replican `%appdata%\YimMenu\`:

```
scripts/
  vehicle_presets.lua              -> %appdata%\YimMenu\scripts\
scripts_config/
  vehicle_presets.lua/             -> %appdata%\YimMenu\scripts_config\
    adder_rojo.json
    zentorno_negro.json
    t20_azul.json
    sultanrs_blanco.json
    elegy_verde.json
```

YimMenu solo deja que un script lea y escriba archivos dentro de
`%appdata%\YimMenu\scripts_config\<nombre del script>\`; para este script esa carpeta se llama
`vehicle_presets.lua` (con el `.lua`, asi la crea YimMenu). Ahi van los presets.

## Uso

1. Copia `scripts\vehicle_presets.lua` a `%appdata%\YimMenu\scripts\`.
2. Copia la carpeta `scripts_config\vehicle_presets.lua\` a `%appdata%\YimMenu\scripts_config\`.
3. Recarga los scripts en YimMenu y abre la pestana **Vehicle Presets**.
4. Escribe el nombre de un preset (ej. `adder_rojo`) y pulsa **Cargar preset**, luego **Spawnear**.

Botones: Spawnear, Aplicar al vehiculo actual, Leer vehiculo actual, Guardar preset, Cargar preset.

## Formato del preset

```json
{
  "model": "adder",
  "r": 255, "g": 0, "b": 0,
  "r2": 0, "g2": 0, "b2": 0,
  "wheel_type": 7, "wheel_index": 12,
  "engine": 3, "brakes": 2, "transmission": 2,
  "suspension": 3, "armor": 4, "turbo": 1
}
```

- `model`: nombre del modelo (o su hash numerico).
- `r g b` / `r2 g2 b2`: pintura primaria / secundaria (0-255).
- `wheel_type`: 0 Sport, 1 Muscle, 2 Lowrider, 3 SUV, 4 Offroad, 5 Tuner, 7 High End...
- `wheel_index`, `engine`, `brakes`, `transmission`, `suspension`, `armor`: nivel de mod; `-1` = de serie.
  Si pides mas nivel del que tiene el vehiculo, se usa el maximo disponible.
- `turbo`: 1 con turbo, 0 sin turbo.

El lector solo entiende este formato plano (sin objetos anidados ni arreglos).

Aviso: usar YimMenu en GTA Online va contra los terminos de Rockstar y puede causar baneos.
