require "fileutils"

namespace :plum do
  desc "Build Tailwind and copy the result into Plum's packaged stylesheet"
  task build_styles: :environment do
    system(Rails.root.join("bin/rails").to_s, "tailwindcss:build", exception: true)
    source = Rails.root.join("app/assets/builds/tailwind.css")
    destination = Rails.root.join("app/assets/stylesheets/plum/control_panel.css")
    FileUtils.cp(source, destination)
    puts "Packaged #{destination.relative_path_from(Rails.root)}"
  end
end
