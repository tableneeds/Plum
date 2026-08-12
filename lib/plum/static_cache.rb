require "rack/mime"

module Plum
  # Full-page static cache. Rendered public pages are written to disk keyed by
  # host + path; subsequent requests are served from the file without touching
  # the database or Liquid. A web server can serve the same files directly
  # (nginx try_files) for the "full measure" where Rails never sees the hit.
  #
  # Cache entries are invalidated by deletion (see StaticCacheInvalidation) —
  # the next request re-renders and re-stores the page. Over-flushing is cheap,
  # so anything ambiguous flushes the whole site.
  module StaticCache
    MARKER_HEADER = "X-Plum-Static-Cache".freeze

    class << self
      # Explicit opt-in only — see docs/static-caching.md. There is
      # deliberately no "auto-on in production" mode: this cache is only
      # correct on a single-server deployment, and defaulting it on would
      # silently corrupt pages the moment an app scales to 2+ nodes.
      def enabled?
        !!Plum.configuration.static_cache_enabled
      end

      def cache_root
        Pathname(Plum.configuration.static_cache_path || Rails.root.join("storage", "plum_static_cache"))
      end

      # Pages are stored as {host}/{path}/index.html so a web server can map
      # URLs to files directly. Paths with a file extension (theme assets) are
      # stored verbatim.
      def file_path(host, path)
        key = normalized_path(path)
        return nil unless key

        base = cache_root.join(sanitized_host(host))
        full = File.extname(key).present? ? base.join(key) : base.join(key, "index.html")
        full = Pathname(File.expand_path(full))
        return nil unless full.to_s.start_with?(cache_root.to_s + File::SEPARATOR)

        full
      end

      def read(host, path)
        file = file_path(host, path)
        file if file&.file?
      end

      def store(host, path, body)
        file = file_path(host, path)
        return unless file

        file.dirname.mkpath
        tmp = file.sub_ext(".tmp-#{Process.pid}-#{Thread.current.object_id}")
        tmp.binwrite(body)
        File.rename(tmp, file)
        file
      rescue SystemCallError => e
        Rails.logger.error("[Plum] static cache write failed for #{path}: #{e.message}")
        nil
      end

      def flush_site!(site)
        return flush_all! if site.nil? || site.domain.blank?

        [ site.domain, "www.#{site.domain}" ].each do |host|
          dir = cache_root.join(sanitized_host(host))
          FileUtils.rm_rf(dir) if dir.to_s.start_with?(cache_root.to_s) && dir.exist?
        end
      end

      def flush_all!
        return unless cache_root.exist?

        cache_root.children.each { |child| FileUtils.rm_rf(child) }
      end

      def content_type_for(file)
        Rack::Mime.mime_type(File.extname(file.to_s), "text/html")
      end

      private

      def sanitized_host(host)
        cleaned = host.to_s.downcase.gsub(/[^a-z0-9.\-]/, "")
        cleaned.presence || "_default"
      end

      # Rejects anything that could escape the cache directory and normalizes
      # "/" and "/about/" style paths to a shared key.
      def normalized_path(path)
        decoded = begin
          URI.decode_www_form_component(path.to_s)
        rescue ArgumentError
          return nil
        end
        return nil if decoded.include?("..") || decoded.include?("\0")

        trimmed = decoded.delete_prefix("/").chomp("/")
        trimmed.presence || "_root"
      end
    end
  end
end
