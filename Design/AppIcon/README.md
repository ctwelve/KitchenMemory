# App icon source

The face-on recipe tray is assembled from simple SVG fragments in `Layers`.
`Design/Palette.json` is the source of truth for its colors and for the named
colors in the application asset catalog.

From the repository root, regenerate the committed SVG artwork and color sets:

```sh
swift Design/generate-theme.swift
```

Verify that generated files match their sources without changing them:

```sh
swift Design/generate-theme.swift --check
```

The generated layer SVGs use the default appearance and are the files to import
into Icon Composer. Use the dark values from `Design/Palette.json` for Icon
Composer's dark fill specializations. Glass, shadows, translucency, and mono
appearance tuning remain Icon Composer concerns rather than SVG effects.

The preview SVGs are flattened design checks only. Do not import their rounded
background into Icon Composer; configure the canvas background there so the
system owns the platform mask.
