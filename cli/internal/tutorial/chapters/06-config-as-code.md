# Config as code

Your content model belongs in git. Plum serializes it to YAML:

```
plum/
  content_types/
    posts.yml      # name, handle, field blueprint
    pages.yml
  fieldsets/
    seo.yml
```

Three rake tasks (which the CLI wraps — next chapters) move structure
between files and database:

- `plum:config:export` — write the database's current model to files
- `plum:config:sync` — apply the files to the database (create missing
  types, update changed blueprints; deletes only with `PRUNE=1`, and
  types that still have entries also need `FORCE=1`)
- `plum:config:check` — report drift, exit nonzero if files and database
  disagree — made for CI

The workflow: change a blueprint in YAML, review it in a pull request
like any other code, then push it to the server. Content model changes
get code review; entry *data* is never touched by any of this.

Full guide: `docs/config-as-code.md`.
