require "test_helper"
require_relative "../../../support/singleton_stub"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"
require_relative "../../../support/market_orders"

class Game::Market::OrderBackedAuctionTest < ActiveSupport::TestCase
  include SingletonStub
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketOrders
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @first = accounts_players(:moderator)
    @second = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    @settings = open_market!(increment_basis_points: 500)
    hold(@seller, @card.id, 2)
    [ @seller, @first, @second ].each { fund!(it, 1_000) }
  end

  def place!(player, price, **) = order!(player, @card, price, **).tap { Game::Market::RebuildWanted.new.call(player:).value! }

  def list(starting_price: 300, player: @seller)
    Game::Market::ListCard.new.call(player:, card_season_id: @card.id, starting_price:, duration_hours: 24, settings_token: @settings.token)
  end

  def notices(player, kind) = Game::Market::Notice.where(player_id: player.id, kind:)

  def listed_event = events(Game::Market::CardListed).last

  def orders_reading(player) = Game::Market::PlayerOrders.call(player:, locale: :en)

  test "the worked example turns two orders into bids: the best leads, the other is beaten and refunded" do
    destroyed = Game::Market::ReconcileWallets.call.destroyed
    best = place!(@first, 400)
    other = place!(@second, 350)

    listing = list.value!

    assert_equal [ @first.id, 400, 368 ], listing.reload.attributes.values_at("leader_id", "leader_maximum", "current_price")
    assert_equal %w[bid beaten], [ best, other ].map { it.reload.status }
    assert_equal [ [ 600, 400 ], [ 1_000, 0 ] ], [ figures(@first), figures(@second) ]
    assert_equal [ [ @first.id, 400 ] ], entries_of(listing).where(kind: "hold").pluck(:player_id, :committed_delta)
    assert_equal [ [ "beaten", 368 ], [ "leading", 368 ] ], Game::Market::Bid.where(listing_id: listing.id).pluck(:outcome, :price_after).sort
    assert_equal destroyed + @settings.stamp_common, Game::Market::ReconcileWallets.call.destroyed
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "the order's release and the listing's hold both stand for the leader, once each" do
    order = place!(@first, 400)
    listing = list.value!

    ledger = Game::Market::LedgerEntry.where(player_id: @first.id).where.not(kind: "mint").order(:id)
    assert_equal [ [ "hold", order.id, nil ], [ "release", order.id, nil ], [ "hold", nil, listing.id ] ], ledger.pluck(:kind, :order_id, :listing_id)
  end

  test "a single order leads at the starting price" do
    place!(@first, 400)

    listing = list.value!

    assert_equal [ @first.id, 400, 300 ], listing.reload.attributes.values_at("leader_id", "leader_maximum", "current_price")
  end

  test "an order at the starting price converts and one below it stays open with its notice" do
    at = place!(@first, 300)
    below = place!(@second, 280)

    listing = list.value!

    assert_equal %w[bid open], [ at, below ].map { it.reload.status }
    assert_equal [ 720, 280 ], figures(@second)
    assert_equal [ listing.id ], notices(@second, "listed_above_order").pluck(:listing_id)
    assert_empty notices(@second, "order_beaten")
  end

  test "equal maximums go to the earlier order" do
    later = place!(@first, 400, created_at: 1.hour.ago)
    earlier = place!(@second, 400, created_at: 2.hours.ago)

    listing = list.value!

    assert_equal [ @second.id, 400, 400 ], listing.reload.attributes.values_at("leader_id", "leader_maximum", "current_price")
    assert_equal %w[beaten bid], [ later, earlier ].map { it.reload.status }
  end

  test "the history shows an older beaten order as covered by the leader, not as an ordinary bid" do
    place!(@first, 450, created_at: 1.hour.ago)
    place!(@second, 400, created_at: 2.hours.ago)
    listing = list.value!

    lines = Game::Market::BidHistory.call(token: listing.token, viewer: nil)

    assert_equal [ :covered, :bid, :created ], lines.map(&:kind)
    assert_equal [ @second, @first ], lines.first(2).map(&:player)
    assert_equal @first, lines.first.leader
  end

  test "an order of a banned or a deleted owner is never converted" do
    banned = place!(@first, 400)
    deleted = place!(@second, 350)
    @first.update_columns(banned_at: Time.current)
    @second.update_columns(deleted_at: Time.current, steam_id: nil)

    listing = list.value!

    assert_nil listing.reload.leader_id
    assert_equal %w[open open], [ banned, deleted ].map { it.reload.status }
    assert_equal [ [ 600, 400 ], [ 650, 350 ] ], [ figures(@first), figures(@second) ]
  end

  test "the seller's own order is never converted" do
    own = place!(@seller, 400)

    listing = list.value!

    assert_nil listing.reload.leader_id
    assert_equal "open", own.reload.status
  end

  test "an order ended between the read and the locks is left out" do
    best = place!(@first, 400)
    other = place!(@second, 350)
    original = Game::TradeLocks.method(:players)
    ending = ->(*ids) do
      best.update_columns(status: "cancelled")
      original.call(*ids)
    end

    stub_singleton(Game::TradeLocks, :players, ending) { @listing = list.value! }

    assert_equal [ @second.id, 350, 300 ], @listing.reload.attributes.values_at("leader_id", "leader_maximum", "current_price")
    assert_equal %w[cancelled bid], [ best, other ].map { it.reload.status }
  end

  def before_the_locks(change)
    original = Game::TradeLocks.method(:players)
    stub_singleton(Game::TradeLocks, :players, ->(*ids) { change.call.then { original.call(*ids) } }) { yield }
  end

  def auction_lines = [ { card_season_id: @card.id, copies: 1, choice: "auction", starting_price: 300, duration_hours: 24 } ]

  def list_from_the_table
    Game::Market::ApplyWantedChoices.new.call(player: @seller, lines: auction_lines, settings_token: @settings.token).value!.listed.sole.listing
  end

  def assert_left_open(order, listing)
    assert_nil listing.reload.leader_id
    assert_equal "open", order.reload.status
    assert_empty Game::Market::Bid.where(listing_id: listing.id)
    assert_equal [ [ "hold", order.id ] ], Game::Market::LedgerEntry.where(order_id: order.id).pluck(:kind, :order_id)
    assert_equal [ 600, 400 ], figures(@first)
  end

  test "an order that expires in the lock wait is left open for the expiry job" do
    order = place!(@first, 400)

    before_the_locks(-> { order.update_columns(expires_at: 1.second.ago) }) { @listing = list.value! }

    assert_left_open(order, @listing)
  end

  test "an order that expires in the lock wait of the Confier table is left open for the expiry job" do
    order = place!(@first, 400)

    before_the_locks(-> { order.update_columns(expires_at: 1.second.ago) }) { @listing = list_from_the_table }

    assert_left_open(order, @listing)
  end

  test "an order placed after the read is not converted" do
    placed = place!(@first, 400)
    later = nil

    before_the_locks(-> { later ||= place!(@second, 500) }) { @listing = list.value! }

    assert_equal [ @first.id, 400, 300 ], @listing.reload.attributes.values_at("leader_id", "leader_maximum", "current_price")
    assert_equal %w[bid open], [ placed, later ].map { it.reload.status }
  end

  test "an order placed after the read of the Confier table is not converted" do
    placed = place!(@first, 400)
    later = nil

    before_the_locks(-> { later ||= place!(@second, 500) }) { @listing = list_from_the_table }

    assert_equal [ @first.id, 400, 300 ], @listing.reload.attributes.values_at("leader_id", "leader_maximum", "current_price")
    assert_equal %w[bid open], [ placed, later ].map { it.reload.status }
  end

  test "a start above every order behaves as before" do
    order = place!(@first, 400)

    listing = list(starting_price: 500).value!

    assert_nil listing.reload.leader_id
    assert_equal "open", order.reload.status
    assert_equal [ 600, 400 ], figures(@first)
    assert_empty listed_event.data.fetch(:converted)
  end

  test "the event names every converted order and the notices are written once" do
    best = place!(@first, 400)
    other = place!(@second, 350)

    listing = list.value!

    assert_equal [ { order_id: best.id, owner_id: @first.id, listing_id: listing.id, price: 400, status: "bid" },
      { order_id: other.id, owner_id: @second.id, listing_id: listing.id, price: 350, status: "beaten" } ], listed_event.data.fetch(:converted)
    assert_equal [ [ listing.id, 400 ] ], notices(@first, "order_leads").pluck(:listing_id, :amount)
    assert_equal [ [ listing.id, 350 ] ], notices(@second, "order_beaten").pluck(:listing_id, :amount)
    assert_empty notices(@first, "wanted") + notices(@second, "wanted")
  end

  test "an auction opened from the Confier table converts the orders, tells their owners once and leaves them no wanted notice" do
    best = place!(@first, 400)
    other = place!(@second, 350)
    lines = [ { card_season_id: @card.id, copies: 1, choice: "auction", starting_price: 300, duration_hours: 24 } ]

    listing = Game::Market::ApplyWantedChoices.new.call(player: @seller, lines:, settings_token: @settings.token).value!.listed.sole.listing

    assert_equal [ @first.id, 400, 368 ], listing.reload.attributes.values_at("leader_id", "leader_maximum", "current_price")
    assert_equal %w[bid beaten], [ best, other ].map { it.reload.status }
    assert_equal [ { order_id: best.id, owner_id: @first.id, listing_id: listing.id, price: 400, status: "bid" },
      { order_id: other.id, owner_id: @second.id, listing_id: listing.id, price: 350, status: "beaten" } ],
      events(Game::Market::WantedChoicesApplied).sole.data.fetch(:converted)
    assert_equal [ [ listing.id, 400 ] ], notices(@first, "order_leads").pluck(:listing_id, :amount)
    assert_equal [ [ listing.id, 350 ] ], notices(@second, "order_beaten").pluck(:listing_id, :amount)
    assert_empty notices(@first, "wanted") + notices(@second, "wanted")
    assert_equal [ [ 600, 400 ], [ 1_000, 0 ] ], [ figures(@first), figures(@second) ]
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "a later bid releases the converted leader's PiCoins as any maximum and the order reads outbid" do
    order = place!(@first, 400)
    listing = list.value!
    @listing = listing

    assert bid(@second, 500).success?

    assert_equal "bid", order.reload.status
    assert_equal [ 1_000, 0 ], figures(@first)
    assert_equal [ "outbid" ], outcomes(@first)
    assert_equal [ "outbid" ], notices(@first, "outbid").pluck(:kind)
    assert_equal [ "outbid" ], orders_reading(@first).recent.map(&:status)
    assert_equal [ listing.token ], orders_reading(@first).recent.map(&:listing_token)
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "the order reads in the auction while it leads, and won once the auction sold to it" do
    place!(@first, 400)
    @listing = list.value!

    assert_equal [ "bid" ], orders_reading(@first).in_progress.map(&:status)

    @listing.update_columns(ends_at: 1.minute.ago)
    assert Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id).success?

    assert_equal [ "won" ], orders_reading(@first).recent.map(&:status)
    assert_equal [ 1, 0 ], Game::Holding.find_by!(player_id: @first.id, card_season_id: @card.id).attributes.values_at("quantity", "reserved")
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "the orders in progress sort by the end they show, the auction's for a bid" do
    place!(@first, 400, expires_at: 7.days.from_now)
    waiting = order!(@first, catalog_card_seasons(:uncommon_card_one), 100, expires_at: 3.days.from_now)
    list.value!

    assert_equal [ "bid", "open" ], orders_reading(@first).in_progress.map(&:status)
    assert_equal waiting.token, orders_reading(@first).in_progress.last.token
  end

  test "a beaten order reads outbid with the auction linked" do
    place!(@first, 400)
    other = place!(@second, 350)
    listing = list.value!

    row = orders_reading(@second).recent.sole

    assert_equal [ other.token, "outbid", listing.token ], [ row.token, row.status, row.listing_token ]
  end

  test "a converted order reads its auction with every notice of it deleted: leading, outbid, then won" do
    leading = place!(@first, 400)
    beaten = place!(@second, 350)
    @listing = list.value!
    Game::Market::Notice.where(kind: %w[order_leads order_beaten]).delete_all

    assert_equal [ [ leading.token, "bid", @listing.token ] ], orders_reading(@first).in_progress.map { [ it.token, it.status, it.listing_token ] }
    assert_equal [ [ beaten.token, "outbid", @listing.token ] ], orders_reading(@second).recent.map { [ it.token, it.status, it.listing_token ] }

    @listing.update_columns(ends_at: 1.minute.ago)
    assert Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id).success?
    Game::Market::Notice.where(kind: %w[order_leads order_beaten]).delete_all

    assert_equal [ [ leading.token, "won", @listing.token ] ], orders_reading(@first).recent.map { [ it.token, it.status, it.listing_token ] }
  end

  test "a converted order whose auction was withdrawn reads outbid with its PiCoins returned" do
    order = place!(@first, 400)
    listing = list.value!
    @seller.update_columns(banned_at: Time.current)

    assert Game::Market::WithdrawListing.new.call(player: @seller, listing_id: listing.id).success?

    assert_equal [ 1_000, 0 ], figures(@first)
    assert_equal [ [ order.token, "outbid", listing.token ] ], orders_reading(@first).recent.map { [ it.token, it.status, it.listing_token ] }
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "a converted order whose auction ended cancelled reads outbid" do
    order = place!(@first, 400)
    listing = list.value!

    listing.update_columns(status: "cancelled")

    assert_equal [ [ order.token, "outbid", listing.token ] ], orders_reading(@first).recent.map { [ it.token, it.status, it.listing_token ] }
  end

  test "the converted bids feed the tied-bids signal and the bid history" do
    place!(@first, 400)
    listing = list.value!
    @listing = listing

    found = Game::Market::AltSignals::TiedBids.call(now: Time.current, ties: [ [ @seller.id, @first.id ].minmax ])
    lines = Game::Market::BidHistory.call(token: listing.token, viewer: nil)

    assert_equal [ [ @first.id, @seller.id ] ], found.map { [ it.account_id, it.other_account_id ] }
    assert_equal [ :bid, :created ], lines.map(&:kind)
    assert_equal [ @first, @seller ], lines.map(&:player)
  end
end
