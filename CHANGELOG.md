# Changelog

## 0.1.2 — 2026-08-04

### Fixed

- Allowed long control-panel brand names, subtitles, and content-type names to
  wrap without clipping or displacing their icons.
- Kept control-panel branding limited to the configured `cp_name` and
  `cp_subtitle`; public “Powered by” attribution is not appended to the sidebar.
- Allowed the control-panel subtitle to be omitted by setting `cp_subtitle` to
  `nil`.

## 0.1.1 — 2026-08-04

### Changed

- Redesigned image pickers with a responsive image library, accessible upload
  controls, drag-and-drop support, clearer status feedback, and consistent
  pointer cursors throughout the control panel.
- Added independent Hotwire image saving for entry image fields and the site
  logo so image changes do not submit or overwrite other in-progress edits.
- Image removals now require confirmation and persist immediately without an
  extra save step.

### Fixed

- Synchronized the compiled control-panel stylesheet with its Tailwind source.
- Included the independent image-save routes in both development and packaged
  engine route sets.

## 0.1.0 — 2026-07-31

The first public release of Plum, a Rails-native content management engine.

### Included

- A Hotwire control panel for entries, content types, navigation, globals,
  taxonomies, forms, assets, themes, and site settings.
- Structured fields, relationships, reusable blocks, and Lexxy rich text.
- Portable Liquid themes with public entries, collections, taxonomies, search,
  forms, nested route prefixes, heading anchors, and tables of contents.
- Standalone and embedded operation with host-owned identity, authorization,
  tenancy, and registered content sources.
- SQLite-first persistence with PostgreSQL compatibility.
- Configurable control-panel branding and theme package installation.

Plum 0.1 is intentionally pre-1.0. Public APIs may evolve as the project is
used in more Rails applications and content-first sites.
