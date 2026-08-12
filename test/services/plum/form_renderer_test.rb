require "test_helper"

module Plum
  class FormRendererTest < ActiveSupport::TestCase
    test "renders a public form from Liquid form context" do
      html = FormRenderer.new(
        {
          "name" => "Contact",
          "handle" => "contact",
          "action" => "/forms/contact",
          "return_to" => "/",
          "fields" => [
            { "handle" => "email", "type" => "email", "label" => "Email", "required" => true, "options" => [] },
            { "handle" => "topic", "type" => "select", "label" => "Topic", "required" => false, "options" => [ "Catering" ] }
          ]
        }
      ).render

      assert_includes html, 'method="post"'
      assert_includes html, 'action="/forms/contact"'
      assert_includes html, 'name="form_submission[website]"'
      refute_includes html, "authenticity_token"
      assert_includes html, 'name="form_submission[data][email]"'
      assert_includes html, 'type="email"'
      assert_includes html, "Catering"
    end
  end
end
