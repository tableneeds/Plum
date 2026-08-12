module Plum
  module Cp
    class StaticCacheController < BaseController
      before_action :require_admin

      def destroy
        Plum::StaticCache.flush_site!(current_site)
        redirect_back fallback_location: cp_root_path, notice: "Page cache cleared"
      end
    end
  end
end
