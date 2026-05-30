module Plum
  module Cp
    class ThemesController < BaseController
      before_action :set_themes

      def index
      end

      def create
        installer = ThemePackageInstaller.new(params[:theme_package])

        if installer.install
          redirect_to cp_themes_path, notice: "Theme installed"
        else
          @theme_package_errors = installer.errors
          render :index, status: :unprocessable_entity
        end
      end

      def update
        theme = ThemeRegistry.new.find(params[:id])

        if theme
          site_settings.update!(theme_name: theme.handle)
          current_site.update!(
            theme_name: theme.handle,
            theme_settings: ThemeSettingsParams.new(theme).normalize(current_site.theme_settings)
          )
          redirect_to cp_themes_path, notice: "Theme activated"
        else
          redirect_to cp_themes_path, alert: "Theme not found"
        end
      end

      private

      def set_themes
        registry = ThemeRegistry.new

        @themes = registry.all
        @active_theme = registry.fetch(site_settings.theme_name)
      end

      def site_settings
        @site_settings ||= SiteSetting.instance(current_site)
      end
    end
  end
end
