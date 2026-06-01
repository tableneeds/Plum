# Bagel Boy dogfood site seed. Idempotent — safe to re-run.
#   RAILS_ENV=development bin/rails runner db/seeds/bagel_boy.rb
# (Specify the env — a plain `bin/rails runner` may target the test database.)
#
# Copy is the real Bagel Boy brand voice. Image fields are left blank — add the
# food/award photos through the CP image picker. Order/EZ-catering links are "#"
# placeholders until the real URLs are wired.
require "securerandom"

site = Plum::Site.first_or_create_standalone!
site.update!(
  name: "Bagel Boy",
  theme_name: "bagel-boy",
  theme_settings: { "accent_color" => "#FB404C", "secondary_color" => "#FDC694", "show_powered_by" => true }
)

settings = Plum::SiteSetting.instance(site)
settings.update!(
  name: "Bagel Boy",
  tagline: "Your favorite bagel shop in Foley.",
  theme_name: "bagel-boy",
  seo_title: "Bagel Boy — Foley's Best Bagels",
  seo_description: "24-hour fermented, boiled-to-perfection bagels, coffee, and bakery in Foley. Three-time Best of Baldwin winner.",
  support_email: "hello@bagelboy.example"
)

admin = Plum::User.find_or_create_by!(email: "admin@example.com") do |u|
  u.password = "password123"
  u.role = :admin
end

def block(type, fields)
  { "id" => SecureRandom.uuid, "type" => type, "fields" => fields }
end

ORDER_URL = "#order".freeze
CATERING_URL = "#catering".freeze

pages_type = site.content_types.find_or_create_by!(handle: "pages") do |ct|
  ct.name = "Pages"
  ct.blueprint = { "fields" => [ { "handle" => "sections", "type" => "blocks", "label" => "Sections" } ] }
  ct.icon = "page"
end
unless pages_type.fields.any? { |f| f["type"] == "blocks" }
  fields = pages_type.fields + [ { "handle" => "sections", "type" => "blocks", "label" => "Sections" } ]
  pages_type.update!(blueprint: { "fields" => fields })
end

# ---------------------------------------------------------------------------
# Home page (slug "home" = the homepage, by convention)
# ---------------------------------------------------------------------------
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
        "heading" => "Fuel Up with Bagel Boy",
        "subheading" => "Boiled, baked, and slung fresh in Foley.",
        "button_label" => "Order Online",
        "button_url" => ORDER_URL
      }),
      block("rich_text", {
        "body" => "<h2>Welcome to the Thunderdome!</h2>" \
          "<p><em>(aka your favorite bagel shop in Foley)</em></p>" \
          "<p>Where ovens hum like V8 engines, bagels don't just rise—they arrive swinging, and the only law is hunger. " \
          "We roll 'em fresh, sling 'em fast, and schmear like it's our calling. Napkins? Always ready.</p>" \
          "<p>Since August 2022, Bagel Boy has been turning a humble drive-thru into a full-blown Foley ritual. " \
          "What started with flinging fresh bagels out the window like edible joy-discs is now a local obsession—" \
          "with indoor seating so you can vibe while you bite and catch the morning magic in action.</p>" \
          "<p>We're rallying the city, one bagel at a time—fueling school runs, day shifts, and dance parties " \
          "disguised as coffee breaks. It's loud (in the best way), it's local, and it's 100% us. You in?</p>"
      }),
      block("gallery", {
        "heading" => "Bagels! Coffee! Bakery!"
      }),
      block("cta", {
        "heading" => "Hungry yet?",
        "text" => "Order ahead and skip the line.",
        "button_label" => "Order Online",
        "button_url" => ORDER_URL
      }),
      block("image_text", {
        "heading" => "We don't mean to brag, but… Best of Baldwin 2025, 2024 & 2023",
        "image_position" => "right",
        "body" => "<p>Our award-winning bagels? Crafted by a band of elite breakfast artisans who've earned their titles " \
          "through legendary trials, pilgrimages through flour storms, and push-ups over flaming ovens. " \
          "The dough-slingers, egg-flippers, bacon whisperers, and caffeine oracles—every shift, every bagel, " \
          "every perfectly drippy egg is a love letter to the process.</p>" \
          "<p>To our bagel-obsessed community: <strong>you're the real MVPs.</strong> Thanks for every order, every messy table, " \
          "every \"I'll take two more.\"</p>" \
          "<p>We love you all the way we love carbs: endlessly, shamelessly, and with zero regard for napkins.</p>"
      }),
      block("image_text", {
        "heading" => "The Bagels You Love, Made the RIGHT Way",
        "image_position" => "left",
        "body" => "<p>We don't do basic. We do <strong>24-hour fermented, boiled-to-perfection, crispy-crusted, " \
          "chewy-centered BAGELS that slap.</strong></p>" \
          "<p>No shortcuts. No fluff. No \"eh, close enough.\" This is real-deal, sink-your-teeth-into-it, " \
          "make-you-weep-a-little kind of bagel artistry.</p>" \
          "<p>Plain bagel? Respect. Everything bagel with double schmear and hot honey? We salute your chaos.</p>" \
          "<p><strong>Fuel up. Freak out. Repeat.</strong> Bagel Boy loves you (like, aggressively loves you.)</p>"
      }),
      block("hours", {
        "heading" => "Come See Us",
        "schedule" => "Mon–Fri   6:00a – 2:00p\nSat–Sun   7:00a – 3:00p"
      }),
      block("cta", {
        "heading" => "Ready to fuel up?",
        "text" => "Order online or swing by the shop in Foley.",
        "button_label" => "Order Online",
        "button_url" => ORDER_URL
      })
    ]
  }
)
home.save!

# ---------------------------------------------------------------------------
# Catering page (slug "catering")
# ---------------------------------------------------------------------------
catering = site.entries.find_or_initialize_by(slug: "catering")
catering.assign_attributes(
  content_type: pages_type,
  author: admin,
  title: "Catering",
  status: :published,
  published_at: Time.current,
  data: {
    "sections" => [
      block("hero", {
        "heading" => "Bagel Boy Catering",
        "subheading" => "Breakfast. But louder.",
        "button_label" => "Book Catering",
        "button_url" => CATERING_URL
      }),
      block("rich_text", {
        "body" => "<p>Trying to impress your team? Planning a chill get-together that deserves something better than " \
          "sad muffins and a half-empty coffee pot?</p>" \
          "<p><strong>Bagel Boy Catering in Foley pulls up STRONG.</strong> We're talking hot breakfast sammies, " \
          "heavy-on-the-schmear platters, and caffeine that could make a mime sing.</p>" \
          "<p>We've got the goods. You just bring the people. <strong>Book now before someone suggests a fruit tray.</strong></p>"
      }),
      block("image_text", {
        "heading" => "We're great at parties… and know how to liven up a meeting",
        "image_position" => "left",
        "body" => "<ul>" \
          "<li>Corporate breakfasts &amp; lunch meetings</li>" \
          "<li>School or university events</li>" \
          "<li>Community fundraisers &amp; nonprofit gatherings</li>" \
          "<li>Baby showers, bridal brunches &amp; birthdays</li>" \
          "<li>Rehearsal brunches &amp; post-wedding bites</li>" \
          "<li>Holiday parties &amp; weekend get-togethers</li>" \
          "</ul>"
      }),
      block("cta", {
        "heading" => "Ready to be a breakfast hero?",
        "text" => "Book Bagel Boy Catering now.",
        "button_label" => "Book Catering",
        "button_url" => CATERING_URL
      })
    ]
  }
)
catering.save!

# ---------------------------------------------------------------------------
# Footer globals (merchant-editable in CP)
# ---------------------------------------------------------------------------
company = site.globals.find_or_initialize_by(handle: "company")
company.update!(name: "Company Info", data: { "address" => "Foley, AL", "phone" => "(251) 555-0123" })

social = site.globals.find_or_initialize_by(handle: "social")
social.update!(name: "Social", data: { "instagram" => "https://instagram.com/", "facebook" => "https://facebook.com/" })

# ---------------------------------------------------------------------------
# Nav
# ---------------------------------------------------------------------------
nav = site.nav_menus.find_or_initialize_by(handle: "main")
nav.update!(name: "Main")
[
  [ "Home", "/", nil, 1 ],
  [ "Catering", nil, catering, 2 ],
  [ "Order", ORDER_URL, nil, 3 ]
].each do |label, url, entry, pos|
  item = nav.nav_items.find_or_initialize_by(label: label)
  item.update!(site: site, url: url, entry: entry, parent: nil, position: pos)
end

puts "✓ Bagel Boy site seeded (home + catering). Theme=bagel-boy."
puts "  Add photos via /cp image picker; wire ORDER/CATERING URLs when ready."
