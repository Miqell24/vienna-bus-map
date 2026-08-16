#!/usr/bin/env bash
# Downloads input data: Wiener Linien GTFS, OSM networks (Overpass), MapLibre GL.
# Everything is cached — re-running only fetches what is missing.
#
# ONE feed covers the whole Vienna network (data.gv.at, CC BY 4.0): Wiener Linien
# buses, trams and the U-Bahn (U1–U6, with shapes and the official line colors in
# routes.txt), plus the Badner Bahn of Wiener Lokalbahnen — an interurban tram
# that leaves the city and runs 27 km south to Baden. Modes are separated by
# route_type at build time.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/gtfs data/osm web/vendor

# A downloaded extract is only accepted if it PARSES and carries a plausible
# number of elements. `grep -q '"elements"'` — the guard this family used
# everywhere — passes on a truncated response too: Brașov's roads arrived as a
# 65 kB fragment that still contained the string, was taken for complete, and
# silently skipped the city (16.08.2026).
# The minimum differs by extract: a road network runs to tens of thousands of
# ways, a city rail network to a few hundred, so the caller passes its own floor
# rather than sharing one.
# A rejected file is deleted rather than left behind — the `[ ! -f … ]` gates
# below only ask whether the file exists, so a fragment on disk would be taken
# for a finished download on the next run.
ok_json () { # $1=file  $2=minimum element count
  python3 - "$1" "$2" <<'PYEOF' 2>/dev/null
import json, sys
try:
    sys.exit(0 if len(json.load(open(sys.argv[1])).get("elements", [])) >= int(sys.argv[2]) else 1)
except Exception:
    sys.exit(1)
PYEOF
}

# 1) GTFS — the Wiener Linien bundle (stable URL, refreshed in place)
#    Heavy: 78 MB zipped, 620 MB of stop_times alone.
if [ ! -f data/gtfs/routes.txt ]; then
  echo "== Wiener Linien GTFS =="
  curl -fL --retry 3 --max-time 900 -o data/vienna-gtfs.zip \
    "https://www.wienerlinien.at/ogd_realtime/doku/ogd/gtfs/gtfs.zip"
  unzip -o data/vienna-gtfs.zip -d data/gtfs
fi

# 2) OSM — roadways over the whole network extent (GTFS stops span 48.00–48.30 N,
#    16.20–16.55 E: Vienna plus the Badner Bahn corridor down to Baden)
if [ ! -f data/osm/vienna.json ]; then
  echo "== Overpass (roads) =="
  Q='[out:json][timeout:900];way(47.95,16.13,48.36,16.61)["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|busway|construction|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link)$"];out geom;'
  ok=0
  for EP in "https://overpass-api.de/api/interpreter" \
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter" \
            "https://overpass.kumi.systems/api/interpreter"; do
    echo "-- $EP"
    if curl -fsS --max-time 900 -o data/osm/vienna.json --data-urlencode "data=$Q" "$EP" \
       && ok_json "data/osm/vienna.json" 2000; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { rm -f data/osm/vienna.json; echo "Overpass: all mirrors failed" >&2; exit 1; }
fi

# 2b) OSM — rails for the tram and U-Bahn modes: tram tracks, the U-Bahn
#     (railway=subway, including the U6 viaduct sections) and light_rail/rail,
#     which is what the Badner Bahn runs on outside the city. Same bbox.
if [ ! -f data/osm/vienna-rail.json ]; then
  echo "== Overpass (rails) =="
  QT='[out:json][timeout:600];way(47.95,16.13,48.36,16.61)["railway"~"^(subway|tram|light_rail|rail)$"];out geom;'
  ok=0
  for EP in "https://overpass-api.de/api/interpreter" \
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter" \
            "https://overpass.kumi.systems/api/interpreter"; do
    echo "-- $EP"
    if curl -fsS --max-time 600 -o data/osm/vienna-rail.json --data-urlencode "data=$QT" "$EP" \
       && ok_json "data/osm/vienna-rail.json" 40; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { rm -f data/osm/vienna-rail.json; echo "Overpass (rails): all mirrors failed" >&2; exit 1; }
fi

# 3) MapLibre GL (vendored, no CDN at runtime)
if [ ! -f web/vendor/maplibre-gl.js ]; then
  echo "== MapLibre GL =="
  curl -fL --retry 3 -o web/vendor/maplibre-gl.js  https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.js
  curl -fL --retry 3 -o web/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.css
fi

echo "OK — data ready:"
du -sh data/vienna-gtfs.zip data/osm/vienna.json data/osm/vienna-rail.json 2>/dev/null || true
