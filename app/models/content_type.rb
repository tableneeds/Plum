class ContentType < ApplicationRecord
  has_many :entries, dependent: :destroy

  validates :name, presence: true
  validates :handle, presence: true, uniqueness: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }

  before_validation :generate_handle, on: :create

  def fields
    blueprint&.dig("fields") || []
  end

  private

  def generate_handle
    self.handle = name&.parameterize(separator: "_") if handle.blank?
  end
end
