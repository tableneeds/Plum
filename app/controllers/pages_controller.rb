class PagesController < ApplicationController
  def home
    @site_settings = SiteSetting.instance
    html = LiquidRenderer.render_template("index", build_context)
    render html: html.html_safe, layout: false
  end

  def show
    @entry = Entry.live.find_by!(slug: params[:slug])
    template = "entries/#{@entry.content_type.handle}"
    html = LiquidRenderer.render_template(template, build_context(@entry))
    render html: html.html_safe, layout: false
  rescue ActiveRecord::RecordNotFound
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end

  private

  def build_context(entry = nil)
    {
      "site" => site_context,
      "entry" => entry ? entry_context(entry) : nil,
      "entries" => entries_context,
      "globals" => globals_context
    }.compact
  end

  def site_context
    settings = SiteSetting.instance
    {
      "name" => settings.name,
      "tagline" => settings.tagline,
      "seo_title" => settings.seo_title,
      "seo_description" => settings.seo_description,
      "primary_color" => settings.primary_color,
      "support_email" => settings.support_email,
      "theme_name" => settings.theme_name,
      "meta_title" => settings.seo_title,
      "meta_description" => settings.seo_description
    }
  end

  def entry_context(entry)
    {
      "title" => entry.title,
      "slug" => entry.slug,
      "published_at" => entry.published_at,
      "url" => "/#{entry.slug}",
      "data" => entry.data || {}
    }
  end

  def entries_context
    ContentType.includes(:entries).each_with_object({}) do |content_type, hash|
      live_entries = content_type.entries.live.order(published_at: :desc, created_at: :desc)
      hash[content_type.handle] = live_entries.map { |entry| entry_context(entry) }
    end
  end

  def globals_context
    Global.all.each_with_object({}) do |global, hash|
      hash[global.handle] = global.data
    end
  end
end
