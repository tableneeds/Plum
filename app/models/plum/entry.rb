module Plum
  class Entry < ApplicationRecord
    include SiteScoped

    belongs_to :content_type
    belongs_to :author, class_name: "Plum::User", optional: true

    enum :status, { draft: 0, published: 1, scheduled: 2 }

    validates :title, presence: true
    validates :slug, presence: true, uniqueness: { scope: :site_id }, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
    validates :status, presence: true

    before_validation :generate_slug
    before_validation :set_published_at, if: :published?

    scope :live, -> { published.where("published_at <= ?", Time.current) }

    def field_value(handle)
      data&.dig(handle)
    end

    private

    def generate_slug
      self.slug = title&.parameterize if slug.blank?
    end

    def set_published_at
      self.published_at ||= Time.current
    end
  end
end
