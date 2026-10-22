require "test_helper"
require_relative "../support/steam_sign_in"

# What the root answers by the Accept header and the verb: a visitor's
# request that accepts HTML (or anything) meets the landing, and a request
# that accepts only something else is refused with a status, never a
# redirect to the same address or a server error.
class RootRequestFormatsTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  BROWSER_ACCEPT = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"
  TURBO_STREAM = "text/vnd.turbo-stream.html"

  def landing_marker = "h1#landing-hero"

  test "a visitor reads the landing for any Accept that takes HTML" do
    [ "*/*", "text/html", BROWSER_ACCEPT, "#{TURBO_STREAM}, text/html, application/xhtml+xml", nil ].each do |accept|
      get home_path(locale: :en), headers: ({ "Accept" => accept } if accept)

      assert_response :success, "Accept #{accept.inspect}"
      assert_equal "text/html", response.media_type, "Accept #{accept.inspect}"
      assert_select landing_marker, 1
    end
  end

  test "a visitor's HEAD of the root answers the landing's headers for */* and no Accept" do
    [ "*/*", nil ].each do |accept|
      head home_path(locale: :en), headers: ({ "Accept" => accept } if accept)

      assert_response :success, "Accept #{accept.inspect}"
      assert_equal "text/html", response.media_type
      assert_empty response.body
    end
  end

  test "a visitor whose request accepts only another type is refused with 401, never a redirect or a server error" do
    [ TURBO_STREAM, "application/json", "text/plain", "image/*" ].each do |accept|
      get home_path(locale: :en), headers: { "Accept" => accept }

      assert_response :unauthorized, "Accept #{accept}"
    end
  end

  test "a visitor's HEAD that accepts only another type is refused with 401" do
    head home_path(locale: :en), headers: { "Accept" => TURBO_STREAM }

    assert_response :unauthorized
  end

  test "a visitor's JSON refusal names the code" do
    get home_path(locale: :en), headers: { "Accept" => "application/json" }

    assert_equal "sign_in_required", response.parsed_body.dig("error", "code")
  end

  test "a signed-in player reads the hub for any Accept that takes HTML" do
    sign_in(accounts_players(:player))

    [ "*/*", "text/html", BROWSER_ACCEPT, nil ].each do |accept|
      get home_path(locale: :en), headers: ({ "Accept" => accept } if accept)

      assert_response :success, "Accept #{accept.inspect}"
      assert_select "h1.hub__title", 1
      assert_select landing_marker, 0
    end
  end

  test "a signed-in player's request that accepts only another type is not the landing" do
    sign_in(accounts_players(:player))

    [ TURBO_STREAM, "application/json" ].each do |accept|
      get home_path(locale: :en), headers: { "Accept" => accept }

      assert_response :not_acceptable, "Accept #{accept}"
    end
  end
end
