#!/usr/bin/env bash
# Downloads input data: the two GTFS feeds, the OSM network (Geofabrik +
# pyosmium) and MapLibre GL. Everything is cached — re-running only fetches
# what is missing.
#
# TWO feeds make this map:
#
#   VOR — the Verbund's own GTFS: Wiener Linien's buses, trams and U-Bahn,
#   Österreichische Postbus, Dr. Richard, N-Bus, Blaguss, the Verkehrsbetriebe
#   Burgenland and the town networks, plus the NÖVOG railways and the CAT —
#   926 lines of 27 operators. It is published by Mobilitätsverbünde Österreich
#   on data.mobilitaetsverbuende.at and needs a FREE ACCOUNT: register, confirm
#   the mail, accept the licence on the data set "Fahrplandaten Verkehrsverbund
#   Ost-Region (GTFS)", then either
#     * download the zip by hand and drop it in as data/vor-gtfs.zip, or
#     * export a token and let this script fetch it:
#         token=$(curl -s -d client_id=dbp-public-ui -d grant_type=password \
#           -d scope=openid -d username=YOU -d password=SECRET \
#           https://user.mobilitaetsverbuende.at/auth/realms/dbp-public/protocol/openid-connect/token \
#           | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')
#         VOR_TOKEN=$token bash pipeline/download.sh
#   The token is short-lived, so the file is the calmer route.
#
#   ÖBB — the national rail feed (static.web.oebb.at, CC BY 4.0), open, no
#   account. The Verbund's own data deliberately leaves ÖBB out, so this is
#   where the S-Bahn, REX, CJX and R trains come from; pipeline/scope.mjs picks
#   the VOR's share of its 273 national routes.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/gtfs-vor data/gtfs-oebb data/gtfs-dpb data/gtfs-idsbk data/osm/tiles web/vendor

# 1) GTFS — the Verbund (account-gated: file or token, see the header)
if [ ! -f data/gtfs-vor/routes.txt ]; then
  if [ ! -f data/vor-gtfs.zip ] && [ -n "${VOR_TOKEN:-}" ]; then
    echo "== VOR GTFS (data set 52, via token) =="
    curl -fL --retry 3 --max-time 3600 -H "Authorization: Bearer $VOR_TOKEN" \
      -H "Accept: application/zip" -o data/vor-gtfs.zip \
      "https://data.mobilitaetsverbuende.at/api/public/v1/data-sets/52/2026/file"
  fi
  if [ ! -f data/vor-gtfs.zip ]; then
    echo "brak data/vor-gtfs.zip — pobierz zbiór \"Fahrplandaten Verkehrsverbund Ost-Region (GTFS)\"" >&2
    echo "z https://data.mobilitaetsverbuende.at/de/data-sets (darmowe konto) albo ustaw VOR_TOKEN" >&2
    exit 1
  fi
  echo "== VOR GTFS =="
  unzip -o data/vor-gtfs.zip -d data/gtfs-vor
fi

# 1b) GTFS — ÖBB (open, the rail backbone the Verbund feed leaves out)
if [ ! -f data/gtfs-oebb/routes.txt ]; then
  echo "== ÖBB GTFS =="
  curl -fL --retry 3 --max-time 3600 -o data/oebb-gtfs.zip \
    "https://static.web.oebb.at/open-data/soll-fahrplan-gtfs/GTFS_Fahrplan_2026.zip"
  unzip -o data/oebb-gtfs.zip -d data/gtfs-oebb
  # the zip carries one folder; the build reads the files directly
  if [ -d data/gtfs-oebb/GTFS_Fahrplan_2026 ]; then
    mv data/gtfs-oebb/GTFS_Fahrplan_2026/* data/gtfs-oebb/
    rmdir data/gtfs-oebb/GTFS_Fahrplan_2026
  fi
fi

# 1d) GTFS — the IDS BK (Wien & Bratislava, 11.09.2026), both open, listed on
#     https://www.idsbk.sk/en/about/open-data/:
#     * Dopravný podnik Bratislava — the city's buses, trolleybuses and trams,
#       an ArcGIS item that always serves the current file;
#     * the regional buses (ARRIVA) — a Google Drive folder of dated zips,
#       GTFS and JDF side by side; the newest "<date>-AMS-gtfs" is taken.
if [ ! -f data/gtfs-dpb/routes.txt ]; then
  echo "== DPB Bratislava GTFS =="
  curl -fL --retry 3 --max-time 600 -o data/dpb-gtfs.zip \
    "https://www.arcgis.com/sharing/rest/content/items/aba12fd2cbac4843bc7406151bc66106/data"
  mkdir -p data/gtfs-dpb && unzip -o -q data/dpb-gtfs.zip -d data/gtfs-dpb
fi
if [ ! -f data/gtfs-idsbk/routes.txt ]; then
  echo "== IDS BK regional buses GTFS =="
  id=$(curl -fsL -A "Mozilla/5.0" "https://drive.google.com/embeddedfolderview?id=1n9r_hGe-msl3bGa0q9vqI_ENODHT6n7x" | python3 -c '
import re, sys
s = sys.stdin.read()
files = re.findall(r"file/d/([^/]+)/.*?flip-entry-title\">([^<]+)<", s, re.S)
gtfs = sorted((n, i) for i, n in files if "-AMS-gtfs" in n)
print(gtfs[-1][1] if gtfs else "")')
  [ -n "$id" ] || { echo "nie znalazłem pliku *-AMS-gtfs w folderze IDS BK" >&2; exit 1; }
  curl -fL --retry 3 --max-time 600 -o data/idsbk-gtfs.zip \
    "https://drive.usercontent.google.com/download?id=$id&export=download&confirm=t"
  mkdir -p data/gtfs-idsbk && unzip -o -q data/idsbk-gtfs.zip -d data/gtfs-idsbk
fi

# 1c) scope: which ÖBB routes are the VOR's, and the line keys of the Verbund
if [ ! -f data/scope.json ]; then
  node --max-old-space-size=8192 pipeline/scope.mjs
fi

# 2) OSM — from the Geofabrik austria extract, not Overpass. The map is the
#    Verbund: Vienna, Lower Austria and Burgenland, 267 × 205 km, far past what
#    a public Overpass mirror will serve (the wall Berlin, London and São Paulo
#    hit before). pipeline/pbf-tiles.py cuts a 7 × 7 road grid and the rail box
#    — which reaches past the Verbund border, because the trains do — writing
#    exactly the JSON shape Overpass would have returned, node ids included.
if [ ! -f data/osm/tiles/t49.json ] || [ ! -f data/osm/vienna-rail.json ]; then
  python3 -c "import osmium" 2>/dev/null || { echo "brak pakietu osmium — zainstaluj: pip3 install --user osmium" >&2; exit 1; }
  if [ ! -f data/austria-latest.osm.pbf ]; then
    echo "== Geofabrik austria-latest.osm.pbf =="
    curl -fL --retry 5 --retry-delay 5 -C - --max-time 3600 -o data/austria-latest.osm.pbf \
      "https://download.geofabrik.de/europe/austria-latest.osm.pbf"
  fi
  echo "== cutting OSM tiles out of the extract =="
  python3 pipeline/pbf-tiles.py
fi
# 2b) the Bratislava region comes from its own country's extract: the Austrian
#     one stops at the border (tiles sk1–sk4 + bratislava-rail.json)
if [ ! -f data/osm/tiles/sk4.json ] || [ ! -f data/osm/bratislava-rail.json ]; then
  if [ ! -f data/slovakia-latest.osm.pbf ]; then
    echo "== Geofabrik slovakia-latest.osm.pbf =="
    curl -fL --retry 5 --retry-delay 5 -C - --max-time 3600 -o data/slovakia-latest.osm.pbf \
      "https://download.geofabrik.de/europe/slovakia-latest.osm.pbf"
  fi
  python3 pipeline/pbf-tiles.py --sk
fi

# 3) MapLibre GL (vendored, no CDN at runtime)
if [ ! -f web/vendor/maplibre-gl.js ]; then
  echo "== MapLibre GL =="
  curl -fL --retry 3 -o web/vendor/maplibre-gl.js  https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.js
  curl -fL --retry 3 -o web/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.css
fi

echo "OK — data ready:"
du -sh data/gtfs-vor data/gtfs-oebb data/osm 2>/dev/null || true
