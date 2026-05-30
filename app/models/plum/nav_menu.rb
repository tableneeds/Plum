module Plum
  class NavMenu < ApplicationRecord
    include SiteScoped

    has_many :nav_items, dependent: :destroy

    validates :name, presence: true
    validates :handle, presence: true, uniqueness: { scope: :site_id }, format: { with: /\A[a-z][a-z0-9_]*\z/ }

    before_validation :generate_handle, on: :create

    def items
      nav_items.where(parent_id: nil).order(:position)
    end

    alias root_items items

    private

    def generate_handle
      self.handle = name&.parameterize(separator: "_") if handle.blank?
    end
  end
end
