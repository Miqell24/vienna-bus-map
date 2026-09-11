# Wien & Bratislava — VOR & IDS BK — interactive map

Interactive, poster-grade map of the **whole Verkehrsverbund Ost-Region**:
Wiener Linien's buses, trams and the U-Bahn, the Badner Bahn, the buses of
Postbus, Dr. Richard, N-Bus, Blaguss and the county operators of Lower Austria
and Burgenland, the NÖVOG railways and the CAT — and the S-Bahn, REX, CJX and
R trains that tie the region together — and since 11.09.2026 the IDS BK across
the border: Bratislava's buses, trolleybuses and trams (DPB) and the regional buses
of the Bratislava region (ARRIVA). **1 085 lines / 48 400 km**, drawn along
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
- **Lines sort on the printed number, not the key.** Nineteen numbers belong
  to more than one operator, so Wiener Linien's 1 is keyed `wl:1` and prints
  "1"; until 11.09.2026 the rows sorted on the key and the Ring read
  "71, 1, 2". Every list — number rows, badge grids, the panel — now compares
  the label and uses the key only to break ties.
- **"Wien " is dropped from the capital's stop names.** The VOR writes every
  stop as "<town> <stop>" (Wien Oper, Baden Josefsplatz, Wiener Neustadt
  Hauptbahnhof); on Vienna's own map the 4 528 "Wien …" poles print without
  the town, the other towns keep theirs, and Wien Mitte stays whole.

- **Terminus boxes print the number, not the key** (11.09.2026): the badge
  layer read `line` and showed `blag:1` or `dpb:N44` on 754 boxes since the
  Verbund build; it reads `lbl` first now, and so do the journey planner's
  overlay and result list.

## Bratislava — the IDS BK (11.09.2026)

The map is **Wien & Bratislava** since 11.09.2026: the integrated transport
system of the Bratislava region joins the Verbund, from the two open feeds
listed on [idsbk.sk/en/about/open-data](https://www.idsbk.sk/en/about/open-data/):

| feed | what it brings |
|---|---|
| **Dopravný podnik Bratislava** — an ArcGIS item that always serves the current file | the city's buses (3), trolleybuses (11, green) and trams 1, 3, 4, 9 (0), night lines N21–N99 |
| **IDS BK regional buses** — a Google Drive folder of dated GTFS/JDF zips, the newest `<date>-AMS-gtfs` taken | ARRIVA's regional lines 2xx–7xx: Záhorie, Pezinok, Senec, Šamorín |

- Every Bratislava key carries the operator code — `dpb:1`, `arriva:205` —
  and prints bare: Bratislava's tram 1 and Vienna's never merge, and the panel
  lists the two capitals' city operators first (Wiener Linien, DPB).
- **The regional feed is thin**: its `shapes.txt` is linked to no trip and it
  has no `direction_id`. The feed option `ignoreShapes` makes the stop
  sequences the geometry (pseudo-matching on the road graph), and `dirKey`
  takes the direction from the trip number's parity — the Slovak (JDF) rule,
  odd trips out, even back. `stopName` drops the "Bratislava, " prefix the
  regional feed writes before the city's stops, so they meet DPB's poles.
- DPB ships a two-point stub shape for one direction of 27, 69 and 144;
  `stubPseudo` draws those from their stops instead of dropping them.
- Left out: **901** (Hainburg – Bratislava), which the VOR feed already
  carries, and DOMINIQ's **105 808** to Rajka — not an IDS BK line (its own
  tickets) and mostly in Hungary. The ZSSK trains of the IDS BK are not in
  either feed.
- **OSM**: the Austrian extract stops at the border, so `pbf-tiles.py --sk`
  cuts four road tiles (47.95–48.66 N, 16.80–17.64 E) and Bratislava's tram
  network out of Geofabrik's `slovakia-latest.osm.pbf`.

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

**The series so far:** five builds of the metropolitan sheet (Wiener Linien only,
189–190 lines) from the weekly MobilityDatabase snapshots of the Wiener Linien
feed (mdb-648) — 14.07, 28.07, 13.08 (the sheet as published), 25.08 and
1.09.2026, on all of which tram 18 still ended at Schlachthausgasse — and
8.09.2026, the whole Verbund (927 lines; tram 18 extended through the Prater to
U2 Stadion on 5.09.2026, seven new stops from Ludwig-Koeßler-Platz to
Meiereistraße). The older sheets were rebuilt on 10.09 with the pipeline as it
was before 8.09 (a git worktree) and the snapshot feeds; the VOR feed itself
has no public history (it needs an account), so the Verbund sheet starts on
8.09.

## Pipeline

`npm run download` fetches both feeds (see above for the VOR account), computes
the scope and cuts the OSM data. **The OSM comes from Geofabrik, not
Overpass**: 267 × 205 km of Austria is far past what the public mirrors serve,
so `pipeline/pbf-tiles.py` (needs `pip3 install --user osmium`) cuts a 7 × 7
road grid and one rail box out of `austria-latest.osm.pbf`. `npm run build`
map-matches every line (HMM/Viterbi on the OSM graphs) and writes GeoJSON to
`data/out/`. `npm run serve` hosts the map at http://localhost:8136.

Data: VOR / Mobilitätsverbünde Österreich · ÖBB (CC BY 4.0) · IDS BK
(Dopravný podnik Bratislava, ARRIVA) ·
base map © OpenFreeMap / OpenMapTiles / OpenStreetMap contributors.
