module Plum
  class FormRenderer
    FIELD_CLASSES = "plum-form-field".freeze

    def initialize(form)
      @form = form
    end

    def render
      return "" if form.blank?

      <<~HTML
        <form class="plum-form" method="post" action="#{h(form['action'])}" data-plum-form-handle="#{h(form['handle'])}">
          #{hidden_inputs}
          #{fields_html}
          <button class="plum-form-submit" type="submit">Submit</button>
        </form>
      HTML
    end

    private

    attr_reader :form

    def hidden_inputs
      [
        hidden_input(form["csrf_param"], form["csrf_token"]),
        hidden_input("return_to", form["return_to"])
      ].compact.join("\n  ")
    end

    def fields_html
      Array(form["fields"]).map { |field| field_html(field) }.join("\n  ")
    end

    def field_html(field)
      handle = field["handle"].to_s
      type = field["type"].to_s
      label = field_label(field)
      input_id = "plum_form_#{form['handle']}_#{handle}"

      <<~HTML.strip
        <div class="#{FIELD_CLASSES}">
          <label for="#{h(input_id)}">#{h(label)}</label>
          #{input_html(field, input_id)}
        </div>
      HTML
    end

    def input_html(field, input_id)
      case field["type"]
      when "textarea"
        textarea_html(field, input_id)
      when "select"
        select_html(field, input_id)
      when "checkbox"
        checkbox_html(field, input_id)
      else
        text_input_html(field, input_id)
      end
    end

    def text_input_html(field, input_id)
      type = field["type"] == "email" ? "email" : "text"

      %(<input type="#{type}" id="#{h(input_id)}" name="#{field_name(field)}"#{required_attribute(field)}>)
    end

    def textarea_html(field, input_id)
      %(<textarea id="#{h(input_id)}" name="#{field_name(field)}"#{required_attribute(field)}></textarea>)
    end

    def select_html(field, input_id)
      options = Array(field["options"]).map do |option|
        %(<option value="#{h(option)}">#{h(option)}</option>)
      end.join

      %(<select id="#{h(input_id)}" name="#{field_name(field)}"#{required_attribute(field)}><option value=""></option>#{options}</select>)
    end

    def checkbox_html(field, input_id)
      <<~HTML.squish
        <input type="hidden" name="#{field_name(field)}" value="0">
        <input type="checkbox" id="#{h(input_id)}" name="#{field_name(field)}" value="1"#{required_attribute(field)}>
      HTML
    end

    def hidden_input(name, value)
      return if name.blank? || value.blank?

      %(<input type="hidden" name="#{h(name)}" value="#{h(value)}">)
    end

    def field_name(field)
      h("form_submission[data][#{field['handle']}]")
    end

    def field_label(field)
      field["label"].presence || field["handle"].to_s.humanize
    end

    def required_attribute(field)
      ActiveModel::Type::Boolean.new.cast(field["required"]) ? " required" : ""
    end

    def h(value)
      ERB::Util.html_escape(value.to_s)
    end
  end
end
