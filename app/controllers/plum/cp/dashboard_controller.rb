module Plum
  module Cp
    class DashboardController < BaseController
      def show
        @content_types = ContentType.for_site(current_site)
        @recent_entries = Entry.for_site(current_site).includes(:content_type).order(updated_at: :desc).limit(10)
      end
    end
  end
end
