# Zero to agency

Everything in this tour compounds into one story: **hosting client sites
with nothing but a cheap VPS and this CLI.** No GitHub, no container
registry, no CI, no PaaS bill.

```
plum new client-site        # a running site, locally, in one command
plum connect 203.0.113.5    # SSH keys, Docker, Once — installed for you
plum deploy                 # build locally, stream over SSH, live with TLS
```

Your laptop builds the image; SSH carries it; Once runs it behind a
TLS-terminating proxy. Deploys happen when you say so, never by surprise.

Then the rhythm you already know from this tour:

- `plum pull` — client's production content onto your laptop
- `plum push` / `plum check` — content-model changes, reviewed in git
- `plum logs --follow`, `plum backup` — the operational comforts

The second client is the fun part: `plum new`, `plum connect` (your
server is already in the pick-list), `plum deploy` — Once runs each site
in its own container on the same box, TLS per hostname. A $6–12 droplet
holds several small sites, and `plum projects list` is your whole
agency dashboard.

The full walkthrough — DigitalOcean specifics, DNS, scaling past one box,
honest costs — lives in `docs/zero-to-agency.md`.
