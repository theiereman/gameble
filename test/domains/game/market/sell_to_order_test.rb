require "test_helper"
require_relative "../../../support/singleton_stub"
require_relative "../../../support/decks"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"
require_relative "../../../support/market_orders"
require_relative "../../../support/market_sales"

class Game::Market::SellToOrderTest < ActiveSupport::TestCase
  include SingletonStub
  include Decks
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketOrders
  include MarketSales
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @buyer = accounts_players(:moderator)
    @card = catalog_card_seasons(:uncommon_card_one)
    @settings = open_market!(commission_basis_points: 1_000)
    fund!(@seller, 1_000)
    fund!(@buyer, 10_000)
    hold(@seller, @card.id, 1)
    @order = order!(@buyer, @card, 900)
  end

  def sell(order = @order, player: @seller, card: @card, settings_token: Game::Market::CurrentSettings.call.token)
    Game::Market::SellToOrder.new.call(player:, card_season_id: card.id, order_token: order&.token, settings_token:)
  end

  def copies(player) = Game::Holding.find_by(player_id: player.id, card_season_id: @card.id)&.attributes&.values_at("quantity", "reserved")

  def entries = Game::Market::LedgerEntry.where(order_id: @order.id).where.not(kind: "hold").order(:id)

  def nothing_moves(&)
    assert_no_difference([ -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.sum(:quantity) }, -> { Game::Holding.sum(:reserved) },
      -> { Rails.configuration.event_store.read.count } ], &)
    assert_equal "open", @order.reload.status
  end

  def refused(code, *, **)
    result = nil
    nothing_moves { result = sell(*, **) }
    assert_equal code, result.failure
  end

  test "a sale serves the order, moves the copy and settles both wallets in one post" do
    destroyed = Game::Market::ReconcileWallets.call.destroyed

    freeze_time do
      assert sell.success?

      assert_equal [ "served", @seller.id, @card.id, Time.current, 900 ],
        @order.reload.attributes.values_at("status", "seller_id", "served_card_season_id", "served_at", "average_after_sale")
    end
    assert_equal [ 0, 0 ], copies(@seller)
    assert_equal [ 1, 0 ], copies(@buyer)
    assert_equal [ 9_100, 0 ], figures(@buyer)
    assert_equal [ 1_810, 0 ], figures(@seller)
    assert_equal [ [ @buyer.id, "purchase", 0, -900 ], [ @seller.id, "sale", 900, 0 ], [ @seller.id, "commission", -90, 0 ] ],
      entries.pluck(:player_id, :kind, :available_delta, :committed_delta)
    assert_equal 1, entries.distinct.count(:created_at)
    assert_equal destroyed + 90, Game::Market::ReconcileWallets.call.destroyed
    assert Game::Market::ReconcileWallets.call.balanced?
    assert_equal 0, Game::Market::LedgerEntry.where(kind: "stamp").count
    assert_equal [ { order_id: @order.id, buyer_id: @buyer.id, seller_id: @seller.id, card_season_id: @card.id, price: 900 } ],
      events(Game::Market::OrderServed).map(&:data)
    assert_equal 1, Rails.configuration.event_store.read.stream(Game::Operation.stream_name(@seller.id)).of_type(Game::Market::OrderServed).count
  end

  test "the commission is the confirmed version's while purchase and sale keep the order's" do
    confirmed = open_market!(commission_basis_points: 2_000)

    assert sell.success?

    assert_equal [ [ "purchase", @settings.id ], [ "sale", @settings.id ], [ "commission", confirmed.id ] ], entries.pluck(:kind, :settings_id)
    assert_equal(-180, entries.find_by!(kind: "commission").available_delta)
  end

  test "the sale counts in the edition's average, stored on the order" do
    sold!(@card, 2_000, sold_at: 2.days.ago)
    sold!(@card, 1_000, sold_at: 1.day.ago)

    sell

    assert_equal [ 1_000, 3 ], Game::Market::EditionPrice.find_by!(card_season_id: @card.id).attributes.values_at("average", "sales_used")
    assert_equal 1_000, @order.reload.average_after_sale
  end

  test "one free copy is sold beside copies reserved by a deck, a trade offer and a listing, whose reservations stay" do
    friend = accounts_players(:administrator)
    common = catalog_card_seasons(:common_card_one)
    Game::Holding.where(player_id: @seller.id, card_season_id: @card.id).update_all(quantity: 4)
    hold(friend, common.id, 1)
    Game::Friendship.create!(low_player_id: [ @seller.id, friend.id ].min, high_player_id: [ @seller.id, friend.id ].max)
    rank([ @card.id ])
    deck = Game::CreateDeck.new.call(player: @seller, name: "Tide").value!
    Game::AddCardToDeck.new.call(player: @seller, token: deck.token, card_season_id: @card.id).value!
    Game::ProposeTrade.new.call(player: @seller, recipient: friend, offer: { @card.id => 1 }, request: { common.id => 1 }).value!
    Game::Market::ListCard.new.call(player: @seller, card_season_id: @card.id, starting_price: 1_000, duration_hours: 24, settings_token: @settings.token).value!
    assert_equal [ 4, 3 ], copies(@seller)

    assert sell.success?

    assert_equal [ 3, 3 ], copies(@seller)
  end

  test "a sale into a full window drops the oldest sale and counts the order's price" do
    open_market!(commission_basis_points: 1_000, average_sale_count: 3)
    sold!(@card, 100, sold_at: 3.days.ago)
    sold!(@card, 2_000, sold_at: 2.days.ago)
    sold!(@card, 800, sold_at: 1.day.ago)

    assert sell.success?

    assert_equal [ 900, 3 ], Game::Market::EditionPrice.find_by!(card_season_id: @card.id).attributes.values_at("average", "sales_used")
    assert_equal 900, @order.reload.average_after_sale
  end

  test "a Rare and above is never sold to an order, after the market and the version are checked, and nothing moves" do
    cards = %i[rare_card_one portal_one].map { catalog_card_seasons(it) }
    orders = cards.map { |card| hold(@seller, card.id, 1) && order!(@buyer, card, 900) }

    cards.zip(orders).each do |card, order|
      assert_no_difference([ -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.sum(:quantity) }, -> { Game::Holding.sum(:reserved) },
        -> { Rails.configuration.event_store.read.count } ]) do
        assert_equal :direct_sale_not_for_rarity, sell(order, card:).failure
        assert_equal :amounts_changed, sell(order, card:, settings_token: "stale").failure
      end
      assert_equal "open", order.reload.status
    end
  end

  test "a buyer banned since the screen was drawn is no longer served" do
    @buyer.update_columns(banned_at: Time.current)

    refused(:best_order_changed)
  end

  test "the best order is served, best price then oldest" do
    better = order!(accounts_players(:administrator).tap { fund!(it, 5_000) }, @card, 1_000)

    assert sell(better).success?

    assert_equal [ "open", "served" ], [ @order.reload.status, better.reload.status ]
  end

  test "an order outbid by a better one is refused" do
    order!(accounts_players(:administrator).tap { fund!(it, 5_000) }, @card, 1_000)

    refused(:best_order_changed)
  end

  def refused_once_changed
    assert_no_difference([ -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.sum(:quantity) } ]) do
      assert_equal :best_order_changed, sell.failure
    end
  end

  test "an order withdrawn meanwhile is refused" do
    @order.update_columns(status: "withdrawn")

    refused_once_changed
  end

  test "an order served meanwhile is refused" do
    @order.update_columns(status: "served", seller_id: accounts_players(:administrator).id, served_card_season_id: @card.id, served_at: Time.current,
      average_after_sale: 900)

    refused_once_changed
  end

  test "an order that stops being the best once the locks are held is refused" do
    calls = 0
    better = nil
    original = Game::Market::BestEligibleOrder.method(:call)
    second_look = ->(*args, **options) do
      calls += 1
      better ||= order!(accounts_players(:administrator).tap { fund!(it, 5_000) }, @card, 1_000) if calls == 2
      original.call(*args, **options)
    end

    result = stub_singleton(Game::Market::BestEligibleOrder, :call, second_look) { sell }

    assert_equal :best_order_changed, result.failure
    assert_equal [ "open", 1 ], [ @order.reload.status, copies(@seller).first ]
  end

  test "an unknown token, an expired order and the seller's own order are refused" do
    refused(:best_order_changed, Game::Market::Order.new(token: "unknown"))
    own = order!(@seller, @card, 950)
    refused(:best_order_changed, own)
    @order.update_columns(expires_at: 1.minute.ago)
    refused(:best_order_changed)
  end

  test "a stale settings version and a closed market are refused" do
    refused(:amounts_changed, settings_token: "stale")
    close_market!
    refused(:market_closed)
  end

  test "a copy that is not free is refused" do
    Game::Holding.where(player_id: @seller.id).update_all(reserved: 1)

    refused(:copy_not_free)
  end

  test "a removed seller is refused" do
    @seller.update_columns(banned_at: Time.current)

    refused(:player_required)
  end

  test "a seller deleted before the locks are taken is refused" do
    stub_singleton(Game::TradeLocks, :players, ->(*) { @seller.update_columns(deleted_at: Time.current, steam_id: nil) }) do
      refused(:player_required)
    end
  end

  test "an edition without a rarity has no order to serve" do
    @card.update_columns(rarity: nil)

    refused(:best_order_changed)
  end

  test "a deadlock is the market being busy" do
    stub_singleton(Game::Market::Ledger, :post, ->(*) { raise ActiveRecord::Deadlocked }) do
      refused(:market_busy)
    end
  end
end
