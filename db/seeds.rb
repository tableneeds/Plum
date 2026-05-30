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

puts "\n✓ Seeds complete!"
puts "Login at: http://localhost:3000/login"
puts "View your page at: http://localhost:3000/about"
puts "View your post at: http://localhost:3000/hello-world"
