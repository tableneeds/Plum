module Plum
  class Discussion < ApplicationRecord
    belongs_to :site, class_name: "Plum::Site"
    belongs_to :commentable, polymorphic: true
    has_many :comments, class_name: "Plum::Comment", dependent: :destroy
    validates :subject_handle, presence: true
    validate :subject_belongs_to_site

    private

    def subject_belongs_to_site
      unless commentable.is_a?(Plum::Commentable) && commentable.plum_comment_site == site
        errors.add(:commentable, "must belong to this site and include Plum::Commentable")
      end
    end
  end
end
