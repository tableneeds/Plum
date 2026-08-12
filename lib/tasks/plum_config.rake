# This repo is both the engine and an app, so Rails loads lib/tasks twice
# (engine railtie + application). Rake appends actions on re-definition, which
# would run every task body twice — guard against the second load.
unless Rake::Task.task_defined?("plum:config:export")
  namespace :plum do
    namespace :config do
      def plum_config_site
        site = ENV["SITE_ID"].present? ? Plum::Site.find(ENV["SITE_ID"]) : Plum::Site.first
        abort "No Plum site exists" unless site
        site
      end

      def plum_config_dir
        ENV["DIR"].presence || Plum.configuration.config_path || Rails.root.join("plum")
      end

      desc "Write the content model (content types, fieldsets) to YAML files (SITE_ID optional; DIR defaults to plum/)"
      task export: :environment do
        files = Plum::ConfigSync.export(site: plum_config_site, dir: plum_config_dir)
        puts "Exported #{files.length} config files to #{plum_config_dir}"
      end

      desc "Apply YAML config files to the database (SITE_ID optional; PRUNE=1 deletes types absent from files; FORCE=1 allows deleting types with entries)"
      task sync: :environment do
        result = Plum::ConfigSync.apply(
          site: plum_config_site,
          dir: plum_config_dir,
          prune: ENV["PRUNE"].present?,
          force: ENV["FORCE"].present?
        )
        puts "Config sync: #{result.summary}"
      rescue Plum::ConfigSync::UnsafePruneError => e
        abort e.message
      end

      desc "Fail if the database content model has drifted from the YAML files (for CI)"
      task check: :environment do
        drift = Plum::ConfigSync.check(site: plum_config_site, dir: plum_config_dir)
        if drift.any?
          drift.each { |line| puts "DRIFT #{line}" }
          abort "Content model has drifted from config files (#{drift.length} differences)"
        else
          puts "Content model matches config files"
        end
      end
    end
  end
end
