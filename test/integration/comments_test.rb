require "test_helper"
require "tmpdir"

class CommentHostLesson < ActiveRecord::Base
  self.table_name = "comment_host_lessons"
  include Plum::Commentable
  belongs_to :site, class_name: "Plum::Site"
end

class CommentsTest < ActionDispatch::IntegrationTest
  setup do
    @old_config = Plum.configuration
    Plum.instance_variable_set(:@configuration, Plum::Configuration.new)
    @config = Plum.configuration.comments
    @config.enabled = true
    @site = Plum::Site.create!(name: "Comments", skip_defaults: true)
    @type = @site.content_types.create!(name: "Lessons", handle: "lessons", comments_enabled: true, blueprint: { "fields" => [] })
    @entry = @type.entries.create!(site: @site, title: "Grace", slug: "grace", status: :published, published_at: 1.day.ago)
    @reader = Plum::User.create!(email: "reader@example.com", password: "password123", role: :viewer)
    Plum.configuration.current_site_resolver = ->(_) { @site }
    @config.author_name_resolver = ->(_) { "A reader" }
  end

  teardown do
    Plum.instance_variable_set(:@configuration, @old_config)
  end

  def url(entry = @entry)
    discussion_path(handle: "entries", subject_id: entry.id)
  end

  def post_comment(body = "A question", **extras)
    post discussion_comments_path(handle: "entries", subject_id: @entry.id), params: { comment: { body: body }.merge(extras) }
  end

  def sign_in_reader
    @config.commenter_resolver = ->(_) { @reader }
  end

  def thread
    @thread ||= @site.discussions.find_by(commentable: @entry) || @site.discussions.create!(commentable: @entry, subject_handle: "entries")
  end

  def comment(status: "approved", **attributes)
    thread.comments.create!({ body: "Thoughtful reply", author_gid: @reader.to_global_id.to_s, author_name: "Reader", status: status }.merge(attributes))
  end

  def moderator
    @admin = Plum::User.create!(email: "admin@example.com", password: "password123", role: :admin)
    Plum.configuration.current_user_resolver = ->(_) { @admin }
  end

  test "disabled by default and GET never creates a discussion" do
    assert_not Plum::Comments::Configuration.new.enabled
    assert_no_difference "Plum::Discussion.count" do
      get url
      assert_response :success
    end
    assert_includes response.headers["Cache-Control"], "no-store"
    @config.enabled = false
    get url
    assert_response :not_found
  end

  test "anonymous and reader accounts cannot enter CMS or moderate" do
    post_comment
    assert_response :unauthorized
    sign_in_reader
    get cp_comments_path
    assert_response :redirect
    post_comment
    assert_response :see_other
    assert_equal "pending", Plum::Comment.last.status
    assert_equal @reader.to_global_id.to_s, Plum::Comment.last.author_gid
    get url
    refute_includes response.body, "A question"
  end

  test "client cannot impersonate authors approve itself or bypass throttling" do
    sign_in_reader
    post_comment("First", status: "approved", author_name: "Pastor", author_badge: "Pastor", author_gid: "fake")
    assert_response :see_other
    saved = Plum::Comment.last
    assert_equal "pending", saved.status
    assert_equal "A reader", saved.author_name
    assert_nil saved.author_badge
    assert_no_difference "Plum::Comment.count" do
      post_comment("Second")
      assert_response :too_many_requests
    end
  end

  test "draft scheduled future disabled and other site entries remain inaccessible" do
    @entry.update!(status: :draft)
    get url
    assert_response :not_found
    @entry.update!(status: :published, published_at: 1.day.from_now)
    get url
    assert_response :not_found
    @entry.update!(published_at: 1.day.ago, comments_mode: "disabled")
    get url
    assert_response :not_found
    @entry.update!(comments_mode: "open")
    other = Plum::Site.create!(name: "Other", skip_defaults: true)
    Plum.configuration.current_site_resolver = ->(_) { other }
    sign_in_reader
    get url
    assert_response :not_found
    post_comment
    assert_response :not_found
  end

  test "entry policy also protects posts reports and private lessons" do
    saved = comment
    sign_in_reader
    @config.entry_authorizer = ->(_, _, _) { false }
    get url
    assert_response :not_found
    post_comment
    assert_response :not_found
    post report_discussion_comment_path(handle: "entries", subject_id: @entry.id, id: saved.id), params: { report: { reason: "Concern" } }
    assert_response :not_found
  end

  test "comments are escaped hidden parents hide their replies and nesting is limited" do
    root = comment(body: "<script>alert(1)</script>")
    reply = comment(body: "Visible reply", parent: root)
    invalid = thread.comments.build(body: "Nested", author_gid: "test", author_name: "Reader", parent: reply)
    assert_not invalid.valid?
    get url
    assert_response :success
    assert_includes response.body, "&lt;script&gt;"
    refute_includes response.body, "<script>alert"
    assert_includes response.body, "Visible reply"
    root.update!(status: "hidden")
    get url
    refute_includes response.body, "Visible reply"
  end

  test "closed discussions preserve reading but reject writes" do
    comment(body: "Still visible")
    thread.update!(closed: true)
    sign_in_reader
    get url
    assert_response :success
    assert_includes response.body, "Still visible"
    post_comment
    assert_response :forbidden
  end

  test "moderation requires an explicit host permission and records an audit" do
    saved = comment(status: "pending")
    moderator
    Plum.configuration.authorize_with = :host
    Plum.configuration.host_authorization_resolver = ->(_) { true }
    get cp_comments_path
    assert_response :forbidden
    @config.moderator_resolver = ->(_, _) { true }
    get cp_comments_path
    assert_response :success
    patch cp_comment_path(saved), params: { operation: "approve" }
    assert_response :see_other
    assert saved.reload.approved?
    assert_equal "pending", saved.moderations.last.previous_status
    assert_equal @admin.to_global_id.to_s, saved.moderations.last.moderator_gid
    patch cp_close_discussion_path(thread), params: { closed: true }
    assert thread.reload.closed?
  end

  test "reports are private unique and resolvable" do
    saved = comment
    sign_in_reader
    report_url = report_discussion_comment_path(handle: "entries", subject_id: @entry.id, id: saved.id)
    2.times { post report_url, params: { report: { reason: "Private concern" } }; assert_response :see_other }
    assert_equal 1, saved.reports.count
    get url
    refute_includes response.body, "Private concern"
    moderator
    get cp_comments_path(status: "reported")
    assert_includes response.body, "Private concern"
    patch cp_comment_path(saved), params: { operation: "resolve_reports" }
    assert saved.reports.first.reload.resolved_at
  end

  test "unregistered types and cross-discussion replies are rejected" do
    get discussion_path(handle: "Plum::User", subject_id: @reader.id)
    assert_response :not_found
    other_entry = @type.entries.create!(site: @site, title: "Hope", slug: "hope", status: :published, published_at: 1.day.ago)
    other_thread = @site.discussions.create!(commentable: other_entry, subject_handle: "entries")
    foreign = other_thread.comments.create!(body: "Other", status: "approved", author_gid: "test", author_name: "Reader")
    sign_in_reader
    post_comment("Reply", parent_id: foreign.id)
    assert_response :not_found
  end

  test "registered models use a scoped resolver and explicit authorization" do
    @config.register("lessons", resolve: ->(_, site, id) { site.entries.find(id) }, authorize: ->(_, action, _) { action == :read })
    get discussion_path(handle: "lessons", subject_id: @entry.id)
    assert_response :success
    sign_in_reader
    post discussion_comments_path(handle: "lessons", subject_id: @entry.id), params: { comment: { body: "Blocked" } }
    assert_response :not_found
  end

  test "host models with UUID primary keys work without inheriting Plum entry" do
    connection = ActiveRecord::Base.connection
    connection.create_table(:comment_host_lessons, id: :string, if_not_exists: true) do |table|
      table.bigint :site_id
      table.string :title
    end
    CommentHostLesson.reset_column_information
    lesson = CommentHostLesson.create!(id: SecureRandom.uuid, site: @site, title: "Host lesson")
    @config.register(:host_lessons,
      resolve: ->(_, site, id) { CommentHostLesson.where(site: site).find(id) },
      authorize: ->(_, _, _) { true })
    sign_in_reader
    @config.auto_approve = ->(_, _, _) { true }
    post discussion_comments_path(handle: "host_lessons", subject_id: lesson.id), params: { comment: { body: "A host-model comment", video_seconds: 123 } }
    assert_response :see_other
    get discussion_path(handle: "host_lessons", subject_id: lesson.id)
    assert_response :success
    assert_includes response.body, "A host-model comment"
    assert_includes response.body, "2:03"
    assert_equal lesson, Plum::Comment.last.discussion.commentable
    lesson.destroy!
    assert_equal 0, Plum::Discussion.where(commentable_type: "CommentHostLesson").count
  end

  test "creation requires read permission even if create permission allows it" do
    sign_in_reader
    @config.entry_authorizer = ->(_, action, _) { action == :create }
    assert_no_difference "Plum::Comment.count" do
      post_comment
      assert_response :not_found
    end
  end

  test "moderators cannot inspect another site or an explicitly restricted subject" do
    saved = comment
    moderator
    @config.entry_authorizer = ->(_, action, _) { action != :moderate }
    get cp_comments_path(status: "approved")
    assert_response :success
    refute_includes response.body, "Thoughtful reply"
    patch cp_comment_path(saved), params: { operation: "hide" }
    assert_response :not_found
    Plum.configuration.current_site_resolver = ->(_) { Plum::Site.create!(name: "Other", skip_defaults: true) }
    patch cp_comment_path(saved), params: { operation: "hide" }
    assert_response :not_found
    assert saved.reload.approved?
  end

  test "invalid bodies and timestamps cannot create comments" do
    sign_in_reader
    [ { body: "" }, { body: "a" * 10001 }, { body: "Question", video_seconds: -1 } ].each do |attributes|
      post discussion_comments_path(handle: "entries", subject_id: @entry.id), params: { comment: attributes }
      assert_response :unprocessable_entity
    end
    assert_equal 0, Plum::Comment.count
  end

  test "comment posts require a valid CSRF token" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    sign_in_reader
    assert_no_difference "Plum::Comment.count" do
      post_comment
      assert_response :unprocessable_entity
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "editors can manage discussion settings and entry overrides win" do
    moderator
    get edit_cp_content_type_path(@type)
    assert_response :success
    assert_select "input[name='content_type[comments_enabled]']"
    get edit_cp_content_type_entry_path(@type, @entry)
    assert_response :success
    assert_select "select[name='entry[comments_mode]']"
    @type.update!(comments_enabled: false)
    assert_not @entry.reload.plum_comments_enabled?
    @entry.update!(comments_mode: "open")
    assert @entry.plum_comments_open?
    @entry.update!(comments_mode: "closed")
    assert @entry.plum_comments_enabled?
    assert_not @entry.plum_comments_open?
    @entry.update!(comments_mode: "disabled")
    assert_not @entry.plum_comments_enabled?
  end

  test "Liquid themes inherit layout and individually override comment and form partials" do
    Dir.mktmpdir("plum-discussion-theme") do |directory|
      parent = Pathname(directory).join("discussion_parent")
      child = Pathname(directory).join("discussion_child")
      FileUtils.mkdir_p(parent.join("layouts"))
      FileUtils.mkdir_p(parent.join("templates/comments"))
      FileUtils.mkdir_p(child.join("templates/comments"))
      parent.join("theme.yml").write("name: Discussion parent\nhandle: discussion_parent\nextends: default\n")
      child.join("theme.yml").write("name: Discussion child\nhandle: discussion_child\nextends: discussion_parent\n")
      parent.join("layouts/base.liquid").write("<main data-parent-layout>Theme layout {{ content }}</main>")
      parent.join("templates/comments/_comment.liquid").write('<aside class="theme-comment">{{ comment.author_name }}: {{ comment.body }} {{ comment.author_gid }} {{ comment.reports }}</aside>')
      child.join("templates/comments/_form.liquid").write('<form class="theme-form" method="post" action="{{ discussion.post_url }}"><input type="hidden" name="authenticity_token" value="{{ discussion.csrf_token }}"><label for="theme-body">Ask the pastor</label><textarea id="theme-body" name="comment[body]"></textarea><button>Ask</button></form>')
      Plum.configuration.theme_paths = [ Pathname(directory), *Plum.configuration.theme_paths ]
      Plum::SiteSetting.instance(@site).update!(theme_name: "discussion_child")
      comment(body: "<script>unsafe()</script>", author_name: "<img src=x onerror=unsafe()>")
      comment(status: "pending", body: "PRIVATE PENDING BODY")
      sign_in_reader
      get url
      assert_response :success
      assert_select "main[data-parent-layout]"
      assert_select ".theme-comment", count: 1
      assert_select ".theme-form textarea[name='comment[body]']"
      assert_select ".theme-form input[name='authenticity_token']"
      assert_includes response.body, "&lt;script&gt;"
      assert_includes response.body, "&lt;img"
      refute_includes response.body, "PRIVATE PENDING BODY"
      refute_includes response.body, @reader.to_global_id.to_s
      assert_includes response.headers["Cache-Control"], "no-store"
    end
  end

  test "theme forms contain a working CSRF token and Rails renderer remains available" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    sign_in_reader
    get url
    token = css_select('.plum-comment-form input[name="authenticity_token"]').first["value"]
    post discussion_comments_path(handle: "entries", subject_id: @entry.id), params: { authenticity_token: token, comment: { body: "Token-protected question" } }
    assert_response :see_other
    @config.renderer = :rails
    get url
    assert_response :success
    assert_select "textarea[name='comment[body]']"
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "after commit notification hook exposes identifiers rather than private bodies" do
    payloads = []
    subscriber = ->(*args) { payloads << args.last }
    sign_in_reader
    ActiveSupport::Notifications.subscribed(subscriber, "comment.created.plum") { post_comment("Private question") }
    assert_equal 1, payloads.size
    assert_equal @site.id, payloads.first[:site_id]
    assert_equal "pending", payloads.first[:status]
    assert_equal Plum::Comment.last.id, payloads.first[:comment_id]
    refute payloads.first.key?(:body)
  end

  test "close requires an explicit boolean and replies cannot be pinned" do
    saved = comment
    reply = comment(parent: saved)
    moderator
    patch cp_close_discussion_path(thread)
    assert_response :unprocessable_entity
    assert_not thread.reload.closed?
    patch cp_comment_path(reply), params: { operation: "pin" }
    assert_response :unprocessable_entity
    assert_not reply.reload.pinned?
  end

  test "published Liquid entry pages link to their optional discussion" do
    get "/#{@entry.slug}"
    assert_response :success
    assert_select "a[href='#{url}']", text: "Questions & discussion →"
    @type.update!(comments_enabled: false)
    get "/#{@entry.slug}"
    assert_response :success
    assert_select ".plum-discussion-link", count: 0
  end

  test "theme reply and report forms retain scoped targets and parent identity" do
    saved = comment(created_at: 1.minute.ago)
    sign_in_reader
    get url
    assert_select "#comment-#{saved.id} form input[name='comment[parent_id]'][value='#{saved.id}']"
    assert_select "#comment-#{saved.id} form textarea[name='report[reason]']"
    post_comment("A reply from the theme", parent_id: saved.id)
    assert_response :see_other
    assert_equal saved.id, Plum::Comment.last.parent_id
    assert_equal "pending", Plum::Comment.last.status
  end

  test "renderer configuration accepts strings and rejects unknown renderers" do
    @config.renderer = "rails"
    assert_equal :rails, @config.renderer
    assert_raises(ArgumentError) { @config.renderer = :unknown }
  end

  test "deleting a subject cleans replies reports audits and its discussion" do
    root = comment
    comment(parent: root)
    root.reports.create!(reporter_gid: "reader", reason: "Concern")
    root.moderations.create!(moderator_gid: "admin", action: "approve", previous_status: "pending")
    @entry.destroy!
    assert_equal 0, Plum::Discussion.where(commentable_id: @entry.id).count
    assert_equal 0, Plum::Comment.count
    assert_equal 0, Plum::CommentReport.count
    assert_equal 0, Plum::CommentModeration.count
  end
end
