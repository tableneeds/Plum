# Plum's Vision

Plum is the Rails-native CMS.

It gives Rails developers a default way to add managed content to an existing
application or build a complete content-first site without introducing another
application stack.

## Why Plum Exists

Rails is excellent at building applications, but content management is still
usually assembled from bespoke admin screens, delegated to a remote headless
CMS, or moved into a separate publishing platform. Each choice adds work or
pulls content away from the application that uses it.

Plum makes content a native part of Rails. It uses the application's database,
models, users, authorization, jobs, mail, storage, and deployment environment.
Developers keep the flexibility of Ruby and Rails. Editors get a focused,
polished place to manage content.

## Who Plum Is For

### Rails application teams

Mount Plum inside an existing application to manage marketing pages,
documentation, announcements, navigation, help content, and other editorial
material. Application records can be exposed safely alongside managed content
without copying them into an external CMS.

### Independent developers and agencies

Use Plum as the foundation of a complete client site. Start with Rails, SQLite,
a Plum theme, and one deployable container. Retain the ability to add ordinary
Rails features when the project grows beyond a brochure site.

### SaaS products

Give each account a site-scoped, white-labelled editing experience while the
host application continues to own identity, authorization, tenancy, and
business data.

## The Promise

A developer should be able to add Plum to a Rails application and publish an
editable page in less than ten minutes.

A small content site should be able to run as one Rails application with SQLite
and persistent storage. An agency should be able to operate several independent
Plum sites on one VM as portable containers. A larger application should be
able to use PostgreSQL and embed Plum without changing its content model.

Content must remain portable. Plum should never require a hosted Plum account,
a proprietary runtime, or a second frontend application.

## What Makes Plum Different

- It is Rails infrastructure, not a remote content service.
- It works both as a mountable engine and as the center of a standalone site.
- It lets editorial content and host application data participate in the same
  rendering context.
- It follows the Rails approach: strong conventions, ordinary Ruby extension
  points, and ownership of the complete application.
- It supports a low-operations SQLite path without limiting applications that
  need PostgreSQL.
- It treats themes, content, assets, backups, and deployments as portable parts
  of a site rather than features of a vendor account.

## The Long-Term Goal

When a Rails developer asks, "How do I let someone edit this content?", Plum
should be the obvious answer.

Plum succeeds when it becomes normal to:

- mount Plum in a Rails product;
- start a client content site with Plum;
- publish and share Plum themes and blocks;
- run a collection of independent Plum sites economically; and
- extend content workflows with familiar Rails code.

The goal is not to reproduce every feature of every CMS. The goal is to make
content management feel like it has always belonged in Rails.
