# Plum

Plum is a Rails-native CMS engine with a Hotwire control panel, Liquid themes,
and site-scoped content. It can run as a standalone Rails app or be mounted in a
larger Rails app.

## Installation

Add Plum to your Gemfile:

```ruby
gem "plum-cms", "~> 0.1.0"
```

Then:

```bash
bundle install
bin/rails generate plum:install
bin/rails active_storage:install   # if not already installed
bin/rails db:migrate
bin/rails server
```

Visit `/cms` (or your custom mount path) and create or seed an administrator.

Plum is pre-1.0 software. Pin the minor version in production and review the
changelog before upgrading.

### Mount path

The default mount path is `/cms`. Change it during install:

```bash
bin/rails generate plum:install --mount-path=/website
```

Or mount the engine manually in `config/routes.rb`:

```ruby
mount Plum::Engine, at: "/website"
```

## Embedding in a Host App

For apps like Table Needs where users already have accounts:

```ruby
Plum.configure do |config|
  config.current_site_resolver = ->(controller) { Current.restaurant.plum_site }
  config.current_user_resolver = ->(controller) { Current.user }
  config.authorize_with = :host
  config.host_authorization_resolver = ->(controller) {
    Current.user&.can_manage_website?(Current.restaurant)
  }
end
```

In host mode:
- Plum's login page is bypassed (returns 403 instead of redirect)
- Plum's role system is skipped — the host app owns authorization
- `current_user` doesn't need to be a `Plum::User`

Each customer gets one `Plum::Site`, typically through the polymorphic `owner`
association on `plum_sites`.

## White-Label

The entire control panel can be rebranded:

```ruby
Plum.configure do |config|
  # Branding
  config.cp_name = "Table Needs"
  config.cp_subtitle = "Website"
  config.cp_logo_path = "table-needs-logo.svg"

  # Colors
  config.cp_accent_color = "#2563eb"
  config.cp_sidebar_bg = "#1e293b"
  config.cp_sidebar_header_bg = "#0f172a"
  config.cp_sidebar_text = "#cbd5e1"
  config.cp_sidebar_muted = "#64748b"

  # Back link to host app
  config.cp_back_url = "/dashboard"
  config.cp_back_label = "← Table Needs"
end
```

`cp_name` and `cp_subtitle` are the only text shown in the control-panel
header. Set either value to any brand copy you want (or set `cp_subtitle` to
`nil` to omit the second line). Public-site “Powered by” copy is configured
separately with `powered_by_name` and `powered_by_url`; it is not appended to
the control-panel header.

All buttons, links, focus rings, sidebar, login page, and page titles follow
the configured brand. Zero Plum branding when white-labeled.

## Content Sources

Host apps can inject live application data into Liquid templates without copying
it into Plum tables:

```ruby
Plum.configure do |config|
  config.register_content_source :restaurant, ->(context) { context.owner.to_liquid }
  config.register_content_source :menu, "TableNeeds::PlumAdapters::Menu"
end
```

Registered sources become top-level Liquid objects:

```liquid
<h1>{{ restaurant.name }}</h1>
{% for item in menu.items %}
  <p>{{ item.name }} — {{ item.price }}</p>
{% endfor %}
```

This is the foundation for AI grounding — the same registry that makes content
sources available to templates can feed AI with live merchant data.

## Field Types

Blueprint fields define the content model for each content type:

| Type | Description |
|------|-------------|
| `text` | Single-line text input |
| `textarea` | Multi-line text |
| `rich_text` | Lexxy rich text editor (images, formatting, tables) |
| `number` | Numeric input |
| `boolean` | Checkbox (true/false) |
| `date` | Date, time, or date-time input with bounds |
| `select` | Dropdown with label/value options |
| `radio` | Visible single-choice radio controls |
| `button_group` | Compact single-choice segmented controls |
| `checkboxes` | Multi-select checkboxes (requires `options` array) |
| `color` | Native color picker |
| `url` | URL input |
| `image` | Image picker (Active Storage) |
| `images` | Multi-image library picker with min/max limits |
| `relationship` | Single or multiple related entries |
| `taxonomy` | Term picker from a taxonomy (requires `taxonomy` handle) |
| `blocks` | Page builder sections |
| `list` | Ordered list of plain values |
| `group` | One object containing nested fields |
| `repeater` | Ordered rows containing nested fields |
| `section` | Form heading that stores no entry data |

Fields support `instructions`, `required`, `default`, `placeholder`, and a
responsive `width` from 1–12. Conditional fields use a source field, operator,
and optional value:

```json
{
  "handle": "featured_caption",
  "type": "text",
  "width": 6,
  "condition": { "field": "featured", "operator": "equals", "value": "true" }
}
```

Supported condition operators are `equals`, `not_equals`, `contains`, `empty`,
and `not_empty`. Conditions affect both the editor and server-side required
validation. Select-like fields accept legacy strings or stable label/value
objects: `{ "label": "Published", "value": "published" }`.

See [Blueprint fields](docs/blueprint-fields.md) for the complete schema.

Reusable fieldsets can snapshot any content type's field configuration and be
inserted into another blueprint. Plum rejects handle collisions and copies the
fields, so later fieldset deletion never damages existing content types.

Rails applications and gems can register custom field types with editor,
normalization, validation, and Liquid/API expansion callbacks. See
[Extending Plum](docs/extensions.md).

## Image Transforms

Images expose pre-built variant URLs via Active Storage:

```liquid
<img src="{{ entry.data.hero_image.medium }}" alt="{{ entry.data.hero_image.alt_text }}">
```

Available sizes: `thumb` (300x300 fill), `small` (640px), `medium` (1200px),
`large` (2000px), `url` (original). Requires `libvips` — falls back to the
original URL without it.

## Taxonomies

Taxonomies (categories, tags) are managed in the CP under Taxonomies. Add a
`taxonomy` field to a content type's blueprint to tag entries with terms.

```json
{ "handle": "categories", "type": "taxonomy", "label": "Categories", "taxonomy": "categories" }
```

Front-end pages are automatic:
- `/:taxonomy_slug` — lists all terms with entry counts
- `/:taxonomy_slug/:term_slug` — lists entries tagged with that term (paginated)

In templates:

```liquid
{% for tag in entry.terms.categories %}
  <a href="{{ tag.url }}">{{ tag.name }}</a>
{% endfor %}

{% for term in taxonomies.categories.terms %}
  <a href="{{ term.url }}">{{ term.name }}</a>
{% endfor %}
```

## Collection Pages

Visiting `/:content_type_handle` (e.g. `/posts`) renders a paginated index of
all published entries for that content type. Themes provide collection templates
at `collections/{handle}.liquid` with a `_default.liquid` fallback.

Pagination variables: `pagination.current_page`, `pagination.total_pages`,
`pagination.previous_url`, `pagination.next_url`.

## Search

`/search?q=term` searches entry titles and slugs. Themes provide a
`search.liquid` template with a search form and results.

## Portability and backups

Plum can move or recover an entire site—including assets and remapped content
relationships—with versioned archives:

```sh
bin/rails plum:site:export ARCHIVE=site.plum.zip
bin/rails plum:site:import ARCHIVE=site.plum.zip
bin/rails plum:backup:create DIRECTORY=/var/backups/plum
bin/rails plum:backup:restore ARCHIVE=/var/backups/plum/site.plum.zip
```

See [the portability guide](docs/portability.md) for archive guarantees and
production backup guidance.

## Content API

Published entries are available through a read-only, site-scoped JSON API:

```text
GET /api/v1/collections/posts/entries?page=1&per_page=20&q=plum
GET /api/v1/collections/posts/entries/hello-world
```

Responses include expanded assets and relationships, taxonomy terms, public
URLs, and pagination metadata. Draft and future-scheduled entries are never
returned. Page size is capped at 100. Pass `locale=es` to request a configured
translation.

## Localization

Configure locale codes and a default locale under Site Settings. Entries share
one translation group while retaining locale-specific titles, slugs, content,
publishing status, revisions, and taxonomy terms. Default-locale URLs remain
unchanged; other locales receive a prefix such as `/es/about`.

## Roles

Standalone mode has three roles: `viewer` (read-only CP), `editor` (manage
content), `admin` (full access including content types, settings, themes,
taxonomies). In embedded/host mode, roles are skipped entirely.

## Revisions

Every control-panel entry save records an immutable snapshot of its content,
publishing state, terms, and editor identity. Editors can browse history and
restore an older version; restoration itself creates a new revision so no
content is discarded.

## Rich Text

Rich text fields use [Lexxy](https://basecamp.github.io/lexxy/) (Basecamp's
editor built on Meta's Lexical). Supports bold, italic, strikethrough, headings,
lists, links, quotes, code blocks, tables, image uploads, and text colors.

Images uploaded through Lexxy use Active Storage Direct Upload and render on the
front-end as standard `<img>` tags. Text colors are resolved from Lexxy's CSS
variables to real color values at render time.

## Globals and Navigation

Globals are site-wide JSON objects (company info, social links):

```liquid
{{ globals.company.phone }}
```

Navigation menus are managed in the CP:

```liquid
{% for item in nav.main.items %}
  <a href="{{ item.url }}">{{ item.label }}</a>
{% endfor %}
```

## Themes

Themes live in `app/themes/{handle}/` with:
- `theme.yml` — name, settings, block definitions
- `layouts/base.liquid` — site layout
- `templates/` — entry, collection, taxonomy, search templates
- `blocks/{handle}.liquid` — block partials
- `assets/` — CSS, images

Themes can be installed from a zip in the CP.

## Database

Plum is SQLite-first but database-agnostic. All JSON is filtered in Ruby (no
DB-specific SQL), so it runs on PostgreSQL too. Test against Postgres:

```bash
PLUM_TEST_DB=postgres bin/rails test
```

## Development

```bash
git clone git@github.com:tableneeds/Plum.git && cd Plum
bin/setup
bin/rails server
```

Login: `admin@example.com` / `password`

For Bagel Boy demo content: `bin/rails runner "load 'db/seeds/bagel_boy.rb'"`
