module Plum
  class CommentModeration < ApplicationRecord
    belongs_to :comment, class_name: "Plum::Comment"
    validates :moderator_gid, :previous_status, presence: true
    validates :action, inclusion: { in: %w[approve hide pin unpin resolve_reports] }
  end
end
