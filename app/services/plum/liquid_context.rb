module Plum
  class LiquidContext
    def initialize(controller:, site:, entry: nil, theme_name: nil, theme_settings: nil)
      @controller = controller
      @site = site
      @entry = entry
      @theme_name = theme_name
      @theme_settings = theme_settings
    end

    def to_h
      {
        "site" => site_context,
        "entry" => entry ? entry_context(entry) : nil,
        "entries" => entries_context,
        "globals" => globals_context,
        "nav" => nav_context
      }.compact.merge(Plum.content_sources_for(controller, site: site))
    end

    private

    attr_reader :controller, :site, :entry, :theme_name, :theme_settings

    def site_context
      settings = SiteSetting.instance(site)
      {
        "name" => settings.name,
        "tagline" => settings.tagline,
        "seo_title" => settings.seo_title,
        "seo_description" => settings.seo_description,
        "primary_color" => settings.primary_color,
        "support_email" => settings.support_email,
        "theme_name" => theme_name.presence || settings.theme_name,
        "theme_settings" => theme_settings || site.theme_settings,
        "theme_asset_base_url" => theme_asset_base_url,
        "custom_css" => site.custom_css,
        "url" => public_root_path,
        "meta_title" => settings.seo_title,
        "meta_description" => settings.seo_description
      }
    end

    def entry_context(entry)
      {
        "title" => entry.title,
        "slug" => entry.slug,
        "published_at" => entry.published_at,
        "url" => public_entry_path(entry),
        "data" => entry_data_context(entry)
      }
    end

    def entry_data_context(entry)
      data = (entry.data || {}).deep_dup

      entry.content_type.fields.each do |field|
        next unless field["type"] == "image"

        handle = field["handle"].to_s
        data[handle] = image_asset_context(data[handle])
      end

      data
    end

    def entries_context
      ContentType.for_site(site).includes(:entries).each_with_object({}) do |content_type, hash|
        live_entries = content_type.entries.live.order(published_at: :desc, created_at: :desc)
        hash[content_type.handle] = live_entries.map { |entry| entry_context(entry) }
      end
    end

    def globals_context
      Global.for_site(site).each_with_object({}) do |global, hash|
        hash[global.handle] = global.data
      end
    end

    def nav_context
      NavMenu.for_site(site).includes(nav_items: [ :entry, :children ]).each_with_object({}) do |menu, hash|
        hash[menu.handle] = {
          "name" => menu.name,
          "handle" => menu.handle,
          "items" => menu.root_items.map { |item| nav_item_context(item) }
        }
      end
    end

    def nav_item_context(item)
      {
        "label" => item.label,
        "url" => nav_item_url(item),
        "entry" => item.entry ? entry_context(item.entry) : nil,
        "children" => item.children.map { |child| nav_item_context(child) }
      }
    end

    def nav_item_url(item)
      item.entry ? public_entry_path(item.entry) : item.url
    end

    def image_asset_context(value)
      return if value.blank?

      asset_cache[value.to_i]&.to_liquid
    end

    def asset_cache
      @asset_cache ||= Asset.for_site(site).with_attached_file.index_by(&:id)
    end

    def public_root_path
      controller.request.script_name.presence || "/"
    end

    def theme_asset_base_url
      "#{controller.request.script_name.to_s.chomp("/")}/theme_assets/#{theme_name.presence || site.theme_name}"
    end

    def public_entry_path(entry)
      "#{controller.request.script_name.to_s.chomp("/")}/#{entry.slug}"
    end
  end
end
