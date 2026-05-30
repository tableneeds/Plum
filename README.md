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
