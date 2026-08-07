module Plum
  module Cp
    class SiteSettingsController < BaseController
      helper_method :theme_setting_input_id,
        :theme_setting_input_name,
        :theme_setting_value,
        :theme_setting_checked?

      before_action :set_site_settings
      before_action :set_theme_options
      before_action :require_admin, only: [ :edit, :update, :image_field ]

      def show
        redirect_to edit_cp_site_settings_path
      end

      def edit
      end

      def update
        settings_attributes = site_settings_params
        theme_settings_by_theme = settings_attributes.delete(:theme_settings_by_theme).to_h
        locales = normalized_locales(settings_attributes.delete(:locales))
        default_locale = settings_attributes.delete(:default_locale).to_s
        @site_settings.assign_attributes(settings_attributes)

        unless locales.any? && locales.include?(default_locale)
          @site_settings.errors.add(:base, "Locales must be valid codes and include the default locale")
          set_theme_options
          return render :edit, status: :unprocessable_entity
        end

        if @site_settings.save
          site_settings = current_site.settings.to_h.merge("locales" => locales, "default_locale" => default_locale)
          current_site.update!(theme_settings: theme_settings_for(@site_settings.theme_name, theme_settings_by_theme), settings: site_settings)
          redirect_to edit_cp_site_settings_path, notice: "Site settings updated"
        else
          set_theme_options
          render :edit, status: :unprocessable_entity
        end
      end

      def image_field
        asset_id = params[:asset_id].presence
        if asset_id && !current_site.assets.exists?(id: asset_id)
          return render json: { error: "Image is not available" }, status: :unprocessable_entity
        end

        if @site_settings.update(logo: asset_id&.to_s)
          render json: { saved: true, asset_id: asset_id&.to_i }
        else
          render json: { error: @site_settings.errors.full_messages.to_sentence }, status: :unprocessable_entity
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
        settings = current_site.theme_settings.to_h
        handle = field["handle"].to_s

        settings.key?(handle) ? settings[handle] : field["default"]
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
          :locales,
          :default_locale,
          theme_settings_by_theme: {}
        )
      end

      def normalized_locales(value)
        value.to_s.split(/[\s,]+/).filter_map do |locale|
          parts = locale.split("-", 2)
          normalized = [ parts[0]&.downcase, parts[1]&.upcase ].compact.join("-")
          normalized if normalized.match?(/\A[a-z]{2}(?:-[A-Z]{2})?\z/)
        end.uniq
      end
    end
  end
end
