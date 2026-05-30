module Plum
  module Cp
    class ThemePreviewsController < BaseController
      def show
        theme = ThemeRegistry.new.find(params[:handle])
        return render file: Rails.public_path.join("404.html"), status: :not_found, layout: false unless theme

        context = LiquidContext.new(
          controller: self,
          site: current_site,
          theme_name: theme.handle,
          theme_settings: preview_theme_settings(theme)
        )

        html = LiquidRenderer.render_template("index", context.to_h)
        render html: html.html_safe, layout: false
      end

      private

      def preview_theme_settings(theme)
        raw_settings = params.fetch(:theme_settings, {}).permit!.to_h if params[:theme_settings].respond_to?(:permit!)
        ThemeSettingsParams.new(theme).normalize(raw_settings.presence || current_site.theme_settings)
      end
    end
  end
end
