# Static caching

Turn it on and Plum writes every rendered public page to disk, keyed by
host and path. The next request for that page is served **without touching
Rails or the database at all** — static-site speed with a live CMS behind
it.

```ruby
# config/initializers/plum.rb
config.static_cache_enabled = true
```

Invalidation is delete-only and automatic: saving content flushes the
affected site's cached pages, and the next visitor regenerates them.
(Draft autosaves don't count — nothing public changed.)

Because cached reads never reach the database, **SQLite becomes a fully
production-capable choice**: the database only works when someone edits
content or submits a form. One $6 VPS, one SQLite file, effectively
unlimited cached page throughput.

Two things to know before enabling it:

- **Single server only.** Each node keeps its own cache but invalidations
  don't cross nodes — multi-server deploys would serve permanently stale
  pages. (A CDN/surrogate-key backend is the future answer.)
- **Forms on cached pages** can't carry Rails CSRF tokens, so Plum's
  public forms use honeypot protection instead — invisible to humans,
  effective against bots.

It's **off by default** and documented in depth in
`docs/static-caching.md`, including a "should you enable this?" decision
table.
