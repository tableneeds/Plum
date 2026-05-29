class NavMenu < ApplicationRecord
  has_many :nav_items, dependent: :destroy

  validates :name, presence: true
  validates :handle, presence: true, uniqueness: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }

  before_validation :generate_handle, on: :create

  def items
    nav_items.where(parent_id: nil).order(:position)
  end

  private

  def generate_handle
    self.handle ||= name&.parameterize(separator: "_")
  end
end
