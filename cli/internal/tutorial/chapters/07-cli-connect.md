# The CLI: connecting a server

The `plum` CLI wraps the engine's rake tasks over a transport — **it adds
ergonomics, never behavior**. Anything it does, you could do by hand with
ssh and `bin/rails`; it just remembers the incantations for you.

Start here:

```
plum connect 203.0.113.5
```

The wizard handles the whole first-contact ritual: checks for a local SSH
key (offers to generate one), tests key-based login (offers `ssh-copy-id`),
detects how your repo deploys, asks the right questions for that shape,
optionally adds a `plum-production` alias to `~/.ssh/config`, writes
`plum.yml`, registers the project, and verifies the server end to end —
offering to install Docker or `once` if they're missing.

It asks as little as possible: known servers are offered from your SSH
config, deployed apps are discovered from the server itself, and on an
**already-configured project** `plum connect` asks *nothing* — it becomes
a health check that verifies your setup still works.

**Press `d` to watch a connect health check run.**

## Transports

Each remote in `plum.yml` picks a `via:`:

- **ssh** (default) — the app lives at a path on a server you ssh into
- **kamal** — shells out to your local Kamal binary; `config/deploy.yml`
  stays the source of truth
- **once** — 37signals' Once; its CLI runs *on the server*, so plum
  ssh-es in and runs `once exec <app> ...` there

The transport only changes how commands *reach* the app — what runs is
identical.
