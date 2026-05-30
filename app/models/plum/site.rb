module Plum
  class Site < ApplicationRecord
    has_one :site_setting, dependent: :destroy
    has_many :content_types, dependent: :destroy
    has_many :entries, dependent: :destroy
    has_many :globals, dependent: :destroy
    has_many :nav_menus, dependent: :destroy
    has_many :nav_items, dependent: :destroy
    has_many :assets, dependent: :destroy
    has_many :form_definitions, dependent: :destroy
    has_many :form_submissions, dependent: :destroy

    before_validation :set_theme_defaults

    validates :name, presence: true
    validates :theme_name, presence: true

    def self.first_or_create_standalone!
      first_or_create!(name: "My Site", theme_name: "default")
    end

    def theme
      ThemeRegistry.new.fetch(theme_name)
    end

    def theme_settings
      super || {}
    end

    private

    def set_theme_defaults
      self.theme_name = "default" if theme_name.blank?
      self.theme_settings = {} if has_attribute?(:theme_settings) && theme_settings.blank?
    end
  end
end
