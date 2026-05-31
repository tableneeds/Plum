module Plum
  class LiquidContext
    MAX_RELATIONSHIP_DEPTH = 2

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
        "forms" => forms_context,
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

    def entry_context(entry, relationship_depth: MAX_RELATIONSHIP_DEPTH)
      {
        "title" => entry.title,
        "slug" => entry.slug,
        "published_at" => entry.published_at,
        "url" => public_entry_path(entry),
        "data" => entry_data_context(entry, relationship_depth: relationship_depth)
      }
    end

    def entry_data_context(entry, relationship_depth:)
      data = (entry.data || {}).deep_dup

      entry.content_type.fields.each do |field|
        handle = field["handle"].to_s
        next if handle.blank?

        case field["type"]
        when "image"
          data[handle] = image_asset_context(data[handle])
        when "relationship"
          data[handle] = relationship_entry_context(data[handle], relationship_depth: relationship_depth)
        when "blocks"
          data[handle] = blocks_html(data[handle])
        end
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

    def forms_context
      FormDefinition.for_site(site).each_with_object({}) do |form, hash|
        hash[form.handle] = {
          "name" => form.name,
          "handle" => form.handle,
          "fields" => form.form_fields,
          "action" => public_form_path(form),
          "csrf_token" => form_authenticity_token,
          "csrf_param" => "authenticity_token",
          "return_to" => controller.request.fullpath
        }
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

    def relationship_entry_context(value, relationship_depth:)
      return if value.blank? || relationship_depth <= 0

      related_entry = relationship_entry_cache[value.to_i]
      return unless related_entry

      entry_context(related_entry, relationship_depth: relationship_depth - 1)
    end

    # Renders a blocks field value (an array of block instances) into HTML using
    # the active theme's Liquid block partials. The shared site context (site,
    # globals, nav, forms, registered content sources) is exposed inside each
    # block, but the global `entries` collection is intentionally excluded to
    # avoid an infinite render loop, since every entry's blocks are expanded.
    def blocks_html(value)
      return "".html_safe unless value.is_a?(Array) && value.any?

      theme = blocks_theme
      return "".html_safe unless theme

      BuilderRenderer.new(
        blocks: value,
        base_assigns: blocks_base_assigns,
        site: site,
        theme: theme,
        registers: blocks_registers
      ).render
    end

    def blocks_theme
      @blocks_theme ||= ThemeRegistry.new.fetch(blocks_theme_name)
    end

    def blocks_theme_name
      theme_name.presence || SiteSetting.instance(site).theme_name
    end

    def blocks_base_assigns
      @blocks_base_assigns ||= {
        "site" => site_context,
        "globals" => globals_context,
        "nav" => nav_context,
        "forms" => forms_context
      }.merge(Plum.content_sources_for(controller, site: site))
    end

    def blocks_registers
      base_url = theme_asset_base_url
      {
        theme_asset_url_builder: ->(path) { ThemeAssetPath.url(base_url: base_url, path: path) },
        form_renderer: ->(handle) { FormRenderer.new(forms_context[handle]).render }
      }
    end

    def asset_cache
      @asset_cache ||= Asset.for_site(site).with_attached_file.index_by(&:id)
    end

    def relationship_entry_cache
      @relationship_entry_cache ||= Entry.for_site(site).live.includes(:content_type).index_by(&:id)
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

    def public_form_path(form)
      "#{controller.request.script_name.to_s.chomp("/")}/forms/#{form.handle}"
    end

    def form_authenticity_token
      controller.send(:form_authenticity_token) if controller.respond_to?(:form_authenticity_token, true)
    end
  end
end
