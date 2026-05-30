require "test_helper"
require "tmpdir"
require "zip"

module Plum
  class ThemePackageInstallerTest < ActiveSupport::TestCase
    test "installs a valid theme package" do
      with_theme_package do |zip_path, install_root|
        build_theme_zip(zip_path)

        installer = ThemePackageInstaller.new(zip_path, install_root: install_root)

        assert installer.install, installer.errors.join(", ")
        assert_equal "Counter Theme", installer.theme.name
        assert_equal "counter-theme", installer.theme.handle
        assert install_root.join("counter-theme/theme.yml").file?
        assert install_root.join("counter-theme/templates/index.liquid").file?
        assert install_root.join("counter-theme/assets/theme.css").file?
      end
    end

    test "installs a package wrapped in one top-level directory" do
      with_theme_package do |zip_path, install_root|
        build_theme_zip(zip_path, root: "counter-theme")

        installer = ThemePackageInstaller.new(zip_path, install_root: install_root)

        assert installer.install, installer.errors.join(", ")
        assert install_root.join("counter-theme/theme.yml").file?
      end
    end

    test "rejects packages without a manifest" do
      with_theme_package do |zip_path, install_root|
        build_zip(zip_path, "templates/index.liquid" => "Hello")

        installer = ThemePackageInstaller.new(zip_path, install_root: install_root)

        refute installer.install
        assert_includes installer.errors, "Theme package must contain theme.yml at the root"
      end
    end

    test "rejects packages with invalid handles" do
      with_theme_package do |zip_path, install_root|
        build_theme_zip(zip_path, manifest: "name: Bad\nhandle: Bad Handle\n")

        installer = ThemePackageInstaller.new(zip_path, install_root: install_root)

        refute installer.install
        assert_includes installer.errors, "theme.yml handle must use lowercase letters, numbers, and hyphens"
      end
    end

    test "rejects packages without Liquid templates or layouts" do
      with_theme_package do |zip_path, install_root|
        build_zip(zip_path, "theme.yml" => default_manifest, "assets/theme.css" => "body {}")

        installer = ThemePackageInstaller.new(zip_path, install_root: install_root)

        refute installer.install
        assert_includes installer.errors, "Theme package must include at least one Liquid layout or template"
      end
    end

    test "rejects duplicate theme handles" do
      with_theme_package do |zip_path, install_root|
        install_root.join("counter-theme").mkpath
        build_theme_zip(zip_path)

        installer = ThemePackageInstaller.new(zip_path, install_root: install_root)

        refute installer.install
        assert_includes installer.errors, "Theme counter-theme is already installed"
      end
    end

    test "rejects path traversal entries" do
      with_theme_package do |zip_path, install_root|
        build_theme_zip(zip_path, extra_files: { "../evil.txt" => "nope" })

        installer = ThemePackageInstaller.new(zip_path, install_root: install_root)

        refute installer.install
        assert installer.errors.any? { |error| error.include?("must stay inside") }
        refute install_root.parent.join("evil.txt").exist?
      end
    end

    private

    def with_theme_package
      Dir.mktmpdir("plum-theme-package-test") do |dir|
        root = Pathname(dir)
        yield root.join("theme.zip"), root.join("themes")
      end
    end

    def build_theme_zip(zip_path, root: nil, manifest: default_manifest, extra_files: {})
      files = {
        "theme.yml" => manifest,
        "layouts/base.liquid" => "<main>{{ content }}</main>",
        "templates/index.liquid" => "Counter theme",
        "assets/theme.css" => "body { color: #222; }"
      }.merge(extra_files)

      files = files.transform_keys { |path| root ? "#{root}/#{path}" : path }

      build_zip(zip_path, files)
    end

    def build_zip(zip_path, files)
      Zip::File.open(zip_path, create: true) do |zip|
        files.each do |path, content|
          zip.get_output_stream(path) { |stream| stream.write(content) }
        end
      end
    end

    def default_manifest
      <<~YAML
        name: Counter Theme
        handle: counter-theme
        version: 1.0.0
      YAML
    end
  end
end
