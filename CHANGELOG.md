# Changelog

## Unreleased

### Added

- Added versioned, checksum-verified site archives covering content schemas,
  entries, relationships, taxonomies, navigation, globals, forms, settings,
  revisions, and original asset files.
- Added export/import and timestamped backup/restore Rake tasks with safe
  new-site restoration and identifier remapping.
- Reframed the roadmap around a production-readiness 0.3.0 milestone.

## 0.2.0 — 2026-08-07

### Added

- Expanded visual blueprints to 21 field types, including structured lists,
  groups, repeaters, radio controls, button groups, multi-image collections,
  and presentation sections.
- Added responsive field widths, conditional visibility, nested-field editing,
  collection constraints, stable option values, and field-level instructions.
- Added single and multiple entry relationships with site-scoped validation and
  Liquid expansion.
- Added reusable fieldsets with collision-safe insertion into blueprints.
- Added immutable, attributed entry revisions with non-destructive restoration.
- Added a live-only, paginated JSON content API with expanded field values.
- Added site locales, linked translation variants, locale-specific slugs,
  localized public routes, and locale-aware API responses.
- Added asset focal points and multi-image library fields.
- Added comprehensive field showcase seeds and blueprint schema documentation.

### Changed

- Redesigned blueprint field cards for clearer, responsive configuration.
- Automated synchronization of Tailwind output into the packaged control-panel
  stylesheet.
- Added normalized server-side validation for numeric, temporal, collection,
  option, relationship, asset, nested, and conditional values.

### Fixed

- Restored reliable image selection and default alt text for inline uploads.
- Isolated system-test data and updated browser coverage for Lexxy and the
  current image picker.

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
