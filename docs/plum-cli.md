# The Plum CLI

`cli/` (Go, `github.com/tableneeds/Plum/cli`) is the Plum command line. It
wraps the rake tasks that ship with the engine — `plum:site:export`,
`plum:site:replace`, `plum:config:sync`, `plum:backup:create`, and so on —
over a transport of your choosing. **The CLI adds transport and ergonomics,
never behavior.** Anything it does, you could also do by hand with `ssh` and
`bin/rails`; it just saves you from typing the same incantation every time
and from having to remember which task does what.

Status: early. Every command has been exercised end-to-end against a local
Plum install (`via: ssh` with `host: local`), and `via: once` has been
verified against a live Once deployment on a real VPS (`plum connect`,
tooling detection, and `plum logs` included). `via: kamal`'s
argument-building is unit-tested against fake binaries and smoke-tested
against the real `kamal` executable's argument parser, but hasn't been run
against a real Kamal fleet yet.

## Install

No published binary yet — build from source:

```bash
cd cli
go build -o plum .
# put ./plum somewhere on your PATH, e.g.:
mv plum ~/.local/bin/plum
```

## Two layers of configuration

This mirrors the Firebase CLI's model deliberately, because it solves the
same two problems: "how does this directory reach its server" and "how do I
work with a project without cd-ing into its directory first."

1. **`plum.yml`** — lives in a site's own repo, defines its **remotes**
   (servers). This is the source of truth for how to reach that one site.
2. **The global project registry** (`~/.config/plum/config.yml`, or
   `$XDG_CONFIG_HOME/plum/config.yml`) — lives on your dev machine, not in
   any repo. It's just a name → directory index plus one "active project"
   pointer, so you can run `plum pull` from your home directory and have it
   know you mean the Table Needs site, without `cd`-ing there first.

### `plum.yml`

The easy way — guided setup, no YAML editing:

```bash
plum connect 203.0.113.5
```

Walks you through: checking for a local SSH key (offers to `ssh-keygen` one
if you don't have one), testing whether key-based login to the server
already works, offering to run `ssh-copy-id` if it doesn't, optionally
adding a `Host` alias to your real `~/.ssh/config` (so `ssh
plum-production` also works, and plum.yml can reference the alias instead
of raw host/user), and finally writing `plum.yml` for you.

It also **detects how the repo deploys** and asks the right questions for
that shape: `config/deploy.yml` means Kamal, a `Dockerfile` without one
usually means Once (you confirm the guess either way). A plain ssh remote
gets asked for the app's path on the server; a Once remote gets asked for
the app's hostname (`once_app`) instead, since the app lives in a container
rather than at a path; a Kamal remote needs neither.

For Kamal and Once shapes it then **checks the server's tooling** — Docker
Engine for both, plus the `once` binary for Once — and offers to install
whatever's missing (`curl -fsSL https://get.docker.com | sh`, `curl
https://get.once.com | sh`), each only with your explicit confirmation. It
stops short of deploying the app itself: pushing images and registry
credentials stay in your hands. Finally it verifies what it can — that
`bin/rails` exists at the path you gave (ssh), or that `once list` shows
your app (once) — so you find out immediately if something's off instead of
on your first `plum pull`.

`plum connect` (with no IP) prompts for the host interactively too. Run it
again to add a second remote (e.g. staging) to an existing plum.yml — it
merges in the new remote rather than overwriting the file, though note that
re-saving via `connect` does not preserve hand-written comments in an
existing plum.yml.

The manual way — writes an editable template with comments intact:

```bash
plum init
```

```yaml
default: production   # which remote to use when none is named

remotes:
  production:
    host: your-server.example.com
    user: deploy
    path: /var/www/your-site
    # rails: bin/rails          # how to invoke rails in `path` (default shown)
    # ssh_args: ["-p", "2222"]  # extra ssh/scp args: custom port, identity file, etc.

  staging:
    host: staging.example.com
    user: deploy
    path: /var/www/your-site-staging
```

Omit the remote name on any command to use `default:` (or the only remote,
if there's just one).

### The project registry (fleet management)

```bash
plum projects add table-needs ~/Work/TableNeeds   # register a directory
plum projects list                                  # see what's registered
plum use table-needs                                 # make it the active project
plum projects remove table-needs                     # forget it (files untouched)
```

Once a project is active, every command works from anywhere:

```bash
cd ~                  # nowhere near the TableNeeds repo
plum use table-needs
plum pull              # pulls TableNeeds' production data into TableNeeds' local site
```

Resolution order for any command (`pull`, `sync`, `check`, `backup`, `run`):

1. `--project NAME` on the command itself — always wins.
2. A `plum.yml` in the **current directory** — so working inside a repo
   behaves exactly like today, unaffected by whatever project is active
   elsewhere.
3. The globally **active project** (`plum use`) — the fallback that makes
   fleet commands work from anywhere.
4. Otherwise: an error telling you to `plum init` or `plum use`.

```bash
plum pull --project table-needs   # one-off target, doesn't change what's active
```

## Commands

```
plum connect [ip-or-host]
```
Guided setup — see above. The only command that touches your local SSH
config or generates keys, and only with your confirmation at each step.

```
plum pull [remote] [--yes]
```
Replaces your local site with the remote's: exports an archive there,
downloads it, and runs `plum:site:replace` locally. Content-only — the
underlying database engine doesn't have to match (Postgres in production,
SQLite locally works fine; see `docs/config-as-code.md` and the site archive
format). Prompts for confirmation unless `--yes` is passed.

```
plum sync [remote] [--prune] [--force]
plum check [remote]
```
Upload the local `plum/` config-as-code directory (see
`docs/config-as-code.md`; generate it with `bin/rails plum:config:export`)
and apply or verify it against the remote. `check`'s exit code is nonzero on
drift — wire it into CI. `--prune` deletes content types missing from the
files; `--force` allows that even when they still have entries.

```
plum backup [remote]
```
Runs `plum:backup:create` on the remote (writes a timestamped archive on the
server; doesn't download it — that's what `pull` is for).

```
plum logs [remote] [--follow]
```
Shows the app's recent logs; `--follow` (or `--tail`) streams them until you
Ctrl-C, heroku-style. What "the logs" means depends on the transport: plain
ssh tails `log/production.log` under the app path, Kamal runs `kamal app
logs` (all hosts, not just the primary), and Once streams `docker logs` from
the app's container on the server.

```
plum run [remote] -- TASK [ENV=value ...]
```
Escape hatch: run any rake task on the remote. `plum run production --
plum:site:export ARCHIVE=/tmp/x.zip` is what `pull` does internally, spelled
out.

## Transports (`via:`)

Every remote picks a `via:`. It only changes *how* the command above reaches
the server — the rake tasks and their behavior are identical either way.

### `via: ssh` (default)

Plain `ssh`/`scp`, inheriting your `~/.ssh/config`, SSH agent, and jump
hosts. Needs `host`, usually `user` and `path`.

### `via: kamal` — for apps deployed with [Kamal](https://kamalmanual.com)

```yaml
remotes:
  production:
    via: kamal
    # kamal_bin: bin/kamal          # default: bin/kamal if present, else `kamal` on PATH
    # kamal_config: config/deploy.yml
    # kamal_destination: staging     # for config/deploy.staging.yml
```

No `host` or `path` needed — Kamal already knows your servers from
`config/deploy.yml` and owns its own SSH connection. Commands run as
`kamal app exec --reuse --primary "<command>"`, matching the pattern this
repo's own `config/deploy.yml` already uses for its `console`/`shell`
aliases. `--primary` targets one host even if you deploy to several, so a
rake task like `plum:site:export` runs exactly once.

### `via: once` — for apps deployed with [Once](https://once.com)

```yaml
remotes:
  production:
    via: once
    host: plum-production          # how to SSH into the server (IP or ~/.ssh/config alias)
    once_app: your-app.example.com # the hostname you gave `once deploy --host ...`
    # user: root                   # if host isn't an alias that already sets it
    # once_bin: once               # path to once ON THE SERVER (default shown)
```

Unlike Kamal, Once's CLI runs **on the server**, not on your dev machine —
it talks straight to the local Docker daemon. So this transport is really
ssh underneath: it connects to `host` (same semantics as `via: ssh` —
aliases, agents, and `ssh_args` all work) and runs
`once exec <once_app> <command> [args...]` there.

That's why there are two identifiers: `host` is how you *reach the box*,
`once_app` is which *app on it* you mean — commonly different values, e.g.
an SSH alias pointing at a bare IP vs. the app's public DNS hostname. One
server can run several Once apps; `once_app` picks yours.

`plum logs` is the one command that doesn't go through `once exec`: the
Rails image logs to the container's stdout (there's no `log/production.log`
inside it), and deployed Once has no `logs` subcommand — so the CLI finds
your app's container by the `once` label Once stamps on it and streams
`docker logs`, the same daemon Once itself drives.

## What this doesn't do (yet)

- **No deploys.** `plum connect` will install the *tooling* a fresh server
  needs (Docker Engine, the `once` binary — each with your confirmation),
  but actually deploying the app — building images, registry credentials,
  `once deploy` / `kamal deploy` — stays in your hands. Kamal and Once
  already do that well; wrapping them for exec is as far as this goes on
  purpose (see `docs/config-as-code.md` and the CLI design notes for why
  re-inventing deploy tooling isn't the goal).
- **No `--all` / fleet-wide command yet.** Today you target one project (or
  one remote) per invocation. Running one command across every registered
  project is a natural next step, not yet built.
- **No downloaded database snapshot for SQLite-in-production setups.**
  `pull` always goes through the portable site archive, which works
  regardless of the production database engine. A faster SQLite-specific
  path (`sqlite3 prod.db "VACUUM INTO ..."`) was considered and deliberately
  skipped — the archive is the one code path that works whether production
  runs SQLite or Postgres, and duplicating that logic for a marginal speedup
  wasn't worth the two-path maintenance cost.
