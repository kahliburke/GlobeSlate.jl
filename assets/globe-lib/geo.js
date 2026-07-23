// Pure spherical geometry for globe overlays — no echarts, no DOM. The SIBLING module that
// globe-lib.js imports with a relative specifier (`./geo.js`); together they exercise Slate's
// `provide_assets!` seam serving a MULTI-FILE ES module (a lib that can't be inlined as one string).

const D2R = Math.PI / 180, R2D = 180 / Math.PI;

// (lon,lat)° → unit vector on the sphere.
function toVec([lon, lat]) {
  const a = lon * D2R, b = lat * D2R, c = Math.cos(b);
  return [c * Math.cos(a), c * Math.sin(a), Math.sin(b)];
}
// unit vector → (lon,lat)°.
function toLonLat([x, y, z]) {
  return [Math.atan2(y, x) * R2D, Math.asin(Math.max(-1, Math.min(1, z))) * R2D];
}

// Great-circle (slerp) samples between two (lon,lat) endpoints — the shortest path over the sphere,
// the curve a flight actually follows (a straight lon/lat lerp bows the wrong way near the poles).
// Returns `n + 1` points; a degenerate (coincident) pair collapses to the two endpoints.
export function greatCircle(a, b, n = 64) {
  const u = toVec(a), v = toVec(b);
  const dot = Math.max(-1, Math.min(1, u[0] * v[0] + u[1] * v[1] + u[2] * v[2]));
  const w = Math.acos(dot);                          // angular distance between the endpoints
  if (w < 1e-9) return [a.slice(), b.slice()];
  const s = Math.sin(w), out = [];
  for (let i = 0; i <= n; i++) {
    const t = i / n, k0 = Math.sin((1 - t) * w) / s, k1 = Math.sin(t * w) / s;
    out.push(toLonLat([k0 * u[0] + k1 * v[0], k0 * u[1] + k1 * v[1], k0 * u[2] + k1 * v[2]]));
  }
  return out;
}

// A lat/lon graticule as an array of polylines (each a list of (lon,lat)) at `step`° spacing —
// orientation cues for an untextured globe.
export function graticule(step = 30) {
  const lines = [];
  for (let lat = -90 + step; lat < 90; lat += step) {
    const row = [];
    for (let lon = -180; lon <= 180; lon += 5) row.push([lon, lat]);
    lines.push(row);
  }
  for (let lon = -180; lon < 180; lon += step) {
    const col = [];
    for (let lat = -90; lat <= 90; lat += 5) col.push([lon, lat]);
    lines.push(col);
  }
  return lines;
}
