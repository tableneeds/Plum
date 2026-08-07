module Plum
  module Api
    module V1
      class EntriesController < Plum::ApplicationController
        MAX_PER_PAGE = 100
        DEFAULT_PER_PAGE = 20

        def index
          content_type = ContentType.for_site(current_site).find_by!(handle: params[:collection_handle])
          scope = Entry.for_site(current_site).live.where(content_type: content_type)
                       .where(locale: requested_locale)
                       .includes(:content_type, terms: :taxonomy)
                       .order(published_at: :desc, created_at: :desc)
          scope = scope.search(params[:q].to_s.strip) if params[:q].present?
          page = [ params.fetch(:page, 1).to_i, 1 ].max
          per_page = params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)
          total = scope.count
          entries = scope.offset((page - 1) * per_page).limit(per_page)

          render json: {
            data: entries.map { |entry| serializer.as_json(entry) },
            meta: { page: page, per_page: per_page, total: total, total_pages: (total / per_page.to_f).ceil }
          }
        end

        def show
          content_type = ContentType.for_site(current_site).find_by!(handle: params[:collection_handle])
          entry = Entry.for_site(current_site).live.includes(:content_type, terms: :taxonomy)
                       .find_by!(content_type: content_type, slug: params[:slug], locale: requested_locale)
          render json: { data: serializer.as_json(entry) }
        end

        private

        def serializer
          @serializer ||= EntrySerializer.new(site: current_site)
        end

        def requested_locale
          locale = params[:locale].presence || current_site.default_locale
          raise ActiveRecord::RecordNotFound unless current_site.locales.include?(locale)

          locale
        end
      end
    end
  end
end
