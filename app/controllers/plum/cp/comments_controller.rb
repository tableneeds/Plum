module Plum
  module Cp
    class CommentsController < BaseController
      before_action :require_comment_moderator

      def index
        @status = params[:status].presence_in(%w[pending approved hidden reported]) || "pending"
        scope = Comment.joins(:discussion).where(plum_discussions: { site_id: current_site.id })
        scope = @status == "reported" ? scope.where(id: CommentReport.where(resolved_at: nil).select(:comment_id)) : scope.where(status: @status)
        @comments = scope.includes(:reports, :discussion).order(created_at: :desc).limit(50).offset((params[:page].to_i.clamp(1, 10_000) - 1) * 50).select { |comment| accessible?(comment.discussion) }
      end

      def update
        comment = Comment.joins(:discussion).where(plum_discussions: { site_id: current_site.id }).find(params[:id])
        raise ActiveRecord::RecordNotFound unless accessible?(comment.discussion)
        action = params[:operation].to_s
        return head :unprocessable_entity unless %w[approve hide pin unpin resolve_reports].include?(action)
        return head :unprocessable_entity if action == "pin" && comment.parent_id.present?
        comment.with_lock do
          previous = comment.status
          case action
          when "approve" then comment.update!(status: "approved")
          when "hide" then comment.update!(status: "hidden", pinned: false)
          when "pin" then comment.update!(pinned: true)
          when "unpin" then comment.update!(pinned: false)
          when "resolve_reports" then comment.reports.where(resolved_at: nil).update_all(resolved_at: Time.current)
          end
          comment.moderations.create!(moderator_gid: Comments::Context.identity(Plum.current_user(self)), action: action, previous_status: previous)
        end
        redirect_to cp_comments_path, notice: "Comment updated", status: :see_other
      end

      def close
        discussion = current_site.discussions.find(params[:id])
        raise ActiveRecord::RecordNotFound unless accessible?(discussion)
        return head :unprocessable_entity unless [ true, false, "true", "false", "1", "0" ].include?(params[:closed])
        discussion.with_lock { discussion.update!(closed: ActiveModel::Type::Boolean.new.cast(params[:closed])) }
        redirect_to cp_comments_path, notice: "Discussion updated", status: :see_other
      end

      private

      def require_comment_moderator
        response.headers["Cache-Control"] = "private, no-store"
        head :forbidden unless Plum.configuration.comments.enabled && Plum.configuration.comments.moderator_resolver.call(self, current_site) && Comments::Context.identity(Plum.current_user(self))
      end

      def accessible?(discussion)
        Comments::Context.new(self, handle: discussion.subject_handle, id: discussion.commentable_id, action: :moderate).subject == discussion.commentable
      rescue ActiveRecord::RecordNotFound
        false
      end
    end
  end
end
