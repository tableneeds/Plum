module Plum
  module Comments
    class ThemeRenderer
      def initialize(controller:, context:, comments:, page:)
        @controller, @context, @comments, @page = controller, context, comments.to_a, page
      end

      def render
        data = LiquidContext.new(controller: controller, site: context.site).layout_context
        discussion = {
          "title" => h(context.subject.plum_discussion_title),
          "open" => context.open?, "signed_in" => context.author_gid.present?,
          "back_url" => h(context.config.subject_url_resolver.call(controller, context.subject)),
          "login_url" => h(context.config.login_url_resolver.call(controller)),
          "post_url" => h(controller.discussion_comments_path(handle: context.handle, subject_id: context.subject.id)),
          "csrf_token" => h(controller.send(:form_authenticity_token)),
          "stylesheet_url" => h(controller.view_context.asset_path("plum/comments.css")),
          "previous_url" => page > 1 ? h(url(page - 1)) : nil,
          "next_url" => comments.size == 50 ? h(url(page + 1)) : nil,
          "notices" => controller.flash.map { |_key, value| h(value) }
        }
        data["discussion"] = discussion
        # Only approved, authorized records reach this renderer. No account IDs,
        # report reasons, audit records or pending bodies enter the Liquid context.
        discussion["comments"] = comments.map { |comment| comment_data(comment) }
        discussion["form_html"] = form(data, nil)
        discussion["comments_html"] = discussion["comments"].map do |comment|
          locals = data.merge("comment" => comment)
          comment["reply_form_html"] = form(data, comment["id"]) if discussion["signed_in"] && discussion["open"] && !comment["parent_id"]
          comment["report_form_html"] = LiquidRenderer.render_partial("comments/_report", locals) if discussion["signed_in"]
          LiquidRenderer.render_partial("comments/_comment", locals)
        end.join
        LiquidRenderer.render_template("comments/show", data)
      end

      private

      attr_reader :controller, :context, :comments, :page

      def h(value)
        ERB::Util.html_escape(value.to_s)
      end

      def url(number)
        controller.discussion_path(handle: context.handle, subject_id: context.subject.id, page: number)
      end

      def form(data, parent_id)
        return "" unless data["discussion"]["signed_in"] && data["discussion"]["open"]
        LiquidRenderer.render_partial("comments/_form", data.merge("form" => { "parent_id" => parent_id, "id" => parent_id || "new" }))
      end

      def comment_data(comment)
        {
          "id" => comment.id, "body" => h(comment.body), "author_name" => h(comment.author_name),
          "author_badge" => h(comment.author_badge), "pinned" => comment.pinned?,
          "parent_id" => comment.parent_id, "parent_author_name" => h(comment.parent&.author_name),
          "created_at" => comment.created_at.iso8601, "date" => h(comment.created_at.to_date.to_fs(:long)),
          "video_seconds" => comment.video_seconds,
          "video_time" => comment.video_seconds && "#{comment.video_seconds / 60}:#{format('%02d', comment.video_seconds % 60)}",
          "report_url" => h(controller.report_discussion_comment_path(handle: context.handle, subject_id: context.subject.id, id: comment.id))
        }
      end
    end
  end
end
