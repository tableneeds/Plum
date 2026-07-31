require "rails/generators"

module Plum
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      class_option :mount_path,
                   type: :string,
                   default: "/cms",
                   desc: "Path where Plum::Engine should be mounted"

      class_option :skip_route,
                   type: :boolean,
                   default: false,
                   desc: "Skip adding the Plum engine mount to config/routes.rb"

      def copy_initializer
        template "plum_initializer.rb", "config/initializers/plum.rb"
      end

      def copy_migrations
        rake "plum:install:migrations"
      end

      def create_theme_directory
        empty_directory "app/themes"
      end

      def mount_engine
        return if options[:skip_route]

        route %(mount Plum::Engine, at: "#{options[:mount_path]}")
      end

      def print_next_steps
        say <<~TEXT

          Plum is installed.

          Next steps:
            bin/rails active_storage:install  # if not already installed
            bin/rails db:migrate

          Plum is mounted at #{options[:mount_path]}.

          Migrations are copied to db/migrate/ and can be reviewed
          before running. JavaScript and CSS are served from the
          engine automatically.
        TEXT
      end
    end
  end
end
