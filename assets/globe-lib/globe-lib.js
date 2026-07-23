// GlobeSlate's front-end helper library — a MULTI-FILE ES module served from the package's vendored
// asset dir via `provide_assets!`. It imports a SIBLING (`./geo.js`), so it can't be inlined as a single
// `provide_frontend!` string: it must be SERVED as a directory. The bootstrap script (declared from
// `__slate_frontend`) dynamic-`import()`s this module once per page; it publishes `window.GlobeSlate`,
// helpers that build echarts-gl `lines3D` overlays (great-circle arcs, a graticule) for a `globe` scene.

import { greatCircle, graticule } from "./geo.js";

const VERSION = "0.1.0";

// Great-circle arcs between (lon,lat) endpoint pairs, as an echarts-gl `lines3D` series on the globe.
// `pairs` is `[[[lon,lat],[lon,lat]], …]`; drop the return value into a globe option's `series`.
function arcSeries(pairs, { n = 64, color = "#ffd166", width = 2, opacity = 0.85 } = {}) {
  return {
    type: "lines3D", coordinateSystem: "globe",
    lineStyle: { color, width, opacity },
    data: pairs.map(([a, b]) => ({ coords: greatCircle(a, b, n) })),
  };
}

// A faint lat/lon graticule as a `lines3D` series — orientation cues on an untextured globe.
function graticuleSeries({ step = 30, color = "#3b6ea5", width = 1, opacity = 0.35 } = {}) {
  return {
    type: "lines3D", coordinateSystem: "globe",
    lineStyle: { color, width, opacity },
    data: graticule(step).map(coords => ({ coords })),
  };
}

const api = { version: VERSION, arcSeries, graticuleSeries, greatCircle, graticule };
// Merge (don't clobber) so repeated page loads / a future Julia-side surface stay additive.
window.GlobeSlate = Object.assign(window.GlobeSlate || {}, api);
window.dispatchEvent(new CustomEvent("globeslate:ready", { detail: { version: VERSION } }));
export default api;
