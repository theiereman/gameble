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

  test "a copy over the daily cap stays in the collection and the result names it" do
    settings = open_market!
    legendary = catalog_card_seasons(:legendary_card_one)
    uncommon = catalog_card_seasons(:uncommon_card_one)
    hold(@player, legendary.id, 1)
    hold(@player, uncommon.id, 2)
    hold(@player, @common.id, 1)
    Game::Market::Mint.credit(player_id: @player.id, amount: 1_150_000, settings_id: settings.id)
    sign_in_through_the_site

    visit new_market_entrustment_path(locale: :en)
    [ legendary, uncommon, @common ].each do |card_season|
      fill_in "copies[#{card_season.card.slug}:#{card_season.season.number}]", with: card_season == uncommon ? "2" : "1"
    end
    click_on "Entrust"

    assert_selector ".market-entrust__total", text: "5,000 PiCoins"
    assert_selector "[role=status] .market-entrust__stayed-line", text: "100,000 PiCoins"
    assert_selector ".market-entrust__stayed-cap", text: "50,000"
    assert_equal 1, Game::Holding.find_by(player_id: @player.id, card_season_id: legendary.id).quantity
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
