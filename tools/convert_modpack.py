"""Convierte los .json de vehiculos del modpack (formato YimMenu 'persist car' y 'Cherax Entity')
al formato de vehiculo guardado de YimMenuV2, quedandose solo con modelos que YimMenuV2 conoce.

Uso: python3 -I tools/convert_modpack.py <carpeta_extraida> tools/v2_vehicles.txt scripts/vehicle_presets/garaje informe.json

v2_vehicles.txt sale de src/game/gta/data/Vehicles.hpp de YimMenuV2 (commit 39a0f22, sept. 2026).
"""
import hashlib, json, os, re, sys, unicodedata, collections

MOD_NAMES = ["MOD_SPOILERS", "MOD_FRONTBUMPER", "MOD_REARBUMPER", "MOD_SIDESKIRT", "MOD_EXHAUST", "MOD_FRAME", "MOD_GRILLE", "MOD_HOOD", "MOD_FENDER", "MOD_RIGHTFENDER", "MOD_ROOF", "MOD_ENGINE", "MOD_BRAKES", "MOD_TRANSMISSION", "MOD_HORNS", "MOD_SUSPENSION", "MOD_ARMOR", "", "MOD_TURBO", "", "MOD_TIRESMOKE", "", "MOD_XENONHEADLIGHTS", "MOD_FRONTWHEEL", "MOD_REARWHEEL", "MOD_PLATEHOLDER", "MOD_VANITYPLATES", "MOD_TRIMDESIGN", "MOD_ORNAMENTS", "MOD_DASHBOARD", "MOD_DIALDESIGN", "MOD_DOORSPEAKERS", "MOD_SEATS", "MOD_STEERINGWHEELS", "MOD_COLUMNSHIFTERLEVERS", "MOD_PLAQUES", "MOD_SPEAKERS", "MOD_TRUNK", "MOD_HYDRAULICS", "MOD_ENGINEBLOCK", "MOD_AIRFILTER", "MOD_STRUTS", "MOD_ARCHCOVER", "MOD_AERIALS", "MOD_TRIM", "MOD_TANK", "MOD_WINDOWS", "", "MOD_LIVERY"]
TOGGLES = {18, 20, 22}


def joaat(s):
    h = 0
    for c in s.lower().encode():
        h = (h + c) & 0xFFFFFFFF
        h = (h + (h << 10)) & 0xFFFFFFFF
        h ^= h >> 6
    h = (h + (h << 3)) & 0xFFFFFFFF
    h ^= h >> 11
    h = (h + (h << 15)) & 0xFFFFFFFF
    return h


def signed(h):
    h &= 0xFFFFFFFF
    return h - (1 << 32) if h >= (1 << 31) else h


def as_int(v, lo=None, hi=None):
    if isinstance(v, bool):
        v = int(v)
    if not isinstance(v, (int, float)):
        return None
    v = int(v)
    if lo is not None and (v < lo or v > hi):
        return None
    return v


def rgb(v):
    if isinstance(v, dict):
        v = [v.get("r"), v.get("g"), v.get("b")]
    if isinstance(v, list) and len(v) >= 3:
        c = [as_int(x, 0, 255) for x in v[:3]]
        if None not in c:
            return c
    return None


def from_yim(d):
    out = {"model": as_int(d.get("vehicle_model_hash"))}
    mods = {}
    for slot, name in enumerate(MOD_NAMES):
        if not name or name not in d:
            continue
        v = d[name]
        if v == "TOGGLE" and slot in TOGGLES:
            mods[name] = "TOGGLE"
        elif isinstance(v, list) and len(v) >= 1 and slot not in TOGGLES:
            idx = as_int(v[0], -1, 1000)
            var = as_int(v[1] if len(v) > 1 else 0, 0, 1) or 0
            if idx is not None:
                mods[name] = [idx, var]
    out["mods"] = mods
    for k in ("primary_color", "secondary_color", "pearlescent_color", "wheel_color", "interior_color", "dash_color"):
        out[k] = as_int(d.get(k), 0, 255)
    out["custom_primary_color"] = rgb(d.get("custom_primary_color"))
    out["custom_secondary_color"] = rgb(d.get("custom_secondary_color"))
    out["tire_smoke_color"] = rgb(d.get("tire_smoke_color"))
    out["neon_color"] = rgb(d.get("neon_color"))
    nl = d.get("neon_lights")
    out["neon_lights"] = [bool(x) for x in nl[:4]] if isinstance(nl, list) and len(nl) >= 4 else None
    out["headlight_color"] = as_int(d.get("headlight_color"), -1, 255)
    out["vehicle_window_tint"] = as_int(d.get("vehicle_window_tint"), -1, 6)
    out["wheel_type"] = as_int(d.get("wheel_type"), -1, 12)
    out["plate_text_index"] = as_int(d.get("plate_text_index"), 0, 12)
    out["plate_text"] = d.get("plate_text") if isinstance(d.get("plate_text"), str) else None
    out["tire_can_burst"] = as_int(d.get("tire_can_burst"), 0, 1)
    out["drift_tires"] = as_int(d.get("drift_tires"), 0, 1)
    out["vehicle_livery"] = as_int(d.get("vehicle_livery"), -1, 100)
    extras = {}
    ex = d.get("vehicle_extras")
    if isinstance(ex, dict):
        for k, v in ex.items():
            i = as_int(int(k), 0, 20) if str(k).lstrip("-").isdigit() else None
            if i is not None:
                extras[str(i)] = 1 if v else 0
    elif isinstance(ex, list):  # [[id, on], ...]
        for e in ex:
            if isinstance(e, list) and len(e) == 2:
                i = as_int(e[0], 0, 20)
                if i is not None:
                    extras[str(i)] = 1 if e[1] else 0
    out["vehicle_extras"] = extras
    return out


def from_cherax(d):
    out = {"model": as_int(d.get("model"))}
    mods = {}
    for k, v in (d.get("mods") or {}).items():
        m = re.fullmatch(r"mod(\d+)", k)
        if not m or not isinstance(v, dict):
            continue
        slot = int(m.group(1))
        if slot >= len(MOD_NAMES) or not MOD_NAMES[slot]:
            continue
        idx = as_int(v.get("index"), -1, 1000)
        if idx is None:
            continue
        if slot in TOGGLES:
            if idx > 0:
                mods[MOD_NAMES[slot]] = "TOGGLE"
        else:
            mods[MOD_NAMES[slot]] = [idx, 1 if v.get("variation") else 0]
    out["mods"] = mods
    out["primary_color"] = as_int(d.get("primaryColor"), 0, 255)
    out["secondary_color"] = as_int(d.get("secondaryColor"), 0, 255)
    out["pearlescent_color"] = as_int(d.get("pearlescentColor"), 0, 255)
    out["wheel_color"] = as_int(d.get("wheelColor"), 0, 255)
    out["interior_color"] = as_int(d.get("interiorColor"), 0, 255)
    out["dash_color"] = as_int(d.get("dashBoardColor"), 0, 255)
    out["custom_primary_color"] = rgb(d.get("customPrimaryColor")) if d.get("isPrimaryColorCustom") else None
    out["custom_secondary_color"] = rgb(d.get("customSecondaryColor")) if d.get("isSecondaryColorCustom") else None
    out["tire_smoke_color"] = rgb(d.get("tyreSmokeColor"))
    nk = d.get("neonKits") or {}
    out["neon_color"] = rgb(nk.get("color"))
    out["neon_lights"] = [bool(nk.get(s)) for s in ("left", "right", "front", "back")] if nk else None
    out["headlight_color"] = None
    out["vehicle_window_tint"] = as_int(d.get("windowTint"), -1, 6)
    out["wheel_type"] = as_int(d.get("wheelType"), -1, 12)
    out["plate_text_index"] = as_int(d.get("plateTextIndex"), 0, 12)
    out["plate_text"] = d.get("plateText") if isinstance(d.get("plateText"), str) else None
    bp = d.get("bulletproofTyres")
    out["tire_can_burst"] = None if bp is None else (0 if bp else 1)
    dt = d.get("driftTyres")
    out["drift_tires"] = None if dt is None else (1 if dt else 0)
    out["vehicle_livery"] = None
    extras = {}
    for k, v in (d.get("extras") or {}).items():
        m = re.fullmatch(r"extra(\d+)", k)
        if m and v:  # solo los que estan encendidos; el resto se deja como venga de fabrica
            extras[m.group(1)] = 1
    out["vehicle_extras"] = extras
    return out


def to_v2(c):
    """Formato de vehiculo guardado de YimMenuV2 (game/backend/SavedVehicles.cpp)."""
    j = {"vehicle_model_hash": c["model"] & 0xFFFFFFFF}
    for name in MOD_NAMES:
        if name and name in c["mods"]:
            j[name] = c["mods"][name]
    for k in ("primary_color", "secondary_color", "pearlescent_color", "wheel_color", "interior_color", "dash_color",
              "custom_primary_color", "custom_secondary_color", "tire_smoke_color", "neon_color", "neon_lights",
              "headlight_color", "vehicle_window_tint", "wheel_type", "plate_text", "plate_text_index",
              "tire_can_burst", "drift_tires", "vehicle_livery"):
        if c.get(k) is not None:
            j[k] = c[k]
    if c["vehicle_extras"]:
        # nlohmann guarda std::map<int, int> como lista de pares [id, encendido]
        j["vehicle_extras"] = sorted([int(k), v] for k, v in c["vehicle_extras"].items())
    if "plate_text" in j:
        j["plate_text"] = re.sub(r"[^ -~]", "", j["plate_text"])[:8]
    return j


def clean_name(s):
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    s = re.sub(r"(?i)\s*by\s*4b4nd0'?n4d0_xxx|4b4nd0n4d0_xxx|\s*by\s*piotrulojr", "", s)
    s = re.sub(r"[^A-Za-z0-9 _\-()\[\]]+", " ", s)
    s = re.sub(r"\s+", " ", s).strip(" -_")
    return s[:60] or "vehiculo"


def main(src, vlist, outdir, report):
    names = [l.strip() for l in open(vlist) if l.strip()]
    known = {joaat(n): n for n in names}
    stats = collections.Counter()
    rejected = collections.Counter()
    seen = {}
    used = set()
    for dp, _, fs in sorted(os.walk(src)):
        for f in sorted(fs):
            if not f.lower().endswith(".json"):
                continue
            p = os.path.join(dp, f)
            raw = open(p, "rb").read()
            stats["archivos"] += 1
            try:
                d = json.loads(raw.decode("utf-8-sig"))
            except Exception:
                try:
                    d = json.loads(raw.decode("latin-1"))
                except Exception:
                    stats["ilegibles"] += 1
                    continue
            if not isinstance(d, dict):
                stats["otro_formato"] += 1
                continue
            if "vehicle_model_hash" in d:
                c = from_yim(d)
            elif d.get("format") == "Cherax Entity" and "model" in d:
                c = from_cherax(d)
            else:
                stats["no_es_vehiculo"] += 1
                continue
            if c["model"] is None:
                stats["sin_modelo"] += 1
                continue
            h = c["model"] & 0xFFFFFFFF
            if h not in known:
                rejected[h] += 1
                stats["modelo_no_spawneable"] += 1
                continue
            j = to_v2(c)
            key = hashlib.sha1(json.dumps(j, sort_keys=True).encode()).hexdigest()
            if key in seen:
                stats["duplicados"] += 1
                continue
            rel = os.path.relpath(p, src).split(os.sep)
            # carpeta = la carpeta donde estaba el archivo (sin el sufijo __x de los .rar internos)
            pack = clean_name(re.sub(r"__x$", "", rel[-2])) if len(rel) > 1 else "Sueltos"
            name = clean_name(os.path.splitext(f)[0])
            base = f"{pack}/{name}"
            final, n = base, 2
            while final.lower() in used:
                final, n = f"{base} ({n})", n + 1
            used.add(final.lower())
            seen[key] = final
            os.makedirs(os.path.join(outdir, pack), exist_ok=True)
            with open(os.path.join(outdir, final + ".json"), "w", newline="\n") as fh:
                json.dump(j, fh, separators=(",", ":"))
                fh.write("\n")
            stats["validos"] += 1
    per_pack = collections.Counter(v.split("/")[0] for v in seen.values())
    models = collections.Counter()
    for v in seen.values():
        j = json.load(open(os.path.join(outdir, v + ".json")))
        models[known[j["vehicle_model_hash"]]] += 1
    json.dump({"stats": stats, "por_carpeta": per_pack, "modelos_distintos": len(models),
               "hashes_rechazados": {str(signed(k)): c for k, c in rejected.most_common()}},
              open(report, "w"), indent=2)
    print(json.dumps(stats), "\ncarpetas:", dict(per_pack), "\nmodelos distintos:", len(models),
          "\nhashes no reconocidos:", len(rejected))


if __name__ == "__main__":
    main(*sys.argv[1:5])
