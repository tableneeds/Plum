# This repo is both the engine and an app, so Rails loads lib/tasks twice
# (engine railtie + application). Rake appends actions on re-definition, which
# would run every task body twice — guard against the second load.
unless Rake::Task.task_defined?("plum:site:export")
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

    namespace :site do
      desc "Replace the local site with an archive — the 'pull' refresh (ARCHIVE required; SITE_ID optional; FORCE=1 required in production)"
      task replace: :environment do
        path = ENV.fetch("ARCHIVE") { abort "ARCHIVE is required" }
        if Rails.env.production? && ENV["FORCE"].blank?
          abort "Refusing to replace a site in production (set FORCE=1 to override)"
        end

        old_site = ENV["SITE_ID"].present? ? Plum::Site.find(ENV["SITE_ID"]) : Plum::Site.first
        old_name = old_site&.name

        site = ActiveRecord::Base.transaction do
          old_site&.destroy!
          Plum::SiteArchive.load(path: path, name: ENV["NAME"], domain: ENV["DOMAIN"])
        end

        puts old_name ? "Replaced #{old_name} with #{site.name} (site #{site.id})" : "Imported #{site.name} as site #{site.id}"
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
end
