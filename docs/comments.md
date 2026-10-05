# Comments and discussions

Plum 0.3 adds optional discussions for CMS entries and application models. The feature is off by default. The new engine migration is required on every upgrade to 0.3.0, even if comments remain disabled:

```sh
bin/rails plum:install:migrations
bin/rails db:migrate
```

## Enable and connect authentication

```ruby
Plum.configure do |config|
  config.comments.enabled = true
  # A persisted, GlobalID-compatible account, authenticated by YOUR application.
  # Check email verification, suspension, membership, etc. here as appropriate.
  config.comments.commenter_resolver = ->(controller) {
    user = controller.current_reader
    user if user&.email_verified? && !user.suspended?
  }
  config.comments.author_name_resolver = ->(user) { user.display_name }
  config.comments.login_url_resolver = ->(controller) { controller.main_app.new_session_path }
  config.comments.subject_url_resolver = ->(controller, subject) {
    controller.main_app.lesson_path(subject.slug)
  }
end
```

Reader authentication is independent of `Plum.current_user` and never grants CMS access. By default there is no commenter, names display as “Reader,” no badge is added, and new comments require approval. The host must supply a verified account, a safe public display name, and any additional account/IP abuse protection. The built-in write limit is one comment per reader per discussion every ten seconds; it is not a global anti-spam service.

Enable comments on a content type in the control panel, or set `comments_enabled: true` on `Plum::ContentType`. Each entry has a `comments_mode`: `inherit`, `open`, `closed` (readable), or `disabled` (hidden). Unpublished/future entries are never publicly accessible through the built-in entry endpoint. Closing a discussion stops new comments and replies; reports remain possible.

For restricted content, configure **all** relevant actions. Read authorization is also required for creating and reporting. Moderator authorization deliberately can include unpublished content:

```ruby
config.comments.entry_authorizer = ->(controller, action, entry) {
  action == :moderate ? controller.can_moderate?(entry) : controller.can_read?(entry)
}
```

The callbacks receive `:read`, `:create`, `:report`, or `:moderate`. Enforce parent course visibility, enrollment, paid access, and group membership here: a published lesson alone does not prove access to its course. Site membership is independently checked on every request.

## Application models

```ruby
class Lesson < ApplicationRecord
  include Plum::Commentable
  belongs_to :site, class_name: "Plum::Site"

  # Override these methods when your schema differs:
  def plum_comment_site = site
  def plum_discussion_title = title
  def plum_comments_enabled? = published?
  def plum_comments_open? = published? && !archived?
end

Plum.configure do |config|
  config.comments.register :lessons,
    resolve: ->(controller, site, id) { Lesson.where(site: site).find(id) },
    authorize: ->(controller, action, lesson) { controller.allowed?(action, lesson) }
end
```

Registration is required. Request parameters never choose arbitrary model classes or resolve arbitrary GlobalIDs. Integer and UUID subject IDs are supported. Each subject has one discussion, with dependent cleanup when the subject is destroyed. Register a single stable handle per model; changing handles requires migrating existing discussion `subject_handle` values. `entries` is reserved for Plum entries.

## Rendering

By default, discussions render inside the active Plum theme's `layouts/base.liquid`, inheriting the same theme settings, custom CSS, fonts and colors. Override any of these files in your theme:

```
templates/comments/show.liquid
templates/comments/_comment.liquid
templates/comments/_form.liquid
templates/comments/_report.liquid
```

Liquid entry templates receive `entry.discussion_url` when comments are enabled for that entry. The bundled entry templates display a link automatically. Custom themes can use:

```liquid
{% if entry.discussion_url %}
  <a href="{{ entry.discussion_url }}">Questions &amp; discussion</a>
{% endif %}
```

This link is safe in static content; authorization and personalized forms are evaluated on the dynamic discussion page.

Normal parent-theme inheritance applies to each template independently, then falls back to the bundled default. You can change the page structure, form layout, empty state, sign-in prompt, wording and styling without changing the gem. The discussion controller still enforces authorization, CSRF, validation and moderation.

`discussion` includes `title`, `open`, `signed_in`, `back_url`, `login_url`, `previous_url`, `next_url`, `notices`, `stylesheet_url`, `comments`, `comments_html`, and `form_html`. Each approved comment includes `id`, `body`, `author_name`, `author_badge`, `date`, `created_at`, `parent_id`, `parent_author_name`, `pinned`, `video_seconds`, `video_time`, `reply_form_html`, and `report_form_html`. User-supplied text is **already HTML escaped** before entering Liquid: output it directly as `{{ comment.body }}`, without `escape` or decoding it. The HTML fragments are rendered from the theme's partials. No author account IDs, report details or unpublished comment bodies are exposed.

Custom forms must retain the hidden `authenticity_token` with `discussion.csrf_token`, `method="post"`, and the supplied `discussion.post_url` or `comment.report_url`. Field names are `comment[body]`, optional `comment[parent_id]`/`comment[video_seconds]`, and `report[reason]`. Form partials receive `form.id` and `form.parent_id`. Themes can style the stable `.plum-discussion`, `.plum-comment`, `.plum-comment-body`, `.plum-comment-form`, and `.plum-comment-report-form` classes. The baseline CSS inherits fonts/colors and exposes `--plum-comment-border`, `--plum-discussion-title-size`, `--plum-comment-button-background`, and `--plum-comment-button-color` variables. Override the page template to omit the baseline stylesheet entirely.

For an application such as Redeemer that renders its public site in Rails ERB, use `config.comments.renderer = :rails`. Override the engine's ERB views/layout in the host (see below) to reuse that application's design system.

In a dynamic host Rails view, include `Plum::CommentsHelper` in the host helper module, then:

```erb
<%= plum_comments_link(@entry) %>
<%= plum_comments_link(@lesson, handle: "lessons", label: "Ask a question") %>
```

Links open the engine's accessible discussion page, with forms, one level of replies, pagination, pinned comments and reporting. No JavaScript dependency is required. Replies to hidden/pending parents are hidden too. Bodies are plain text, escaped on output, and limited to 10,000 characters. Optional `comment[video_seconds]` stores a nonnegative integer timestamp (up to seven days); it does not synchronize YouTube comments.

Override `app/views/layouts/plum/discussion.html.erb` or `app/views/plum/discussions/{show,_comments,_form}.html.erb` in the host for full branding. The default layout loads `plum/comments.css`. Controller paths and route helpers are engine scoped; use `plum.discussion_path(handle: "entries", subject_id: entry.id)` from a host. The helper uses the mounted engine route proxy.

Do not put user-specific comment forms in Liquid/static page caches. Discussion responses use `private, no-store`; the default design links from cached content to a dynamic page. No comments are added to the public content API automatically.

## Moderation

The Comments control-panel queue supports pending/approved/hidden/reported views, approval, hiding/restoring, pinning, report resolution, and closing/reopening discussions. Comment moderation actions record actor GlobalID, action, previous status and timestamp. Discussion close/reopen changes are not part of that comment audit trail. A moderator must pass both normal CMS authorization and the separate comments moderator check. Entry/model authorization is applied to each record too.

Plum-managed editor/admin accounts can moderate by default. Host-authenticated applications **must explicitly configure** the moderator callback; generic CMS access alone is insufficient:

```ruby
config.comments.moderator_resolver = ->(controller, site) {
  controller.current_user.can_moderate_comments?(site)
}
```

`Plum.current_user` must return a persisted GlobalID-compatible moderator for the audit trail. Optional trusted-author settings:

```ruby
config.comments.auto_approve = ->(controller, author, subject) { author.trusted? }
config.comments.author_badge_resolver = ->(controller, author) { "Pastor" if author.pastor? }
```

Badges, authors and approval status are always assigned by server callbacks, never request parameters. Author name/badge are snapshots. Applications own policies for account deletion, pseudonyms, retention, and removal of historical display names. GlobalIDs are stored as references, not automatically dereferenced when rendering, so deleted accounts do not break threads.

## Notifications and backups

After commit, `comment.created.plum` and `comment.updated.plum` events carry `comment_id`, `discussion_id`, `site_id`, and `status`. Subscribe with `ActiveSupport::Notifications` and enqueue your own job or Noticed notification. Fetch the current record and re-check publication and recipient authorization before sending; never email pending/private comments to unauthorized readers. Subscribers should handle their own delivery failures and avoid synchronous mail delivery.

```ruby
ActiveSupport::Notifications.subscribe("comment.created.plum") do |*args|
  payload = args.last
  CommentModerationNotificationJob.perform_later(payload[:comment_id])
end
```

Comments, reports and audit records are application data: include the `plum_discussions`, `plum_comments`, `plum_comment_reports` and `plum_comment_moderations` tables in database backups. Site archive/config exports include comment settings, **not conversations or account identities**. Replacing/deleting a site's content deletes its discussions, so take a database backup before archive replacement. A site archive alone is not a backup of community data.
