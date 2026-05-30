module Plum
  module Cp
    class ThemesController < BaseController
      helper_method :theme_screenshot_url,
        :theme_initials,
        :theme_setting_input_id,
        :theme_setting_input_name,
        :theme_setting_value,
        :theme_setting_checked?

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
            theme_settings: ThemeSettingsParams.new(theme).normalize(theme_settings_params_for(theme))
          )
          redirect_to cp_themes_path, notice: theme_update_notice(theme)
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

      def theme_screenshot_url(theme)
        return if theme.screenshot_path.blank?

        theme_asset_path(theme.handle, theme.screenshot_path)
      end

      def theme_initials(theme)
        theme.name.split.first(2).map { |part| part.first.to_s.upcase }.join.presence || theme.handle.first.to_s.upcase
      end

      def theme_setting_input_id(theme, field)
        "theme_settings_#{theme.handle.parameterize}_#{field['handle'].to_s.parameterize}"
      end

      def theme_setting_input_name(field)
        "theme_settings[#{field['handle']}]"
      end

      def theme_setting_value(field)
        settings = current_site.theme_settings.to_h
        handle = field["handle"].to_s

        settings.key?(handle) ? settings[handle] : field["default"]
      end

      def theme_setting_checked?(field)
        ActiveModel::Type::Boolean.new.cast(theme_setting_value(field))
      end

      def theme_settings_params_for(theme)
        raw_settings = params[:theme_settings].respond_to?(:permit!) ? params[:theme_settings].permit!.to_h : nil
        return raw_settings if raw_settings
        return current_site.theme_settings if current_site.theme_name == theme.handle

        {}
      end

      def theme_update_notice(theme)
        params[:theme_settings].present? && current_site.theme_name == theme.handle ? "Theme settings updated" : "Theme activated"
      end

      def site_settings
        @site_settings ||= SiteSetting.instance(current_site)
      end
    end
  end
end
