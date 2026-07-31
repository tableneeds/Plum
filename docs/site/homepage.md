# Homepage Copy

## Hero

### Plum

**The Rails-native CMS.**

Add managed content to an existing Rails application or build a complete
content-first site—without leaving the Rails stack.

Primary action: **Get started**

Secondary action: **View on GitHub**

Supporting note: Open source. Self-hosted. SQLite and PostgreSQL.

## One Stack, Complete Control

Plum uses the Rails application you already understand: its database, users,
authorization, jobs, mail, storage, and deployment. There is no external CMS to
synchronize and no second frontend to maintain.

```ruby
gem "plum"
```

```bash
bin/rails generate plum:install --mount-path=/website
bin/rails db:migrate
```

## Two Ways to Use Plum

### Add content to your application

Mount Plum in an existing Rails product. Let customers or editors manage pages,
navigation, documentation, announcements, and structured content while the host
application continues to own identity and business data.

Action: **Embed Plum**

### Build the whole site with Plum

Start with Rails, SQLite, and a Plum theme. Ship a fast, portable content site
that can grow into a custom Rails application whenever the project demands it.

Action: **Build a Plum site**

## Application Data Meets Editorial Content

Expose host application data safely to Plum templates without copying it into a
remote CMS.

```ruby
Plum.configure do |config|
  config.current_site_resolver = ->(_) { Current.account.plum_site }
  config.current_user_resolver = ->(_) { Current.user }

  config.register_content_source :products do |context|
    context.owner.products.published
  end
end
```

Editors manage the story. Rails remains the source of truth for the application.

## Familiar Rails Foundations

- Rails 8 engine
- Hotwire control panel
- Active Record content
- Active Storage assets
- Active Job notifications
- Liquid themes
- SQLite and PostgreSQL
- Host-owned authentication and authorization

## For Independent Developers and Agencies

Package each client site as an independent Rails application with its own
SQLite database, assets, domain, and backup. Run several sites economically on
one VM with an ONCE-compatible container, and move any client without untangling
a shared CMS installation.

Action: **See the agency model**

## Built in Public, Used for Real

This website is a Rails application powered by Plum and SQLite. The same public
engine, theme system, and deployment path are available to every Plum project.

Action: **How this site works**

## Closing Call to Action

### Keep content in Rails.

Give editors the tools they need without giving up the application stack you
want.

Primary action: **Read the getting-started guide**

Secondary action: **Explore the roadmap**
