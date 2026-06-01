Plum.configure do |config|
  config.current_site_resolver = ->(_controller) { Plum::Site.first_or_create_standalone! }
  config.current_user_resolver = lambda { |controller|
    Plum::User.find_by(id: controller.session[:plum_user_id]) if controller.session[:plum_user_id]
  }
  config.authorize_with = :plum
  config.cp_name = "Table Needs"
  config.cp_subtitle = "Website"
  config.cp_logo_path = "table-needs-logo.svg"
end
