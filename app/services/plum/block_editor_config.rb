module Plum
  # Translates a theme's declared blocks (theme.yml `blocks:`) into a
  # JSON-serializable config our own block editor consumes to render the block
  # picker and per-block field inputs. This is the seam that keeps the editor in
  # the engine and the block library in themes: the editor never reads a theme
  # directly — it reads this generated config. Theme authors write zero JS.
  #
  # Shape:
  #   {
  #     "blocks" => [
  #       { "id" => "hero", "label" => "Hero", "category" => "Blocks",
  #         "fields" => [ { "handle" => "heading", "type" => "text", "label" => "Heading" }, ... ] }
  #     ]
  #   }
  #
  # An optional `allowed` list (the blueprint field's `blocks:` whitelist) limits
  # which theme blocks are offered for a given field.
  class BlockEditorConfig
    DEFAULT_CATEGORY = "Blocks".freeze

    def initialize(theme, allowed: nil)
      @theme = theme
      @allowed = allowed.nil? ? nil : Array(allowed).map(&:to_s)
    end

    def blocks
      definitions.map do |definition|
        {
          "id" => definition["handle"],
          "label" => definition["label"],
          "category" => definition["category"].presence || DEFAULT_CATEGORY,
          "fields" => Array(definition["fields"]).map { |field| field_config(field) }
        }
      end
    end

    def to_h
      { "blocks" => blocks }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    private

    attr_reader :theme, :allowed

    def definitions
      list = theme ? theme.blocks : []
      return list if allowed.nil?

      list.select { |definition| allowed.include?(definition["handle"]) }
    end

    def field_config(field)
      {
        "handle" => field["handle"],
        "type" => field["type"].presence || "text",
        "label" => field["label"].presence || field["handle"].to_s.humanize,
        "options" => Array(field["options"])
      }
    end
  end
end
