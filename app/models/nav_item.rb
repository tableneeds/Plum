class NavItem < ApplicationRecord
  belongs_to :nav_menu
  belongs_to :parent, class_name: "NavItem", optional: true
  belongs_to :entry, optional: true
  has_many :children, class_name: "NavItem", foreign_key: :parent_id, dependent: :destroy

  validates :label, presence: true

  default_scope { order(:position) }

  def href
    entry&.slug ? "/#{entry.slug}" : url
  end
end
