module Plum
  class PagesController < ApplicationController
    HOMEPAGE_SLUG = "home".freeze

    def home
      @site_settings = SiteSetting.instance(current_site)
      @entry = Entry.for_site(current_site).live
                    .where(locale: requested_locale)
                    .includes(:content_type, terms: :taxonomy)
                    .find_by(slug: HOMEPAGE_SLUG)

      template = @entry ? "entries/#{@entry.content_type.handle}" : "index"
      html = Plum::LiquidRenderer.render_template(template, build_context(@entry).to_h)
      render html: html.html_safe, layout: false
    end

    def localized_home
      raise ActiveRecord::RecordNotFound unless current_site.locales.include?(params[:locale])

      home
    rescue ActiveRecord::RecordNotFound
      render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
    end

    def search
      query = params[:q].to_s.strip
      context = build_context
      results = Entry.for_site(current_site).live.search(query)
                     .where(locale: requested_locale)
                     .includes(:content_type)
                     .order(published_at: :desc)
                     .limit(50)

      context_hash = context.to_h.merge(
        "search" => {
          "query" => query,
          "results" => results.map { |e| context.send(:entry_context, e) },
          "total" => results.size
        }
      )
      html = Plum::LiquidRenderer.render_template("search", context_hash)
      render html: html.html_safe, layout: false
    end

    def show
      raise ActiveRecord::RecordNotFound unless current_site.locales.include?(requested_locale)

      slug = params[:slug]

      @content_type = ContentType.for_site(current_site).find_by(handle: slug)
      if @content_type
        return render_collection(@content_type)
      end

      if slug.include?("/")
        parts = slug.split("/", 2)
        content_type = ContentType.for_site(current_site).find do |candidate|
          candidate.route_prefix == parts[0]
        end
        if content_type
          @entry = Entry.for_site(current_site).live
                        .where(locale: requested_locale)
                        .includes(:content_type, terms: :taxonomy)
                        .find_by!(content_type: content_type, slug: parts[1])
          html = Plum::LiquidRenderer.render_template("entries/#{content_type.handle}", build_context(@entry).to_h)
          return render html: html.html_safe, layout: false
        end

        taxonomy = Taxonomy.for_site(current_site).find_by(slug: parts[0])
        if taxonomy
          term = taxonomy.terms.find_by!(slug: parts[1])
          return render_term_page(taxonomy, term)
        end
      else
        taxonomy = Taxonomy.for_site(current_site).find_by(slug: slug)
        return render_taxonomy_index(taxonomy) if taxonomy
      end

      @entry = Entry.for_site(current_site).live
                    .where(locale: requested_locale)
                    .includes(:content_type, terms: :taxonomy)
                    .find_by!(slug: slug)
      template = "entries/#{@entry.content_type.handle}"
      html = Plum::LiquidRenderer.render_template(template, build_context(@entry).to_h)
      render html: html.html_safe, layout: false
    rescue ActiveRecord::RecordNotFound
      render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
    end

    private

    PER_PAGE = 12

    def render_collection(content_type)
      context = build_context
      page = [ params.fetch(:page, 1).to_i, 1 ].max
      all_entries = Entry.for_site(current_site).live
                        .where(locale: requested_locale)
                        .where(content_type: content_type)
                        .order(published_at: :desc, created_at: :desc)
      total = all_entries.count
      total_pages = (total / PER_PAGE.to_f).ceil
      page = [ page, [ total_pages, 1 ].max ].min
      entries = all_entries.offset((page - 1) * PER_PAGE).limit(PER_PAGE)

      context_hash = context.to_h.merge(
        "collection" => {
          "title" => content_type.name,
          "handle" => content_type.handle,
          "entries" => entries.map { |e| context.send(:entry_context, e) }
        },
        "pagination" => {
          "current_page" => page,
          "total_pages" => total_pages,
          "total_entries" => total,
          "per_page" => PER_PAGE,
          "previous_url" => page > 1 ? "#{request.path}?page=#{page - 1}" : nil,
          "next_url" => page < total_pages ? "#{request.path}?page=#{page + 1}" : nil
        }
      )
      template = "collections/#{content_type.handle}"
      html = Plum::LiquidRenderer.render_template(template, context_hash)
      render html: html.html_safe, layout: false
    end

    def render_term_page(taxonomy, term)
      context = build_context
      page = [ params.fetch(:page, 1).to_i, 1 ].max
      all_entries = Entry.for_site(current_site).live
                        .where(locale: requested_locale)
                        .joins(:entry_terms)
                        .where(plum_entry_terms: { term_id: term.id })
                        .order(published_at: :desc)
      total = all_entries.count
      total_pages = [ (total / PER_PAGE.to_f).ceil, 1 ].max
      page = [ page, total_pages ].min
      entries = all_entries.offset((page - 1) * PER_PAGE).limit(PER_PAGE)

      context_hash = context.to_h.merge(
        "taxonomy" => { "name" => taxonomy.name, "handle" => taxonomy.handle, "slug" => taxonomy.slug },
        "term" => { "name" => term.name, "slug" => term.slug },
        "collection" => {
          "title" => "#{taxonomy.name}: #{term.name}",
          "entries" => entries.map { |e| context.send(:entry_context, e) }
        },
        "pagination" => {
          "current_page" => page, "total_pages" => total_pages, "total_entries" => total, "per_page" => PER_PAGE,
          "previous_url" => page > 1 ? "#{request.path}?page=#{page - 1}" : nil,
          "next_url" => page < total_pages ? "#{request.path}?page=#{page + 1}" : nil
        }
      )
      template = "taxonomies/#{taxonomy.handle}"
      html = Plum::LiquidRenderer.render_template(template, context_hash)
      render html: html.html_safe, layout: false
    end

    def render_taxonomy_index(taxonomy)
      context = build_context
      terms = taxonomy.terms.ordered
      context_hash = context.to_h.merge(
        "taxonomy" => {
          "name" => taxonomy.name,
          "handle" => taxonomy.handle,
          "slug" => taxonomy.slug,
          "terms" => terms.map { |t| { "name" => t.name, "slug" => t.slug, "url" => localized_path("#{taxonomy.slug}/#{t.slug}"), "entries_count" => t.entries.live.where(locale: requested_locale).count } }
        }
      )
      template = "taxonomies/#{taxonomy.handle}_index"
      html = Plum::LiquidRenderer.render_template(template, context_hash)
      render html: html.html_safe, layout: false
    end

    def build_context(entry = nil)
      LiquidContext.new(controller: self, site: current_site, entry: entry)
    end

    def requested_locale
      params[:locale].presence || current_site.default_locale
    end

    def localized_path(path)
      prefix = requested_locale == current_site.default_locale ? nil : requested_locale
      "/#{[ prefix, path ].compact.join('/')}"
    end
  end
end
