namespace :plum do
  namespace :site do
    desc "Export a complete Plum site archive (SITE_ID or first site; ARCHIVE required)"
    task export: :environment do
      path = ENV.fetch("ARCHIVE") { abort "ARCHIVE is required" }
      site = ENV["SITE_ID"].present? ? Plum::Site.find(ENV["SITE_ID"]) : Plum::Site.first
      abort "No Plum site exists" unless site

      archive = Plum::SiteArchive.dump(site: site, path: path)
      puts "Exported #{site.name} to #{archive}"
    end

    desc "Import a Plum site archive as a new site (ARCHIVE required; NAME and DOMAIN optional)"
    task import: :environment do
      path = ENV.fetch("ARCHIVE") { abort "ARCHIVE is required" }
      site = Plum::SiteArchive.load(path: path, name: ENV["NAME"], domain: ENV["DOMAIN"])
      puts "Imported #{site.name} as site #{site.id}"
    end
  end

  namespace :backup do
    desc "Create a timestamped Plum site backup (SITE_ID optional; DIRECTORY defaults to backups/plum)"
    task create: :environment do
      site = ENV["SITE_ID"].present? ? Plum::Site.find(ENV["SITE_ID"]) : Plum::Site.first
      abort "No Plum site exists" unless site
      directory = Rails.root.join(ENV.fetch("DIRECTORY", "backups/plum"))
      filename = "plum-site-#{site.id}-#{Time.current.utc.strftime('%Y%m%d%H%M%S')}.plum.zip"
      archive = Plum::SiteArchive.dump(site: site, path: directory.join(filename))
      puts "Backed up #{site.name} to #{archive}"
    end

    desc "Restore a Plum backup as a new site (ARCHIVE required; NAME and DOMAIN optional)"
    task restore: :environment do
      Rake::Task["plum:site:import"].invoke
    end
  end
end
