# Manual Test Matrix

Native behaviors that automated tests cannot cover run on physical
devices before each release. Record the device, OS version, and result.

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
