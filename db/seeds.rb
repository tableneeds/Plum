# Create admin user
admin = Plum::User.find_or_create_by!(email: "admin@example.com") do |user|
  user.password = "password123"
  user.role = :admin
end
puts "Created admin user: admin@example.com / password123"

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
    "body" => "Plum is a small Rails-native CMS for calm websites, reusable themes, and client-friendly editing."
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
    "body" => "## Welcome to Plum CMS

This is your first blog post. You can edit it from the control panel.

Plum uses **Liquid templates** to render your content, giving you full control over your site's appearance.

- Easy to use control panel
- Flexible content types
- Liquid templating
- Markdown support",
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
        "fields" => { "body" => "Blocks are defined by the **theme** and arranged in the control panel." } }
    ]
  }
end
puts "Created landing page: /welcome"

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
