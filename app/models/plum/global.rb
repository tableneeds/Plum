module Plum
  class Global < ApplicationRecord
    include SiteScoped

    validates :name, presence: true
    validates :handle, presence: true, uniqueness: { scope: :site_id }, format: { with: /\A[a-z][a-z0-9_]*\z/ }

    before_validation :generate_handle, on: :create

    def data
      super || {}
    end

    def value(key)
      data&.dig(key)
    end

    private

    def generate_handle
      self.handle = name&.parameterize(separator: "_") if handle.blank?
    end
  end
end
