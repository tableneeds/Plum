module Plum
  class Taxonomy < ApplicationRecord
    include SiteScoped

    has_many :terms, dependent: :destroy

    validates :name, presence: true
    validates :handle, presence: true, uniqueness: { scope: :site_id }, format: { with: /\A[a-z][a-z0-9_]*\z/ }
    validates :slug, presence: true, uniqueness: { scope: :site_id }, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }

    before_validation :generate_handle
    before_validation :generate_slug

    private

    def generate_handle
      self.handle = name&.parameterize(separator: "_") if handle.blank?
    end

    def generate_slug
      self.slug = name&.parameterize if slug.blank?
    end
  end
end
