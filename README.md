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
    garaje/                  -> vehiculos del modpack, una carpeta por grupo
```

YimMenuV2 solo deja que los scripts lean y escriban dentro de su carpeta `scripts`, por eso los
presets van en `scripts\vehicle_presets\`. Si la carpeta no existe, el script la crea.

## Uso

1. Copia el contenido de `scripts\` del repo a `%appdata%\YimMenuV2\scripts\`.
2. Recarga los scripts en YimMenuV2 y abre el menu **Vehicle Presets**.
3. Elige un preset de la lista (o escribe su nombre) y pulsa **Cargar preset**, luego **Spawnear**.

Botones: Spawnear, Aplicar al vehiculo actual, Leer vehiculo actual, Guardar preset, Cargar preset,
Actualizar lista. Todos los valores se pueden editar en el menu antes de spawnear o guardar.

**Aplicar al vehiculo actual** primero pide el control de red del vehiculo; si no lo consigue (por ejemplo,
el vehiculo es de otro jugador en GTA Online), avisa con un error y no cambia nada.

## Garaje (vehiculos del modpack)

La categoria **Garaje** del menu lista los 2.042 vehiculos del SUPERMODPACK-CARS que se pueden
spawnear en YimMenuV2, con todas sus mejoras (piezas de carroceria, rines, colores de paleta y RGB,
neones, polarizado, placa, humo de llantas, xenon y extras).

1. Elige la carpeta en **Carpeta** (son las carpetas originales del modpack, por ejemplo `228 Veh` o `Drift`).
2. Escribe en **Buscar** para filtrar por nombre y haz clic en un vehiculo.
3. Pulsa **Spawnear del garaje**. Si agregas o borras archivos, pulsa **Actualizar garaje**.

Los archivos estan en `scripts\vehicle_presets\garaje\<carpeta>\<nombre>.json` y usan el mismo formato
que el menu "Saved Vehicles" de YimMenuV2, asi que tambien puedes copiar esas carpetas a
`%appdata%\YimMenuV2\saved_json_vehicles\`.

Que se quedo fuera del modpack:
- Copias repetidas (4.076 archivos con el mismo vehiculo y la misma configuracion).
- 101 archivos `.json` vacios o rotos, y 8 que no eran vehiculos.
- Los objetos pegados al vehiculo (`vehicle_attachments` / `model_attachments` de YimMenu legacy):
  YimMenuV2 no los soporta.
- Los outfits, los .exe y las copias de YimMenu que venian en el paquete.

Todos los modelos que quedaron estan en la lista de vehiculos de YimMenuV2. Si aun asi alguno no
existe en tu version del juego, el script avisa con "Modelo invalido" y no hace nada.

Para convertir otro pack (formatos YimMenu legacy y Cherax), usa `tools/convert_modpack.py`;
las instrucciones estan al inicio del archivo.

### Probar todo el garaje

**Garaje > Prueba automatica > Probar todo el garaje** crea cada vehiculo del garaje como lo hace
**Spawnear del garaje**, comprueba que aparece y que tiene sus mejoras, y lo borra. Solo funciona en
modo historia: si estas en linea, espera. El vehiculo aparece 40 m delante, congelado y sin colision,
asi que no te golpea. **Detener prueba** para al terminar el vehiculo actual; al volver a pulsar
**Probar todo el garaje** sigue donde iba. **Borrar resultados** hace que la proxima prueba empiece
de cero.

Resultados, en `scripts\vehicle_presets\`:
- `prueba_garaje.txt`: una linea por vehiculo, `ESTADO|carpeta/nombre|detalle`.
- `resumen_prueba.txt`: cuantos funcionan y la lista de los que no.
- `garaje_ok\`: copia de los que funcionan, con las mismas carpetas.

| Estado | Significa |
| --- | --- |
| `OK` | Spawnea con todas sus mejoras |
| `PARCIAL` | Spawnea, pero alguna mejora no se aplica en ese modelo (cuenta como que funciona) |
| `NO_EXISTE` | El modelo no esta en tu juego |
| `NO_CARGA` | El modelo no cargo en 10 segundos |
| `NO_SPAWN` | El juego no creo el vehiculo |
| `CRASH` | El juego se cerro dos veces probando ese vehiculo |
| `ROTO` | El `.json` no se puede leer |

Si el juego se cierra a mitad de la prueba, el archivo `probar_garaje.flag` sigue ahi y la prueba se
retoma sola la proxima vez que se cargue el script. Para lanzarla sin abrir el menu, crea ese
archivo vacio en `scripts\vehicle_presets\`.

Ahora el script espera hasta 10 segundos a que cargue el modelo antes de crear el vehiculo (antes eran
unos 30 frames), asi que los modelos pesados ya no fallan al spawnear con el disco ocupado.

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

- `model`: nombre del modelo (o su hash numerico). Es obligatorio: si falta o no es valido, el preset no se carga.
- `r g b` / `r2 g2 b2`: pintura primaria / secundaria (0-255).
- `wheel_type`: 0 Sport, 1 Muscle, 2 Lowrider, 3 SUV, 4 Offroad, 5 Tuner, 7 High End...
- `wheel_index`, `engine`, `brakes`, `transmission`, `suspension`, `armor`: nivel de mod; `-1` = de serie.
  Si pides mas nivel del que tiene el vehiculo, se usa el maximo disponible.
- `turbo`: 1 con turbo, 0 sin turbo.

El lector solo entiende este formato plano (sin objetos anidados ni arreglos).

Aviso: usar YimMenu en GTA Online va contra los terminos de Rockstar y puede causar baneos.
