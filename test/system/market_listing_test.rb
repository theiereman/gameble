require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"

class MarketListingSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one)
    Game::Market::Settings.delete_all
    @settings = open_market!(first_opened_at: 1.day.ago)
    Game::Market::Mint.credit(player_id: @player.id, amount: 1_000, settings_id: @settings.id)
    hold(@player, @common.id, 1)
  end

  def sign_in_through_the_site
    mock_steam_sign_in(@player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  test "a player lists a copy from the card detail at 24 H with a buy-now, lands on the Annonce and finds it on the market" do
    sign_in_through_the_site

    visit card_path(locale: :en, slug: @common.card.slug)
    click_on "Put up for sale"

    assert_selector ".sale-cell[aria-selected=true]"
    assert_selector "input[name=duration_hours][value='24']:checked"
    fill_in "sale-start", with: "1500"
    fill_in "sale-buy-now", with: "3000"
    assert_selector ".sale-line--received .picoin-amount__figure", text: "1,350"
    assert_selector ".sale-line:nth-child(2) .picoin-amount__figure", text: "150"
    find("#sale-buy-now").send_keys(:enter)
    assert_selector "input[name=duration_hours][value='24']:focus"
    assert_equal 0, Game::Market::Listing.count

    click_on "PUT UP FOR SALE"

    assert_selector "#market-listing-heading:focus"
    assert_equal 1, Game::Market::Listing.count
    visit market_path(locale: :en)
    assert_selector ".listing-tile", count: 1
  end

  test "a start under the minimum is refused inline and the amount stays" do
    sign_in_through_the_site

    visit new_market_card_sale_path(locale: :en, slug: @common.card.slug)
    fill_in "sale-start", with: "1000"
    click_on "PUT UP FOR SALE"

    assert_selector "#sale-start-error", text: "At least 1,300 for a common."
    assert_selector "#sale-start[aria-invalid=true]"
    assert_field "sale-start", with: "1000"
    assert_equal 0, Game::Market::Listing.count
  end
end
