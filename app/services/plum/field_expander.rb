module Plum
  # Expands raw stored field values (as kept in entry.data or a block's fields
  # hash) into the richer structures themes expect in Liquid: image ids become
  # asset hashes, relationship ids become published entry hashes. The same rules
  # are reused for entry fields and block fields so blocks behave identically.
  class FieldExpander
    MAX_RELATIONSHIP_DEPTH = 2

    def initialize(site:, url_builder: nil)
      @site = site
      @url_builder = url_builder
    end

    # values: hash of stored field values (handle => raw value)
    # fields: array of blueprint/block field definitions ({ "handle", "type" })
    def expand(values:, fields:, relationship_depth: MAX_RELATIONSHIP_DEPTH)
      data = (values || {}).deep_dup
      data = {} unless data.is_a?(Hash)

      Array(fields).each do |field|
        handle = field["handle"].to_s
        next if handle.blank?

        case field["type"]
        when "image"
          data[handle] = image_asset_context(data[handle])
        when "images"
          data[handle] = Array(data[handle]).filter_map { |value| image_asset_context(value) }
        when "relationship"
          data[handle] = if ActiveModel::Type::Boolean.new.cast(field["multiple"])
            Array(data[handle]).filter_map { |value| relationship_entry_context(value, relationship_depth: relationship_depth) }
          else
            relationship_entry_context(data[handle], relationship_depth: relationship_depth)
          end
        else
          definition = FieldTypeRegistry.find(field["type"])
          if definition&.expander
            data[handle] = definition.expander.call(value: data[handle], field: field, site: site, expander: self)
          end
        end
      end

      data
    end

    private

    attr_reader :site, :url_builder

    def image_asset_context(value)
      return if value.blank?

      asset_cache[value.to_i]&.to_liquid
    end

    def relationship_entry_context(value, relationship_depth:)
      return if value.blank? || relationship_depth <= 0

      related_entry = relationship_entry_cache[value.to_i]
      return unless related_entry

      {
        "title" => related_entry.title,
        "slug" => related_entry.slug,
        "published_at" => related_entry.published_at,
        "url" => entry_url(related_entry),
        "data" => expand(
          values: related_entry.data,
          fields: related_entry.content_type.fields,
          relationship_depth: relationship_depth - 1
        )
      }
    end

    def entry_url(entry)
      return url_builder.call(entry) if url_builder.respond_to?(:call)

      "/#{entry.slug}"
    end

    def asset_cache
      @asset_cache ||= Asset.for_site(site).with_attached_file.index_by(&:id)
    end

    def relationship_entry_cache
      @relationship_entry_cache ||= Entry.for_site(site).live.includes(:content_type).index_by(&:id)
    end
  end
end
