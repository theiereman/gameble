require "application_system_test_case"
require_relative "../support/steam_sign_in"

class PersonalizationTest < ApplicationSystemTestCase
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
  end

  test "the player menu opens Personalization, which holds the showcase the settings no longer show" do
    Game::Holding.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:common_card_one).id, quantity: 1)
    Game::AddToShowcase.new.call(player: @player, card_season_id: catalog_card_seasons(:common_card_one).id).value!
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    find(".player-chip__button").click
    click_link "Personalization"

    assert_selector "h1", text: "PERSONALIZATION"
    assert_selector ".personalization-showcase .card"

    visit settings_path(locale: :en)

    assert_selector "h1", text: "PROFILE AND SETTINGS"
    assert_no_selector ".personalization-showcase"
  end
end
