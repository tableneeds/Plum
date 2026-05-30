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
end
```

Each customer should get one `Plum::Site`, commonly through the optional
polymorphic `owner` association.

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
