module Plum
  class Site < ApplicationRecord
    belongs_to :owner, polymorphic: true, optional: true

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
    validates :owner_id, uniqueness: { scope: :owner_type }, if: :owner_present?

    def self.first_or_create_standalone!
      first_or_create!(name: "My Site", theme_name: "default")
    end

    def self.for_owner!(owner, attributes = {})
      unless owner.respond_to?(:persisted?) && owner.persisted?
        raise ArgumentError, "Owner must be a persisted Active Record model"
      end

      find_or_create_by!(owner: owner) do |site|
        site.name = attributes.fetch(:name) { owner_default_name(owner) }
        site.theme_name = attributes.fetch(:theme_name, "default")
        site.domain = attributes[:domain] if attributes.key?(:domain)
        site.settings = attributes[:settings] if attributes.key?(:settings)
        site.theme_settings = attributes[:theme_settings] if attributes.key?(:theme_settings)
        site.custom_css = attributes[:custom_css] if attributes.key?(:custom_css)
      end
    end

    def theme
      ThemeRegistry.new.fetch(theme_name)
    end

    def theme_settings
      super || {}
    end

    private

    def self.owner_default_name(owner)
      return owner.name if owner.respond_to?(:name) && owner.name.present?

      owner.to_s.presence || "Site"
    end

    private_class_method :owner_default_name

    def owner_present?
      owner_type.present? && owner_id.present?
    end

    def set_theme_defaults
      self.theme_name = "default" if theme_name.blank?
      self.theme_settings = {} if has_attribute?(:theme_settings) && theme_settings.blank?
    end
  end
end
