# lut-shop Design QA

final result: blocked

## Checked

- Static prototype files exist:
  - `index.html`
  - `styles.css`
  - `app.js`
  - local bitmap photo assets under `assets/`
- JavaScript syntax check passed with Node.
- Generated reference images were copied into `assets/reference-gallery.png` and `assets/reference-preview.png`.

## Blocker

Browser screenshot QA could not be completed in this environment. Playwright is installed, but its bundled Chromium executable is missing. Launching the system Chrome in headless mode aborted, and starting a local static server with escalation was not available.

## Manual QA Path

Open `index.html` directly in a browser. The prototype is static and uses relative local assets, so it does not require a backend.

Recommended checks:

- Gallery tab loads with photo grid and selected photo bar.
- Filter tabs update visible photos.
- Photo cards can be selected.
- Bottom navigation switches between Gallery, Preview, LUTs, and Export.
- Preview tab toggles before/after comparison.
- LUT carousel changes selected LUT.
- Intensity sliders update values.
- LUT category chips filter the LUT list.
- Export button animates the export queue progress.
