require "test_helper"

module Plum
  class LiquidFiltersTest < ActiveSupport::TestCase
    include LiquidFilters

    test "table of contents links to second and third level headings" do
      html = '<h2 id="install">Install</h2><p>First step.</p><h3 id="database">Database</h3>'

      toc = table_of_contents(html)

      assert_includes toc, "On this page"
      assert_includes toc, 'href="#install"'
      assert_includes toc, 'class="toc-h3"'
      assert_includes toc, 'href="#database"'
    end
  end
end
