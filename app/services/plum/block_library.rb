module Plum
  # The merged block palette available to an entry: engine-level base blocks
  # (Plum::BaseBlocks) plus the active theme's own blocks. A theme block overrides
  # a base block with the same handle, so a theme can both add new sections and
  # customize universal ones. This is the single resolution point used by the
  # block editor (Plum::BlockEditorConfig) and the renderer (Plum::BuilderRenderer).
  class BlockLibrary
    def initialize(theme = nil)
      @theme = theme
    end

    # Base blocks first, then theme blocks override (by handle) or append.
    def definitions
      merged = {}
      BaseBlocks.definitions.each { |definition| merged[definition["handle"]] = definition }
      Array(@theme&.blocks).each { |definition| merged[definition["handle"]] = definition }
      merged.values
    end

    def definition(handle)
      handle = handle.to_s
      (@theme && @theme.block_definition(handle)) || BaseBlocks.definition(handle)
    end

    # The Liquid source for a block. Theme partial wins; otherwise the base block.
    def template(handle)
      handle = handle.to_s
      (@theme && @theme.block_template(handle)) || BaseBlocks.template(handle)
    end
  end
end
