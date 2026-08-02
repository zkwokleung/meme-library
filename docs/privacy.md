# Privacy

Meme Library is local-first by design.

## What the app stores

- Images you explicitly save (from your photo library, clipboard,
  links, or shares) and the metadata you add (titles, notes, tags).
- Everything lives in the app's private storage on your device. Nothing
  is uploaded anywhere.

## Your photo library

The app holds **no photo-library permission** and cannot browse your
photos. Picking images opens the system photo picker, which runs outside
the app — `PHPickerViewController` on iOS, the Android photo picker on
Android — and hands back only the individual images you select. You will
never see a "allow access to your photos" prompt, because the app never
asks for access.

Thumbnails the app generates carry no camera or location metadata: EXIF
is stripped when a thumbnail is encoded, so a shared backup archive
cannot leak where or with what a photo was taken. Original images are
stored byte-for-byte as you saved them and keep whatever metadata they
already had.

## Network access

The app makes exactly one kind of network request: downloading an image
from a URL that you type or paste yourself. There are no analytics, no
crash reporting, no telemetry, no accounts, and no third-party SDKs that
phone home.

## Data leaving the device

Data leaves the device only when you trigger it:

- **Share / copy** — sends a single image to the app you choose.
- **Backup export** — produces a ZIP file that you save or share
  yourself.

## Data deletion

- Deleting a meme removes its image, thumbnail, and metadata.
- Uninstalling the app deletes the entire library (that is why the app
  recommends keeping a backup).

## Store disclosure summary

| Category            | Collected | Shared | Notes                       |
| ------------------- | --------- | ------ | --------------------------- |
| Photos and images   | On-device only | No | User-saved memes; no library access |
| Personal identifiers| No        | No     |                             |
| Location            | No        | No     |                             |
| Usage analytics     | No        | No     |                             |
| Crash logs          | No        | No     |                             |

Android Data safety form: "No data collected, no data shared."
Apple privacy nutrition label: "Data Not Collected."
