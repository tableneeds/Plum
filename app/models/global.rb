class Global < ApplicationRecord
  validates :name, presence: true
  validates :handle, presence: true, uniqueness: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }

  before_validation :generate_handle, on: :create

  def value(key)
    data&.dig(key)
  end

  private

  def generate_handle
    self.handle ||= name&.parameterize(separator: "_")
  end
end
