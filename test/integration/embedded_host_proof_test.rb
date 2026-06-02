require "test_helper"
require "tmpdir"

class EmbeddedRestaurant < ActiveRecord::Base
  self.table_name = "embedded_restaurants"

  has_one :plum_site, as: :owner, class_name: "Plum::Site", dependent: :destroy

  def to_liquid
    {
      "name" => name,
      "slug" => slug
    }
  end
end

class EmbeddedHostProofTest < ActionDispatch::IntegrationTest
  HostUser = Struct.new(:name, :restaurant_id) do
    def can_manage_website?(restaurant)
      restaurant_id == restaurant.id
    end
  end

  MenuAdapter = Class.new(Plum::ContentSource) do
    def to_liquid
      {
        items: owner.menu_items
      }
    end
  end

  setup do
    create_embedded_restaurants_table
    EmbeddedRestaurant.delete_all

    @previous_authorize_with = Plum.configuration.authorize_with
    @previous_current_site_resolver = Plum.configuration.current_site_resolver
    @previous_current_user_resolver = Plum.configuration.current_user_resolver
    @previous_host_authorization_resolver = Plum.configuration.host_authorization_resolver
    @previous_theme_paths = Plum.configuration.theme_paths
    Plum.configuration.content_sources.clear

    @theme_dir = Dir.mktmpdir("plum-embedded-host-theme")
    build_embedded_theme

    @restaurant = EmbeddedRestaurant.create!(
      name: "Bagel Boy",
      slug: "bagel-boy",
      menu_items: [
        { "name" => "Sesame Bagel", "price" => "$3.50" },
        { "name" => "Cold Brew", "price" => "$4.25" }
      ],
      hours: { "today" => "6 AM - 2 PM" }
    )
    @host_user = HostUser.new("Restaurant Owner", @restaurant.id)
    @site = Plum::Site.for_owner!(@restaurant, name: @restaurant.name, theme_name: "embedded-host", skip_defaults: true)

    Plum.configure do |config|
      config.authorize_with = :host
      config.current_site_resolver = ->(_controller) { @restaurant.plum_site }
      config.current_user_resolver = ->(_controller) { @host_user }
      config.host_authorization_resolver = lambda { |_controller|
        @host_user.can_manage_website?(@restaurant)
      }
      config.theme_paths = [ @theme_dir, Rails.root.join("app/themes") ]
      config.register_content_source :restaurant, ->(context) { context.site.owner.to_liquid }
      config.register_content_source :menu, MenuAdapter
      config.register_content_source :hours, ->(context) { context.site.owner.hours }
    end
  end

  teardown do
    Plum.configuration.authorize_with = @previous_authorize_with
    Plum.configuration.current_site_resolver = @previous_current_site_resolver
    Plum.configuration.current_user_resolver = @previous_current_user_resolver
    Plum.configuration.host_authorization_resolver = @previous_host_authorization_resolver
    Plum.configuration.theme_paths = @previous_theme_paths
    Plum.configuration.content_sources.clear
    FileUtils.remove_entry(@theme_dir) if @theme_dir && Dir.exist?(@theme_dir)
  end

  test "creates and reuses one Plum site for a host restaurant" do
    same_site = Plum::Site.for_owner!(@restaurant, name: "Ignored", theme_name: "default")

    assert_equal @site, same_site
    assert_equal "Bagel Boy", same_site.name
    assert_equal "embedded-host", same_site.theme_name
    assert_equal @restaurant, same_site.owner
    assert_equal 1, Plum::Site.where(owner: @restaurant).count
  end

  test "renders host restaurant data through Liquid content sources" do
    get root_path

    assert_response :success
    assert_includes response.body, "Bagel Boy"
    assert_includes response.body, "bagel-boy"
    assert_includes response.body, "Sesame Bagel"
    assert_includes response.body, "$3.50"
    assert_includes response.body, "Cold Brew"
    assert_includes response.body, "6 AM - 2 PM"
  end

  test "bundled bagel shop theme can render optional host content sources" do
    @site.update!(theme_name: "bagel-shop")

    get root_path

    assert_response :success
    assert_includes response.body, "Bagel Boy"
    assert_includes response.body, "Open today: 6 AM - 2 PM"
    assert_includes response.body, "Sesame Bagel"
    assert_includes response.body, "$3.50"
    assert_includes response.body, "Cold Brew"
  end

  test "lets host authorization control embedded CP access" do
    get cp_root_path

    assert_response :success
    assert_includes response.body, "Welcome back, Restaurant Owner"
    refute_includes response.body, "Logout"
  end

  private

  def create_embedded_restaurants_table
    return if ActiveRecord::Base.connection.table_exists?(:embedded_restaurants)

    ActiveRecord::Base.connection.create_table :embedded_restaurants do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.json :menu_items, default: [], null: false
      t.json :hours, default: {}, null: false
      t.timestamps
    end

    EmbeddedRestaurant.reset_column_information
  end

  def build_embedded_theme
    theme_root = Pathname(@theme_dir).join("embedded-host")
    FileUtils.mkdir_p(theme_root.join("layouts"))
    FileUtils.mkdir_p(theme_root.join("templates"))

    theme_root.join("theme.yml").write(<<~YAML)
      name: Embedded Host
      handle: embedded-host
      version: 1.0.0
    YAML

    theme_root.join("layouts/base.liquid").write(<<~LIQUID)
      <!DOCTYPE html>
      <html>
        <body>{{ content }}</body>
      </html>
    LIQUID

    theme_root.join("templates/index.liquid").write(<<~LIQUID)
      <h1>{{ restaurant.name }}</h1>
      <p>{{ restaurant.slug }}</p>
      <p>Open today: {{ hours.today }}</p>
      <ul>
        {% for item in menu.items %}
          <li>{{ item.name }} - {{ item.price }}</li>
        {% endfor %}
      </ul>
    LIQUID
  end
end
