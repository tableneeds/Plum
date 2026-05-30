require_relative "lib/plum/version"

Gem::Specification.new do |spec|
  spec.name = "plum"
  spec.version = Plum::VERSION
  spec.authors = [ "Ben Simmons" ]
  spec.email = [ "ben@example.com" ]

  spec.summary = "A Rails-native CMS engine."
  spec.description = "Plum is a Rails-native CMS engine with Hotwire control panel, Liquid themes, and site-scoped content."
  spec.homepage = "https://example.com/plum"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z --cached --others --exclude-standard`.split("\x0").select do |path|
      File.file?(path) &&
        (path.match?(%r{\A(app/(assets|controllers/plum|helpers|javascript|models/plum|services/plum|themes|views/layouts/plum|views/plum)|config/locales|lib)/}) ||
          path == "config/plum_routes.rb" ||
          path == "README.md")
    end
  end

  spec.require_paths = [ "lib" ]

  spec.add_dependency "bcrypt", "~> 3.1"
  spec.add_dependency "importmap-rails", "~> 2.0"
  spec.add_dependency "liquid", "~> 5.0"
  spec.add_dependency "propshaft", "~> 1.0"
  spec.add_dependency "rails", ">= 8.0", "< 9.0"
  spec.add_dependency "redcarpet", "~> 3.6"
  spec.add_dependency "stimulus-rails", "~> 1.3"
  spec.add_dependency "tailwindcss-rails", "~> 4.0"
  spec.add_dependency "turbo-rails", "~> 2.0"
end
