require "test_helper"

module Plum
  class FormDefinitionTest < ActiveSupport::TestCase
    test "generates a handle from the name" do
      site = Site.create!(name: "Bagel Boy", theme_name: "default", skip_defaults: true)
      form = site.form_definitions.create!(
        name: "Contact Us",
        fields: []
      )

      assert_equal "contact_us", form.handle
    end

    test "validates field handles and types" do
      site = Site.create!(name: "Bagel Boy", theme_name: "default", skip_defaults: true)
      form = site.form_definitions.build(
        name: "Contact",
        handle: "contact",
        fields: [
          { "handle" => "email", "type" => "email", "label" => "Email" },
          { "handle" => "email", "type" => "unknown", "label" => "Duplicate" }
        ]
      )

      refute form.valid?
      assert_includes form.errors[:fields], "email handle is duplicated"
      assert_includes form.errors[:fields], "email type is invalid"
    end
  end
end
