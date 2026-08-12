# Proposal: Config as Code

Status: phase 1 implemented 2026-08-12 (`Plum::ConfigSync` + `plum:config:export|sync|check`
rake tasks, content types + fieldsets, one-way). Phases 2-3 (two-way CP
write-back, dev file watcher, taxonomies/forms) remain as proposed below.

## Problem

The content *model* (content type blueprints, taxonomies, form definitions)
lives only in the database, created by clicking in the control panel. That
means no git history, no code review, and no repeatable path from development
to production — adding a field to a live site means re-clicking it in the
production CP. This is the classic CMS pain (WordPress/ACF sync, Contentful
migrations, Drupal config management all exist to solve it).

## Principle

Split the two kinds of data a CMS holds:

- **Content** (entries, terms, nav items, assets, submissions): editor-owned,
  changes constantly, stays in the database. Untouched by this proposal.
- **Config** (content types + blueprints, taxonomies, forms, fieldsets):
  developer-owned, changes rarely, belongs in version-controlled files.

Files are the source of truth; the DB holds a synced copy so rendering and
the CP keep working exactly as today.

## File layout (host app repo)

```
plum/
  content_types/posts.yml
  content_types/pages.yml
  taxonomies/topics.yml
  forms/contact.yml
```

```yaml
# plum/content_types/posts.yml
name: Blog Posts
handle: posts
icon: document
route_prefix: blog
fields:
  - handle: body
    type: rich_text
    label: Body
  - handle: reading_time
    type: number
    unit: min
```

## Mechanics

- `Plum::ConfigSync.apply(site:, dir:)` — files → DB. Upsert by handle,
  transactional, flushes the static cache. Runs via `rails plum:sync` and
  optionally on boot.
- `Plum::ConfigSync.export(site:, dir:)` — DB → files. Bootstraps existing
  sites onto the workflow; also called by the CP after visual blueprint edits
  so the clicky builder and git never diverge (**two-way sync** — the
  Statamic trick that makes both editors and developers happy).
- Dev: `ActiveSupport::FileUpdateChecker` re-applies changed files on reload,
  same feel as theme editing.
- CI: `rails plum:sync --check` fails when the DB has drifted from the files
  (hand-edits in prod that were never exported).

## Safety rails

- Removing a field from YAML never deletes entry data — entry data is a JSON
  blob, so orphaned keys simply stop rendering (already true today).
- Renaming a handle is treated as remove+add unless a `renamed_from:` hint is
  given.
- Deleting a content type that still has entries requires `--force`.

## Multi-site / embedded mode

Standalone mode: sync targets the single site; two-way write-back (phase 2)
is appropriate because the developer owns both the repo and the CP.

Embedded/SaaS mode (Table Needs) inverts the flow: the platform owns the
content model, customer sites share it, and customers must not write YAML
into the platform repo. So in host mode:

- files are authoritative **one-way** (no CP write-back),
- `plum:config:sync` needs an `ALL_SITES=1` mode that migrates every site's
  model on deploy, like db:migrate for blueprints (not yet implemented),
- the same files seed newly created sites.

## Configuration

```ruby
Plum.configure do |config|
  config.config_path = Rails.root.join("plum")   # nil disables the feature
  config.config_sync = :two_way                   # :files_authoritative, :off
end
```

## Phasing & estimate

1. One-way `apply` + `export` + rake tasks, content types + fieldsets only
   (~2–3 days).
2. Two-way CP write-back + dev file watcher (~2 days).
3. Taxonomies, forms, CI check, docs (~1 day).
