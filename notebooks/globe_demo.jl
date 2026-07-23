try; import KaimonSlate; catch; error("This is a Kaimon Slate notebook — running it as plain Julia needs the KaimonSlate runtime in this environment. Add it with `import Pkg; Pkg.add(\"KaimonSlate\")`, or open it in Kaimon Slate."); end; KaimonSlate.standalone!(@__MODULE__; dir=@__DIR__)

#%% md id=intro
@md"""
# 🌐 GlobeSlate — 3D charts via echarts-gl

`GlobeSlate` adds 3D charts to a KaimonSlate notebook — surfaces, 3D scatter/bars, and a
textured globe — powered by [echarts-gl](https://github.com/ecomfe/echarts-gl).

It's a dogfood of the **`provide_assets!`** SDK seam: the package vendors `echarts-gl.min.js`
(too large to single-file-inline) and declares its directory, so Slate serves it from a stable,
package-scoped route (`/ext-assets/GlobeSlate/…`) while the package is loaded — offline, pinned,
and travelling in a static export — without forking Slate's `vendor.json`.

Each helper returns a plain echart option `Dict` (with a `requireScripts` marker so the render
waits for echarts-gl to load); wrap it with `echart`.
"""

#%% code id=use
using GlobeSlate

#%% md id=h_surface
@md"""
## Surface — a height field

`surface(z; xs, ys)` renders matrix `z` as a 3D surface, coloured by height. Drag to orbit.
"""

#%% code id=surface
let
    xs = -4:0.2:4
    ys = -4:0.2:4
    z = [exp(-(x^2 + y^2) / 6) * cos(hypot(x, y) * 2) for x in xs, y in ys]
    echart(surface(z; xs, ys, title = "a rippling bump"))
end

#%% md id=h_scatter
@md"""
## Scatter3D — a point cloud

`scatter3d(points)` takes an iterable of `(x, y, z)`, coloured by z.
"""

#%% code id=scatter
let
    pts = [(randn(), randn(), randn()) for _ in 1:1200]
    echart(scatter3d(pts; title = "a gaussian cloud", size = 6))
end

#%% md id=h_bar
@md"""
## Bar3D — a value grid

`bar3d(z; xs, ys)` draws matrix `z` as 3D bars.
"""

#%% code id=bar
let
    xs, ys = 1:8, 1:8
    z = [sin(x / 2) * cos(y / 2) + 1.2 for x in xs, y in ys]
    echart(bar3d(z; xs, ys, title = "a bar field"))
end

#%% md id=h_globe
@md"""
## Globe — geo points on a sphere

`globe(points)` places `(lon, lat, value)` points on a 3D globe. A `baseTexture` image URL
(served asset or CDN) paints the earth; omitted, it's a solid sphere.
"""

#%% code id=globe
let
    cities = [(-122.4, 37.8, 5.0), (2.35, 48.85, 4.0), (139.7, 35.7, 6.0),
              (-0.13, 51.5, 3.5), (151.2, -33.9, 2.5), (-43.2, -22.9, 4.5)]
    echart(globe(cities; title = "cities", size = 10))
end

#%% md id=h_lib
@md"""
## Front-end helper lib — a *multi-file* served ES module

Beyond the single `echarts-gl.min.js`, GlobeSlate vendors a small **multi-file ES module** under
`assets/globe-lib/`: `globe-lib.js` imports its sibling `./geo.js`. A module that imports a sibling
*can't* be inlined as one `provide_frontend!` string — it must be **served as a directory**, which is
exactly what `provide_assets!` provides. A tiny bootstrap (declared from `__slate_frontend`) dynamic-
`import()`s it once per page, publishing `window.GlobeSlate` — great-circle arc + graticule helpers that
build echarts-gl `lines3D` overlays for a `globe` scene.

This exercises the harder half of the asset seam: **path-relative resolution** of `./geo.js` live
(served from `/ext-assets/GlobeSlate/globe-lib/…`) and the **whole-tree copy** into a published export
(where the import URL is repointed to a `./`-relative page sibling). A single-file *standalone* export
can't carry the sibling module, so `window.GlobeSlate` is simply absent there — the charts above still
render; only the overlay helpers degrade.
"""

# ╔═╡ Slate.config · per-notebook settings (Settings panel)
#   docid = f318fa38-c3f6-42d5-9886-c4856ab9787d
# ╚═╡
