# Vienna Public Transport — interactive map

Interactive, poster-grade map of the **Wiener Linien** network: city and night
buses, the tram network and the U-Bahn (U1–U6, drawn in the official line
colors), plus the Badner Bahn of Wiener Lokalbahnen — 189 lines drawn along the
real street and track geometry.

## Live

**https://miqell24.github.io/vienna-bus-map/** — GitHub Pages from `main:/docs`.

Everything comes from ONE feed — the Wiener Linien GTFS bundle published on
[data.gv.at](https://www.data.gv.at) under CC BY 4.0
(https://www.wienerlinien.at/ogd_realtime/doku/ogd/gtfs/gtfs.zip) — split by
`route_type` at build time:

| mode | route_type | lines | graph |
|---|---|---|---|
| buses | 3 | 154: city lines (1A–99B) and night lines (N6–N91) | OSM roadways |
| trams | 0 | 30: 1–71, D, O and the Badner Bahn (BB) | `railway=tram` + `light_rail` |
| U-Bahn | 1 | 5: U1, U2, U3, U4, U6, official colors from `routes.txt` | `railway=subway` |

The Badner Bahn runs on street track inside Vienna and on its own `light_rail`
alignment for the 27 km down to Baden, which is why the tram graph takes both.

Build quirks worth knowing:

- **Rail-replacement services are dropped.** The feed carries dated
  `Schienenersatzverkehr` routes; drawn, they put a phantom line on the map, and
  three line keys (`SEV BB`, `U2E`, `E3`) exist *only* as replacements. Routes
  whose long name says Ersatzverkehr are skipped, and the `SEV` prefix is
  filtered by name as well — one of its routes carries an innocent long name.
- **Trams and U-Bahn get separate matching graphs.** A metro shape often passes
  closer to the tram tracks above its tunnel than to the subway axis, and a
  shared graph then lures the matcher onto disconnected rails.
- The feed is heavy: 78 MB zipped, 620 MB of `stop_times.txt` alone. A full
  build still takes about a minute.

Match quality is the best in the family: mean error 0.0–0.2 m on the U-Bahn,
0.4–2.1 m on the trams, ~1 m on the buses.

## Pipeline

`npm run download` fetches the Wiener Linien feed, OSM roadways and rails
(Overpass, bbox 47.95–48.36 N / 16.13–16.61 E) and MapLibre GL. `npm run build`
map-matches every line (HMM/Viterbi on the OSM graphs) and writes GeoJSON to
`data/out/`. `npm run serve` hosts the map at http://localhost:8136.

Data: Wiener Linien / Wiener Lokalbahnen timetables via data.gv.at (CC BY 4.0) ·
base map © OpenFreeMap / OpenMapTiles / OpenStreetMap contributors.
