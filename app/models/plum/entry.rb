module Plum
  class Entry < ApplicationRecord
    include SiteScoped

    belongs_to :content_type
    belongs_to :author, class_name: "Plum::User", optional: true

    # The page served at "/" — Plum resolves the homepage by this slug
    # (convention over configuration). Its slug is locked and it can't be
    # deleted while published, so a non-technical editor can't orphan the home
    # page by renaming or removing it.
    HOMEPAGE_SLUG = "home".freeze

    enum :status, { draft: 0, published: 1, scheduled: 2 }

    validates :title, presence: true
    validates :slug, presence: true, uniqueness: { scope: :site_id }, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
    validates :status, presence: true
    validate :homepage_slug_is_unchanged

    before_validation :generate_slug
    before_validation :set_published_at, if: :published?
    before_destroy :prevent_homepage_destroy

    scope :live, -> { published.where("published_at <= ?", Time.current) }

    def field_value(handle)
      data&.dig(handle)
    end

    def homepage?
      slug == HOMEPAGE_SLUG
    end

    private

    def generate_slug
      self.slug = title&.parameterize if slug.blank?
    end

    def homepage_slug_is_unchanged
      return unless persisted? && slug_changed? && slug_was == HOMEPAGE_SLUG

      errors.add(:slug, "can't be changed — this is the homepage")
    end

    def prevent_homepage_destroy
      return unless homepage?

      errors.add(:base, "The homepage can't be deleted")
      throw :abort
    end

    def set_published_at
      self.published_at ||= Time.current
    end
  end
end
