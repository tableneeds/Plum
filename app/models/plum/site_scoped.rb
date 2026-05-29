module Plum
  module SiteScoped
    extend ActiveSupport::Concern

    included do
      belongs_to :site, class_name: "Plum::Site"
      before_validation :assign_default_site, on: :create
      scope :for_site, ->(site) { where(site: site) }
    end

    private

    def assign_default_site
      self.site ||= Plum::Site.first_or_create_standalone!
    end
  end
end
