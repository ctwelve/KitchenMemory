# App icon source

The face-on recipe tray is assembled from simple SVG fragments in `Layers`.
Named colors in `KitchenMemory/Assets.xcassets` are the source of truth.
`Design/Palette.json` maps the SVG tokens to those color-set names.

From the repository root, regenerate the committed SVG artwork and color sets:

```sh
swift Design/generate-theme.swift
```

Verify that generated files match their sources without changing them:

```sh
swift Design/generate-theme.swift --check
```

The generator writes reviewable layers and previews under `Generated`, and
builds `KitchenMemory/AppIcon.icon` with light and dark fill specializations.
The app target runs it before resource compilation, so an icon color changed in
the asset catalog is incorporated by the next build.

Glass, shadows, and translucency are fixed in the generated Icon Composer
document. Further visual tuning should be made in the generator rather than
directly in generated files, so subsequent builds do not discard it.

The preview SVGs are flattened design checks only. Do not import their rounded
background into Icon Composer; configure the canvas background there so the
system owns the platform mask.
