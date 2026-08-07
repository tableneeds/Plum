# Create admin user
admin = Plum::User.find_or_initialize_by(email: "admin@example.com")
seed_password = Rails.env.production? ? ENV.fetch("PLUM_ADMIN_PASSWORD") : "password"
admin.password = seed_password
admin.role = :admin
admin.save!
puts Rails.env.production? ? "Created admin user: admin@example.com" : "Created admin user: admin@example.com / password"

# Create standalone site
plum_site = Plum::Site.first_or_create_standalone!
plum_site.update!(name: "My Plum Site", theme_name: "default")
puts "Created Plum site"

# Create site settings
site = Plum::SiteSetting.instance(plum_site)
site.update!(
  name: "My Plum Site",
  tagline: "A fresh CMS experience",
  seo_title: "My Plum Site",
  seo_description: "Welcome to my website powered by Plum CMS",
  primary_color: "#7c3aed",
  support_email: "support@example.com"
)
puts "Created site settings"

# Create Pages content type
pages = plum_site.content_types.find_or_create_by!(handle: "pages") do |ct|
  ct.name = "Pages"
  ct.blueprint = {
    "fields" => [
      { "handle" => "basics", "type" => "section", "label" => "Basic fields", "instructions" => "Section fields organize the editing form without storing entry data." },
      { "handle" => "hero_image", "type" => "image", "label" => "Hero Image" },
      { "handle" => "body", "type" => "rich_text", "label" => "Body" }
    ]
  }
  ct.icon = "page"
end
puts "Created 'Pages' content type"

# Create Blog Posts content type
posts = plum_site.content_types.find_or_create_by!(handle: "posts") do |ct|
  ct.name = "Blog Posts"
  ct.blueprint = {
    "fields" => [
      { "handle" => "hero_image", "type" => "image", "label" => "Hero Image" },
      { "handle" => "body", "type" => "rich_text", "label" => "Body" },
      { "handle" => "excerpt", "type" => "textarea", "label" => "Excerpt" }
    ]
  }
  ct.icon = "document"
end
puts "Created 'Blog Posts' content type"

# Create a sample page
about_page = plum_site.entries.find_or_create_by!(slug: "about") do |e|
  e.content_type = pages
  e.author = admin
  e.title = "About"
  e.status = :published
  e.published_at = Time.current
  e.data = {
    "body" => "<p>Plum is a small Rails-native CMS for calm websites, reusable themes, and client-friendly editing.</p>"
  }
end
puts "Created sample page: /about"

# Create a sample blog post
entry = plum_site.entries.find_or_create_by!(slug: "hello-world") do |e|
  e.content_type = posts
  e.author = admin
  e.title = "Hello World"
  e.status = :published
  e.published_at = Time.current
  e.data = {
    "body" => "<h2>Welcome to Plum CMS</h2><p>This is your first blog post. You can edit it from the control panel.</p><p>Plum uses <strong>Liquid templates</strong> to render your content, giving you full control over your site's appearance.</p><ul><li>Easy to use control panel</li><li>Flexible content types</li><li>Liquid templating</li></ul>",
    "excerpt" => "This is your first blog post created with Plum CMS."
  }
end
puts "Created sample entry: /hello-world"

# Create a Landing Pages content type that uses the blocks (page builder) field
landing = plum_site.content_types.find_or_create_by!(handle: "landing") do |ct|
  ct.name = "Landing Pages"
  ct.blueprint = {
    "fields" => [
      { "handle" => "sections", "type" => "blocks", "label" => "Sections" }
    ]
  }
  ct.icon = "layout"
end
puts "Created 'Landing Pages' content type"

plum_site.entries.find_or_create_by!(slug: "welcome") do |e|
  e.content_type = landing
  e.author = admin
  e.title = "Welcome"
  e.status = :published
  e.published_at = Time.current
  e.data = {
    "sections" => [
      { "id" => SecureRandom.uuid, "type" => "hero",
        "fields" => { "heading" => "Welcome to Plum", "subheading" => "This page is built from blocks." } },
      { "id" => SecureRandom.uuid, "type" => "rich_text",
        "fields" => { "body" => "<p>Blocks are defined by the <strong>theme</strong> and arranged in the control panel.</p>" } }
    ]
  }
end
puts "Created landing page: /welcome"

# Create a field laboratory containing every registered blueprint field type.
# This gives developers and designers one predictable place to exercise the
# complete editor without rebuilding a content model by hand.
topics = plum_site.taxonomies.find_or_initialize_by(handle: "showcase_topics")
topics.update!(name: "Showcase Topics", slug: "showcase-topics")
design_term = topics.terms.find_or_initialize_by(slug: "design-systems")
design_term.update!(site: plum_site, name: "Design Systems")

showcase_image = plum_site.assets.find_by(folder: "field-showcase", alt_text: "Plum field showcase image")
unless showcase_image
  showcase_image = plum_site.assets.build(folder: "field-showcase", alt_text: "Plum field showcase image")
  showcase_image.file.attach(
    io: File.open(Rails.root.join("app/assets/images/plum-mark.svg")),
    filename: "plum-mark.svg",
    content_type: "image/svg+xml"
  )
  showcase_image.save!
end

field_showcase = plum_site.content_types.find_or_initialize_by(handle: "field_showcase")
field_showcase.update!(
  name: "Field Showcase",
  icon: "code",
  blueprint: {
    "fields" => [
      { "handle" => "showcase_basics", "type" => "section", "label" => "Basic fields", "instructions" => "Section fields organize the editing form without storing entry data." },
      { "handle" => "headline", "type" => "text", "label" => "Text", "instructions" => "Use for short, unformatted values such as names, headlines, identifiers, or labels.", "required" => true, "placeholder" => "Write a headline" },
      { "handle" => "summary", "type" => "textarea", "label" => "Textarea", "instructions" => "Use for longer plain-text content that does not need formatting, such as summaries or notes." },
      { "handle" => "body", "type" => "rich_text", "label" => "Rich Text", "instructions" => "Use for authored content requiring headings, links, lists, quotations, tables, or inline images." },
      { "handle" => "rating", "type" => "number", "label" => "Number", "instructions" => "Use for quantities, prices, scores, measurements, or other values requiring numeric validation.", "number_kind" => "decimal", "min" => "0", "max" => "10", "step" => "0.5", "unit" => "points" },
      { "handle" => "featured", "type" => "boolean", "label" => "Boolean", "instructions" => "Use for a simple yes-or-no state, such as featured, enabled, promoted, or complete." },
      { "handle" => "event_at", "type" => "date", "label" => "Date and Time", "instructions" => "Use for scheduled dates, times, deadlines, event starts, or other temporal values.", "date_mode" => "datetime", "min" => "2026-01-01T00:00" },
      { "handle" => "audience", "type" => "select", "label" => "Select", "instructions" => "Use when an editor must choose exactly one value from a controlled list.", "options" => [ { "label" => "Everyone", "value" => "everyone" }, { "label" => "Developers", "value" => "developers" }, { "label" => "Editors", "value" => "editors" } ] },
      { "handle" => "priority", "type" => "radio", "label" => "Radio", "instructions" => "Use when every available single-choice option should remain visible.", "options" => [ "Low", "Normal", "High" ], "width" => 6 },
      { "handle" => "layout", "type" => "button_group", "label" => "Button Group", "instructions" => "Use for compact visual choices with a small, familiar option set.", "options" => [ { "label" => "Editorial", "value" => "editorial" }, { "label" => "Feature", "value" => "feature" } ], "width" => 6 },
      { "handle" => "channels", "type" => "checkboxes", "label" => "Checkboxes", "instructions" => "Use when an editor may choose several values from a controlled list.", "options" => [ { "label" => "Website", "value" => "web" }, { "label" => "Email newsletter", "value" => "email" }, { "label" => "Social media", "value" => "social" } ] },
      { "handle" => "accent", "type" => "color", "label" => "Color", "instructions" => "Use for theme accents, backgrounds, labels, or other editor-selected colors." },
      { "handle" => "reference_url", "type" => "url", "label" => "URL", "instructions" => "Use for validated web addresses such as external links, sources, or calls to action.", "placeholder" => "https://example.com" },
      { "handle" => "topics", "type" => "taxonomy", "label" => "Taxonomy", "instructions" => "Use to classify entries with centrally managed categories, topics, tags, or other terms.", "taxonomy" => topics.handle },
      { "handle" => "cover", "type" => "image", "label" => "Image", "instructions" => "Use for a single reusable image with alt text, metadata, and generated size variants." },
      { "handle" => "gallery", "type" => "images", "label" => "Images", "instructions" => "Use for an ordered gallery or other multi-image collection.", "min_items" => 1, "max_items" => 6 },
      { "handle" => "related_post", "type" => "relationship", "label" => "Relationship", "instructions" => "Use to connect this entry to another entry and expose its content in templates.", "content_type" => posts.handle },
      { "handle" => "sections", "type" => "blocks", "label" => "Blocks", "instructions" => "Use for flexible page layouts assembled from reusable, theme-defined content sections." },
      { "handle" => "keywords", "type" => "list", "label" => "List", "instructions" => "Use for an ordered collection of simple values, such as keywords, features, or aliases.", "min_items" => 1, "max_items" => 5, "unique" => true },
      { "handle" => "contact", "type" => "group", "label" => "Group", "instructions" => "Use to keep one set of related named values together as a structured object.", "fields" => [
        { "handle" => "name", "type" => "text", "label" => "Name", "instructions" => "The contact's display name.", "required" => true },
        { "handle" => "email", "type" => "text", "label" => "Email", "instructions" => "The contact's email address." },
        { "handle" => "available", "type" => "boolean", "label" => "Available", "instructions" => "Whether this contact is currently available." }
      ] },
      { "handle" => "speakers", "type" => "repeater", "label" => "Repeater", "instructions" => "Use for an ordered collection of structured rows, such as people, locations, or pricing tiers.", "min_items" => 1, "max_items" => 4, "fields" => [
        { "handle" => "name", "type" => "text", "label" => "Name", "instructions" => "The speaker's public name.", "required" => true },
        { "handle" => "role", "type" => "text", "label" => "Role", "instructions" => "The speaker's role in the event." },
        { "handle" => "sessions", "type" => "number", "label" => "Sessions", "instructions" => "How many sessions this speaker leads." },
        { "handle" => "confirmed", "type" => "boolean", "label" => "Confirmed", "instructions" => "Whether the speaker has confirmed participation." }
      ] }
    ]
  }
)

showcase_entry = plum_site.entries.find_or_initialize_by(slug: "field-showcase")
showcase_entry.assign_attributes(
  content_type: field_showcase,
  author: admin,
  title: "Every Blueprint Field",
  status: :draft,
  data: {
    "headline" => "Plum's complete field laboratory",
    "summary" => "Representative values for every blueprint field supported by Plum.",
    "body" => "<h2>Rich content</h2><p>This entry is safe to edit, rearrange, and experiment with.</p>",
    "rating" => 8.5,
    "featured" => true,
    "event_at" => "2026-09-15T10:30",
    "audience" => "developers",
    "priority" => "Normal",
    "layout" => "editorial",
    "channels" => [ "web", "email" ],
    "accent" => "#7c3aed",
    "reference_url" => "https://plumcms.org",
    "cover" => showcase_image.id,
    "gallery" => [ showcase_image.id ],
    "related_post" => entry.id,
    "sections" => [
      { "id" => SecureRandom.uuid, "type" => "hero", "fields" => { "heading" => "Blocks field", "subheading" => "Reorder this section in the editor." } },
      { "id" => SecureRandom.uuid, "type" => "cta", "fields" => { "heading" => "Try every field", "text" => "Nothing here is precious." } }
    ],
    "keywords" => [ "blueprints", "fields", "structured-content" ],
    "contact" => { "name" => "Ada Editor", "email" => "ada@example.com", "available" => true },
    "speakers" => [
      { "name" => "Grace Hopper", "role" => "Keynote", "sessions" => "1", "confirmed" => true },
      { "name" => "Alan Turing", "role" => "Panelist", "sessions" => "2", "confirmed" => false }
    ]
  }
)
showcase_entry.save!
showcase_entry.term_ids = [ design_term.id ]
puts "Created field showcase with all #{Plum::FieldTypeRegistry.handles.size} blueprint field types"

company = plum_site.globals.find_or_create_by!(handle: "company") do |global|
  global.name = "Company Info"
end
company.update!(
  name: "Company Info",
  data: {
    "phone" => "555-0100",
    "address" => "123 Plum Street"
  }
)
puts "Created company global"

main_nav = plum_site.nav_menus.find_or_initialize_by(handle: "main")
main_nav.update!(name: "Main")

home_item = main_nav.nav_items.find_or_initialize_by(label: "Home")
home_item.update!(site: plum_site, url: "/", entry: nil, parent: nil, position: 1)

about_item = main_nav.nav_items.find_or_initialize_by(label: "About")
about_item.update!(site: plum_site, url: nil, entry: about_page, parent: nil, position: 2)

blog_item = main_nav.nav_items.find_or_initialize_by(label: "Blog")
blog_item.update!(site: plum_site, url: nil, entry: entry, parent: nil, position: 3)
puts "Created main navigation"

contact_form = plum_site.form_definitions.find_or_initialize_by(handle: "contact")
contact_form.update!(
  name: "Contact",
  notification_email: site.support_email,
  fields: [
    { "handle" => "name", "type" => "text", "label" => "Name", "required" => true, "options" => [] },
    { "handle" => "email", "type" => "email", "label" => "Email", "required" => true, "options" => [] },
    { "handle" => "message", "type" => "textarea", "label" => "Message", "required" => true, "options" => [] }
  ]
)
puts "Created contact form"

puts "\n✓ Seeds complete!"
puts "Login at: http://localhost:3000/login"
puts "View your page at: http://localhost:3000/about"
puts "View your post at: http://localhost:3000/hello-world"
