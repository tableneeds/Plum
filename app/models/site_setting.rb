class SiteSetting < ApplicationRecord
  before_validation :set_defaults, on: :create

  validates :name, presence: true
  validates :primary_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
  validates :support_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  def self.instance
    first_or_create!(name: "My Site")
  end

  private

  def set_defaults
    self.theme_name = "default" if theme_name.blank?
    self.primary_color = "#7c3aed" if primary_color.blank?
  end
end
