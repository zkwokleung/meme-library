# Manual Test Matrix

Native behaviors that automated tests cannot cover run on physical
devices before each release. Record the device, OS version, and result.

## Import from photos

The picker is the one place the two platforms run different code — iOS
uses `PHPickerViewController` through the method channel, Android uses
the `image_picker` plugin — so every row needs both columns.

| Case | iOS | Android |
| ---- | --- | ------- |
| Pick a single photo → imports | | |
| Pick 10+ photos at once → all import | | |
| First-ever pick shows **no permission dialog** | | |
| Cancel the picker → no message at all, nothing imported | | |
| Pick a photo already in the library → duplicate, no second copy | | |
| Pick a HEIC photo → imports as JPEG, upright | | |
| Pick a portrait photo shot in landscape → upright in grid *and* detail | | |
| Pick an animated GIF → stays animated, timing matches the source | | |
| Pick an animated WebP → stays animated, alpha preserved | | |
| Pick an APNG → stays animated | | |
| Pick a photo over 25 MB → actionable "too large", no crash | | |
| 20-photo import: UI stays responsive throughout (isolate offload) | | |
| Home out with the picker open, return → picker still works | | |
| Live Photo | | — |
| iCloud photo not resident on device | | — |
| Process death mid-pick ("don't keep activities") | — | |

The three animation rows are the regression gate for using native
PHPicker on iOS instead of `image_picker`, which re-encodes every result
through `UIImage` and would flatten them.

## Import

| Case | iOS | Android |
| ---- | --- | ------- |
| Paste image copied from Photos / Gallery | | |
| Paste image copied from a browser | | |
| Paste with empty clipboard → actionable message | | |
| Save from link (https image URL) | | |
| Save from link: 404, timeout, non-image → actionable errors | | |
| Share one image from Photos / Gallery (app closed) | | |
| Share one image (app in background) | | |
| Share multiple images at once | | |
| Share an animated GIF → imports; tile plays in the grid and detail | | |
| Paste a copied GIF → imports animated (not flattened to a still) | | |

## Reuse

| Case | iOS | Android |
| ---- | --- | ------- |
| Copy → paste into iMessage / WhatsApp | | |
| Copy → paste into Telegram / Slack | | |
| Copy a static WebP meme → pastes as PNG (iOS conversion) | | |
| Copy a GIF meme → pastes animated into Telegram / Slack | | |
| Share sheet → save to Files / Drive | | |
| Copy unsupported → falls back to share sheet | | |

## Backup

| Case | iOS | Android |
| ---- | --- | ------- |
| Export completes on a 500+ item library without OOM | | |
| Restore on a clean install reproduces the library | | |
| Restore an older backup over a newer library (replace confirmed) | | |
| Backup round-trips an animated meme; thumbnail still plays | | |

## Accessibility

| Case | iOS | Android |
| ---- | --- | ------- |
| VoiceOver / TalkBack: grid tiles announce titles | | |
| All actions reachable with screen reader | | |
| 200% text scaling: no clipped or overlapping text | | |
| Touch targets ≥ 44pt/48dp | | |
| Contrast in light and dark themes | | |

## Performance budgets (mid-range device)

| Metric | Budget | Result |
| ------ | ------ | ------ |
| Cold start to interactive | < 2 s | |
| Grid scroll at 10k items | no dropped-frame jank | |
| Search latency at 10k items | < 150 ms | |
| Import (5 MB image) | < 2 s | |
