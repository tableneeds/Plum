# Themes & Liquid

Plum renders the public site through **Liquid themes** — the same safe,
designer-friendly template language Shopify and Statamic use. A theme is a
directory of templates, partials, and assets.

Theme resolution is a search path, set in the initializer:

```ruby
config.theme_paths = [
  Rails.root.join("app/themes"),      # your app's themes win
  Plum::Engine.root.join("app/themes") # bundled themes as fallback
]
```

So you can start from a bundled theme and override just the templates you
want to change — your app's copy of a file shadows the engine's.

Templates get a rich context: the current site, the entry being rendered,
globals, nav menus, taxonomies, and any **content sources** the host app
registers (an embedded install can expose its own domain objects — menus,
hours, anything — to Liquid).

Entries render by slug; collection pages, search, and the content API are
built in. Rich text fields are edited in the CP with a Lexical-based
editor and render as clean HTML.
