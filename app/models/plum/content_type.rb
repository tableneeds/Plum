module Plum
  class ContentType < ApplicationRecord
    include SiteScoped

    FIELD_TYPES = %w[text textarea rich_text image boolean select date relationship blocks].freeze

    has_many :entries, dependent: :destroy

    validates :name, presence: true
    validates :handle, presence: true, uniqueness: { scope: :site_id }, format: { with: /\A[a-z][a-z0-9_]*\z/ }
    validate :route_prefix_format

    before_validation :generate_handle, on: :create

    def fields
      blueprint&.dig("fields") || []
    end

    def route_prefix
      blueprint&.dig("route_prefix").presence
    end

    private

    def generate_handle
      self.handle = name&.parameterize(separator: "_") if handle.blank?
    end

    def route_prefix_format
      return if route_prefix.blank? || route_prefix.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)

      errors.add(:blueprint, "route prefix must contain lowercase letters, numbers, and hyphens")
    end
  end
end
