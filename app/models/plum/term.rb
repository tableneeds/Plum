module Plum
  class Term < ApplicationRecord
    include SiteScoped
    include StaticCacheInvalidation

    belongs_to :taxonomy

    has_many :entry_terms, dependent: :destroy
    has_many :entries, through: :entry_terms

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: { scope: :taxonomy_id }, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }

    before_validation :generate_slug

    scope :ordered, -> { order(:position, :name) }

    private

    def generate_slug
      self.slug = name&.parameterize if slug.blank?
    end
  end
end
