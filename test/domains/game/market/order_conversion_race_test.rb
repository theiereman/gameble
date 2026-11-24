require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_orders"
require_relative "../../../support/lock_races"

# Two sellers whose orders sit on each other's cards list at once, each on its own connection, so the test commits for real
# and removes what it wrote.
class Game::Market::OrderConversionRaceTest < ActiveSupport::TestCase
  include Holdings
  include LockRaces
  include MarketAuctions
  include MarketOrders
  include MarketSettings

  self.use_transactional_tests = false

  PAUSE = 0.3

  setup do
    @first = Accounts::Player.create!(steam_id: "76561197960299101", persona_name: "Crossed first")
    @second = Accounts::Player.create!(steam_id: "76561197960299102", persona_name: "Crossed second")
    @common = catalog_card_seasons(:common_card_one)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
    @settings = open_market!
    hold(@first, @common.id)
    hold(@second, @uncommon.id)
    [ @first, @second ].each { fund!(it, 1_000) }
    @first_order = order!(@first, @uncommon, 100)
    @second_order = order!(@second, @common, 100)
  end

  teardown do
    listings = Game::Market::Listing.where(seller_id: [ @first.id, @second.id ]).to_a
    purge_market_race([ @first.id, @second.id ], listing: listings, settings: @settings, card: @common)
  end

  def list(player, card, price) = -> do
    Game::Market::ListCard.new.call(player: Accounts::Player.find(player.id), card_season_id: card.id, starting_price: price, duration_hours: 24,
      settings_token: @settings.token)
  end

  def confier(player, card, price) = -> do
    Game::Market::ApplyWantedChoices.new.call(player: Accounts::Player.find(player.id), settings_token: @settings.token,
      lines: [ { card_season_id: card.id, copies: 1, choice: "auction", starting_price: price, duration_hours: 24 } ])
  end

  # Holds each thread after its first bank lock, so the other takes its own first one.
  def pausing_after_the_first_lock
    original = Game::BankLock.method(:acquire)
    Game::BankLock.define_singleton_method(:acquire) do |player_id|
      original.call(player_id)
      first = Thread.current[:locked].nil?
      Thread.current[:locked] = true
      sleep PAUSE if first
    end
    yield
  ensure
    Game::BankLock.define_singleton_method(:acquire, original)
  end

  test "two sellers with orders on each other's cards both open their auctions" do
    results = pausing_after_the_first_lock { together(list(@first, @common, 20), list(@second, @uncommon, 40)) }

    assert_equal [ true, true ], results.map(&:success?)
    assert_equal [ @second.id, @first.id ], [ @first, @second ].map { Game::Market::Listing.find_by!(seller_id: it.id).leader_id }
    assert_equal %w[bid bid], [ @first_order, @second_order ].map { it.reload.status }
  end

  test "two sellers with orders on each other's cards both open their auctions from the Confier table" do
    results = pausing_after_the_first_lock { together(confier(@first, @common, 20), confier(@second, @uncommon, 40)) }

    assert_equal [ true, true ], results.map(&:success?)
    assert_equal [ @second.id, @first.id ], [ @first, @second ].map { Game::Market::Listing.find_by!(seller_id: it.id).leader_id }
    assert_equal %w[bid bid], [ @first_order, @second_order ].map { it.reload.status }
  end
end
