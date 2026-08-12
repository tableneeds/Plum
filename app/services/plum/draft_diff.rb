module Plum
  # Field-by-field comparison between an entry's live content and its working
  # draft, tokenized for git-style rendering (equal / deleted / inserted
  # segments). Rich text is compared as readable text, structured fields as
  # pretty-printed JSON.
  class DraftDiff
    # Beyond this many differing tokens, fall back to a wholesale
    # replaced-block diff instead of an O(n*m) LCS table.
    TOKEN_LIMIT = 1500

    FieldChange = Struct.new(:handle, :label, :segments, keyword_init: true)

    def initialize(entry)
      @entry = entry
      @content_type = entry.content_type
    end

    def changes
      @changes ||= build_changes
    end

    def any?
      changes.any?
    end

    # Word-level diff as [[op, text], ...] with op in :eq/:del/:ins.
    # Whitespace is kept as tokens so spacing survives reconstruction.
    def self.word_diff(old_text, new_text)
      a = tokenize(old_text)
      b = tokenize(new_text)

      prefix = common_prefix_length(a, b)
      suffix = common_suffix_length(a, b, prefix)
      middle_a = a[prefix...(a.length - suffix)]
      middle_b = b[prefix...(b.length - suffix)]

      segments = []
      segments << [ :eq, a.first(prefix).join ] if prefix.positive?
      segments.concat(diff_middle(middle_a, middle_b))
      segments << [ :eq, a.last(suffix).join ] if suffix.positive?
      merge_segments(segments)
    end

    private

    attr_reader :entry, :content_type

    def build_changes
      list = []

      if entry.draft_title.to_s != entry.title.to_s
        list << FieldChange.new(handle: "title", label: "Title",
                                segments: self.class.word_diff(entry.title.to_s, entry.draft_title.to_s))
      end

      live_data = entry.data.to_h
      draft_data = entry.draft_data.to_h["data"] || {}

      (live_data.keys | draft_data.keys).each do |handle|
        field = field_definition(handle)
        live = normalize(live_data[handle], field)
        draft = normalize(draft_data.key?(handle) ? draft_data[handle] : live_data[handle], field)
        next if live == draft

        list << FieldChange.new(handle: handle, label: label_for(handle, field),
                                segments: self.class.word_diff(live, draft))
      end

      list
    end

    def field_definition(handle)
      content_type.fields.find { |field| field["handle"].to_s == handle }
    end

    def label_for(handle, field)
      field&.dig("label").presence || handle.humanize
    end

    def normalize(value, field)
      case value
      when nil then ""
      when Hash, Array then JSON.pretty_generate(value)
      when String
        field&.dig("type") == "rich_text" ? html_to_text(value) : value
      else value.to_s
      end
    end

    def html_to_text(html)
      text = html.gsub(%r{<(br|/p|/h[1-6]|/li|/blockquote|/div|/tr|/figcaption)[^>]*>}i, "\n")
      text = ActionController::Base.helpers.strip_tags(text).to_s
      text.split("\n").map(&:strip).join("\n").gsub(/\n{3,}/, "\n\n").strip
    end

    class << self
      private

      def tokenize(text)
        text.to_s.scan(/\S+|\s+/)
      end

      def common_prefix_length(a, b)
        limit = [ a.length, b.length ].min
        (0...limit).each { |i| return i if a[i] != b[i] }
        limit
      end

      def common_suffix_length(a, b, prefix)
        limit = [ a.length, b.length ].min - prefix
        (0...limit).each { |i| return i if a[a.length - 1 - i] != b[b.length - 1 - i] }
        limit
      end

      def diff_middle(a, b)
        return [] if a.empty? && b.empty?
        return [ [ :ins, b.join ] ] if a.empty?
        return [ [ :del, a.join ] ] if b.empty?
        if a.length > TOKEN_LIMIT || b.length > TOKEN_LIMIT
          return [ [ :del, a.join ], [ :ins, b.join ] ]
        end

        lcs_segments(a, b)
      end

      # Standard LCS dynamic program with backtracking; inputs are bounded by
      # TOKEN_LIMIT after prefix/suffix trimming.
      def lcs_segments(a, b)
        rows = a.length + 1
        cols = b.length + 1
        table = Array.new(rows) { Array.new(cols, 0) }

        (a.length - 1).downto(0) do |i|
          (b.length - 1).downto(0) do |j|
            table[i][j] = if a[i] == b[j]
              table[i + 1][j + 1] + 1
            else
              [ table[i + 1][j], table[i][j + 1] ].max
            end
          end
        end

        segments = []
        i = 0
        j = 0
        while i < a.length && j < b.length
          if a[i] == b[j]
            segments << [ :eq, a[i] ]
            i += 1
            j += 1
          elsif table[i + 1][j] >= table[i][j + 1]
            segments << [ :del, a[i] ]
            i += 1
          else
            segments << [ :ins, b[j] ]
            j += 1
          end
        end
        segments.concat(a[i..].map { |token| [ :del, token ] })
        segments.concat(b[j..].map { |token| [ :ins, token ] })
        segments
      end

      def merge_segments(segments)
        segments.each_with_object([]) do |(op, text), merged|
          next if text.empty?

          if merged.last && merged.last[0] == op
            merged.last[1] += text
          else
            merged << [ op, text.dup ]
          end
        end
      end
    end
  end
end
