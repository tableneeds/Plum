require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Browser requests use a separate connection, so their writes are not rolled
  # back with the test transaction on SQLite. Keep every system example isolated
  # explicitly; otherwise fixed blueprint handles leak into the next example.
  setup do
    Plum::Site.find_each(&:destroy!)
    Plum::User.delete_all
    Plum::Site.create!(name: "My Site", theme_name: "default", skip_defaults: true)
  end
end
