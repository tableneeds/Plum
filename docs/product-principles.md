# Product Principles

These principles guide product and architectural decisions in Plum.

## Rails Owns the Application

The host application has the final say. Plum should integrate with its users,
authorization, tenancy, models, jobs, mail, storage, routes, and deployment
instead of creating parallel systems.

## The First Useful Result Is Fast

Installation must lead to an editable, published page in less than ten minutes.
Defaults should be good enough to ship and understandable enough to replace.

## The Escape Hatches Are Ruby

When a project exceeds Plum's conventions, developers should extend it with
ordinary Ruby, Rails configuration, models, controllers, helpers, and views.
Plum should not require a proprietary plugin runtime.

## Editors Do Not Need to Know Rails

Developers define content structure and presentation. Editors should receive a
clear, forgiving interface with preview, validation, history, and recovery.

## Content Is Structured and Portable

Content should be reusable across templates and exportable with its schema and
assets. A site owner must be able to leave without scraping rendered HTML or
depending on a Plum service.

## One Stack Is a Feature

Plum should not require Node services, a remote CMS database, webhooks, API
tokens, or a separate frontend. Optional integrations may add capability, but
the complete product must work as a conventional Rails application.

## SQLite Is a First-Class Production Path

Small content sites should run reliably with SQLite and persistent storage.
Plum must also remain database-agnostic for embedded and higher-scale uses.

## Sites Are Operationally Independent

For agency work, one client site should be one portable application, container,
database, and backup unit. For SaaS products, site scoping should support many
tenants inside one host application. Plum should document both patterns rather
than forcing one onto the other.

## Deployment Tools Have Clear Boundaries

Plum creates and manages content applications. A Plum CLI may scaffold, inspect,
export, import, upgrade, and package them. ONCE, Kamal, and other deployment
tools operate the resulting containers and servers. Plum should integrate
cleanly without becoming an infrastructure orchestrator.

## Documentation Is Part of the Product

Every public capability needs an example and a clear contract. If a feature is
difficult to explain, its design is not finished.

## Dogfood Without Special Cases

The Plum marketing and documentation site must run on the public product. Any
general improvement it needs belongs in Plum; site-specific behavior belongs in
the site's application or theme.

## Prefer Coherence Over Feature Count

Plum should excel at the everyday path from modeling content to publishing a
site. Features that strengthen installation, authoring confidence, portability,
and Rails integration take priority over breadth for its own sake.
