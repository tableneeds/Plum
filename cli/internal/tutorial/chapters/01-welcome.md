# Welcome to Plum

Plum is a **Rails-native CMS engine**. It mounts inside any Rails app — as
the whole site, or embedded under a path in an app you already have — and
gives editors a fast Hotwire control panel while giving you, the developer,
something rarer: a CMS that behaves like the rest of your stack.

The idea that ties everything together is **content like code**:

- Your *content model* lives in YAML files in git (config as code)
- Your *content* moves between environments as portable archives
  (`plum pull` production → laptop, any database engine to any other)
- Drafts behave like branches, with a diff review before publishing
- Rendered pages can be served as static files — no database on the
  request path at all

This tutorial covers the engine's big ideas and the `plum` CLI that drives
them. It's a quick read — each chapter is a screenful or two.

## Navigating

- **←/→** (or `h`/`l`) — previous / next chapter
- **↑/↓** (or `j`/`k`) — scroll within a chapter
- **1–9** — jump straight to a chapter
- **d** — on CLI chapters: watch the command run
- **q** — quit

There's a short quiz at the end. Press **→** to begin.
