module Plum
  module Comments
    class Context
      attr_reader :controller, :site, :subject, :handle

      def initialize(controller, handle:, id:, action: :read)
        @controller, @handle = controller, handle.to_s
        @site = Plum.current_site(controller)
        raise ActiveRecord::RecordNotFound unless config.enabled && site
        if @handle == "entries"
          @subject = site.entries.find(id)
          raise ActiveRecord::RecordNotFound unless action == :moderate || site.entries.live.exists?(subject.id)
          allowed = config.entry_authorizer.call(controller, action, subject)
          allowed &&= config.entry_authorizer.call(controller, :read, subject) unless action == :moderate
        else
          registration = config.subjects.fetch(@handle) { raise ActiveRecord::RecordNotFound }
          @subject = registration[:resolve].call(controller, site, id)
          allowed = subject && registration[:authorize].call(controller, action, subject)
          allowed &&= registration[:authorize].call(controller, :read, subject) unless action == :moderate
        end
        unless allowed && subject.is_a?(Plum::Commentable) && subject.plum_comment_site == site && (action == :moderate || subject.plum_comments_enabled?)
          raise ActiveRecord::RecordNotFound
        end
      end

      def config
        Plum.configuration.comments
      end

      def discussion
        @discussion ||= site.discussions.find_by(commentable: subject)
      end

      def open?
        !!(subject.plum_comments_open? && !discussion&.closed?)
      end

      def author
        @author ||= config.commenter_resolver.call(controller)
      end

      def author_gid
        self.class.identity(author)
      end

      def self.identity(author)
        author.to_global_id.to_s if author.respond_to?(:persisted?) && author.persisted? && author.respond_to?(:to_global_id)
      end

      def create_comment!(attributes)
        raise ActiveRecord::RecordNotFound unless author_gid && open?
        thread = discussion || site.discussions.create_or_find_by!(commentable: subject) { |record| record.subject_handle = handle }
        thread.with_lock do
          raise ActiveRecord::RecordNotFound if thread.closed? || !subject.reload.plum_comments_open?
          # Serialize posting per discussion; the host may apply stricter account/IP limits.
          if thread.comments.where(author_gid: author_gid).where("created_at > ?", 10.seconds.ago).exists?
            raise RateLimited
          end
          parent = attributes[:parent_id].presence && thread.comments.publicly_visible.find(attributes[:parent_id])
          thread.comments.create!(attributes.except(:parent_id).merge(
            parent: parent, author_gid: author_gid,
            author_name: config.author_name_resolver.call(author),
            author_badge: config.author_badge_resolver.call(controller, author),
            status: config.auto_approve.call(controller, author, subject) ? "approved" : "pending"
          ))
        end
      end
    end
  end
end
