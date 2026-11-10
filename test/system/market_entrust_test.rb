require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"

class MarketEntrustSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    Game::Market::Settings.delete_all
  end

  def sign_in_through_the_site
    mock_steam_sign_in(@player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  test "a player enters copies of two editions and sees the total minted, and the collection holds fewer copies" do
    open_market!
    hold(@player, @common.id, 2)
    hold(@player, @rare.id, 1)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    fill_in "copies[#{@common.card.slug}:#{@common.season.number}]", with: "2"
    fill_in "copies[#{@rare.card.slug}:#{@rare.season.number}]", with: "1"
    click_on "Entrust"

    assert_selector ".market-entrust__total", text: "7,000 PiCoins"
    assert_selector ".market-entrust__count", text: "3 copies entrusted"
    assert_equal 0, Game::Holding.where(player_id: @player.id).sum(:quantity)
  end

  test "while the market is closed the page opens and validation is disabled" do
    Game::Market::CreateFirstSettings.new.call.value!
    hold(@player, @common.id, 1)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)

    assert_selector ".market-entrust__notice", text: "closed"
    assert_button "Entrust", disabled: true
  end
end
