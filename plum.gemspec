require_relative "lib/plum/version"

Gem::Specification.new do |spec|
  spec.name = "plum"
  spec.version = Plum::VERSION
  spec.authors = [ "Ben Simmons" ]
  spec.email = [ "ben@example.com" ]

  spec.summary = "A Rails-native CMS engine."
  spec.description = "Plum is a Rails-native CMS engine with Hotwire control panel, Liquid themes, and site-scoped content."
  spec.homepage = "https://plumcms.org"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["source_code_uri"] = "https://github.com/tableneeds/plum"
  spec.metadata["bug_tracker_uri"] = "https://github.com/tableneeds/plum/issues"

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "app/assets/**/*",
      "app/controllers/plum/**/*",
      "app/helpers/**/*",
      "app/javascript/**/*",
      "app/models/plum/**/*",
      "app/services/plum/**/*",
      "app/themes/**/*",
      "app/views/layouts/plum/**/*",
      "app/views/plum/**/*",
      "config/locales/**/*",
      "db/engine_migrate/**/*",
      "lib/**/*",
      "vendor/javascript/**/*",
      "config/plum_routes.rb",
      "config/plum_importmap.rb",
      "README.md"
    ].select { |path| File.file?(path) }.sort
  end

  spec.require_paths = [ "lib" ]

  spec.add_dependency "bcrypt", "~> 3.1"
  spec.add_dependency "importmap-rails", "~> 2.0"
  spec.add_dependency "liquid", "~> 5.0"
  spec.add_dependency "propshaft", "~> 1.0"
  spec.add_dependency "rails", ">= 8.0", "< 9.0"
  spec.add_dependency "redcarpet", "~> 3.6"
  spec.add_dependency "rubyzip", ">= 2.4", "< 4.0"
  spec.add_dependency "stimulus-rails", "~> 1.3"
  spec.add_dependency "tailwindcss-rails", "~> 4.0"
  spec.add_dependency "turbo-rails", "~> 2.0"
  spec.add_dependency "lexxy", "~> 0.1"
  spec.add_dependency "image_processing", "~> 1.2"
end
