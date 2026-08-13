# Sites, content types, entries

Everything in Plum is scoped to a **site**. Standalone installs have one;
embedded installs (a SaaS giving each customer a website) have many, and a
resolver in the initializer decides which site a request belongs to.

Inside a site:

- **Content types** define the shape of your content — a *blueprint* of
  fields (text, rich text, images, dates, references, and so on). A
  "Posts" type, a "Pages" type, a "Team members" type.
- **Entries** are the content itself: one entry per post, page, or team
  member, holding data that matches its type's blueprint.
- **Fieldsets** are reusable groups of fields you can mix into multiple
  blueprints.
- **Taxonomies & terms** classify entries (categories, tags).
- **Globals** hold site-wide values (footer text, social links).
- **Nav menus** are editor-manageable navigation trees that can point at
  entries or arbitrary URLs.

Editors work with all of this in the control panel at **`/cp`** — a fast,
Hotwire-driven UI you can white-label from the initializer (name, logo,
colors).

The homepage is the entry with the slug `home` — by convention, and the
CP protects it: its slug is locked and it can't be deleted out from under
the site.
