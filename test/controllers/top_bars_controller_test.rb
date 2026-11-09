require "test_helper"
require_relative "../support/steam_sign_in"

class TopBarsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  test "a player reads the top bar's values again, for the chip, the rarities and the menu's badge" do
    sign_in accounts_players(:player)

    get top_bar_path(locale: :en), as: :turbo_stream

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_select "turbo-stream[action=replace][target=packs-chip] template"
    assert_select "turbo-stream[action=replace][target=rarity-counter] template"
    assert_select "turbo-stream[action=update][target=player-menu-badge] template"
  end

  test "an app with the native bar reads the values it reports from the same refresh" do
    sign_in accounts_players(:player)

    get top_bar_path(locale: :en), as: :turbo_stream, headers: { "User-Agent" => "Hotwire Native iOS; bridge-components: [top-bar]" }

    assert_response :success
    assert_select "turbo-stream[action=replace][target=packs-chip] template"
    assert_select "turbo-stream[action=update][target=player-menu-badge] template"
    assert_select "turbo-stream[action=update][target=tab-trades-badge] template"
    assert_select "turbo-stream[action=update][target=player-menu-invitations-badge] template"
  end

  test "a page without the native bar has no tab badges to refresh" do
    sign_in accounts_players(:player)

    get top_bar_path(locale: :en), as: :turbo_stream

    assert_select "turbo-stream[target=tab-trades-badge], turbo-stream[target=player-menu-invitations-badge]", 0
  end

  test "a visitor is refused" do
    get top_bar_path(locale: :en), as: :turbo_stream

    assert_not_equal 200, response.status
  end
end
