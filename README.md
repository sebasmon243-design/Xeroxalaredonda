# Vehicle Presets (YimMenuV2, Lua)

Script para **YimMenuV2** (GTA V Enhanced) que spawnea un vehiculo por nombre, le aplica pintura,
rines y nivel de mejora, y guarda/carga esa configuracion como un archivo `.json` por vehiculo.

> Es para YimMenuV2. El YimMenu clasico (legacy) usa otra API de Lua y este script no funciona ahi.

## Estructura

La carpeta `scripts/` del repo replica `%appdata%\YimMenuV2\scripts\`:

```
scripts/
  vehicle_presets.lua        -> %appdata%\YimMenuV2\scripts\vehicle_presets.lua
  vehicle_presets/           -> %appdata%\YimMenuV2\scripts\vehicle_presets\
    adder_rojo.json
    zentorno_negro.json
    t20_azul.json
    sultanrs_blanco.json
    elegy_verde.json
```

YimMenuV2 solo deja que los scripts lean y escriban dentro de su carpeta `scripts`, por eso los
presets van en `scripts\vehicle_presets\`. Si la carpeta no existe, el script la crea.

## Uso

1. Copia el contenido de `scripts\` del repo a `%appdata%\YimMenuV2\scripts\`.
2. Recarga los scripts en YimMenuV2 y abre el menu **Vehicle Presets**.
3. Elige un preset de la lista (o escribe su nombre) y pulsa **Cargar preset**, luego **Spawnear**.

Botones: Spawnear, Aplicar al vehiculo actual, Leer vehiculo actual, Guardar preset, Cargar preset,
Actualizar lista. Todos los valores se pueden editar en el menu antes de spawnear o guardar.

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
