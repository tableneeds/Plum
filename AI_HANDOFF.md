# Plum CMS AI Handoff

This file is for future AI agents or collaborators picking up the Plum CMS work.
Read this first, then `README.md`, then recent commits.

## Current State

Plum is a Rails 8 CMS built as a mountable, site-scoped Rails engine. It can run
as the standalone app in this repo, or be installed into another Rails app from
a local path/private Git source and mounted at a path such as `/website`.

Latest verified commit:

```text
3866cbc Add relationship fields
```

Recent feature commits:

```text
3866cbc Add relationship fields
d47a800 Add Tiptap rich text editor
7e81f93 Add forms and public submissions
779c666 Add globals and navigation management
123dbd4 Add asset library and image fields
22ee1f3 Formalize host content sources
e9e7b3e Add theme metadata and customization UI
74e2fd0 Add theme package upload flow
3930098 Add theme asset serving
f8f1c22 Prove embedded host site integration
```

## Architecture

- Rails 8, SQLite-first.
- `Plum::Engine` is isolated and intended to be gem-installable/mountable.
- All CMS data is site-scoped through `Plum::Site`.
- Standalone mode uses one implicit site via `Plum::Site.first_or_create_standalone!`.
- Embedded mode should resolve one `Plum::Site` per host customer, usually with
  `Plum::Site.for_owner!(Current.restaurant)` or equivalent.
- Host apps provide `current_site`, `current_user`, and authorization through
  `Plum.configure` in `config/initializers/plum.rb`.
- Table Needs-style host data should enter Liquid through registered content
  sources, not by copying POS data into Plum tables.

Example embedded configuration:

```ruby
Plum.configure do |config|
  config.current_site_resolver = ->(_controller) { Plum::Site.for_owner!(Current.restaurant) }
  config.current_user_resolver = ->(_controller) { Current.user }
  config.authorize_with = :host
  config.host_authorization_resolver = ->(_controller) { Current.user.can_manage_website?(Current.restaurant) }
  config.register_content_source :restaurant, ->(context) { context.site.owner.to_liquid }
  config.register_content_source :menu, "TableNeeds::PlumAdapters::Menu"
end
```

## Implemented Features

- Content types with JSON blueprints.
- Entries with dynamic blueprint-backed fields.
- Public Liquid rendering through theme templates.
- Site settings.
- Theme registry and theme selection.
- Theme settings UI and Liquid exposure.
- Theme asset serving.
- Theme package zip upload with `theme.yml` validation.
- Host content source registry for embedded apps.
- Asset library using Active Storage.
- Image blueprint fields with inline upload and Liquid expansion.
- Globals.
- Navigation menus and nested nav items.
- Forms and public submissions.
- Tiptap rich text editor for `rich_text` fields.
- Relationship fields for linking one entry to another same-site entry.

## Field Contracts

Blueprint fields are stored on `Plum::ContentType#blueprint`:

```json
{
  "fields": [
    { "handle": "body", "type": "rich_text", "label": "Body" },
    { "handle": "hero_image", "type": "image", "label": "Hero Image" },
    {
      "handle": "featured_post",
      "type": "relationship",
      "label": "Featured Post",
      "content_type": "posts"
    }
  ]
}
```

Important behavior:

- `rich_text` stores sanitized HTML in `entry.data`.
- `image` stores an asset id in `entry.data`; Liquid expands it to an asset object.
- `relationship` stores an entry id in `entry.data`; Liquid expands published
  related entries to entry objects.
- Relationship saves validate same-site membership and optional target content
  type handle.
- Public relationship expansion only exposes live/published related entries.

Liquid examples:

```liquid
{{ entry.data.body }}
{{ entry.data.hero_image.url }}
{{ entry.data.featured_post.title }}
{{ entry.data.featured_post.url }}
```

## Theme System

Built-in themes live in `app/themes`:

- `default`
- `bagel-shop`

Theme packages can be uploaded from the control panel. A valid zip contains
`theme.yml`, Liquid templates/layouts, and optional assets:

```text
theme.yml
layouts/base.liquid
templates/index.liquid
templates/entries/posts.liquid
assets/theme.css
assets/screenshot.svg
```

Theme settings are defined in `theme.yml` and stored per `Plum::Site` in
`theme_settings`. Site-specific custom CSS is stored on the site.

## Local Running

Common local commands:

```bash
bin/rails db:setup
bin/rails server
```

Then visit:

```text
http://localhost:3000
http://localhost:3000/cp
```

The standalone app uses Plum-managed auth. Create users in seeds, console, or
tests as needed.

## Gem/Embedded Install

Until the gem is published, install from a local path:

```ruby
gem "plum", path: "../plum"
```

Then in the host app:

```bash
bin/rails generate plum:install --mount-path=/website
bin/rails active_storage:install # if the host has not installed Active Storage
bin/rails db:migrate
```

The install generator currently copies:

- Plum initializer.
- Plum tables migration.
- JS controllers.
- vendored Tiptap importmap dependencies.
- Tiptap importmap pins.
- mount route unless skipped.

## Verification Commands

These were green after the latest relationship-fields commit:

```bash
bin/rails test
bin/rails test:system
bin/rubocop
bin/rails zeitwerk:check
gem build plum.gemspec
bin/rails generate plum:install --pretend --skip --mount-path=/website
git diff --check
```

Note: SQLite can report `database is locked` if multiple test processes or
system-test commands are run at the same time. Rerun the affected test by itself
before assuming the app is broken.

## Current Constraints

- Plum is not registered on RubyGems.
- Embedded install is proven by generator and test coverage, not by a live Table
  Needs mount in this repo.
- Forms store submissions; email notification delivery is not implemented yet.
- Relationship fields are single-entry relationships only.
- Theme marketplace/premium purchase flow does not exist yet.
- No first-class page builder/block editor exists yet.
- No CLI exists yet for `plum new`, `plum deploy`, or theme commands.

## Recommended Next Steps

1. Add a block/section field or page-builder foundation.
2. Add multi-entry relationships if needed for collections such as related posts.
3. Add theme export/download so agencies can package themes from the UI.
4. Add form notification mailer and background job delivery.
5. Add a minimal CLI wrapper for install/theme workflows.
6. Create a small dummy host app in `test/dummy` or a separate fixture app to
   prove a real mounted install path beyond generator checks.
7. Add Table Needs adapter examples for `restaurant`, `menu`, `hours`, and
   `locations` content sources.

## Rules For Future Agents

- Prefer existing Rails/Hotwire/importmap patterns.
- Keep Plum engine code host-agnostic. Host-specific data belongs in content
  sources or resolver configuration.
- Preserve `Plum::Site` scoping on all content-bearing data.
- Do not introduce React/Vue.
- Use Liquid for public themes.
- Run tests and RuboCop before committing.
