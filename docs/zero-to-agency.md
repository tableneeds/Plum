# Zero to Agency

How to go from an empty directory to hosting client sites — with one
cheap VPS, the `plum` CLI, and nothing else. No GitHub required, no
container registry, no CI pipeline, no platform-as-a-service bill. Your
laptop builds, your server runs, SSH connects them.

The stack under the hood: Rails + Plum in a Docker container, managed by
[Once](https://once.com) (37signals' single-container deploy tool) behind
its bundled TLS-terminating proxy, on any Linux box. The examples use
DigitalOcean; any VPS provider works the same way.

## What you need

- A [DigitalOcean](https://digitalocean.com) account (or any VPS provider)
- Docker on your laptop (Docker Desktop or Docker Engine) — `plum deploy`
  builds images locally
- The `plum` CLI
- Ruby and Rails — and if you don't have them, `plum new` offers to
  install both for you (via [mise](https://mise.jdx.dev))

## 1. Create the server

In DigitalOcean: **Create → Droplet**. Ubuntu LTS, the $6/month size is
enough to start (pick $12 for headroom). Add your SSH key if you have one
— if you don't, that's fine: `plum connect` will generate one and offer
to copy it over with the root password DigitalOcean emails you. Note the
droplet's IP.

That's the last time you touch a cloud dashboard.

## 2. Create the site

```bash
plum new client-site
cd client-site
bin/rails server
```

You have a running Plum site at `http://localhost:3000` — the control
panel is at `/cp`. Build the client's theme in `app/themes/`, model
their content types in the CP (or as YAML in `plum/` — see
`docs/config-as-code.md`), and load in their content.

## 3. Connect the server

```bash
plum connect 203.0.113.5      # your droplet's IP
```

The wizard handles the entire first-contact ritual: SSH keys, passwordless
login, detecting that this is a Once-shaped app, and — on a fresh droplet —
**installing Docker Engine and Once for you** (each with your
confirmation). When it asks for the app hostname, give it the client's
real domain (`clientname.com`): that's how the server routes requests and
provisions TLS.

## 4. Point DNS

At the client's DNS: an **A record** for their domain (and `www`) to the
droplet's IP. **This must happen before the first deploy** — Once
verifies `https://<domain>` end-to-end as the final step of a first
deploy and rolls back if the domain doesn't reach the server yet
(`plum deploy` checks this up front and warns you). Proxied DNS
(Cloudflare in Full strict mode) is fine.

Building ahead of a domain cutover? That's what previews are for:

```bash
plum deploy --preview
```

This ships the site as a *separate* Once app under a preview hostname —
by default `<app>.<server-ip>.sslip.io`, magic wildcard DNS that reaches
your server with zero configuration, so you have a shareable client
preview URL before any real DNS exists. For branded previews, point one
wildcard record (`*.preview.your-agency.com`) at the droplet and set
`preview_host: client.preview.your-agency.com` on the remote in
plum.yml. Iterate on the preview as long as you like; when the client
flips DNS, `plum deploy` (no flag) puts the same site live under the
real domain.

## 5. Deploy

```bash
plum deploy
```

Watch it go: the image builds on your laptop, streams to the server over
SSH (`docker save | docker load` — this is why no registry account
exists in this guide), Once starts it behind the proxy, and the CLI waits
for the container to report healthy. `https://clientname.com` is live.

Deploys are explicit — the site changes when you run `plum deploy`,
never by surprise. Ship again any time with the same command.

## 6. The agency rhythm

Day-to-day, the CLI is your relationship with every client site:

```bash
plum pull                # production content → your laptop, any DB engine
plum push                # content-model changes (plum/ YAML) → production
plum check               # did anyone drift the model? (CI-friendly)
plum logs --follow       # heroku-style tail, prettified
plum backup              # timestamped archive on the server
plum run -- TASK         # any rake task, any remote
```

Content pulls down, structure pushes up. Clients edit in `/cp` on
production; you develop locally against a full copy of their real
content. Turn on **static caching** (`docs/static-caching.md`) and the
site serves rendered pages from disk — SQLite happily runs a
production site on the smallest droplet, because cached reads never
touch the database at all.

## 7. The second client

This is where it becomes an agency:

```bash
plum new second-client
cd second-client
plum connect             # the host prompt offers your existing server
plum deploy
```

Once runs each site in its own container on the same box, routing by
hostname, each with its own TLS certificate. A $6–12 droplet comfortably
hosts several small client sites; each new client is marginal-cost-zero
until the box runs hot. Manage the fleet from anywhere:

```bash
plum projects list       # every site you run
plum use second-client   # switch the active project
plum pull --project client-site   # or target one explicitly
```

## 8. When you outgrow one box

- **More sites than one droplet likes**: create a second droplet,
  `plum connect` the new sites there. The registry doesn't care how many
  servers are behind it.
- **A client needs Postgres** (heavy dynamic features): switch that app's
  database and redeploy — `plum pull` still works across engines.
- **Backups off the box**: `plum backup` writes archives on the server;
  Once's auto-backup handles scheduling. Pull copies down with `plum pull`
  or scp them to storage you control.

## Costs, honestly

| Thing | Cost |
| --- | --- |
| Droplet (several small sites) | $6–12/mo |
| Domains | the client's problem |
| Registry, CI, PaaS, per-seat CMS pricing | $0 — none exist in this setup |

The whole model: you charge for design and content strategy; the
infrastructure is a rounding error.
