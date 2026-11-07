require "test_helper"
require_relative "../support/steam_sign_in"

# GET /service-worker.js: the worker that keeps the booster screen for
# offline visits, registered by the layout for signed-in players only.
class ServiceWorkerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  test "the worker is served at the site root as JavaScript, without a cookie" do
    get "/service-worker.js"

    assert_response :success
    assert_equal "text/javascript", response.media_type
    assert_includes response.body, "addEventListener(\"fetch\""
    assert_nil response.headers["Set-Cookie"]
  end

  test "a signed-in player's page names the worker" do
    sign_in(accounts_players(:player))

    get how_it_works_path(locale: :en)

    assert_select "meta[name='service-worker'][content='/service-worker.js']"
  end

  test "a visitor's page names no worker, so the client forgets what it kept" do
    get how_it_works_path(locale: :en)

    assert_response :success
    assert_select "meta[name='service-worker']", count: 0
  end
end
