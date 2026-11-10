require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::ListingOutcomeTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @winner = accounts_players(:moderator)
    @loser = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!(increment_basis_points: 500, soft_close_seconds: 180)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, buy_now_price: 60_000, ends_at: 1.day.from_now)
    [ @winner, @loser ].each { fund!(it, 100_000) }
  end

  def outcome(viewer) = Game::Market::ListingOutcome.call(token: @listing.token, viewer:, locale: :en)

  def sell_to_winner(maximum: 40_000)
    bid(@loser, 30_000)
    bid(@winner, maximum)
    @listing.update_columns(ends_at: 1.minute.ago)
    Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id)
  end

  test "an open listing that is not due has no outcome and a due one is closing" do
    assert_nil outcome(@winner)

    @listing.update_columns(ends_at: 1.minute.ago)

    assert_instance_of Game::Market::ListingOutcome::Closing, outcome(@winner)
  end

  test "an unknown token reads nothing" do
    assert_nil Game::Market::ListingOutcome.call(token: "nope", viewer: nil, locale: :en)
  end

  test "the winner reads the price and the surplus" do
    sell_to_winner
    result = outcome(@winner)

    assert_equal [ :won, 31_500, 8_500, false ], [ result.kind, result.price, result.surplus, result.buy_now ]
    assert_equal @winner, result.winner
    assert_equal @card.card.slug, result.card.id
  end

  test "a winner whose maximum equals the price has no surplus" do
    sell_to_winner(maximum: 31_500)

    assert_equal [ :won, 0 ], outcome(@winner).then { [ it.kind, it.surplus ] }
  end

  test "the seller reads the amount received, the sale less the commission" do
    sell_to_winner
    result = outcome(@seller)
    ledger = entries_of.where(player_id: @seller.id, kind: %w[sale commission]).sum(:available_delta)

    assert_equal :seller_sold, result.kind
    assert_equal ledger, result.received
    assert_operator result.received, :<, result.price
  end

  test "a bidder who lost reads the winner and the price" do
    sell_to_winner
    result = outcome(@loser)

    assert_equal [ :lost, @winner, 31_500 ], [ result.kind, result.winner, result.price ]
  end

  test "a visitor and any other player read the neutral outcome" do
    sell_to_winner

    assert_equal :viewer_sold, outcome(nil).kind
    assert_equal :viewer_sold, outcome(accounts_players(:banned)).kind
  end

  test "a winner who only raised is the winner, never a loser" do
    bid(@winner, 30_000)
    bid(@winner, 35_000)
    @listing.update_columns(ends_at: 1.minute.ago)
    Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id)

    assert_equal :won, outcome(@winner).kind
  end

  test "a purchase at the buy-now price is bought for the winner and marked for the others" do
    bid(@loser, 30_000)
    bid(@winner, 60_000)

    assert_equal [ :bought, 60_000, true ], outcome(@winner).then { [ it.kind, it.price, it.buy_now ] }
    assert_equal [ :seller_sold, true ], outcome(@seller).then { [ it.kind, it.buy_now ] }
    assert_equal [ :lost, true ], outcome(@loser).then { [ it.kind, it.buy_now ] }
    assert_equal [ :viewer_sold, true ], outcome(nil).then { [ it.kind, it.buy_now ] }
  end

  test "an auction without a bid, a cancelled one and a withdrawn one read their own outcome" do
    @listing.update_columns(ends_at: 1.minute.ago)
    Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id)
    assert_equal :no_bid, outcome(nil).kind

    @listing.update_columns(status: "cancelled")
    assert_equal :cancelled, outcome(@seller).kind

    @listing.update_columns(status: "withdrawn")
    assert_equal :withdrawn, outcome(nil).kind
  end
end
