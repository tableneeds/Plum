require "test_helper"

class PlumCmsEntrypointTest < ActiveSupport::TestCase
  test "package entrypoint loads Plum" do
    $LOAD_PATH.unshift Rails.root.join("compat").to_s
    assert_nothing_raised { require "plum-cms" }
    assert_equal "0.2.2", Plum::VERSION
  ensure
    $LOAD_PATH.delete(Rails.root.join("compat").to_s)
  end
end
