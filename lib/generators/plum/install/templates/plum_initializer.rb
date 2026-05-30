Plum.configure do |config|
  # Standalone/default mode: Plum manages its own site and users.
  config.current_site_resolver = ->(_controller) { Plum::Site.first_or_create_standalone! }
  config.current_user_resolver = lambda { |controller|
    Plum::User.find_by(id: controller.session[:plum_user_id]) if controller.session[:plum_user_id]
  }
  config.authorize_with = :plum

  # Host themes win first, bundled Plum themes provide the fallback.
  config.theme_paths = [
    Rails.root.join("app/themes"),
    Plum::Engine.root.join("app/themes")
  ]

  # Embedded host example:
  #
  # config.current_site_resolver = ->(_controller) { Current.restaurant.plum_site }
  # config.current_user_resolver = ->(_controller) { Current.user }
  # config.authorize_with = :host
  # config.register_content_source :restaurant, ->(context) { context.site.owner.to_liquid }
  # config.register_content_source :menu, TableNeeds::PlumAdapters::Menu
end
