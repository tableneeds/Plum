require "test_helper"

class HostAuthorizationTest < ActionDispatch::IntegrationTest
  HostUser = Struct.new(:name)

  setup do
    @previous_authorize_with = Plum.configuration.authorize_with
    @previous_current_site_resolver = Plum.configuration.current_site_resolver
    @previous_current_user_resolver = Plum.configuration.current_user_resolver
    @previous_host_authorization_resolver = Plum.configuration.host_authorization_resolver
    @previous_cp_name = Plum.configuration.cp_name
    @previous_cp_subtitle = Plum.configuration.cp_subtitle

    @site = Plum::Site.create!(name: "Embedded Site", theme_name: "default", skip_defaults: true)
  end

  teardown do
    Plum.configuration.authorize_with = @previous_authorize_with
    Plum.configuration.current_site_resolver = @previous_current_site_resolver
    Plum.configuration.current_user_resolver = @previous_current_user_resolver
    Plum.configuration.host_authorization_resolver = @previous_host_authorization_resolver
    Plum.configuration.cp_name = @previous_cp_name
    Plum.configuration.cp_subtitle = @previous_cp_subtitle
  end

  test "host mode denies control panel access when the host resolver rejects the request" do
    configure_host_mode(authorized: false)

    get cp_root_path

    assert_response :forbidden
  end

  test "host mode allows control panel access through the host resolver" do
    configure_host_mode(authorized: true, user: HostUser.new("Restaurant Owner"))

    get cp_root_path

    assert_response :success
    assert_includes response.body, "Welcome back, Restaurant Owner"
    refute_includes response.body, "Logout"
  end

  test "control panel header wraps configurable branding without adding a host byline" do
    configure_host_mode(authorized: true)
    Plum.configuration.cp_name = "A Control Panel Name That Needs More Than One Line"
    Plum.configuration.cp_subtitle = "Published with Plum CMS"
    content_type = Plum::ContentType.create!(
      site: @site,
      name: "A Particularly Long Collection Name That Must Wrap",
      blueprint: { "fields" => [] }
    )

    get cp_root_path

    assert_response :success
    assert_select ".plum-sidebar-header.min-h-16"
    assert_select ".plum-sidebar-header .plum-sidebar-wrapping-text", text: Plum.configuration.cp_name
    assert_select ".plum-sidebar-header .plum-sidebar-wrapping-text", text: Plum.configuration.cp_subtitle
    assert_select "a[href='#{cp_content_type_path(content_type)}'] .plum-sidebar-wrapping-text", text: content_type.name
    refute_includes response.body, "by Table Needs"
  end

  test "control panel header omits an empty subtitle" do
    configure_host_mode(authorized: true)
    Plum.configuration.cp_subtitle = nil

    get cp_root_path

    assert_response :success
    assert_select ".plum-sidebar-subtitle", count: 0
  end

  private

  def configure_host_mode(authorized:, user: HostUser.new("Host User"))
    Plum.configuration.authorize_with = :host
    Plum.configuration.current_site_resolver = ->(_controller) { @site }
    Plum.configuration.current_user_resolver = ->(_controller) { user }
    Plum.configuration.host_authorization_resolver = ->(_controller) { authorized }
  end
end
