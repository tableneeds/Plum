# plumcms.org Information Architecture

The site serves three audiences: developers adding content to an existing Rails
application, developers building a content-first site, and agencies operating
multiple client sites.

## Primary Navigation

- Why Plum
- Use Cases
- Documentation
- Roadmap
- GitHub

The persistent primary action is **Get started**.

## Routes

```text
/
/why-plum
/features
/use-cases
  /existing-rails-apps
  /content-sites
  /agencies
/docs
  /getting-started
  /concepts
  /content-modeling
  /themes
  /embedding
  /deployment
  /reference
/roadmap
/changelog
/demo
```

## Homepage Story

The homepage should answer five questions in order:

1. What is Plum?
2. Why would a Rails developer use it instead of another CMS?
3. Can it work in my kind of project?
4. What does the code and editing experience look like?
5. Can I trust and try it?

## Documentation Structure

### Start

- Introduction
- Installation
- Your first editable page
- Build a small content site

### Core concepts

- Sites
- Content types and blueprints
- Entries and publishing
- Fields
- Liquid rendering

### Content features

- Blocks
- Rich text
- Assets and images
- Relationships
- Taxonomies
- Navigation
- Globals
- Forms

### Themes

- Theme anatomy
- Templates and layouts
- Theme manifests
- Settings
- Assets
- Blocks
- Packaging and installation

### Embed Plum

- Mounting the engine
- Host authentication
- Authorization
- Site resolution and tenancy
- Host content sources
- Routes and URLs
- White labelling

### Operate

- SQLite deployment
- PostgreSQL deployment
- Active Storage
- Jobs and email
- Docker and ONCE
- Backups and restore
- Upgrading

### Reference

- Configuration
- Blueprint field contracts
- Liquid objects and filters
- Theme manifest
- Generators
- Troubleshooting

## Content Types

### Pages

- Title
- Slug
- Summary
- Sections (`blocks`)
- SEO title
- SEO description

### Documentation pages

- Title
- Slug
- Section taxonomy
- Parent relationship
- Position
- Summary
- Body

### Releases

- Version
- Published date
- Summary
- Body

### Roadmap items

- Title
- Horizon (`now`, `next`, or `later`)
- Status
- Problem
- Intended outcome

## Initial Blocks

- Hero
- Prose
- Code example
- Feature grid
- Use-case cards
- Steps
- Comparison
- Quote
- Call to action

Blocks should be general enough to ship as examples or reusable base blocks.
Site-specific styling belongs in the plumcms.org theme.

## Proof the Site Must Provide

- The homepage is editable through Plum.
- Documentation is navigable and pleasant to read.
- A visitor can see real installation code immediately.
- The public roadmap distinguishes current capability from future intent.
- The application runs on Rails and SQLite in production.
- Its container, persistence, backup, and restore approach are documented.
- No private Plum features or site-specific engine patches are required.
