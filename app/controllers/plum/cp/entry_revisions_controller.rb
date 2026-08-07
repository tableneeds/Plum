module Plum
  module Cp
    class EntryRevisionsController < BaseController
      before_action :require_editor
      before_action :set_entry

      def index
        @revisions = @entry.revisions.order(created_at: :desc)
      end

      def restore
        revision = @entry.revisions.find(params[:id])
        @entry.restore_revision!(revision, editor: current_user)
        redirect_to edit_cp_content_type_entry_path(@content_type, @entry), notice: "Revision restored"
      rescue ActiveRecord::RecordInvalid => error
        redirect_to cp_content_type_entry_revisions_path(@content_type, @entry), alert: "Could not restore revision: #{error.record.errors.full_messages.to_sentence}"
      end

      private

      def set_entry
        @content_type = current_site.content_types.find(params[:content_type_id])
        @entry = @content_type.entries.find(params[:entry_id])
      end
    end
  end
end
