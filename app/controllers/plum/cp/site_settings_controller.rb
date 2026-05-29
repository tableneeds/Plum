module Plum
  module Cp
    class SiteSettingsController < BaseController
      before_action :set_site_settings

      def show
      end

      def edit
      end

      def update
        if @site_settings.update(site_settings_params)
          redirect_to cp_site_settings_path, notice: "Site settings updated"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def set_site_settings
        @site_settings = SiteSetting.instance(current_site)
      end

      def site_settings_params
        params.require(:site_setting).permit(
          :name,
          :tagline,
          :logo,
          :favicon,
          :seo_title,
          :seo_description,
          :primary_color,
          :support_email,
          :theme_name
        )
      end
    end
  end
end
