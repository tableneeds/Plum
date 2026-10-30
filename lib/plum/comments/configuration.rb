module Plum
  module Comments
    class Configuration
      attr_accessor :enabled, :commenter_resolver, :moderator_resolver,
                    :author_name_resolver, :author_badge_resolver, :auto_approve,
                    :entry_authorizer, :login_url_resolver, :subject_url_resolver
      attr_reader :subjects, :renderer

      def initialize
        @enabled = false
        @renderer = :theme
        # Deliberately separate from CMS authentication. Hosts supply verified readers.
        @commenter_resolver = ->(_controller) { nil }
        @moderator_resolver = lambda { |controller, _site|
          user = Plum.current_user(controller)
          Plum.configuration.authorize_with == :plum && user.is_a?(Plum::User) && %w[editor admin].include?(user.role)
        }
        @author_name_resolver = ->(_author) { "Reader" }
        @author_badge_resolver = ->(_controller, _author) { nil }
        @auto_approve = ->(_controller, _author, _subject) { false }
        @entry_authorizer = ->(_controller, _action, _entry) { true }
        @login_url_resolver = ->(_controller) { nil }
        @subject_url_resolver = ->(_controller, _subject) { nil }
        @subjects = {}
      end

      def renderer=(value)
        raise ArgumentError, "Comments renderer must be theme or rails" unless %w[theme rails].include?(value.to_s)
        @renderer = value.to_sym
      end

      # The resolver must return a record from the host's authorized tenant scope.
      # Neither a model class nor a GlobalID is accepted from the HTTP client.
      def register(handle, resolve:, authorize:)
        key = handle.to_s
        unless key.match?(/\A[a-z][a-z0-9_]*\z/) && key != "entries"
          raise ArgumentError, "Use a lowercase subject handle other than entries"
        end
        @subjects[key] = { resolve: resolve, authorize: authorize }
      end
    end
  end
end
