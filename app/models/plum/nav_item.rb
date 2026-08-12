module Plum
  class NavItem < ApplicationRecord
    include SiteScoped
    include StaticCacheInvalidation

    belongs_to :nav_menu
    belongs_to :parent, class_name: "Plum::NavItem", optional: true
    belongs_to :entry, optional: true
    has_many :children, class_name: "Plum::NavItem", foreign_key: :parent_id, dependent: :destroy

    validates :label, presence: true
    validates :url, presence: true, unless: :entry_id?
    validate :nav_menu_belongs_to_site
    validate :entry_belongs_to_site
    validate :parent_belongs_to_menu
    validate :parent_does_not_create_cycle

    default_scope { order(:position) }

    def href
      entry&.slug ? "/#{entry.slug}" : url
    end

    private

    def nav_menu_belongs_to_site
      return if nav_menu.blank? || site.blank? || nav_menu.site_id == site_id

      errors.add(:nav_menu, "must belong to the same site")
    end

    def entry_belongs_to_site
      return if entry.blank? || site.blank? || entry.site_id == site_id

      errors.add(:entry, "must belong to the same site")
    end

    def parent_belongs_to_menu
      return if parent.blank?

      errors.add(:parent, "must belong to the same menu") if parent.nav_menu_id != nav_menu_id
      errors.add(:parent, "must belong to the same site") if site_id.present? && parent.site_id != site_id
      errors.add(:parent, "cannot be itself") if parent_id.present? && parent_id == id
    end

    def parent_does_not_create_cycle
      ancestor = parent

      while ancestor
        if ancestor == self
          errors.add(:parent, "cannot be a descendant")
          break
        end

        ancestor = ancestor.parent
      end
    end
  end
end
