module Plum
  class SiteSetting < ApplicationRecord
    include SiteScoped

    before_validation :set_defaults, on: :create

    validates :name, presence: true
    validates :site_id, uniqueness: true
    validates :primary_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
    validates :support_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

    def self.instance(site = Plum::Site.first_or_create_standalone!)
      find_or_create_by!(site: site) do |settings|
        settings.name = site.name.presence || "My Site"
        settings.theme_name = site.theme_name.presence || "default"
      end
    end

    private

    def set_defaults
      self.theme_name = "default" if theme_name.blank?
      self.primary_color = "#7c3aed" if primary_color.blank?
    end
  end
end
