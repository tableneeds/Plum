module Plum
  class Fieldset < ApplicationRecord
    include SiteScoped

    validates :name, presence: true
    validates :handle, presence: true, uniqueness: { scope: :site_id }, format: { with: /\A[a-z][a-z0-9_]*\z/ }
    validates :fields, presence: true

    before_validation :generate_handle, on: :create

    private

    def generate_handle
      self.handle = name&.parameterize(separator: "_") if handle.blank?
    end
  end
end
