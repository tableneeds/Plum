module Plum
  class PagesController < ApplicationController
    HOMEPAGE_SLUG = "home".freeze

    def home
      @site_settings = SiteSetting.instance(current_site)
      @entry = Entry.for_site(current_site).live.includes(:content_type).find_by(slug: HOMEPAGE_SLUG)

      template = @entry ? "entries/#{@entry.content_type.handle}" : "index"
      html = Plum::LiquidRenderer.render_template(template, build_context(@entry).to_h)
      render html: html.html_safe, layout: false
    end

    def show
      slug = params[:slug]

      @content_type = ContentType.for_site(current_site).find_by(handle: slug)
      if @content_type
        return render_collection(@content_type)
      end

      @entry = Entry.for_site(current_site).live.find_by!(slug: slug)
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

    def build_context(entry = nil)
      LiquidContext.new(controller: self, site: current_site, entry: entry)
    end
  end
end
