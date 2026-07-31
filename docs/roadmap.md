# Roadmap

Plum's roadmap is organized by outcomes rather than promised dates. Items move
as the product is exercised in real applications and the Rails community gives
feedback.

## Now: Make Plum Real and Adoptable

The current milestone is to build and publish the Plum marketing and
documentation site as a standalone Rails application powered by Plum and
SQLite.

### Product foundation

- Publish a clear vision, product principles, and supported use cases.
- Build `plumcms.org` with Plum as an external dependency.
- Define a portable production layout for the SQLite database, uploaded assets,
  and mutable site data.
- Package the site as an ONCE-compatible Docker application.
- Exercise installation, initialization, health checks, upgrades, backup, and
  restore on a real VM.
- Keep SQLite and PostgreSQL verification in CI.

### Documentation

- Document installation and the first editable page.
- Document sites, content types, fields, entries, and publishing.
- Document blocks, assets, relationships, taxonomies, navigation, globals, and
  forms.
- Document Liquid themes and host content sources.
- Document embedded authentication, authorization, tenancy, and routing.
- Document standalone SQLite and embedded PostgreSQL deployments.
- Publish configuration, troubleshooting, and upgrade references.

### Distribution

- Publish the `plum` gem.
- State supported Ruby and Rails versions.
- Establish semantic versioning and an upgrade policy.
- Test fresh external installations and upgrades in CI.
- Provide a production-ready container contract and example application.

## Next: Editorial Confidence and Portability

Once the public site proves the basic workflow, focus on the features editors
and agencies need to trust Plum in production.

- Draft preview.
- Revisions and rollback.
- Scheduled publishing.
- Multi-entry relationships.
- Reusable blocks and sections.
- Content, schema, and asset export/import.
- Document hierarchy, tables of contents, and site search.
- SEO metadata, canonical URLs, sitemaps, feeds, and redirect management.
- Stronger asset organization and image editing.
- Form spam protection and improved submission workflows.
- Tested backup and restore commands.

## Later: The Rails Content Ecosystem

After installation and production operation are dependable, make Plum easier to
adopt repeatedly and extend publicly.

- A thin `plum` CLI for new sites, diagnostics, themes, export/import, upgrades,
  and packaging.
- Starter applications for common content-site use cases.
- A documented extension contract for fields, blocks, and content sources.
- A collection of high-quality open themes and blocks.
- Theme scaffolding, validation, packaging, and distribution tools.
- Importers for common CMS and structured-data formats.
- Optional content APIs for applications that genuinely need them.
- Community examples, case studies, talks, and contribution programs.

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

Plum is not currently trying to become a general-purpose admin framework, a
freeform visual design tool, an ecommerce platform, or a hosted headless CMS.
Those products solve different problems. Plum's focus is managed content that
belongs inside Rails.
