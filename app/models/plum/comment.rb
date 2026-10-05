module Plum
  class Comment < ApplicationRecord
    belongs_to :discussion, class_name: "Plum::Discussion"
    belongs_to :parent, class_name: "Plum::Comment", optional: true
    has_many :replies, class_name: "Plum::Comment", foreign_key: :parent_id, dependent: :destroy
    has_many :reports, class_name: "Plum::CommentReport", dependent: :destroy
    has_many :moderations, class_name: "Plum::CommentModeration", dependent: :destroy

    validates :body, presence: true, length: { maximum: 10_000 }
    validates :author_gid, presence: true, length: { maximum: 255 }
    validates :author_name, presence: true, length: { maximum: 100 }
    validates :author_badge, length: { maximum: 60 }, allow_nil: true
    validates :status, inclusion: { in: %w[pending approved hidden] }
    validates :video_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 604_800 }, allow_nil: true
    validate :valid_parent

    scope :approved, -> { where(status: "approved") }
    scope :publicly_visible, -> { approved.where(parent_id: nil).or(approved.where(parent_id: approved.where(parent_id: nil).select(:id))) }

    after_create_commit { publish_event("created") }
    after_update_commit { publish_event("updated") }

    def publish_event(event)
      ActiveSupport::Notifications.instrument("comment.#{event}.plum", comment_id: id, discussion_id: discussion_id, site_id: discussion.site_id, status: status)
    end

    def approved?
      status == "approved"
    end

    private

    def valid_parent
      return if parent_id.nil?
      unless parent && parent.discussion_id == discussion_id && parent.parent_id.nil? && parent.id != id
        errors.add(:parent, "must be a top-level comment in this discussion")
      end
    end
  end
end
