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

    validates :name, presence: true

    def self.first_or_create_standalone!
      first_or_create!(name: "My Site", theme_name: "default")
    end
  end
end
