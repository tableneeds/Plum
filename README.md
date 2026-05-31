# Plum

Plum is a Rails-native CMS engine with a Hotwire control panel, Liquid themes,
and site-scoped content. It can run as a standalone Rails app or be mounted in a
larger Rails app.

## Local Engine Install

Until Plum is published, install it from a local path or private Git repo:

```ruby
gem "plum", path: "../plum"
```

Then run:

```bash
bin/rails generate plum:install --mount-path=/cms
bin/rails db:migrate
```

Mount path can be changed for embedded products:

```bash
bin/rails generate plum:install --mount-path=/website
```

Or mount the engine manually:

```ruby
mount Plum::Engine, at: "/website"
```

For Table Needs, configure Plum with host-owned resolvers:

```ruby
Plum.configure do |config|
  config.current_site_resolver = ->(_controller) { Plum::Site.for_owner!(Current.restaurant) }
  config.current_user_resolver = ->(_controller) { Current.user }
  config.authorize_with = :host
  config.host_authorization_resolver = ->(_controller) { Current.user.can_manage_website?(Current.restaurant) }
  config.register_content_source :restaurant, ->(context) { context.site.owner.to_liquid }
  config.register_content_source :menu, "TableNeeds::PlumAdapters::Menu"
  config.register_content_source :hours, ->(context) { context.owner.hours_for_web }
end
```

Each customer should get one `Plum::Site`, commonly through the optional
polymorphic `owner` association.

## Host Content Sources

Host apps can expose read-only application data to Liquid without copying it
into Plum tables. Register each source with a lowercase, underscore-separated
handle:

```ruby
Plum.configure do |config|
  config.register_content_source :restaurant, ->(context) { context.owner.to_liquid }
  config.register_content_source :menu, "TableNeeds::PlumAdapters::Menu"
end
```

Adapters receive a `Plum::ContentSourceContext` with `controller`, `site`,
`owner`, `request`, `params`, `session`, and `current_user`. Adapter classes can
subclass `Plum::ContentSource`:

```ruby
class TableNeeds::PlumAdapters::Menu < Plum::ContentSource
  def to_liquid
    {
      items: owner.menu_items.visible.map do |item|
        {
          name: item.name,
          price: item.formatted_price,
          description: item.description
        }
      end
    }
  end
end
```

Registered sources become top-level Liquid objects:

```liquid
<h1>{{ restaurant.name }}</h1>

{% for item in menu.items %}
  <h2>{{ item.name }}</h2>
  <p>{{ item.description }}</p>
  <strong>{{ item.price }}</strong>
{% endfor %}
```

Content sources must return Liquid-safe data: hashes, arrays, strings, numbers,
booleans, dates/times, or objects that implement `to_liquid`. Hash keys are
normalized to strings.

## Assets And Image Fields

Images live in `Plum::Asset` records with files stored through Active Storage.
The control panel exposes an asset library at `/cp/assets` for uploading images
and editing alt text, captions, and folders.

Blueprints can define image fields:

```json
{
  "fields": [
    { "handle": "hero_image", "type": "image", "label": "Hero Image" }
  ]
}
```

Entry forms let editors choose an existing asset or upload a new image inline.
Plum stores the asset id in `entry.data`, then expands it for Liquid:

```liquid
{% if entry.data.hero_image.url %}
  <img src="{{ entry.data.hero_image.url }}" alt="{{ entry.data.hero_image.alt_text }}">
{% endif %}
```

Image objects expose `id`, `url`, `alt_text`, `caption`, `filename`,
`content_type`, `byte_size`, and `folder`.

## Rich Text Fields

Blueprint fields with `"type": "rich_text"` use the Tiptap editor in the
control panel. Plum stores the generated HTML in `entry.data`, while existing
Markdown-style content still renders through the bundled themes' `markdown`
filter.

```json
{
  "fields": [
    { "handle": "body", "type": "rich_text", "label": "Body" }
  ]
}
```

## Relationship Fields

Relationship fields let one entry point at another entry on the same site. Add
`content_type` to limit the selector to a specific content type handle:

```json
{
  "fields": [
    {
      "handle": "featured_post",
      "type": "relationship",
      "label": "Featured Post",
      "content_type": "posts"
    }
  ]
}
```

Plum stores the related entry id in `entry.data`. Public Liquid expands
published related entries into entry objects:

```liquid
{% if entry.data.featured_post %}
  <a href="{{ entry.data.featured_post.url }}">
    {{ entry.data.featured_post.title }}
  </a>
{% endif %}
```

## Globals And Navigation

Globals are reusable JSON objects for site-wide data such as company info,
announcements, social links, or contact details. A global with handle `company`
is available in Liquid as:

```liquid
{{ globals.company.phone }}
{{ globals.company.address }}
```

Navigation menus are managed in the control panel and exposed by handle. A menu
with handle `main` is available as `nav.main`:

```liquid
{% if nav.main.items.size > 0 %}
  <nav>
    {% for item in nav.main.items %}
      <a href="{{ item.url }}">{{ item.label }}</a>
    {% endfor %}
  </nav>
{% endif %}
```

Navigation items can point to a custom URL or a Plum entry. Entry-backed items
resolve to the correct mounted URL when Plum is embedded in another Rails app.

## Forms

Forms are defined in the control panel and rendered in Liquid by handle:

```liquid
{% if forms.contact %}
  {% form "contact" %}
{% endif %}
```

Supported field types are `text`, `email`, `textarea`, `select`, and
`checkbox`. Public submissions post back to Plum, are scoped to the current
site, and can be reviewed from the form detail screen in the control panel.

The v1 form contract stores submissions in `plum_form_submissions.data`.

When a form has a `notification_email`, Plum emails that address on each new
submission via `Plum::FormMailer`, enqueued with `deliver_later` (Active Job).
The engine only composes and enqueues the message — the host application is
responsible for configuring ActionMailer delivery (SMTP, `default_url_options`,
a queue backend, etc.). Set the "from" address with:

```ruby
Plum.configure do |config|
  config.mailer_sender = "no-reply@yourdomain.com"
end
```

Forms without a `notification_email` are stored but send no email.

## Database

Plum is SQLite-first and ships with SQLite as the default, but the engine is
database-agnostic: all JSON columns are read and filtered in Ruby (no
database-specific JSON SQL), so it also runs on PostgreSQL — the database a host
app such as Table Needs is likely to use. To run the test suite against
PostgreSQL instead of SQLite:

```bash
PLUM_TEST_DB=postgres bin/rails db:test:prepare
PLUM_TEST_DB=postgres bin/rails test
```

Connection details are read from the standard `PG*` environment variables
(`PGHOST`, `PGUSER`, `PGPASSWORD`, and `PLUM_TEST_PG_DATABASE`, default
`plum_test`). CI runs the suite on both SQLite and PostgreSQL.

## Theme Packages

Themes can be installed from a zip in the control panel. A package must contain
`theme.yml` at the root, or inside one top-level folder:

```text
theme.yml
layouts/base.liquid
templates/index.liquid
assets/theme.css
assets/screenshot.svg
```

`theme.yml` is the v1 theme contract:

```yaml
name: Bagel Shop
handle: bagel-shop
version: 1.0.0
author: Plum
category: Restaurant
screenshot: screenshot.svg
description: Warm retail theme for neighborhood food brands.
settings:
  fields:
    - handle: accent_color
      type: color
      label: Accent Color
      default: "#1f6f63"
    - handle: hero_note
      type: text
      label: Hero Note
    - handle: show_powered_by
      type: boolean
      label: Show Powered By
      default: true
    - handle: corner_style
      type: select
      label: Corner Style
      options:
        - label: Soft
          value: soft
        - label: Square
          value: square
      default: soft
```

Theme handles must use lowercase letters, numbers, and hyphens. Theme setting
handles must use lowercase letters, numbers, and underscores. Supported setting
types are `text`, `textarea`, `color`, `boolean`, and `select`.

Screenshots are optional and are resolved relative to the theme's `assets`
folder. Plum rejects packages with unsafe paths, missing manifests, duplicate
handles, invalid setting schemas, screenshots that point outside `assets`, or no
Liquid templates/layouts.
