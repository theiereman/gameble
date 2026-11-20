require "test_helper"
require_relative "../../../support/singleton_stub"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::PlaceOrderTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SingletonStub
  include MarketAuctions
  include MarketBidding
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @card = catalog_cards(:common_card)
    @settings = open_market!(order_duration_days: 7)
    fund!(@player, 1_000)
  end

  def place(price = 100, player: @player, card_id: @card.id, settings_token: @settings.token)
    Game::Market::PlaceOrder.new.call(player:, card_id:, price:, settings_token:)
  end

  def nothing_written(&)
    assert_no_difference([ -> { Game::Market::Order.count }, -> { Game::Market::LedgerEntry.count }, -> { Rails.configuration.event_store.read.count } ], &)
  end

  def refused(code, *, **)
    result = nil
    nothing_written { result = place(*, **) }
    assert_equal code, result.failure
  end

  test "an order holds its price, ends after the order duration and publishes one OrderPlaced" do
    freeze_time do
      order = place(100).value!

      assert_equal [ "open", 100, @card.id, @settings.id, 7.days.from_now ], order.reload.attributes.values_at("status", "price", "card_id", "settings_id", "expires_at")
      assert_equal [ 900, 100 ], figures(@player)
      entry = Game::Market::LedgerEntry.find_by!(order_id: order.id)
      assert_equal [ "hold", -100, 100, @settings.id ], entry.attributes.values_at("kind", "available_delta", "committed_delta", "settings_id")
      assert_equal [ { order_id: order.id, player_id: @player.id, card_id: @card.id, amount: 100 } ], events(Game::Market::OrderPlaced).map(&:data)
    end
  end

  test "the balance notice leaves once the order commits" do
    assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: @player.id, balance: true } ] ]) { assert place.success? }
  end

  test "a closed or suspended market refuses" do
    close_market!(first_opened_at: 1.day.ago)

    refused(:market_closed, settings_token: Game::Market::CurrentSettings.call.token)
  end

  test "a stale settings version refuses" do
    refused(:amounts_changed, settings_token: "stale")
  end

  test "a card with no rarity in a published season refuses" do
    card = Catalog::Card.create!(source_key: "src:901", release_date: Date.new(2000, 1, 1), image_url: "https://images.example.test/901.jpg",
      store_url: "https://store.example.test/901")

    refused(:card_not_published, card_id: card.id)
  end

  test "a second order on one card refuses, even when the first is past its end" do
    place.value!.update_columns(expires_at: 1.minute.ago)

    refused(:order_already_open)
  end

  test "an insert that loses the race to the index refuses as already open" do
    stub_singleton(Game::Market::Order, :create!, ->(*, **) { raise ActiveRecord::RecordNotUnique }) do
      refused(:order_already_open)
    end
  end

  test "a price under every minimum refuses and leaves no order" do
    refused(:order_below_minimum, @settings.minimum_price(:common) - 1)
  end

  test "a price over what is available refuses and leaves no order" do
    refused(:more_than_available, 1_001)
  end

  test "a price that is not a whole positive number refuses" do
    [ "", "0", "abc" ].each { refused(:invalid_price, it) }
  end

  test "a deadlock refuses as busy" do
    stub_singleton(Game::BankLock, :acquire, ->(*) { raise ActiveRecord::Deadlocked }) { refused(:market_busy) }
  end

  test "a removed player refuses" do
    refused(:player_required, player: accounts_players(:banned))
  end
end
