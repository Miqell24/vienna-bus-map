# VOR — Vienna, Lower Austria & Burgenland — interactive map

Interactive, poster-grade map of the **whole Verkehrsverbund Ost-Region**:
Wiener Linien's buses, trams and the U-Bahn, the Badner Bahn, the buses of
Postbus, Dr. Richard, N-Bus, Blaguss and the county operators of Lower Austria
and Burgenland, the NÖVOG railways and the CAT — and the S-Bahn, REX, CJX and
R trains that tie the region together. **928 lines / 43 000 km**, drawn along
the real street and track geometry, weighted mean matching error 0.69 m.

## Live

**https://miqell24.github.io/vienna-bus-map/** — GitHub Pages from `main:/docs`.

## The two feeds

| feed | what it brings | licence |
|---|---|---|
| **VOR** — `data.mobilitaetsverbuende.at`, data set 52 | 926 routes of 27 operators: buses (3), trams (0), U-Bahn (1) and the NÖVOG/CAT railways (2) | Datenlizenz Mobilitätsverbünde Österreich, **free account required** |
| **ÖBB** — `static.web.oebb.at/open-data/soll-fahrplan-gtfs` | the S-Bahn, REX, CJX and R trains — the Verbund's own data deliberately leaves ÖBB out | CC BY 4.0, open |

The VOR file is behind a login: register on the portal, confirm the mail,
accept the licence on "Fahrplandaten Verkehrsverbund Ost-Region (GTFS)", then
either drop the zip in as `data/vor-gtfs.zip` or export a token and let
`pipeline/download.sh` fetch it (see its header). Still missing, because nobody
publishes them openly: the WESTbahn and the Raaberbahn to Sopron.

`pipeline/scope.mjs` decides which of ÖBB's 273 national routes are the
Verbund's — by PRODUCT (S/REX/CJX/R, not the RJ/ICE corridors) and by AREA: at
least half the stops inside Vienna, Lower Austria and Burgenland, tested
against a POLYGON of the three Länder. A box would not do: Austria numbers its
lines per Verbund, and a box over the three Länder also covers eastern Styria
and the Enns valley, so the Styrian S1 from Bruck an der Mur and the Upper
Austrian REX1 from Linz would have walked in under the Viennese ones. A line
that passes is then drawn WHOLE, the way the Berlin map draws its RB/RE.

**Line keys.** Nineteen numbers belong to more than one operator — there are
four different "1" — so a shared number carries its operator's code in the key
(`wl:1`, `pb:1`) and prints bare on the street; the panel groups its chips by
operator. The Randstad rule.

| mode | route_type | lines | graph |
|---|---|---|---|
| buses | 3 | 827 — Wiener Linien 1A–99B and N6–N91, and the whole regional network | OSM roadways |
| trams | 0 | 30: 1–71, D, O and the Badner Bahn (BB) | `railway=tram` + `light_rail` |
| U-Bahn | 1 | 5: U1, U2, U3, U4, U6, official colors from `routes.txt` | `railway=subway` |
| trains | 2 (both feeds) | 66: S1–S80, REX, CJX, R, and NÖVOG's Mariazellerbahn, Waldviertelbahn, Wachaubahn, Reblandbahn, Schneebergbahn, the Höllentalbahn, the Zayataler Schienentaxi and the CAT | `railway=rail` + `narrow_gauge` |

Build quirks worth knowing:

- **The trains carry one colour, the S-Bahn blue** — on these maps the colour
  says the MODE, and S-Bahn, REX and R are one mode: the region's rail. Only
  the U-Bahn keeps its official per-line colours.
- **The Verbindungsbahn is a building site.** The link the S-Bahn uses between
  Rennweg and Meidling is tagged `construction`, `disused` and `proposed` in
  OSM, all of it `usage=main`, and without it the S1 came out with a 4.6 km
  hole through the middle of the city. Mainline track counts whatever stage of
  the rebuild its tags are in; admitted ways are renamed to what they are being
  built as before the graph is built.
- **Narrow gauge counts too.** NÖVOG's lines are 760 mm and the Schneebergbahn
  is a metre-gauge rack railway; without `narrow_gauge` the REX56 to Mariazell
  matched 5 km of the wrong track instead of its 84.
- **Representative variants.** S1 is worked 539 times a day in 68 patterns and
  the busiest is six stops from Meidling to Liesing — the map drew 9 km instead
  of 64 until the pipeline learned to take the longest pattern still worked by
  15% of the busiest one's trips. A two-point shape is not a route, though:
  those are dropped (ÖBB ships one for the R8 across the Slovak border).
- **Rail-replacement services are dropped**, by long name and by the `SEV`
  prefix.

## Timeline — the map's versions

The panel's **Map version** row (10.09.2026, the Kraków mechanism of 3.09)
switches between dated versions of the network in place: the camera, the base,
the picked line, the label sizes, the density and the mode filters all stay as
they are — only the data changes. Each version is a build of `data/out/`,
archived by `pipeline/snapshot.mjs` under `data/out/versions/<YYYY-MM-DD>/`
(the corridor view only: `streets`, `labels`, `stops`, `street-names`,
`badges`, `meta` — the archives carry no `route.geojson`, so the journey
planner works on the current build and says so) and listed in
`data/out/versions.json` with the feeds it came from and its line list; the
row shows the lines added and removed since the previous version.
`#v=2026-08-13` in the URL opens a given version. `npm run build` archives its
predecessor (prebuild) and stamps the new build (postbuild);
`node pipeline/snapshot.mjs --src DIR --id YYYY-MM-DD` imports an outside file
set.

**The series so far:** 13.08.2026 — the metropolitan sheet (Wiener Linien only,
189 lines; tram 18 still ended at Schlachthausgasse) — and 8.09.2026 — the whole
Verbund (927 lines; tram 18 extended through the Prater to U2 Stadion on
5.09.2026, seven new stops from Ludwig-Koeßler-Platz to Meiereistraße).

## Pipeline

`npm run download` fetches both feeds (see above for the VOR account), computes
the scope and cuts the OSM data. **The OSM comes from Geofabrik, not
Overpass**: 267 × 205 km of Austria is far past what the public mirrors serve,
so `pipeline/pbf-tiles.py` (needs `pip3 install --user osmium`) cuts a 7 × 7
road grid and one rail box out of `austria-latest.osm.pbf`. `npm run build`
map-matches every line (HMM/Viterbi on the OSM graphs) and writes GeoJSON to
`data/out/`. `npm run serve` hosts the map at http://localhost:8136.

Data: VOR / Mobilitätsverbünde Österreich · ÖBB (CC BY 4.0) ·
base map © OpenFreeMap / OpenMapTiles / OpenStreetMap contributors.
