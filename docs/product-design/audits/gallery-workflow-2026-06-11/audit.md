# lut-shop Gallery Workflow Audit

Date: 2026-06-11

## Evidence

- Current iOS Gallery screenshot: `01-gallery-current.png`
- Prototype reference: `../../reference/prototype-reference-gallery.png`
- Prototype QA reference: `../../reference/prototype-design-qa.md`

## Scope

Audit the Gallery workflow for:

- Session meaning and management
- Filter and sort controls
- Photo selection behavior
- Batch action bar
- Visual clarity for a professional mobile photography tool

This audit is based on screenshots and current SwiftUI behavior. It does not include instrumented accessibility testing, real photo import, or real device gesture testing.

## Flow Steps

1. **Open Gallery**
   - Health: medium
   - The screen opens directly into a professional dark gallery, which matches the product direction. Photo content is prominent, and the bottom tabs are clear.
   - Issue: the top tool row is crowded. Search, filter, favorite, sort, and select are all equal visual weight, so users need to discover what each control does by tapping.

2. **Understand Current Session**
   - Health: medium-low
   - The session row now shows `All Sessions` and a photo count. This clarifies that the row is a filter/context selector.
   - Issue: the row still does not explain whether a session is a project, shoot, import batch, or album. For photographers, "Session" is acceptable, but first-use clarity needs a create/manage affordance visible from the row.
   - Recommendation: keep the row as the current working context, but add a small trailing `Manage` or `+` action in the session menu/sheet. Empty sessions should be clearly labeled as waiting for import.

3. **Filter Photos**
   - Health: medium
   - Status tabs are understandable: All, New/RAW, Edited, Favorites, Exported.
   - Issue: there are two filter surfaces: the funnel menu and the status tab row. They overlap, which can feel redundant.
   - Recommendation: use the funnel menu for advanced filters only later, such as rating, camera/source, LUT applied, and session. Keep status tabs as the primary quick filter.

4. **Sort Photos**
   - Health: medium
   - The sort button now has a menu-backed behavior.
   - Issue: current icon turns green even when the default sort is active, which can read as "filter applied." Sort should show active only if the user changed from the default.
   - Recommendation: add a compact label or current sort hint in the menu, and keep the icon neutral unless sort differs from the default.

5. **Select Photos**
   - Health: medium-low
   - Selection now supports `Select` mode and visible check circles only while selecting, which is the right direction.
   - Issue shown in current screenshot: selected state can persist when returning to Gallery, causing users to land in a busy selected state with the batch bar covering content.
   - Recommendation: make selection mode explicit. When photos are selected, change top button to `Done`, and consider adding `Cancel`/`Clear` at the left of the batch bar. Avoid silently carrying selection across unrelated navigation unless the user started a batch workflow.

6. **Use Batch Action Bar**
   - Health: medium
   - The batch bar matches the reference direction: thumbnail, selected count, current filename, and batch actions.
   - Issue: the bar is tall and overlaps a large part of the bottom grid. On smaller screens it competes with the tab bar.
   - Recommendation: compress the batch bar slightly and separate "Apply LUT", "Rate", and "Export" with clearer icon hierarchy. `Apply LUT` should probably route to LUT selection, not immediately apply the current LUT without confirmation.

## Priority Findings

1. **Session needs a visible management model**
   - Current implementation now has management logic, but the concept should be made clearer in UI copy.
   - Recommended language: `Shoot / Session` or `Project Session` if you want users to understand it as a project/batch container.

2. **Filter surfaces should not duplicate each other**
   - Keep the status tabs for common filtering.
   - Reserve the funnel for advanced filtering in a later step.

3. **Selection mode needs stronger boundaries**
   - Users should always know whether tapping a photo will open it or select it.
   - The `Select` button and check circles help, but selected state persistence should be reviewed.

4. **Top toolbar is too dense**
   - The prototype reference has cloud/import and overflow actions in the header. Current implementation uses more same-sized controls in one row.
   - Recommendation: move lower-frequency actions into an overflow menu once import/session management grows.

## Accessibility Risks

- Icon-only filter, favorite, and sort buttons need accessibility labels.
- The green accent on dark background is visually clear, but selected borders and small status pills should be checked for contrast on real devices.
- The photo filename overlays are small and can collide with rating dots/stars on dense tiles.
- Menus and sheets need VoiceOver labels for session creation, sorting, and filtering.

## Recommended Next Design Step

Focus on **Gallery interaction hierarchy** before adding more features:

1. Make Session row a clear project/batch manager.
2. Simplify toolbar: Search + Filter + Sort + Select, with import/overflow in header.
3. Tighten selected-state behavior and batch bar layout.
4. Add accessibility labels to all icon buttons.

This should happen before deeper LUT or Export polishing because Gallery is the main entry point and determines whether the app feels like a professional culling workspace.
