# Everyday commands

The rhythm is **pull content down, push structure up** — the same
asymmetry as "push code, pull data":

```
plum pull        # replace your local site with production's content
plum push        # apply plum/ config-as-code files to the remote
plum check       # fail if the remote drifted from plum/ (CI-friendly)
```

`pull` exports a portable site archive on the server, downloads it, and
swaps your local site for it — entries, assets, everything. It works
across database engines: Postgres in production, SQLite on your laptop.
Full local dev parity with production, one command.

```
plum logs            # recent app logs
plum logs --follow   # stream them, Ctrl-C to stop
```

On a terminal, structured log lines are prettified — `GET /up 200 (2ms)`
with color-coded statuses. Piped, you get raw bytes (`plum logs | jq`
works).

```
plum backup                     # timestamped site archive on the server
plum run -- TASK ENV=value      # escape hatch: any rake task, any remote
```

## Fleet management

Working on several sites? Register them once (connect does it for you)
and drive everything from anywhere:

```
plum projects list    # everything registered, ● marks the active project
plum use my-site      # set the active project
plum use              # ...or show it
plum pull --project my-site   # one-off targeting, from any directory
```

Resolution order: `--project` flag → the current directory's `plum.yml` →
the active project.

## Where next

- `docs/plum-cli.md` — transports, plum.yml reference, look-and-feel
- `docs/config-as-code.md`, `docs/static-caching.md` — the deep dives
- `plum help` — every command at a glance

That's the tour. Go build something.
