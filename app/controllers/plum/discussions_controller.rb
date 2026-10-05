module Plum
  class DiscussionsController < Plum::ApplicationController
    protect_from_forgery with: :exception
    layout "plum/discussion"
    helper Plum::CommentsHelper
    before_action :load_context
    rescue_from Comments::RateLimited, with: -> { render plain: "Please wait a few seconds before posting again.", status: :too_many_requests }
    rescue_from ActiveRecord::RecordInvalid, with: ->(error) { render plain: error.record.errors.full_messages.to_sentence, status: :unprocessable_entity }

    def show
      @comments = @context.discussion&.comments&.publicly_visible&.includes(:parent)&.order(pinned: :desc, id: :asc)&.limit(50)&.offset((page - 1) * 50) || []
      if @context.config.renderer == :theme
        html = Comments::ThemeRenderer.new(controller: self, context: @context, comments: @comments, page: page).render
        render html: html.html_safe, layout: false
      end
    end

    def create
      return head :unauthorized unless @context.author_gid
      return head :forbidden unless @context.open?
      @context.create_comment!(params.require(:comment).permit(:body, :parent_id, :video_seconds).to_h.symbolize_keys)
      redirect_to discussion_path(handle: @context.handle, subject_id: @context.subject.id), notice: "Thank you. Your comment has been received.", status: :see_other
    end

    def report
      return head :unauthorized unless @context.author_gid
      comment = @context.discussion&.comments&.publicly_visible&.find(params[:id])
      raise ActiveRecord::RecordNotFound unless comment
      report = comment.reports.find_or_initialize_by(reporter_gid: @context.author_gid)
      report.update!(reason: params.require(:report).permit(:reason)[:reason]) unless report.persisted?
      redirect_to discussion_path(handle: @context.handle, subject_id: @context.subject.id), notice: "Your report has been sent to the moderators.", status: :see_other
    end

    private

    def load_context
      response.headers["Cache-Control"] = "private, no-store"
      @context = Comments::Context.new(self, handle: params[:handle], id: params[:subject_id], action: action_name == "create" ? :create : (action_name == "report" ? :report : :read))
    end

    def page
      @page ||= params[:page].to_i.clamp(1, 10_000)
    end
    helper_method :page
  end
end
