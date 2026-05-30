module Plum
  class PagesController < ApplicationController
    def home
      @site_settings = SiteSetting.instance(current_site)
      html = Plum::LiquidRenderer.render_template("index", build_context.to_h)
      render html: html.html_safe, layout: false
    end

    def show
      @entry = Entry.for_site(current_site).live.find_by!(slug: params[:slug])
      template = "entries/#{@entry.content_type.handle}"
      html = Plum::LiquidRenderer.render_template(template, build_context(@entry).to_h)
      render html: html.html_safe, layout: false
    rescue ActiveRecord::RecordNotFound
      render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
    end

    private

    def build_context(entry = nil)
      LiquidContext.new(controller: self, site: current_site, entry: entry)
    end
  end
end
