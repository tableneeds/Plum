require "erb"

module Plum
  class ThemeAssetPath
    class UnsafePathError < StandardError; end

    class << self
      def normalize(path)
        raw_path = path.to_s
        raise UnsafePathError, "Theme asset path cannot be blank" if raw_path.blank?
        raise UnsafePathError, "Theme asset path cannot contain null bytes" if raw_path.include?("\0")

        parts = raw_path.split("/").reject(&:blank?)
        if Pathname(raw_path).absolute? || parts.any? { |part| part == "." || part == ".." }
          raise UnsafePathError, "Theme asset path must stay inside the theme assets directory"
        end

        parts.join("/")
      end

      def url(base_url:, path:)
        encoded_path = normalize(path).split("/").map { |part| ERB::Util.url_encode(part) }.join("/")

        "#{base_url.to_s.chomp("/")}/#{encoded_path}"
      rescue UnsafePathError
        ""
      end
    end
  end
end
