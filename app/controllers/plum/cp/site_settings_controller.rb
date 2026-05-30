module Plum
  module Cp
    class SiteSettingsController < BaseController
      helper_method :theme_setting_input_id,
        :theme_setting_input_name,
        :theme_setting_value,
        :theme_setting_checked?

      before_action :set_site_settings
      before_action :set_theme_options

      def show
      end

      def edit
      end

      def update
        settings_attributes = site_settings_params
        theme_settings_by_theme = settings_attributes.delete(:theme_settings_by_theme).to_h
        @site_settings.assign_attributes(settings_attributes)

        if @site_settings.save
          current_site.update!(theme_settings: theme_settings_for(@site_settings.theme_name, theme_settings_by_theme))
          redirect_to cp_site_settings_path, notice: "Site settings updated"
        else
          set_theme_options
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def set_site_settings
        @site_settings = SiteSetting.instance(current_site)
      end

      def set_theme_options
        registry = ThemeRegistry.new
        @themes = registry.all
        @current_theme = registry.fetch(@site_settings.theme_name)
      end

      def theme_settings_for(theme_name, theme_settings_by_theme)
        theme = ThemeRegistry.new.fetch(theme_name)
        raw_settings = theme_settings_by_theme[theme.handle] || {}
        ThemeSettingsParams.new(theme).normalize(raw_settings)
      end

      def theme_setting_input_id(theme, field)
        "theme_settings_#{theme.handle.parameterize}_#{field['handle'].to_s.parameterize}"
      end

      def theme_setting_input_name(theme, field)
        "site_setting[theme_settings_by_theme][#{theme.handle}][#{field['handle']}]"
      end

      def theme_setting_value(field)
        current_site.theme_settings[field["handle"].to_s]
      end

      def theme_setting_checked?(field)
        ActiveModel::Type::Boolean.new.cast(theme_setting_value(field))
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
          :theme_name,
          theme_settings_by_theme: {}
        )
      end
    end
  end
end
