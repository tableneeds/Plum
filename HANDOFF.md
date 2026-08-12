# Handoff — authoring platform + Go CLI arc (2026-08-12)

Read this first if you're picking up where the last session left off. Delete
this file once it has served its purpose; `docs/` holds the durable
documentation.

## Where things stand

Everything below is **built, tested, and committed**. Engine: 211 tests
green (`bin/rails test`; the Chrome/Selenium system tests flake ~1–2 per
run even on clean main — environmental, rerun in isolation before blaming
changes). CLI: `cd cli && go test ./...` all green; binary installed at
`~/.local/bin/plum`.

### Engine (Rails, gem `plum-cms`)

- **Full-page static caching** — `lib/plum/static_cache{,.rb}`, middleware
  capture + delete-only invalidation. **Off by default, explicit opt-in**
  (`config.static_cache_enabled = true`); single-server only (multi-node =
  permanently stale pages). Public forms use a honeypot instead of CSRF
  tokens because cached pages can't carry session tokens. See
  `docs/static-caching.md` (has a "should you enable this?" decision table).
- **Writing mode + working drafts** — distraction-free editor at
  `/cp/.../write` (`app/views/plum/cp/entries/write.html.erb`,
  `write_controller.js`). Autosaves into `entries.draft_data` (JSON:
  `{"title" => ..., "data" => {...}}`) without touching the published
  version; publish/discard from the editor; LCS word-diff review
  (`Plum::DraftDiff`, `diff.html.erb`). Draft-only saves skip cache flush
  (`CACHE_IRRELEVANT_COLUMNS` in `static_cache_invalidation.rb`).
- **Config-as-code phase 1** — `Plum::ConfigSync` syncs content types +
  fieldsets between `plum/content_types/*.yml` and the DB;
  `plum:config:export|sync|check` rake tasks (PRUNE/FORCE guards). See
  `docs/config-as-code.md`.
- **Portable site archives** — `plum:site:export|import|replace`; the
  archive is the universal transport (Postgres prod → SQLite dev works).

### Go CLI (`cli/`, module `github.com/tableneeds/Plum/cli`)

Design rule: **every command wraps an engine rake task; the CLI is
transport only, never behavior.** Three transports (`via:` in plum.yml):

- `ssh` — system ssh/scp, inherits ~/.ssh/config.
- `kamal` — shells out to a *local* kamal binary (`kamal app exec --reuse
  --primary`).
- `once` — 37signals' Once runs **on the server**, not locally. The
  transport ssh-es to `host:` and runs `once exec <once_app> ...` there.
  `host:` = how you reach the box; `once_app:` = the hostname given to
  `once deploy --host ...`. Two different values in practice.

Commands: `pull`, `sync`, `check`, `backup`, `run`, `logs [--follow]`,
`init`, `connect`, `projects add/list/remove`, `use` (Firebase-style global
registry in `~/.config/plum/config.yml`). Resolution: `--project` flag >
local plum.yml > active project.

`plum connect <ip>` is the guided setup: SSH key check/generate,
ssh-copy-id, ~/.ssh/config alias, **deployment detection**
(`config/deploy.yml` → kamal, `Dockerfile` alone → once), per-shape
questions, and **server bootstrap** — checks Docker Engine (kamal+once) and
the `once` binary (once), offers to install what's missing, each gated on
explicit confirmation. Scope deliberately stops there (Ben's explicit
choice): no automated deploys, images/registry tokens stay manual.

**Verified live** against Ben's VPS `147.182.221.134` (`~/.ssh/config`
alias `plum-production`, root): connect detection, tooling checks (Docker
29.7.1, once v0.3.0), `once list` verification, and `plum logs` streaming
real production logs from `~/Work/the-final-word`.

### Ground truth about Once (learned the hard way, verified live)

- Deployed once is `v0.3.0-multihost` — it has **no `logs` subcommand**.
- App containers have **no log/production.log**; logs only exist in
  `docker logs`. Container names derive from the *image* name, not the app
  hostname; the reliable hostname→container mapping is the `once` Docker
  label (JSON with a `host` key). `plum logs` greps
  `docker ps --format '{{.Names}} {{.Label "once"}}'` for `once_app`.
- The server runs two once apps (finalwordsports.com, plumcms.org) — never
  assume one container.
- Installers: Docker `curl -fsSL https://get.docker.com | sh`; once
  `curl https://get.once.com | sh`.

## How to verify the world is still green

```bash
bin/rails test                                    # 211 runs, 0 failures
cd cli && go build ./... && go vet ./... && gofmt -l . && go test ./...
go build -o plum . && cp plum ~/.local/bin/plum   # reinstall after changes
```

Real-world smoke tests (read-only, safe):
`cd ~/Work/the-final-word && plum logs` and `plum check`.

## `plum pull` verified live (2026-08-12, later the same day)

`plum pull --yes` ran successfully in `~/Work/plum-site` against the
`plumcms.org` once app: export via `once exec` on production → download →
local `plum:site:replace`; local counts match production exactly. Two bugs
were found and fixed in the process (homepage destroy guard aborting the
replace cascade; kamal-scaffold deploy.yml fooling connect's detection —
see CHANGELOG).

State left behind, deliberately:

- **`~/Work/plum-site/Gemfile` now points at the local checkout**
  (`gem "plum-cms", path: "../Plum"`) so the local side has today's
  `plum:site:replace`. **Do not push plum-site like this** — its Docker
  image build would fail (../Plum isn't in the build context). The real fix
  is releasing plum-cms 0.2.2 with today's features and bumping plum-site
  back to a version constraint.
- **`~/Work/plum-site` local content was replaced with production's**
  (that was the test). Pre-pull dev DB backup, if it matters:
  the session scratchpad's `plum-site-dev-backup.sqlite3` (temp dir, may
  be gone; nothing valuable was in it).
- **the-final-word can't use pull at all yet**: it vendors plum 0.1.0 at
  `vendor/plum` with an empty `lib/tasks/` — no plum rake tasks on either
  side. Its production image needs a rebuilt vendor copy (or a switch to
  the published gem) before pull/sync/backup work there. Its `plum.yml`
  was found clobbered to a bare `via: kamal` (likely a connect re-run
  hitting the detection bug, now fixed) and has been restored to the
  correct via: once form.

## Sensible next steps (none started)

1. **`plum check`/`plum sync` live** — `sync`'s upload path relies on
   `once exec` passing stdin through to the container (tar pipe) —
   plausible but **unconfirmed live**; test `check` (read-only) before
   trusting `sync --prune`. Requires a `plum/` config export locally first.
2. **Release plum-cms 0.2.2** so plum-site can go back to a gem version
   (see above), and consider updating the-final-word's vendored copy.
3. **`via: kamal` against a real Kamal fleet** — argv is unit-tested against
   fake binaries only.
4. **`plum deploy`** — Ben wants heroku-like ergonomics eventually; scope so
   far deliberately excludes it (registry tokens, `once deploy`). Discuss
   scope before building.
5. **Fleet-wide `--all`** across the project registry.
6. **Config-as-code phase 2** — CP write-back to files, dev file watcher,
   ALL_SITES=1.
7. **CDN/surrogate-key cache backend** so static caching works multi-node.

## Gotchas for the next agent

- Stale `public/assets` manifests from gem builds silently shadow new JS
  (Stimulus controllers never register). `bin/rails assets:clobber` fixes.
- Engine + app both load `lib/tasks`; the rake files are wrapped in
  `unless Rake::Task.task_defined?` guards — keep that pattern for new tasks.
- Go lives at `cli/`; use `eval "$(mise env -s bash)"` to get the toolchain.
- Local artifacts are gitignored, not deleted: root `*.gem` files,
  `/cli/plum` binary, `/plum.yml`, `/plum/` (config-as-code export dir).
