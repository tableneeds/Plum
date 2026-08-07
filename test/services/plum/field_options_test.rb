require "test_helper"

module Plum
  class FieldOptionsTest < ActiveSupport::TestCase
    test "converts legacy string options to label and value pairs" do
      assert_equal [ [ "Draft", "Draft" ] ], FieldOptions.pairs([ "Draft" ])
    end

    test "preserves separate labels and stored values" do
      options = [ { "label" => "Published article", "value" => "published" } ]

      assert_equal [ [ "Published article", "published" ] ], FieldOptions.pairs(options)
      assert_equal "Published article | published", FieldOptions.editor_value(options)
    end
  end
end
