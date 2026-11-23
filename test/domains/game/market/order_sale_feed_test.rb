require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_orders"

class Game::Market::OrderSaleFeedTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketOrders
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @buyer = accounts_players(:moderator)
    @other = accounts_players(:administrator)
    open_market!(feed_threshold_multiple: 10)
    @epic = catalog_card_seasons(:portal_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @common = catalog_card_seasons(:common_card_one)
    fund!(@seller, 1_000)
    fund!(@buyer, 10_000)
    fund!(@other, 10_000)
  end

  def sales = Game::FeedEntry.where(kind: "sale")

  def sell!(card, price, buyer: @buyer)
    hold(@seller, card.id, 1)
    order = order!(buyer, card, price)
    assert Game::Market::SellToOrder.new.call(player: @seller, card_season_id: card.id, order_token: order.token,
      settings_token: Game::Market::CurrentSettings.call.token).success?
    order
  end

  def apply_wanted!(orders)
    lines = orders.map do |card, order|
      hold(@seller, card.id, 1)
      { card_season_id: card.id, copies: 1, choice: "order", order_tokens: [ order.token ] }
    end
    assert Game::Market::ApplyWantedChoices.new.call(player: @seller, lines:, settings_token: Game::Market::CurrentSettings.call.token).success?
  end

  def insert(**row)
    now = Time.current
    base = { kind: "sale", player_id: @buyer.id, card_season_id: @common.id, rarity: 1, notable: true, occurred_at: now, created_at: now, updated_at: now }
    Game::FeedEntry.transaction(requires_new: true) { Game::FeedEntry.insert_all!([ base.merge(row) ]) }
  end

  test "an epic sold to a buy order is one entry naming the buyer and carrying the order" do
    order = sell!(@epic, 300)

    entry = sales.sole
    assert_equal [ @buyer.id, order.id, nil, @epic.id, 4 ], [ entry.player_id, entry.order_id, entry.listing_id, entry.card_season_id, entry.rarity ]
  end

  test "a common sold to an order just below the threshold is not an entry" do
    sell!(@common, 129)

    assert_empty sales
  end

  test "a common sold to an order at the threshold is an entry written in the sale's transaction" do
    order = sell!(@common, 130)

    assert_equal [ order.id ], sales.pluck(:order_id)
  end

  test "the wanted table writes one entry per notable sale, by buyer then order, and never twice" do
    epic = order!(@buyer, @epic, 300)
    rare = order!(@other, @rare, 900)

    apply_wanted!(@epic => epic, @rare => rare, @common => order!(@buyer, @common, 20))

    expected = [ [ @buyer.id, epic.id ], [ @other.id, rare.id ] ].sort
    assert_equal expected, sales.order(:id).pluck(:player_id, :order_id)
    event = Rails.configuration.event_store.read.of_type(Game::Market::WantedChoicesApplied).last
    Game::Handlers::SaleFeed.call(event)
    assert_equal 2, sales.count
  end

  test "the database refuses a sale with both references, with neither, an order on another kind and an unknown order" do
    order = order!(@buyer, @common, 50)

    assert_raises(ActiveRecord::CheckViolation) { insert(listing_id: 1, order_id: order.id) }
    assert_raises(ActiveRecord::CheckViolation) { insert }
    assert_raises(ActiveRecord::CheckViolation) { insert(kind: "repost", order_id: order.id) }
    assert_raises(ActiveRecord::InvalidForeignKey) { insert(order_id: Game::Market::Order.maximum(:id) + 1_000) }
  end

  test "an order's entry is priced at the order's price" do
    sell!(@rare, 900)

    assert_equal [ 900 ], Game::FeedEntries.call(nil).select { it.entry.kind == "sale" }.map(&:price)
  end

  test "an order's entry is listed whatever the buyer's visibility, unless the buyer is banned" do
    order = sell!(@rare, 900)
    @buyer.update!(visibility: "private")

    assert_equal [ [ @buyer.id, 900 ] ], Game::NewFeedEntries.call(order_ids: [ order.id ]).map { [ it.player.id, it.price ] }
    assert_equal [ @buyer.id ], Game::FeedEntries.call(@other).select { it.entry.kind == "sale" }.map { it.player.id }
    assert_equal sales.sole, Game::VisibleFeedEntry.call(nil, sales.sole.token)

    @buyer.update_columns(banned_at: Time.current)
    assert_empty Game::NewFeedEntries.call(order_ids: [ order.id ])
    assert_nil Game::VisibleFeedEntry.call(nil, sales.sole.token)
  end
end
