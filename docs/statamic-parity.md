# Statamic capability parity

This matrix tracks practical authoring parity rather than matching Statamic's
internal architecture or naming.

| Capability | Plum status | Notes |
|---|---|---|
| Blueprint field builder | Supported | Visual, nested, typed configuration |
| Reusable fieldsets | Supported | Site-scoped snapshots with collision-safe insertion |
| Field instructions/defaults/required | Supported | Client and server validation |
| Field widths and sections | Supported | Twelve-column responsive editor |
| Conditional fields | Supported | Five common operators |
| Text, rich text, numbers, dates | Supported | Bounds and modes included |
| Choice controls | Supported | Select, radio, buttons, checkboxes |
| Assets | Supported | Single/multi-image fields, metadata, focal points, variants |
| Relationships | Supported | Single/multiple, type-filtered, site-scoped |
| Structured content | Supported | Lists, groups, repeaters, blocks |
| Taxonomies | Supported | Managed terms and public archives |
| Globals and navigation | Supported | Liquid-accessible content |
| Forms | Supported | Definitions, submissions, notifications |
| Themes | Supported | Liquid packages, settings, blocks |
| Revisions and publishing workflow | Supported | Attributed snapshots, restoration, drafts, scheduling |
| Localization/multisite | Supported | Site locales, translation groups, localized URLs/API |
| Content API | Supported | Public, site-scoped, live-only JSON collections |
| Addon field types | Supported | Registry-backed editor and value pipeline |

Longer-term ecosystem work can add commercial-style addon discovery, more
workflow roles, and translation services without changing these authoring APIs.
