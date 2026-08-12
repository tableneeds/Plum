module Plum
  # Flushes the static page cache whenever content that appears in rendered
  # pages changes. Flushing is deletion-only and per-site, so being liberal
  # here costs one lazy re-render per page, never a wrong page.
  module StaticCacheInvalidation
    extend ActiveSupport::Concern

    included do
      after_commit :flush_plum_static_cache
    end

    # Columns that never appear in rendered pages — saves touching only these
    # (draft autosaves) keep the cache warm.
    CACHE_IRRELEVANT_COLUMNS = %w[draft_data updated_at].freeze

    private

    def flush_plum_static_cache
      return unless Plum::StaticCache.enabled?

      changed = respond_to?(:saved_changes) ? saved_changes.keys : []
      return if changed.present? && (changed - CACHE_IRRELEVANT_COLUMNS).empty?

      owner = is_a?(Plum::Site) ? self : (respond_to?(:site) ? site : nil)
      Plum::StaticCache.flush_site!(owner)
    rescue StandardError => e
      Rails.logger.error("[Plum] static cache flush failed: #{e.message}")
    end
  end
end
