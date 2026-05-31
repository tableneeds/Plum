module Plum
  # Engine-level "base" blocks: a small universal palette that exists on every
  # site regardless of theme. Themes can add their own blocks and can override a
  # base block by declaring the same handle (see Plum::BlockLibrary for the
  # merge/override rules). Keeping these in the engine means switching themes
  # never orphans content built from universal sections, and a bare theme still
  # gives owners a usable palette.
  #
  # Each definition matches the theme block shape (handle/label/fields), and each
  # has a matching Liquid partial keyed by handle. Field values are exposed to the
  # partial under `block` exactly like theme blocks.
  module BaseBlocks
    module_function

    DEFINITIONS = [
      {
        "handle" => "hero", "label" => "Hero",
        "fields" => [
          { "handle" => "heading", "type" => "text", "label" => "Heading" },
          { "handle" => "subheading", "type" => "textarea", "label" => "Subheading" },
          { "handle" => "image", "type" => "image", "label" => "Image" },
          { "handle" => "button_label", "type" => "text", "label" => "Button Label" },
          { "handle" => "button_url", "type" => "text", "label" => "Button URL" }
        ]
      },
      {
        "handle" => "rich_text", "label" => "Rich Text",
        "fields" => [
          { "handle" => "body", "type" => "rich_text", "label" => "Body" }
        ]
      },
      {
        "handle" => "image", "label" => "Image",
        "fields" => [
          { "handle" => "image", "type" => "image", "label" => "Image" },
          { "handle" => "caption", "type" => "text", "label" => "Caption" }
        ]
      },
      {
        "handle" => "image_text", "label" => "Image + Text",
        "fields" => [
          { "handle" => "heading", "type" => "text", "label" => "Heading" },
          { "handle" => "body", "type" => "rich_text", "label" => "Body" },
          { "handle" => "image", "type" => "image", "label" => "Image" },
          { "handle" => "image_position", "type" => "select", "label" => "Image Position",
            "options" => [ { "label" => "Left", "value" => "left" }, { "label" => "Right", "value" => "right" } ] }
        ]
      },
      {
        "handle" => "gallery", "label" => "Gallery",
        "fields" => [
          { "handle" => "heading", "type" => "text", "label" => "Heading" },
          { "handle" => "image_one", "type" => "image", "label" => "Image One" },
          { "handle" => "image_two", "type" => "image", "label" => "Image Two" },
          { "handle" => "image_three", "type" => "image", "label" => "Image Three" }
        ]
      },
      {
        "handle" => "cta", "label" => "Call to Action",
        "fields" => [
          { "handle" => "heading", "type" => "text", "label" => "Heading" },
          { "handle" => "text", "type" => "textarea", "label" => "Text" },
          { "handle" => "button_label", "type" => "text", "label" => "Button Label" },
          { "handle" => "button_url", "type" => "text", "label" => "Button URL" }
        ]
      },
      {
        "handle" => "button", "label" => "Button",
        "fields" => [
          { "handle" => "label", "type" => "text", "label" => "Label" },
          { "handle" => "url", "type" => "text", "label" => "URL" }
        ]
      },
      {
        "handle" => "spacer", "label" => "Spacer",
        "fields" => [
          { "handle" => "size", "type" => "select", "label" => "Size",
            "options" => [ { "label" => "Small", "value" => "small" }, { "label" => "Medium", "value" => "medium" }, { "label" => "Large", "value" => "large" } ] }
        ]
      }
    ].freeze

    TEMPLATES = {
      "hero" => <<~LIQUID,
        <section class="plum-block plum-block-hero">
          {% if block.heading %}<h2>{{ block.heading }}</h2>{% endif %}
          {% if block.subheading %}<p>{{ block.subheading }}</p>{% endif %}
          {% if block.image.url %}
            <img class="plum-block-hero-image" src="{{ block.image.url }}" alt="{{ block.image.alt_text | default: block.heading }}">
          {% endif %}
          {% if block.button_label and block.button_url %}
            <a class="plum-block-cta-button" href="{{ block.button_url }}">{{ block.button_label }}</a>
          {% endif %}
        </section>
      LIQUID
      "rich_text" => <<~LIQUID,
        <div class="plum-block plum-block-rich-text prose">
          {{ block.body | markdown }}
        </div>
      LIQUID
      "image" => <<~LIQUID,
        <figure class="plum-block plum-block-image">
          {% if block.image.url %}<img src="{{ block.image.url }}" alt="{{ block.image.alt_text | default: block.caption }}">{% endif %}
          {% if block.caption %}<figcaption>{{ block.caption }}</figcaption>{% endif %}
        </figure>
      LIQUID
      "image_text" => <<~LIQUID,
        <section class="plum-block plum-block-image-text plum-image-{{ block.image_position | default: 'left' }}">
          {% if block.image.url %}
            <div class="plum-block-image-text-media">
              <img src="{{ block.image.url }}" alt="{{ block.image.alt_text | default: block.heading }}">
            </div>
          {% endif %}
          <div class="plum-block-image-text-body">
            {% if block.heading %}<h2>{{ block.heading }}</h2>{% endif %}
            <div class="prose">{{ block.body | markdown }}</div>
          </div>
        </section>
      LIQUID
      "gallery" => <<~LIQUID,
        <section class="plum-block plum-block-gallery">
          {% if block.heading %}<h2>{{ block.heading }}</h2>{% endif %}
          <div class="plum-block-gallery-grid">
            {% if block.image_one.url %}<img src="{{ block.image_one.url }}" alt="{{ block.image_one.alt_text }}">{% endif %}
            {% if block.image_two.url %}<img src="{{ block.image_two.url }}" alt="{{ block.image_two.alt_text }}">{% endif %}
            {% if block.image_three.url %}<img src="{{ block.image_three.url }}" alt="{{ block.image_three.alt_text }}">{% endif %}
          </div>
        </section>
      LIQUID
      "cta" => <<~LIQUID,
        <section class="plum-block plum-block-cta">
          {% if block.heading %}<h2>{{ block.heading }}</h2>{% endif %}
          {% if block.text %}<p>{{ block.text }}</p>{% endif %}
          {% if block.button_label and block.button_url %}
            <a class="plum-block-cta-button" href="{{ block.button_url }}">{{ block.button_label }}</a>
          {% endif %}
        </section>
      LIQUID
      "button" => <<~LIQUID,
        <div class="plum-block plum-block-button">
          {% if block.label and block.url %}<a class="plum-block-cta-button" href="{{ block.url }}">{{ block.label }}</a>{% endif %}
        </div>
      LIQUID
      "spacer" => <<~LIQUID
        <div class="plum-block plum-block-spacer plum-spacer-{{ block.size | default: 'medium' }}"></div>
      LIQUID
    }.freeze

    def definitions
      DEFINITIONS
    end

    def definition(handle)
      DEFINITIONS.find { |definition| definition["handle"] == handle.to_s }
    end

    def template(handle)
      TEMPLATES[handle.to_s]
    end
  end
end
