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

For Table Needs, configure Plum with host-owned resolvers:

```ruby
Plum.configure do |config|
  config.current_site_resolver = ->(_controller) { Current.restaurant.plum_site }
  config.current_user_resolver = ->(_controller) { Current.user }
  config.authorize_with = :host
end
```

Each customer should get one `Plum::Site`, commonly through the optional
polymorphic `owner` association.
