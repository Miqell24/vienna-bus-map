// Picks what belongs on a VOR map and writes data/scope.json: the ÖBB routes
// that are the Verbund's railways, and the line KEY + operator of every route
// of the VOR feed itself.
//
// TWO feeds make this map. The Verbund's own GTFS
// (data.mobilitaetsverbuende.at, free account, licence accepted per data set)
// carries everything VOR runs — Wiener Linien, Postbus, the county operators,
// the NÖVOG railways and the CAT — EXCEPT the trains of ÖBB, the WESTbahn and
// the Raaberbahn. So the rail backbone of the region comes from ÖBB's own open
// feed (static.web.oebb.at, CC BY 4.0), which is national: 273 routes from
// Bregenz to Nickelsdorf.
//
// Two rules pick the VOR share of ÖBB:
//   * the PRODUCT: S-Bahn (S1–S9, S40–S80), REX, CJX and R — the regional
//     network. The A-, number- and CH/E-coded routes are the long-distance
//     corridors (their trips are the RJ/ICE/NJ trains, named in
//     trip_short_name), and SV… is rail replacement by bus;
//   * the AREA: at least half the route's stops inside the Verbund's three
//     Länder (a polygon — see AREA below, and the reason it is not a box). A
//     line that passes is then drawn WHOLE, the way the Berlin map draws its
//     RB/RE — REX92 keeps its run to Mürzzuschlag.
//
// LINE KEYS: 19 numbers belong to more than one operator in the Verbund —
// Wiener Linien's 1, 2 and 5 are also a Postbus line, a Blaguss line and a
// Wiener Neustadt town line. A shared number therefore carries its operator's
// code in the KEY (wl:1, pb:1) and prints bare on the street; the panel groups
// its chips by that operator. The Randstad rule, as in Berlin.
//
// Run by download.sh after the feeds are unpacked; build.mjs needs the result.
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { iterCsv, readCsv } from './lib/csv.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const GD = join(ROOT, 'data/gtfs-oebb');
const VD = join(ROOT, 'data/gtfs-vor');

const t0 = Date.now();
const log = (m) => console.log(`[scope ${((Date.now() - t0) / 1000).toFixed(0)}s] ${m}`);

// Wien + Niederösterreich + Burgenland as a POLYGON, not a box: a box over
// the three Länder also covers eastern Styria and the Enns valley, and
// Austria reuses its line numbers per Verbund — the Styrian S1 (Bruck an der
// Mur) and the Upper Austrian REX1 (Linz) would have walked in under the
// Viennese ones. Twenty vertices are enough to tell the Verbund from its
// neighbours; checked against Graz, Bruck, Linz, Steyr, Selzthal and Salzburg
// on one side and Gmünd, Retz, Bernhardsthal, Neusiedl, Jennersdorf, Güssing,
// Amstetten and the Semmering on the other.
const AREA = [
  [48.78, 14.66], [48.95, 15.05], [48.85, 15.60], [48.94, 16.15], [48.72, 16.55],
  [48.80, 16.95], [48.32, 17.10], [48.00, 17.16], [47.55, 16.72], [47.00, 16.53],
  [46.83, 16.30], [46.88, 16.00], [47.40, 16.00], [47.62, 15.85], [47.66, 15.25],
  [47.83, 14.90], [48.05, 14.72], [48.25, 14.78], [48.55, 14.60],
];
const inArea = (lat, lon) => {
  let c = false;
  for (let i = 0, j = AREA.length - 1; i < AREA.length; j = i++) {
    const [ai, aj] = [AREA[i], AREA[j]];
    if ((ai[0] > lat) !== (aj[0] > lat)
      && lon < (aj[1] - ai[1]) * (lat - ai[0]) / (aj[0] - ai[0]) + ai[1]) c = !c;
  }
  return c;
};
const CORE_SHARE = 0.5;
const PRODUCT = /^(S\d|REX\d*|CJX\d*|R\d)/;

const routes = await readCsv(join(GD, 'routes.txt'));
const named = routes.filter((r) => PRODUCT.test((r.route_short_name || '').trim()));
log(`z ${routes.length} tras ÖBB: ${named.length} to S-Bahn/REX/CJX/R`);

const wanted = new Set(named.map((r) => r.route_id));
const t2r = new Map();
for await (const t of iterCsv(join(GD, 'trips.txt'))) {
  if (wanted.has(t.route_id)) t2r.set(t.trip_id, t.route_id);
}
const stops = new Map();
for await (const s of iterCsv(join(GD, 'stops.txt'))) {
  const lat = Number(s.stop_lat), lon = Number(s.stop_lon);
  if (Number.isFinite(lat) && Number.isFinite(lon)) stops.set(s.stop_id, [lat, lon]);
}
const rStops = new Map();
for await (const st of iterCsv(join(GD, 'stop_times.txt'))) {
  const rid = t2r.get(st.trip_id);
  if (!rid) continue;
  let s = rStops.get(rid);
  if (!s) rStops.set(rid, (s = new Set()));
  s.add(st.stop_id);
}

const rail = [];
const box = [90, -90, 180, -180];
for (const [rid, ss] of rStops) {
  let n = 0, inside = 0;
  const pts = [];
  for (const sid of ss) {
    const p = stops.get(sid);
    if (!p) continue;
    n++;
    if (inArea(p[0], p[1])) inside++;
    pts.push(p);
  }
  if (!n || inside / n < CORE_SHARE) continue;
  rail.push(rid);
  for (const p of pts) {
    if (p[0] < box[0]) box[0] = p[0]; if (p[0] > box[1]) box[1] = p[0];
    if (p[1] < box[2]) box[2] = p[1]; if (p[1] > box[3]) box[3] = p[1];
  }
}
rail.sort();
const names = [...new Set(named.filter((r) => rail.includes(r.route_id))
  .map((r) => (r.route_short_name || '').trim()))].sort();
log(`na mapę: ${rail.length} tras / ${names.length} linii — ${names.join(', ')}`);
log(`zasięg szyn: ${box[0].toFixed(2)}–${box[1].toFixed(2)} N, ${box[2].toFixed(2)}–${box[3].toFixed(2)} E`);
// ---------- the VOR feed: operator codes, line keys, panel headings ----------
// A code per operator, from its name; anything not named here falls back to
// the initials, or the first word where those give less than two letters.
const OP_CODE = [
  [/Wiener Linien/i, 'wl'], [/Wiener Lokalbahnen/i, 'wlb'], [/Postbus/i, 'pb'],
  [/Burgenland/i, 'vbb'], [/Dr\. ?Richard\/Zuklin/i, 'drz'], [/Dr\. ?Richard NÖ/i, 'drn'],
  [/Dr\. ?Richard/i, 'dr'], [/N-Bus/i, 'nbus'], [/NÖVOG/i, 'novog'],
  [/Blaguss/i, 'blag'], [/ZuklinBus/i, 'zuk'], [/Wr\. Neustädter/i, 'wnsw'],
  [/Mattersburg/i, 'matt'], [/Ybbs/i, 'ybbs'], [/Lokalbahnen Betriebsges/i, 'nlb'],
  [/ÖGLB/i, 'oeglb'], [/CAT/, 'cat'], [/VOR GmbH/i, 'vor'], [/Bratislava/i, 'dpb'],
  [/ARRIVA/i, 'arriva'], [/Zayataler/i, 'zay'],
];
const initials = (name) => {
  const ini = (name.match(/\b[A-ZÄÖÜ]/g) || []).join('').slice(0, 4).toLowerCase();
  return ini.length >= 2 ? ini : (name.match(/[A-Za-zÄÖÜäöü]+/) || ['x'])[0].slice(0, 3).toLowerCase();
};
const codeOf = (name) => (OP_CODE.find(([re]) => re.test(name)) || [null, initials(name)])[1];

const vAgencies = new Map();
for (const a of await readCsv(join(VD, 'agency.txt'))) vAgencies.set(a.agency_id, a.agency_name);
const vCode = new Map();
for (const [id, name] of vAgencies) vCode.set(id, codeOf(name));
const opName = {};
for (const [id, name] of vAgencies) {
  const code = vCode.get(id);
  const short = name
    .replace(/\s*\b(GmbH|mbH|AG|OHG|KG|Betriebsges\.m\.b\.H|Ges\.m\.b\.H|& Co\.? ?KG)\b\.?/g, '')
    .replace(/\s*&\s*Co\.?\s*$/i, '').replace(/\s{2,}/g, ' ').replace(/\s*&\s*$/, '').trim();
  if (!opName[code] || short.length < opName[code].length) opName[code] = short;
}
opName.oebb = 'ÖBB — S-Bahn, REX, R';

const vRoutes = await readCsv(join(VD, 'routes.txt'));
const byName = new Map();
for (const r of vRoutes) {
  const sn = (r.route_short_name || '').trim();
  if (!sn) continue;
  let set = byName.get(sn);
  if (!set) byName.set(sn, (set = new Set()));
  set.add(vCode.get(r.agency_id));
}
const shared = new Set([...byName].filter(([, ops]) => ops.size > 1).map(([sn]) => sn));
const key = {}, op = {};
for (const r of vRoutes) {
  const sn = (r.route_short_name || '').trim();
  const code = vCode.get(r.agency_id);
  key[r.route_id] = shared.has(sn) ? `${code}:${sn}` : sn;
  op[r.route_id] = code;
}
log(`feed VOR: ${vRoutes.length} tras, ${vAgencies.size} przewoźników, `
  + `${shared.size} numerów u więcej niż jednego (dostaną kod w kluczu)`);

writeFileSync(join(ROOT, 'data/scope.json'),
  JSON.stringify({ rail, bbox: box, key, op, opName }, null, 0));
log('zapisano data/scope.json');
