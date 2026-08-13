# Writing mode & drafts

Click **Write** on any entry and the CP gets out of your way: a
distraction-free, full-screen editor for long-form writing.

While you type, your work autosaves as a **working draft** — into the
entry's `draft_data`, never into the published version. The live site
keeps serving exactly what was published while you noodle on a rewrite
for a week.

Drafts behave like branches:

- The edit form shows your draft values, flagged as such
- A **diff view** shows draft vs. live as a word-level diff — green
  insertions, red deletions, like `git diff` for prose
- **Publish** applies the draft to the live entry (and records a
  revision); **Discard** throws it away

Revisions are kept on every publish, so there's a history to fall back
on. Draft saves are also invisible to the static cache — autosaving a
draft never flushes a cached page, because nothing public changed.
