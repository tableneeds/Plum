require "rails/generators"
require "rails/generators/active_record"

module Plum
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

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

      def copy_migration
        migration_template "create_plum_tables.rb", "db/migrate/create_plum_tables.rb"
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
            bin/rails db:migrate
            bin/rails active_storage:install # if the host app has not installed Active Storage yet

          Plum is mounted at #{options[:mount_path]}.
        TEXT
      end

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end
    end
  end
end
