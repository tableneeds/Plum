module Plum
  class EntryRevision < ApplicationRecord
    include SiteScoped

    belongs_to :entry
    belongs_to :editor, class_name: "Plum::User", optional: true

    validates :snapshot, presence: true

    def editor_label
      editor_name.presence || editor_email.presence || editor&.email.presence || "Unknown editor"
    end
  end
end
