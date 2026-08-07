# Roadmap

Plum's roadmap is organized by outcomes rather than promised dates. Priorities
move as the product is exercised in real Rails applications.

## Shipped: Plum 0.2.0 — Authoring Foundation

Plum 0.2.0 established the practical authoring surface:

- a visual blueprint builder with 21 field types, reusable fieldsets, nested
  structures, validation, field widths, sections, and conditions;
- assets with single and multiple image fields, metadata, focal points, and
  responsive variants;
- relationships, taxonomies, navigation, globals, forms, and Liquid themes;
- drafts, scheduled publishing, immutable revisions, and rollback;
- localized entries, locale-aware public routes, and a live-only content API;
- registry-backed custom field types and packaged Tailwind control-panel styles.

See [the Statamic parity matrix](statamic-parity.md) for the supported surface.

## Now: Plum 0.3.0 — Production Readiness

The 0.3.0 milestone makes Plum safe to adopt, move, recover, and operate outside
its development repository.

### 1. Portability and recovery

- Versioned site export/import covering schemas, entries, relationships,
  taxonomies, navigation, globals, forms, settings, and assets.
- Tested backup and restore commands with integrity checks and clear failure
  behavior.
- A documented archive format that remains readable across compatible releases.

### 2. Real-world installation

- Build `plumcms.org` as a standalone Rails application using the released gem.
- Test fresh external installations and 0.2.x upgrades in CI.
- Publish a production Docker contract and SQLite deployment example.
- Exercise health checks, upgrades, persistence, backup, and restore on a VM.

### 3. Publishing and discovery

- SEO metadata, canonical URLs, redirects, XML sitemaps, and feeds.
- Document hierarchy, breadcrumbs, generated tables of contents, and site search.
- Secure, shareable preview links for draft and scheduled content.

### 4. Editorial operations

- Asset folders, search, replacement, cropping, and richer transformations.
- Granular editorial roles, approvals, and publish permissions.
- Form spam protection and improved submission review/export workflows.

### 5. Documentation

- Complete installation and first-page guides.
- Document every supported field and content primitive.
- Document standalone SQLite and embedded PostgreSQL operation.
- Publish configuration, troubleshooting, extension, upgrade, backup, and
  restore references.

## Next: Plum 0.4.0 — Repeatable Adoption

- A thin `plum` CLI for diagnostics, export/import, backup/restore, upgrades,
  themes, and packaging.
- Starter applications for common publishing use cases.
- Theme scaffolding, validation, packaging, and distribution tools.
- A collection of high-quality open themes and blocks.
- Importers for common CMS and structured-data formats.
- Addon discovery and a documented compatibility contract.

## Later: The Rails Content Ecosystem

- Translation-service integrations and richer localization workflows.
- Agency-oriented multisite operations and reusable project recipes.
- Community examples, case studies, talks, and contribution programs.
- Broader content APIs where real applications demonstrate the need.

## Plum 1.0

Plum 1.0 means another Rails developer can reproduce what powers
`plumcms.org` without private knowledge or site-specific patches.

It requires:

- a published, versioned gem;
- an editable page within ten minutes of installation;
- dependable standalone and embedded installation paths;
- a documented SQLite production deployment;
- clean host authentication, authorization, and tenancy integration;
- preview, revisions, export, backup, and restore;
- complete documentation for the supported public surface;
- a tested upgrade path;
- at least one production standalone site and one production embedded use; and
- a public example application that agencies can study and adapt.

## Not on the Near-Term Roadmap

Plum is not trying to become a general-purpose admin framework, a freeform
visual design tool, an ecommerce platform, or a hosted headless CMS. Plum's
focus is managed content that belongs inside Rails.
