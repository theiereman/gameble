require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/market_orders"

# Listing a card at or below the buy orders waiting for it turns them into bids; a later bid outbids the leading order and returns its PiCoins.
class MarketOrderBackedAuctionSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketAuctions
  include MarketOrders
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @leader = accounts_players(:moderator)
    @runner_up = accounts_players(:administrator)
    @rare = catalog_card_seasons(:rare_card_one)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago, increment_basis_points: 500)
    [ @seller, @leader, @runner_up ].each { fund!(it, 10_000) }
    hold(@seller, @rare.id, 1)
    @best = order!(@leader, @rare, 900)
    @lowest = order!(@runner_up, @rare, 700)
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  test "the seller sees the orders and the start they give, lists, and the leading order reads in the auction until another bid outbids it" do
    sign_in_through_the_site(@seller)
    visit new_market_sale_path(locale: :en)
    find("[role=option]", text: "Blue Depths").click

    assert_selector ".sale-orders", text: /2 buy orders, the best at\s+900/
    assert_field "sale-start", with: "700"
    assert_selector ".sale-opening__line", text: "With these orders, the auction starts at 735, led by a buy order."
    fill_in "sale-start", with: "800"
    assert_selector ".sale-opening__line", text: "With these orders, the auction starts at 800, led by a buy order."
    assert_selector ".sale-opening__line", text: "The order at 700 stays open."
    fill_in "sale-start", with: "700"
    assert_no_selector ".sale-opening__line", text: "stays open"

    find(".sale-summary button[type=submit]", text: /PUT UP FOR SALE/).click
    assert_current_path(/\/market\/listings\//)

    assert_equal %w[bid beaten], [ @best, @lowest ].map { it.reload.status }
    listing = Game::Market::Listing.order(:id).last
    assert_equal [ @leader.id, 900, 735 ], listing.attributes.values_at("leader_id", "leader_maximum", "current_price")

    Capybara.reset_sessions!
    sign_in_through_the_site(@leader)
    visit market_my_orders_path(locale: :en)
    assert_selector ".market-row__chip", text: "IN AUCTION"
    assert_selector ".market-row__note a", text: "SEE THE LISTING"

    rival = buyer!
    fund!(rival, 10_000)
    Game::Market::PlaceBid.new.call(player: rival, listing_id: listing.id, maximum: 1_000).value!
    visit market_my_orders_path(locale: :en)

    assert_selector ".market-row__chip", text: "OUTBID"
    assert_selector ".market-row__note", text: "PiCoins returned"
    assert_equal [ 10_000, 0 ], Game::Market::Wallet.find_by!(player_id: @leader.id).attributes.values_at("available", "committed")
  end
end
