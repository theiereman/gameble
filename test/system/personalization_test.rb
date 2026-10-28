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
    assert_selector ".profile-showcase .card"

    visit settings_path(locale: :en)

    assert_selector "h1", text: "PROFILE AND SETTINGS"
    assert_no_selector ".profile-showcase"
  end

  test "the player reorders and removes showcase cards on Personalization" do
    [ catalog_card_seasons(:common_card_one), catalog_card_seasons(:rare_card_one) ].each do |card|
      Game::Holding.create!(player_id: @player.id, card_season_id: card.id, quantity: 1)
      Game::AddToShowcase.new.call(player: @player, card_season_id: card.id).value!
    end
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit personalization_path(locale: :en)

    labels = all(".profile-showcase__slot .card-link").map { it[:"aria-label"] }
    within(".profile-showcase__slot:first-child") { find("form[data-direction='later'] button").click }

    assert_selector ".profile-showcase__slot:first-child .card-link[aria-label=\"#{labels.last}\"]"

    within(".profile-showcase__slot:first-child") { find("button[aria-label^='Remove']").click }

    assert_selector ".profile-showcase__slot", count: 1
    assert_selector ".profile-showcase__slot .card-link[aria-label=\"#{labels.first}\"]"
  end
end
