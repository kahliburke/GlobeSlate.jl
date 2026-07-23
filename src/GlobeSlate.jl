"""
    GlobeSlate

3D charts for KaimonSlate notebooks — surfaces, 3D scatter/bars, and a textured globe — powered by
[echarts-gl](https://github.com/ecomfe/echarts-gl). A dogfood of the SlateExtensionsBase
`provide_assets!` seam: the package VENDORS `echarts-gl.min.js` (a multi-hundred-KB library that can't
be single-file-inlined) and declares its directory so Slate serves it from a stable, package-scoped
route (`/ext-assets/GlobeSlate/…`) while the package is loaded — offline, pinned, and travelling in a
static export — WITHOUT forking KaimonSlate's `vendor.json`.

Each helper returns a plain echart OPTION `Dict` carrying `requireScripts` (the marker Slate's render
path gates on, so the chart waits for echarts-gl to load before `setOption`). Wrap it with `echart`:

```julia
using GlobeSlate
z = [sin(hypot(x, y)) for x in -3:0.2:3, y in -3:0.2:3]
echart(surface(z; title = "a ripple"))
```
"""
module GlobeSlate

using SlateExtensionsBase

export surface, scatter3d, bar3d, globe

# The served URL of the vendored library. `provide_assets!` (in `__slate_frontend`) maps the "GlobeSlate"
# scope to the on-disk `assets` dir; `ext_asset_url` builds the route Slate serves each file at
# (rewritten to a page-local sibling in a static export) — no hardcoded prefix. Every chart option below
# lists it under `requireScripts`, the Slate render-gate marker: the chart waits until this script has
# loaded, so the 3D series types echarts-gl registers onto the global `echarts` exist before first paint.
_gl_script() = ext_asset_url("GlobeSlate", "echarts-gl/echarts-gl.min.js")

# Package-global front-end hook: Slate invokes `__slate_frontend(slate_on)` once per drain per loaded
# module (guarded), so a package declares its front-end from HERE — no `__init__`, no boot cell. We
# vendor the whole `assets` dir (echarts-gl under `echarts-gl/`, the front-end helper lib under
# `globe-lib/`) and inject a tiny bootstrap that dynamic-`import()`s the lib once per page. echarts-gl
# itself is loaded per-chart via `requireScripts`, not here; `slate_on` (the JS→Julia handler registrar)
# still goes unused — this package is push-only.
function __slate_frontend(slate_on)
    provide_assets!("GlobeSlate", @pkg_dir("assets"))
    # Bootstrap: load the MULTI-FILE helper lib (globe-lib.js imports its sibling ./geo.js) from the
    # served asset dir. `ext_asset_url` yields the live `/ext-assets/…` route; a static export rewrites it
    # to a page-local sibling. A failed import is swallowed so a single-file standalone export (which can't
    # carry the sibling module) degrades to "no window.GlobeSlate" instead of a console error storm.
    boot = """
    import($(repr(ext_asset_url("GlobeSlate", "globe-lib/globe-lib.js"))))
      .catch(e => console.warn("GlobeSlate: front-end lib unavailable (single-file export?)", e));
    """
    provide_frontend!(boot; id = "globeslate-lib", esm = true)
    return nothing
end

# Tag an option dict as needing echarts-gl loaded first, and hand it back — every public helper ends here.
_gl!(opt::Dict{String,Any}) = (opt["requireScripts"] = String[_gl_script()]; opt)

# A `grid3D` scene (the cartesian 3D coordinate system echarts-gl draws surface/scatter/bar into) with
# axis names and an orbit camera. `autoRotate` gives the idle spin that reads as "3D" at a glance.
function _grid3d(; xname, yname, zname, autoRotate)
    Dict{String,Any}(
        "grid3D" => Dict{String,Any}(
            "viewControl" => Dict{String,Any}("autoRotate" => autoRotate, "autoRotateSpeed" => 8,
                                              "distance" => 200),
            "boxWidth" => 100, "boxDepth" => 100, "boxHeight" => 80),
        "xAxis3D" => Dict{String,Any}("type" => "value", "name" => xname),
        "yAxis3D" => Dict{String,Any}("type" => "value", "name" => yname),
        "zAxis3D" => Dict{String,Any}("type" => "value", "name" => zname))
end

# A continuous `visualMap` colouring points/faces by their z value — the viridis-ish ramp Slate's theme
# uses elsewhere. `min`/`max` are the z extent so the full ramp is used.
function _visualmap(zmin, zmax)
    Dict{String,Any}("show" => true, "dimension" => 2, "min" => zmin, "max" => zmax,
        "inRange" => Dict{String,Any}("color" => ["#313695", "#4575b4", "#74add1", "#abd9e9",
            "#e0f3f8", "#ffffbf", "#fee090", "#fdae61", "#f46d43", "#d73027", "#a50026"]))
end

_titleblock(title) = isempty(title) ? Dict{String,Any}[] :
    [Dict{String,Any}("text" => title, "left" => "center")]

"""
    surface(z; xs, ys, title="", autoRotate=false, wireframe=false) -> Dict

A 3D height surface of matrix `z` over grids `xs` (rows) and `ys` (columns), coloured by height.
`xs`/`ys` default to the axis indices. Pass to `echart`:

```julia
z = [exp(-(x^2 + y^2) / 4) for x in -4:0.25:4, y in -4:0.25:4]
echart(surface(z; xs = -4:0.25:4, ys = -4:0.25:4, title = "a bump"))
```
"""
function surface(z::AbstractMatrix; xs = axes(z, 1), ys = axes(z, 2),
                 title::AbstractString = "", autoRotate::Bool = false, wireframe::Bool = false)
    xv, yv = collect(xs), collect(ys)
    (length(xv), length(yv)) == size(z) ||
        throw(ArgumentError("length(xs)×length(ys) = $(length(xv))×$(length(yv)) must match size(z) = $(size(z))"))
    data = [Any[xv[i], yv[j], z[i, j]] for i in axes(z, 1) for j in axes(z, 2)]
    opt = merge(_grid3d(; xname = "x", yname = "y", zname = "z", autoRotate),
        Dict{String,Any}(
            "title" => _titleblock(title),
            "visualMap" => _visualmap(minimum(z), maximum(z)),
            "series" => [Dict{String,Any}("type" => "surface", "data" => data,
                "wireframe" => Dict{String,Any}("show" => wireframe),
                "shading" => "color")]))
    return _gl!(opt)
end

"""
    scatter3d(points; title="", autoRotate=false, size=8) -> Dict

A 3D scatter of `points` — an iterable of `(x, y, z)` tuples/vectors, coloured by z. `size` is the
symbol size in px.
"""
function scatter3d(points; title::AbstractString = "", autoRotate::Bool = false, size::Real = 8)
    data = [Any[p[1], p[2], p[3]] for p in points]
    zs = [Float64(p[3]) for p in points]
    opt = merge(_grid3d(; xname = "x", yname = "y", zname = "z", autoRotate),
        Dict{String,Any}(
            "title" => _titleblock(title),
            "visualMap" => _visualmap(isempty(zs) ? 0.0 : minimum(zs), isempty(zs) ? 1.0 : maximum(zs)),
            "series" => [Dict{String,Any}("type" => "scatter3D", "data" => data,
                "symbolSize" => size)]))
    return _gl!(opt)
end

"""
    bar3d(z; xs, ys, title="", autoRotate=false) -> Dict

A 3D bar chart of matrix `z` over grids `xs`/`ys`, bar height + colour = value.
"""
function bar3d(z::AbstractMatrix; xs = axes(z, 1), ys = axes(z, 2),
               title::AbstractString = "", autoRotate::Bool = false)
    xv, yv = collect(xs), collect(ys)
    (length(xv), length(yv)) == size(z) ||
        throw(ArgumentError("length(xs)×length(ys) = $(length(xv))×$(length(yv)) must match size(z) = $(size(z))"))
    data = [Any[xv[i], yv[j], z[i, j]] for i in axes(z, 1) for j in axes(z, 2)]
    opt = merge(_grid3d(; xname = "x", yname = "y", zname = "z", autoRotate),
        Dict{String,Any}(
            "title" => _titleblock(title),
            "visualMap" => _visualmap(minimum(z), maximum(z)),
            "series" => [Dict{String,Any}("type" => "bar3D", "data" => data,
                "shading" => "lambert")]))
    return _gl!(opt)
end

# The served URL of the vendored NASA Blue Marble base texture (a ~1.3 MB JPEG under `assets/textures`).
# A binary asset too large to sanely inline — the `provide_assets!` case for a non-code file — served from
# disk live and travelling in a static export (page-local sibling, or a `data:` URL in a standalone page).
_earth_texture() = ext_asset_url("GlobeSlate", "textures/earth.jpg")

"""
    globe(points; title="", autoRotate=false, baseTexture=:earth, baseColor="#1b3a5b", size=6) -> Dict

A 3D globe with a `scatter3D` layer of geo `points` — an iterable of `(lon, lat)` (or `(lon, lat, val)`)
tuples. By default (`baseTexture = :earth`) the sphere is painted with the vendored NASA Blue Marble
texture; pass `baseTexture = nothing` for a solid, lit `baseColor` (a dark ocean blue), or your own image
URL (a served asset or CDN) to paint a different map. Points are coloured by `val` (or the third tuple
element) when present.
"""
function globe(points; title::AbstractString = "", autoRotate::Bool = false,
               baseTexture = :earth, baseColor::AbstractString = "#1b3a5b", size::Real = 6)
    data = [Any[p[1], p[2], length(p) >= 3 ? p[3] : 1.0] for p in points]
    vals = [Float64(length(p) >= 3 ? p[3] : 1.0) for p in points]
    # Without a texture, echarts-gl draws a bare unlit sphere (reads as a flat white disc). A solid
    # `baseColor` + `lambert` shading + a keyed light give it depth so it looks like a globe.
    gl = Dict{String,Any}(
        "baseColor" => baseColor,
        "shading" => "lambert",
        "light" => Dict{String,Any}(
            "main" => Dict{String,Any}("intensity" => 1.6, "shadow" => false, "alpha" => 40, "beta" => 30),
            "ambient" => Dict{String,Any}("intensity" => 0.4)),
        "viewControl" => Dict{String,Any}("autoRotate" => autoRotate, "autoRotateSpeed" => 8))
    tex = baseTexture === :earth ? _earth_texture() : baseTexture
    tex === nothing || (gl["baseTexture"] = String(tex))
    opt = Dict{String,Any}(
        "title" => _titleblock(title),
        "globe" => gl,
        "visualMap" => merge(_visualmap(isempty(vals) ? 0.0 : minimum(vals),
                                        isempty(vals) ? 1.0 : maximum(vals)),
                             Dict{String,Any}("dimension" => 2)),
        "series" => [Dict{String,Any}("type" => "scatter3D", "coordinateSystem" => "globe",
            "data" => data, "symbolSize" => size)])
    return _gl!(opt)
end

end # module
