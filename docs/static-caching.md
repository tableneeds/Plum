# Static Page Caching

Plum ships a full-page static cache: the first request for a public page
renders through Liquid as normal, and the complete HTML response is written to
disk. Subsequent requests are served from that file without touching the
database or the template engine. When content changes, the affected site's
cache is deleted and pages lazily re-render on their next visit.

This is a cache on the one true render path — not a static site generator.
There is no build step, no dependency graph to get wrong, and the control
panel always shows live data.

**It is off by default and must be turned on explicitly.** Read "Should you
enable this?" below before flipping it on — the wrong setting on the wrong
deployment topology causes a specific, silent content bug (stale pages served
forever), not a crash you'd notice.

## Should you enable this?

Ask one question: **does your app run on more than one server/dyno/instance
at the same time?**

| Your deployment | Enable it? | Why |
|---|---|---|
| Single VPS/Droplet/EC2 box (Plum's standalone SQLite mode) | **Yes** | This is the shape it was designed for. One disk, one cache, invalidation always reaches it. Free page-load speed and DB-load reduction. |
| Docker Compose on one host, one app container | **Yes** | Still one filesystem for the app process. |
| Heroku with 1 dyno, Render with 1 instance | **Yes, cautiously** | Correct today, but re-check this the moment you scale to 2 dynos — nothing will warn you when you cross that line. |
| Heroku/Render/Fly with **2+ dynos or instances**, or any horizontally-scaled/load-balanced deployment | **No** | See "Why this fails on multiple nodes" below. Use a CDN in front of the app instead (see that section). |
| Plum mounted inside a larger host app (embedded/SaaS mode, e.g. many customer sites behind one Rails app) | **Depends entirely on the host app's node count** — almost always multi-node in practice, so usually **No** | The host app's deployment shape governs, not Plum's. |
| Not sure / evaluating locally | **Leave it off** | It has zero effect on correctness either way in dev; there's no reason to enable it before you know your production topology. |

If you're unsure, leave it off. The cost of leaving it off is slower page
responses and more DB load. The cost of turning it on wrongly is **visitors
silently seeing outdated or wrong content**, which is worse and harder to
debug — nothing errors, nothing logs, pages simply disagree depending on
which server answered the request.

### Why this fails on multiple nodes

The cache is plain files on the server's own local disk. Invalidation works
by *deleting those files* when content changes. On one server, that's
airtight: the file that would be stale no longer exists, so the next request
always re-renders fresh.

With two or more servers, each has its **own separate disk**. An editor
publishes a change; the request that triggers invalidation lands on
whichever server handled that specific HTTP request — say, server A. Server A
deletes its cached file. Server B's copy of that same file is untouched.
Visitors routed to server B by the load balancer keep seeing the old page
**indefinitely** — not for a few seconds until some TTL expires, but forever,
until something else happens to touch that page on server B too.

This is why there is deliberately no "auto-detect production and turn it on"
behavior. A setting that's silently wrong 100% of the time on a common
deployment shape (small teams scaling from 1 to 2 dynos is one of the most
ordinary things that happens to a growing app) is worse than a setting you
have to think about once.

### If you're on a multi-node platform and still want caching

Don't use the disk store. Put a CDN (Cloudflare, CloudFront, Fastly) in front
of the app and let *it* hold the cached pages — a CDN has exactly one shared
cache, not one per node, so the invalidation problem above doesn't exist. You
still get the "no build step, one render path" benefit described above; only
the storage layer changes. See "Serving cached files from the web server"
below for the shape this takes; a first-class CDN/surrogate-key purge backend
driven by the same capture/invalidation hooks used here is on the roadmap.

## How it works

1. `Plum::StaticCache::Middleware` checks every `GET` request with no query
   string. If a cached file exists for the request host + path, it is served
   immediately (`X-Plum-Static-Cache: hit`).
2. On a miss, the request renders normally. `Plum::PagesController` and
   `Plum::ThemeAssetsController` mark their successful responses, and the
   middleware writes the body to
   `storage/plum_static_cache/{host}/{path}/index.html`
   (theme assets keep their real filename and extension).
3. Content models flush their site's cache directory in an `after_commit`
   hook (`Plum::StaticCacheInvalidation`). Flushing deletes files; it never
   generates anything, so over-flushing is cheap and always correct — this is
   what makes it safe on one server and unsafe across many, per above.

Requests with query strings (search, pagination, UTM-tagged links) are never
cached and never served from the cache. The control panel, API, and form
endpoints are untouched.

## Configuration

```ruby
Plum.configure do |config|
  # Explicit opt-in. Off by default. Read "Should you enable this?" above
  # before setting this to true.
  config.static_cache_enabled = true

  # Where cache files live. Default: Rails.root/storage/plum_static_cache
  config.static_cache_path = "/var/www/site-cache"
end
```

There is no environment-based default (no "automatically on in production")
— it must be set explicitly, on purpose, by someone who has confirmed the
deployment is single-node. This is a deliberate change: earlier versions of
this feature turned on automatically in `production`, which was correct for
the single-VPS case this was designed around but silently wrong the moment an
app scaled to multiple nodes. Explicit opt-in means the person flipping the
switch is the person who knows the deployment topology.

Cache directories are keyed by request host. A site with a `domain` set
flushes `{domain}` and `www.{domain}`; sites without a domain flush the whole
cache root.

Administrators can clear a site's cache manually from the dashboard
("Clear page cache").

## Serving cached files from the web server (full measure)

The middleware already skips the database and rendering, but nginx or Caddy
can serve the files without invoking Ruby at all:

```nginx
server {
  server_name example.com;
  root /path/to/app/storage/plum_static_cache/$host;

  location / {
    try_files $uri $uri/index.html @rails;
  }

  location @rails {
    proxy_pass http://app_upstream;
    proxy_set_header Host $host;
  }
}
```

Anything not in the cache (first hits, search, forms, the control panel)
falls through to Rails. Because invalidation deletes files, the web server
can never serve a stale page that Plum knows is stale.

The same layout works for pushing to object storage: sync the cache directory
to S3/CloudFront and invalidate on deploy, or point a CDN at the app origin
and let the middleware serve as the fast backend.

## Forms and CSRF

Cached pages cannot carry per-session CSRF tokens, so public `{% form %}`
submissions use a hidden honeypot field (`form_submission[website]`) instead.
Submissions with a filled honeypot are silently accepted-and-dropped. The
control panel keeps standard Rails CSRF protection — only the public form
endpoint opts out.

This also means rendering a public page no longer writes a session cookie,
which is what makes responses safely shareable between visitors — and is true
regardless of whether the cache itself is enabled.

## What stays dynamic

- `/search` (query-dependent)
- Collection pagination beyond page 1 (`?page=2`)
- Form submission POSTs
- The JSON content API
- The entire control panel
