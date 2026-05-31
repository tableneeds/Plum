# Bagel Boy dogfood site seed. Idempotent — safe to re-run.
#   RAILS_ENV=development bin/rails runner db/seeds/bagel_boy.rb
# (Specify the env — a plain `bin/rails runner` may target the test database.)
require "securerandom"

site = Plum::Site.first_or_create_standalone!
site.update!(
  name: "Bagel Boy",
  theme_name: "bagel-boy",
  # reset to brand defaults (clears any older accent/secondary from prior runs)
  theme_settings: { "accent_color" => "#FB404C", "secondary_color" => "#FDC694", "show_powered_by" => true }
)

settings = Plum::SiteSetting.instance(site)
settings.update!(
  name: "Bagel Boy",
  tagline: "Boiled, baked, and made with love.",
  theme_name: "bagel-boy",
  seo_title: "Bagel Boy",
  seo_description: "Hand-rolled bagels and good coffee in the neighborhood.",
  support_email: "hello@bagelboy.example"
)

admin = Plum::User.find_or_create_by!(email: "admin@example.com") do |u|
  u.password = "password123"
  u.role = :admin
end

def block(type, fields)
  { "id" => SecureRandom.uuid, "type" => type, "fields" => fields }
end

# Pages: a blocks-driven content type. The homepage is just the page slugged
# "home" (convention) — no special content type.
pages_type = site.content_types.find_or_create_by!(handle: "pages") do |ct|
  ct.name = "Pages"
  ct.blueprint = { "fields" => [ { "handle" => "sections", "type" => "blocks", "label" => "Sections" } ] }
  ct.icon = "page"
end
# Ensure the pages type has a sections (blocks) field even if it already existed.
unless pages_type.fields.any? { |f| f["type"] == "blocks" }
  fields = pages_type.fields + [ { "handle" => "sections", "type" => "blocks", "label" => "Sections" } ]
  pages_type.update!(blueprint: { "fields" => fields })
end

home = site.entries.find_or_initialize_by(slug: "home")
home.assign_attributes(
  content_type: pages_type,
  author: admin,
  title: "Home",
  status: :published,
  published_at: Time.current,
  data: {
    "sections" => [
      block("hero", {
        "heading" => "Bagel Boy",
        "subheading" => "Hand-rolled, kettle-boiled, and baked fresh every morning."
      }),
      block("cta", {
        "heading" => "Order ahead",
        "text" => "Skip the line — grab a dozen for the office or the family.",
        "button_label" => "Order Online",
        "button_url" => "#"
      }),
      block("rich_text", {
        "body" => "## Our Bagels\nEverything, sesame, poppy, plain, cinnamon raisin, and the weekend special."
      }),
      block("menu_item", { "name" => "Everything Bagel", "price" => "$2.50", "description" => "The classic, loaded with seeds." }),
      block("menu_item", { "name" => "Bacon Egg & Cheese", "price" => "$7.00", "description" => "On any bagel, with house spread." }),
      block("menu_item", { "name" => "Lox & Schmear", "price" => "$9.50", "description" => "Cream cheese, capers, red onion." }),
      block("hours", {
        "heading" => "Hours",
        "schedule" => "Mon–Fri   6:00a – 2:00p\nSat–Sun   7:00a – 3:00p"
      })
    ]
  }
)
home.save!

# Footer globals (merchant-editable in CP)
company = site.globals.find_or_initialize_by(handle: "company")
company.update!(name: "Company Info", data: { "address" => "123 Main St, Your Town", "phone" => "(555) 234-5678" })

social = site.globals.find_or_initialize_by(handle: "social")
social.update!(name: "Social", data: { "instagram" => "https://instagram.com/", "facebook" => "https://facebook.com/" })

# Nav
nav = site.nav_menus.find_or_initialize_by(handle: "main")
nav.update!(name: "Main")
[ [ "Home", "/", 1 ], [ "Order", "#", 2 ] ].each do |label, url, pos|
  item = nav.nav_items.find_or_initialize_by(label: label)
  item.update!(site: site, url: url, entry: nil, parent: nil, position: pos)
end

puts "✓ Bagel Boy site seeded. Theme=bagel-boy. Visit / to view; /cp to edit."
