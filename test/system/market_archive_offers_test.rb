require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/market_listings"

class MarketArchiveOffersSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include MarketAuctions
  include MarketListings
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @seller = accounts_players(:moderator)
    @common = catalog_card_seasons(:common_card_one)
    forget_market!
    open_market!(first_opened_at: 1.day.ago, archive_price_rare: 500)
    fund!(@player, 1_000)
    Game::Market::ArchiveStock.create!(card_season_id: catalog_card_seasons(:rare_card_one).id, quantity: 1)
    listing!(seller: @seller, card_season: @common, starting_price: 80)
    listing!(seller: @seller, card_season: @common, starting_price: 900)
  end

  def sign_in_and_visit_market(**params)
    mock_steam_sign_in(@player.steam_id)
    sign_in_browser(locale: :fr)
    visit market_path(locale: :fr, **params)
  end

  test "the market shows the shop panel and mixes the Archive offer into the listings by price" do
    sign_in_and_visit_market(sort: "price_asc")

    within ".shop-panel" do
      assert_selector ".shop-panel__list li", count: 1
      assert_link "Voir toute la boutique"
    end
    assert_selector "#market-tiles > li:nth-child(1) .listing-tile__price", text: "80"
    assert_selector "#market-tiles > li:nth-child(2) .archive-offer__fixed", text: "prix fixe"
    assert_selector "#market-tiles > li:nth-child(2) .archive-offer__price", text: "500"
    assert_selector "#market-tiles > li:nth-child(3) .listing-tile__price", text: "900"
  end

  test "a search for a game only the Archives hold leads to the order form, whose Archives line opens the confirmation" do
    sign_in_and_visit_market(q: "Profondeurs bleues")

    assert_selector ".market-searched__line", text: "Aucune annonce de joueur pour Profondeurs bleues."
    assert_selector "#market-tiles .archive-offer", count: 1
    click_on "PASSER UN ORDRE"

    assert_current_path new_market_card_order_path(locale: :fr, slug: "blue-depths")
    click_on "ACHETER · 500"
    within "dialog#archive-purchase-dialog" do
      assert_selector "h2", text: "ACHETER AUX ARCHIVES"
      assert_selector ".purchase-confirmation__price", text: "500"
    end
  end
end
