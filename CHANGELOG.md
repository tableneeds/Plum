# Changelog

## Unreleased

- Fixed `plum connect` in a directory with no plum.yml silently targeting
  the globally active project (running it from a fresh repo could show —
  or with --reconfigure, rewrite — a different project's connection).
  Connect now always means "set up the current directory"; only an
  explicit `--project NAME` redirects it.
- Connect now finishes the journey: when the once app isn't deployed yet
  it offers to build and ship right there (chains into plum deploy), and
  connecting a project always makes it the active one — working in a
  directory means that's the project you're "in". A brand-new site's app
  question also now defaults to "a new app on this server (type its
  hostname)" instead of pre-selecting an already-deployed app, which
  would have silently pointed the repo at another site's container.
- Untangled project vs. remote in connect's wording: the wizard now asks
  for an "Environment name" (production, staging — plum.yml's remotes)
  with a line explaining the concept, and the closing hint no longer
  prints the nonsensical `plum pull --project production` — it points at
  `plum pull` from the directory, or `--project <site>` from anywhere.
  Terminology now spelled out in docs/plum-cli.md: projects are sites,
  remotes are environments.
- Connect's server pick-list now knows every stored server, not just the
  plum-* SSH aliases: hosts from every registered project's remotes are
  merged in (annotated "— used by <project>"), so a server appears even
  when its alias offer was declined.
- Added `plum new NAME`: scaffold a deploy-ready Plum site in one command
  — rails new, the plum-cms gem, the install generator mounted at `/`, a
  prepared database, and a git history. Bootstraps its own toolchain:
  missing Ruby or Rails are offered for install (mise → ruby → rails),
  each step confirm-gated. Refuses clearly when run inside an existing
  Rails app, and registers the new project in the global registry.
- Added `plum deploy [remote]`: registry-free deploys — build the image
  locally for linux/amd64, stream it to the server over SSH
  (docker save | docker load; no registry, no CI, no accounts), roll the
  Once app to it, and wait for the container health check. Auto-update is
  disabled for these apps: deploys are explicit, never by surprise.
- Added docs/zero-to-agency.md and a matching tutorial chapter: empty
  directory → client sites on a $6 DigitalOcean droplet with `plum new`,
  `plum connect`, `plum deploy`, and the pull/push/backup rhythm.

## 0.2.2 — 2026-08-13

### Fixed

- Fixed `plum:site:replace` (and site destroy generally) aborting with
  `RecordNotDestroyed` on any site that has a homepage entry — i.e. every
  real site. The homepage's can't-be-deleted guard now stands down when the
  entry is being removed as part of its site's dependent cascade. Found by
  the first live `plum pull` against production.
- Fixed `plum connect`'s deployment detection treating an unedited
  `config/deploy.yml` scaffold (the placeholder file `rails new` ships) as
  proof of a Kamal deployment, which steered Once-deployed repos toward a
  broken `via: kamal` remote. A deploy.yml still carrying `kamal init`
  placeholders now counts as absent.

### Added

- Added the Plum CLI (`cli/`, Go): `plum pull` replaces your local site with
  a remote's, `plum sync`/`plum check` apply and verify config-as-code files,
  `plum backup` and `plum run` wrap the remaining rake tasks. Remotes are
  defined per-project in `plum.yml` (`plum init`). Every command wraps an
  engine rake task — the CLI adds transport, never behavior. See
  `docs/plum-cli.md`.
- Added three transports for CLI remotes (`via: ssh|kamal|once`): plain
  ssh/scp (default, inherits ~/.ssh/config/agent/jump hosts); `kamal`, which
  shells out to a local Kamal binary so `config/deploy.yml` is the only
  source of truth for where the app lives; and `once` for 37signals' Once
  tool, whose CLI runs on the server itself — the transport ssh-es to
  `host:` and runs `once exec <once_app> ...` there (`once_app:` is the
  hostname you gave `once deploy --host ...`, distinct from how you reach
  the box). Verified against a live Once deployment. Picking a transport is
  the only thing that changes — the rake tasks behind every command are
  identical either way.
- Added `plum logs [remote] [--follow]` — recent app logs, heroku-style
  tailing with `--follow`. Plain ssh tails `log/production.log`, Kamal runs
  `kamal app logs`, Once streams `docker logs` from the app's container
  (resolved by Once's own container label; the Rails image logs to stdout,
  not a file).
- Gave the CLI a heroku-style voice: `▸` step headers, animated spinners
  that settle into timed `✓ ... (700ms)` result lines, remote rake output
  framed behind a dim `│` gutter, arrow-key selects and styled prompts in
  `plum connect`, a colorized help screen and projects list, and a plum
  accent color adaptive to light/dark terminals (via lipgloss + huh).
  Everything degrades to the old plain sequential output when piped, in
  CI, under `NO_COLOR`, or with `TERM=dumb` — scripted stdin answers and
  log parsing are unaffected; Ctrl-C at any prompt exits quietly (130).
- `plum connect` now answers its own questions where it can: re-runs
  prefill every prompt from the existing plum.yml (Enter-through-everything
  reproduces the current setup, and the stored deployment type outranks
  file detection), and for Once remotes it asks the server itself — `once
  list` over the just-verified SSH connection — offering the deployed apps
  as a pick-list instead of a blank hostname prompt.
- On an already-configured project, bare `plum connect` skips the interview
  entirely and becomes a health check: it prints the stored connection and
  verifies SSH login, server tooling, and that the app is deployed, exiting
  nonzero on failure (CI-friendly). The wizard runs only on first setup,
  with `--reconfigure`, or when a new ip/host is passed explicitly.
- A brand-new project's host prompt now offers the servers you already
  have: plum-* aliases from ~/.ssh/config (the ones `plum connect` itself
  wrote) appear as a pick-list, so connecting a second site to the same
  VPS never re-asks for the IP.
- `plum check`/`plum push` bootstrap themselves on first run: with no
  plum/ directory in the project they offer to run
  `bin/rails plum:config:export` right there (interactive sessions only;
  scripts keep the hard error). Verified live: a first-time `plum check`
  exported the content model, uploaded it through `once exec`'s stdin tar
  pipe — the last transport path that had never run against a real
  server — and production reported no drift.
- Renamed `plum sync` to `plum push`: push moves structure up, pull moves
  content down — the familiar "push code, pull data" asymmetry, since in
  Plum's model the content model is code. `plum sync` keeps working as an
  alias with a gentle pointer to the new name.
- `plum connect` now registers the project in the global registry under
  the directory's name (activating it when nothing is active), so
  `plum use`/`--project` work without a separate `plum projects add`.
- `plum logs` prettifies structured JSON log lines on a terminal: dim
  local-time stamps, color-coded levels and HTTP statuses, and request
  lines compacted to `GET /up 200 (2ms)` with noisy fields dropped. Plain
  Rails log text passes through untouched, and piped output stays raw so
  `plum logs | jq` keeps working. The CLI is now documented in the README
  alongside the engine features.
- Added `plum tutorial`: a built-in, full-screen interactive tour of Plum
  and the CLI (bubbletea + glamour). Eight chapters — content model,
  themes, writing mode and drafts, static caching, config as code, and
  the CLI workflow — as styled markdown with ←/→ chapter navigation,
  1–9 jumps, and a plain-markdown fallback when piped. Chapters slide in
  on harmonica spring physics under an animated gradient progress bar;
  the CLI chapters carry live demos (press `d` to watch `plum pull` or a
  connect health check type itself out, spinners included); and the tour
  ends with a three-question interactive quiz. Harmonica earns its name
  throughout: the tour opens with a splash — the PLUM wordmark springs up
  letter by letter while a plum bounces across it on projectile physics —
  wrong quiz answers shake the question on an underdamped spring, and
  finishing the quiz starts a continuous confetti rain — plum-palette
  particles drifting down the finale on gentle projectile physics for as
  long as you stay to enjoy it.
  The splash is a proper title screen: the show loops (the plum relaunches
  while you watch) and holds until you press a pulsing lipgloss "Start the
  tutorial ↵" button — enter begins, q quits, nothing rushes you.
- Gamified the tutorial. Progress persists to ~/.config/plum/tutorial.json:
  chapters check off as read, demos as watched, and the tour resumes where
  you left off (the title button becomes "Continue the tutorial"). Reading,
  watching, typing, and passing the quiz earn XP, with plum-themed ranks
  climbing in the header (Seedling → Sprout → Sapling → Grower →
  Orchardist). CLI chapters gained typing challenges: press `t` and type
  the real command with strict per-character feedback — typos flash and
  sting but don't land — and nailing it banks XP and rolls the demo as
  your reward. And the title screen hides Plum Drop (`p`): an arcade game
  of catching falling plums (harmonica projectiles) with an arrow-key
  basket, combo multipliers, and a persisted high score. It's endless —
  misses just break your streak, new bests are celebrated the moment they
  happen, and you play until you quit. SSH-served sessions play everything with an ephemeral save.
- `plum tutorial --serve [addr]` hosts the tour over SSH via charm's wish:
  `ssh -p 2222 your-server` gets the full animated tutorial with nothing
  installed. Sessions run only the tutorial (no shell, no exec, any or no
  key accepted); the host key persists under ~/.config/plum so returning
  visitors aren't warned.
- Added a Firebase-CLI-style global project registry (`plum projects
  add/list/remove`, `plum use`, `--project`) so a fleet of Plum sites can be
  managed from one dev machine without `cd`-ing into each repo — a local
  `plum.yml` still always takes precedence when one is present.
- Added `plum connect [ip-or-host]`: guided first-time server setup with no
  YAML editing required. Detects or generates a local SSH key, tests and (on
  confirmation) fixes passwordless login with `ssh-copy-id`, optionally adds
  a `Host` alias to `~/.ssh/config`, and writes `plum.yml` from the answers.
  It also detects the repo's deployment shape (`config/deploy.yml` → Kamal,
  `Dockerfile` alone → Once) and asks the right questions for it, then
  checks the server's tooling — Docker Engine for Kamal/Once, plus the
  `once` binary for Once — offering to install whatever's missing, each
  step gated on explicit confirmation. Deploying the app itself (images,
  registry credentials) intentionally stays manual.
- Fixed destroying an entry (or its site) crashing with a foreign-key
  violation when the entry was linked from a nav menu — nav items are now
  removed with their entry.
- Added `rails plum:site:replace` — the "pull" refresh: swaps the local site
  for a production archive in one transactional step, database-agnostic
  (Postgres prod → SQLite dev), refusing to run in production without FORCE.
- Fixed Plum rake tasks running their bodies twice in the standalone repo
  (engine railtie and application both load lib/tasks; Rake appends actions
  on re-definition).
- Added config-as-code (phase 1): `Plum::ConfigSync` syncs content types and
  fieldsets between YAML files (`plum/content_types/*.yml`) and the database
  via `rails plum:config:export`, `plum:config:sync` (with PRUNE/FORCE
  guards that never touch entry data), and `plum:config:check` for CI drift
  detection. See `docs/config-as-code.md`.
- Added full-page static caching: rendered public pages and theme assets are
  written to disk keyed by host + path, served without touching the database,
  and flushed automatically when site content changes. **Off by default,
  explicit opt-in** (`config.static_cache_enabled = true`) — it is only
  correct on a single-server deployment; enabling it on 2+ nodes/dynos
  silently serves stale pages. The file layout supports direct nginx/Caddy
  `try_files` serving. See `docs/static-caching.md`.
- Added a "Clear page cache" control to the dashboard for administrators.
- Added a distraction-free writing mode for entries with a rich text field:
  full-screen typographic surface with debounced autosave, Cmd/Ctrl+S,
  word count, and unsaved-changes protection, reachable from the entry editor.
- Write-mode saves merge into existing entry data, so partial saves never
  wipe unsubmitted blueprint fields, and identical consecutive saves no
  longer stack duplicate revisions.
- Added a git-style "Review changes" screen for working drafts: field-by-field
  word diffs of draft vs. live content (rich text compared as readable text,
  structured fields as JSON), with publish/discard actions inline. Linked from
  the entry editor's draft banner and the writing surface.
- Added working drafts for published entries: writing-mode autosaves on a
  published entry are stored in a new `draft_data` column and never touch the
  live content or flush its cached pages. Editors publish or discard the
  draft explicitly (from the writing surface or the entry editor's draft
  banner); publishing records a revision. Draft-status entries still save
  directly.

### Changed

- Public `{% form %}` forms now use a honeypot spam trap instead of a
  per-session CSRF token, so cached pages stay valid and public page views no
  longer set session cookies. The control panel keeps standard CSRF
  protection.
- Theme assets are served with `Cache-Control: public, max-age=3600`.

## 0.2.1 — 2026-08-07

### Added

- Added versioned, checksum-verified site archives covering content schemas,
  entries, relationships, taxonomies, navigation, globals, forms, settings,
  revisions, and original asset files.
- Added export/import and timestamped backup/restore Rake tasks with safe
  new-site restoration and identifier remapping.
- Reframed the roadmap around a production-readiness 0.3.0 milestone.

### Fixed

- Corrected the packaged Propshaft search path so engine Stimulus controllers
  resolve under their `plum/` import-map namespace in external applications.
- Upgraded Lexxy so pasted plain text preserves paragraph boundaries and
  block formatting only changes the active paragraph.

## 0.2.0 — 2026-08-07

### Added

- Expanded visual blueprints to 21 field types, including structured lists,
  groups, repeaters, radio controls, button groups, multi-image collections,
  and presentation sections.
- Added responsive field widths, conditional visibility, nested-field editing,
  collection constraints, stable option values, and field-level instructions.
- Added single and multiple entry relationships with site-scoped validation and
  Liquid expansion.
- Added reusable fieldsets with collision-safe insertion into blueprints.
- Added immutable, attributed entry revisions with non-destructive restoration.
- Added a live-only, paginated JSON content API with expanded field values.
- Added site locales, linked translation variants, locale-specific slugs,
  localized public routes, and locale-aware API responses.
- Added asset focal points and multi-image library fields.
- Added comprehensive field showcase seeds and blueprint schema documentation.

### Changed

- Redesigned blueprint field cards for clearer, responsive configuration.
- Automated synchronization of Tailwind output into the packaged control-panel
  stylesheet.
- Added normalized server-side validation for numeric, temporal, collection,
  option, relationship, asset, nested, and conditional values.

### Fixed

- Restored reliable image selection and default alt text for inline uploads.
- Isolated system-test data and updated browser coverage for Lexxy and the
  current image picker.

## 0.1.2 — 2026-08-04

### Fixed

- Allowed long control-panel brand names, subtitles, and content-type names to
  wrap without clipping or displacing their icons.
- Kept control-panel branding limited to the configured `cp_name` and
  `cp_subtitle`; public “Powered by” attribution is not appended to the sidebar.
- Allowed the control-panel subtitle to be omitted by setting `cp_subtitle` to
  `nil`.

## 0.1.1 — 2026-08-04

### Changed

- Redesigned image pickers with a responsive image library, accessible upload
  controls, drag-and-drop support, clearer status feedback, and consistent
  pointer cursors throughout the control panel.
- Added independent Hotwire image saving for entry image fields and the site
  logo so image changes do not submit or overwrite other in-progress edits.
- Image removals now require confirmation and persist immediately without an
  extra save step.

### Fixed

- Synchronized the compiled control-panel stylesheet with its Tailwind source.
- Included the independent image-save routes in both development and packaged
  engine route sets.

## 0.1.0 — 2026-07-31

The first public release of Plum, a Rails-native content management engine.

### Included

- A Hotwire control panel for entries, content types, navigation, globals,
  taxonomies, forms, assets, themes, and site settings.
- Structured fields, relationships, reusable blocks, and Lexxy rich text.
- Portable Liquid themes with public entries, collections, taxonomies, search,
  forms, nested route prefixes, heading anchors, and tables of contents.
- Standalone and embedded operation with host-owned identity, authorization,
  tenancy, and registered content sources.
- SQLite-first persistence with PostgreSQL compatibility.
- Configurable control-panel branding and theme package installation.

Plum 0.1 is intentionally pre-1.0. Public APIs may evolve as the project is
used in more Rails applications and content-first sites.
