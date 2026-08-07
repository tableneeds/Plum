module Plum
  class EntrySerializer
    def initialize(site:)
      @site = site
      @expander = FieldExpander.new(site: site, url_builder: method(:entry_path))
    end

    def as_json(entry)
      {
        "id" => entry.id,
        "title" => entry.title,
        "slug" => entry.slug,
        "locale" => entry.locale,
        "url" => entry_path(entry),
        "status" => entry.status,
        "published_at" => entry.published_at&.iso8601,
        "updated_at" => entry.updated_at&.iso8601,
        "collection" => {
          "handle" => entry.content_type.handle,
          "title" => entry.content_type.name
        },
        "data" => @expander.expand(values: entry.data, fields: entry.content_type.fields),
        "terms" => entry.terms.group_by { |term| term.taxonomy.handle }.transform_values do |terms|
          terms.map { |term| { "name" => term.name, "slug" => term.slug } }
        end
      }
    end

    private

    def entry_path(entry)
      locale_prefix = entry.locale == @site.default_locale ? nil : entry.locale
      "/#{[ locale_prefix, entry.content_type.route_prefix, entry.slug ].compact.join('/')}"
    end
  end
end
