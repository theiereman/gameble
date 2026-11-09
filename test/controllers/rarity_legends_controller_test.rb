require "test_helper"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

class RarityLegendsControllerTest < ActionDispatch::IntegrationTest
  include Holdings
  include SteamSignIn

  test "a player reads the legend again, alone, with the copies they now hold" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:common_card_one).id, 3)
    sign_in(player)

    get rarity_legend_path(locale: :en), as: :turbo_stream

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_select "turbo-stream", 1
    assert_select "turbo-stream[action=replace][target=rarity-legend] template"
    assert_includes response.body, %(<td class="rarity-legend__figure rarity-legend__copies">3</td>)
    assert_not_includes response.body, "rarity-counter__count"
  end

  test "a visitor is refused" do
    get rarity_legend_path(locale: :en), as: :turbo_stream

    assert_not_equal 200, response.status
  end
end
