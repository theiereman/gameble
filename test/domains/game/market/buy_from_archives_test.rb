require "test_helper"
require_relative "../../../support/singleton_stub"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::BuyFromArchivesTest < ActiveSupport::TestCase
  include SingletonStub
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @card = catalog_card_seasons(:rare_card_one)
    @settings = open_market!(archive_price_rare: 500)
    fund!(@player, 1_000)
    @stock = Game::Market::ArchiveStock.create!(card_season_id: @card.id, quantity: 3)
  end

  def token = @token ||= SecureRandom.base58(24)

  def buy(player: @player, card_season_id: @card.id, purchase_token: token, settings_token: Game::Market::CurrentSettings.call.token)
    Game::Market::BuyFromArchives.new.call(player:, card_season_id:, purchase_token:, settings_token:)
  end

  def copies = Game::Holding.find_by(player_id: @player.id, card_season_id: @card.id)&.attributes&.values_at("quantity", "reserved")

  def stock = Game::Market::ArchiveStock.find_by(card_season_id: @card.id)&.quantity

  def nothing_moves(&)
    assert_no_difference([ -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.sum(:quantity) }, -> { Game::Market::ArchiveWithdrawal.count },
      -> { Game::Market::ArchiveStock.sum(:quantity) }, -> { Rails.configuration.event_store.read.count } ], &)
  end

  def refused(code, **)
    result = nil
    nothing_moves { result = buy(**) }
    assert_equal code, result.failure
  end

  test "a purchase records the withdrawal, lowers the stock, gives the copy and destroys the price" do
    hold(@player, @card.id, 2, reserved: 1)
    destroyed = Game::Market::ReconcileWallets.call.destroyed
    result = nil

    freeze_time do
      result = buy
      assert result.success?

      withdrawal = result.value!
      assert_equal [ @player.id, @card.id, token, 500, @settings.id, Time.current ],
        withdrawal.attributes.values_at("player_id", "card_season_id", "purchase_token", "price", "settings_id", "created_at")
      assert_equal Time.current, Game::Market::ArchiveStock.find_by!(card_season_id: @card.id).updated_at
    end
    assert_equal 2, stock
    assert_equal [ 3, 1 ], copies
    assert_equal [ 500, 0 ], figures(@player)
    assert_equal [ [ "archive_purchase", -500, 0, @settings.id ] ],
      Game::Market::LedgerEntry.where(player_id: @player.id, kind: "archive_purchase").pluck(:kind, :available_delta, :committed_delta, :settings_id)
    assert_equal destroyed + 500, Game::Market::ReconcileWallets.call.destroyed
    assert Game::Market::ReconcileWallets.call.balanced?
    assert_equal [ { player_id: @player.id, card_season_id: @card.id, price: 500 } ], events(Game::Market::ArchivePurchased).map(&:data)
    assert_equal 1, Rails.configuration.event_store.read.stream(Game::Operation.stream_name(@player.id)).of_type(Game::Market::ArchivePurchased).count
  end

  test "a purchase is neither in the feed nor in the edition's price" do
    assert_no_difference([ -> { Game::FeedEntry.count }, -> { Game::Market::EditionPrice.count } ]) do
      assert buy.success?
    end
  end

  test "a first copy is a new holding, after the buyer's pending allocation" do
    received = []
    receiver = Object.new
    receiver.define_singleton_method(:call) { |player:, season:| received << player.id and Dry::Monads::Success([]) }

    stub_singleton(Game::ReceiveSeasonAllocation, :new, ->(*) { receiver }) { assert buy.success? }

    assert_equal [ @player.id ], received
    assert_equal [ 1, 0 ], copies
  end

  test "a set tier reached by the copy is recorded as a trade" do
    stub_singleton(Game::SetTier, :record, ->(**arguments) { Thread.current[:tier_args] = arguments; {} }) { buy }

    assert_equal "trade", Thread.current[:tier_args][:reached_by]
    assert_equal [ @card.id ], Thread.current[:tier_args][:card_season_ids]
  end

  test "the last copy deletes the stock row" do
    @stock.update!(quantity: 1)

    assert buy.success?

    assert_nil stock
  end

  test "a repeated purchase token answers the purchase already made and moves nothing" do
    made = buy.value!
    open_market!(archive_price_rare: 600)
    @stock.delete

    result = nil
    nothing_moves { result = buy }

    assert_equal made, result.value!
  end

  test "a second purchase token buys a second copy" do
    buy

    assert buy(purchase_token: SecureRandom.base58(24)).success?

    assert_equal 1, stock
    assert_equal [ 2, 0 ], copies
  end

  test "a closed market and a stale version are refused" do
    refused(:amounts_changed, settings_token: "stale")
    close_market!(archive_price_rare: 500)
    refused(:market_closed)
  end

  test "a rarity without an Archive price, an edition without rarity and an unknown edition are not in the shop" do
    open_market!
    refused(:not_in_shop)
    open_market!(archive_price_rare: 500)
    @card.update_columns(rarity: nil)
    refused(:not_in_shop)
    refused(:not_in_shop, card_season_id: 0)
  end

  test "a price above the available PiCoins is refused" do
    open_market!(archive_price_rare: 1_001)

    refused(:more_than_available)
  end

  test "an edition the Archives do not hold is out of stock" do
    @stock.delete

    refused(:out_of_stock)
  end

  test "a blank or malformed purchase token is refused" do
    refused(:invalid_purchase_token, purchase_token: "")
    refused(:invalid_purchase_token, purchase_token: "0" * 24)
    refused(:invalid_purchase_token, purchase_token: SecureRandom.base58(23))
  end

  test "a banned or deleted player is refused" do
    @player.update_columns(banned_at: Time.current)
    refused(:player_required)
    @player.update_columns(banned_at: nil, deleted_at: Time.current, steam_id: nil)
    refused(:player_required)
  end

  test "a deadlock is the market being busy" do
    stub_singleton(Game::Market::Ledger, :post, ->(*) { raise ActiveRecord::Deadlocked }) do
      refused(:market_busy)
    end
  end
end
