require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_sales"

class Game::Market::OrderNoticeLinesTest < ActiveSupport::TestCase
  include MarketListings
  include MarketSales
  include MarketSettings

  setup do
    @reader = accounts_players(:moderator)
    @seller = accounts_players(:player)
    @settings = open_market!
    @rare = catalog_card_seasons(:rare_card_one)
  end

  def order(status: "open") = Game::Market::Order.create!(player: @reader, card_id: @rare.card_id, settings: @settings, price: 100, status:,
    expires_at: 7.days.from_now)

  def lines = Game::Market::OrderNoticeLines.call(player: @reader, locale: :en)

  test "each order line names its card and carries the edition its link opens, the newest first" do
    served = served!(@rare, 100, buyer: @reader, seller: @seller)
    expired = order(status: "expired")
    above = order
    listing = listing!(seller: @seller, card_season: @rare, starting_price: 150)
    Game::Market::Notice.record(player_id: @reader.id, order_id: served.id, kind: "order_served", amount: 100, at: 3.hours.ago)
    Game::Market::Notice.record(player_id: @reader.id, order_id: expired.id, kind: "order_expired", amount: 100, at: 2.hours.ago)
    Game::Market::Notice.record(player_id: @reader.id, order_id: above.id, listing_id: listing.id, kind: "listed_above_order",
      other_player_id: @seller.id, amount: 150, at: 1.hour.ago)

    assert_equal [ [ :listed_above_order, above.token, listing.token, 150 ], [ :order_expired, expired.token, nil, 100 ],
      [ :order_served, served.token, nil, 100 ] ], lines.map { [ it.kind, it.token, it.listing_token, it.amount ] }
    assert_equal [ "Blue Depths" ] * 3, lines.map(&:card)
    assert_equal [ @rare.season.number ] * 3, lines.map { it.edition.season_number }
    assert_equal @seller, lines.first.other
  end

  test "the push reads only the order kinds asked for, of the orders given" do
    expired = order(status: "expired")
    other = order(status: "cancelled")
    Game::Market::Notice.record(player_id: @reader.id, order_id: expired.id, kind: "order_expired", amount: 100)
    Game::Market::Notice.record(player_id: @reader.id, order_id: other.id, kind: "order_expired", amount: 100)

    lines = Game::Market::OrderNoticeLines.of_orders(player_id: @reader.id, order_ids: [ expired.id ], kinds: %w[order_served order_expired], locale: :en)

    assert_equal [ expired.token ], lines.map(&:token)
  end
end
