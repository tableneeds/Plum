require_relative "../static_cache"

module Plum
  module StaticCache
    # Serves cached pages before the request reaches Rails and captures
    # renders on the way out. Controllers opt responses in by setting the
    # X-Plum-Static-Cache header to "store" (see PagesController); everything
    # else passes through untouched.
    class Middleware
      MARKER = StaticCache::MARKER_HEADER.downcase

      def initialize(app)
        @app = app
      end

      def call(env)
        if StaticCache.enabled? && cacheable_request?(env) && (file = StaticCache.read(env["HTTP_HOST"], env["PATH_INFO"]))
          return serve(file, env)
        end

        status, headers, body = @app.call(env)
        maybe_store(env, status, headers, body)
      end

      private

      def cacheable_request?(env)
        return false unless env["REQUEST_METHOD"] == "GET" || env["REQUEST_METHOD"] == "HEAD"

        env["QUERY_STRING"].to_s.empty?
      end

      def serve(file, env)
        body = env["REQUEST_METHOD"] == "HEAD" ? [] : [ file.binread ]
        headers = {
          "content-type" => StaticCache.content_type_for(file),
          "content-length" => file.size.to_s,
          MARKER => "hit"
        }
        [ 200, headers, body ]
      end

      def maybe_store(env, status, headers, body)
        # The marker is internal — strip it even when the response isn't stored.
        marker = headers.delete(MARKER) || headers.delete(StaticCache::MARKER_HEADER)
        return [ status, headers, body ] unless marker == "store" && StaticCache.enabled? && cacheable_request?(env)
        return [ status, headers, body ] unless status == 200 && env["REQUEST_METHOD"] == "GET"
        return [ status, headers, body ] if headers["set-cookie"].present? || headers["Set-Cookie"].present?

        chunks = []
        body.each { |chunk| chunks << chunk.to_s }
        body.close if body.respond_to?(:close)
        full_body = chunks.join

        StaticCache.store(env["HTTP_HOST"], env["PATH_INFO"], full_body)
        headers[MARKER] = "miss"
        [ status, headers, [ full_body ] ]
      end
    end
  end
end
