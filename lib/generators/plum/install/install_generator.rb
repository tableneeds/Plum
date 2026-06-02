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

      def install_importmap
        return if destination_file_exists?("config/importmap.rb")

        rails_command "importmap:install"
      end

      def install_turbo
        return if destination_file_includes?("app/javascript/application.js", "@hotwired/turbo-rails")

        rails_command "turbo:install"
      end

      def install_stimulus
        return if destination_file_exists?("app/javascript/controllers/index.js")

        rails_command "stimulus:install"
      end

      def copy_javascript_controllers
        empty_directory "app/javascript/controllers/plum"

        Dir[Plum::Engine.root.join("app/javascript/controllers/plum/*.js")].each do |path|
          copy_file path, "app/javascript/controllers/plum/#{File.basename(path)}"
        end
      end

      def copy_vendor_files
        empty_directory "vendor/javascript"

        Dir[Plum::Engine.root.join("vendor/javascript/*.js")].each do |path|
          copy_file path, "vendor/javascript/#{File.basename(path)}"
        end
      end

      def setup_importmap_pins
        importmap_path = File.join(destination_root, "config/importmap.rb")
        return unless File.exist?(importmap_path)

        content = File.read(importmap_path)

        unless content.include?('"lexxy"')
          append_to_file "config/importmap.rb", %(pin "lexxy", to: "lexxy.js"\n)
        end

        unless content.include?('"@rails/activestorage"')
          append_to_file "config/importmap.rb", %(pin "@rails/activestorage", to: "activestorage.esm.js"\n)
        end
      end

      def setup_lexxy_import
        js_path = File.join(destination_root, "app/javascript/application.js")
        return unless File.exist?(js_path)

        content = File.read(js_path)

        unless content.include?('"lexxy"')
          append_to_file "app/javascript/application.js", <<~JS

            import "lexxy"

            document.addEventListener("turbo:submit-start", (event) => {
              event.target.querySelectorAll("lexxy-editor[data-hidden-field]").forEach((editor) => {
                const hidden = document.getElementById(editor.dataset.hiddenField)
                if (hidden) hidden.value = editor.value
              })
            })

            document.addEventListener("submit", (event) => {
              event.target.querySelectorAll("lexxy-editor[data-hidden-field]").forEach((editor) => {
                const hidden = document.getElementById(editor.dataset.hiddenField)
                if (hidden) hidden.value = editor.value
              })
            })
          JS
        end
      end

      def mount_engine
        return if options[:skip_route]

        route %(mount Plum::Engine, at: "#{options[:mount_path]}")
      end

      def print_next_steps
        say <<~TEXT

          Plum is installed.

          Next steps:
            bin/rails active_storage:install # if the host app has not installed Active Storage yet
            bin/rails db:migrate

          Plum is mounted at #{options[:mount_path]}.
        TEXT
      end

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      private

      def destination_file_exists?(path)
        File.exist?(File.join(destination_root, path))
      end

      def destination_file_includes?(path, content)
        destination_path = File.join(destination_root, path)

        File.exist?(destination_path) && File.read(destination_path).include?(content)
      end
    end
  end
end
