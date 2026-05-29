module Cp
  class DashboardController < BaseController
    def show
      @content_types = ContentType.all
      @recent_entries = Entry.includes(:content_type).order(updated_at: :desc).limit(10)
    end
  end
end
