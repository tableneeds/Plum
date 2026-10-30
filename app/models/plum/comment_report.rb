module Plum
  class CommentReport < ApplicationRecord
    belongs_to :comment, class_name: "Plum::Comment"
    validates :reporter_gid, presence: true, uniqueness: { scope: :comment_id }
    validates :reason, presence: true, length: { maximum: 1_000 }
  end
end
