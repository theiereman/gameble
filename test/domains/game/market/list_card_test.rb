require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/singleton_stub"

class Game::Market::ListCardTest < ActiveSupport::TestCase
  include Holdings
  include MarketSettings
  include SingletonStub

  setup do
    @player = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one)
    @settings = open_market!
    @minimum = @settings.minimum_price_common
    @stamp = @settings.stamp_common
    fund(@player, 1_000)
    hold(@player, @common.id, 1)
  end

  def fund(player, amount)
    Game::Market::Mint.credit(player_id: player.id, amount:, settings_id: @settings.id)
  end

  def list(card_season_id: @common.id, starting_price: @minimum, buy_now_price: nil, duration_hours: 24, token: @settings.token, player: @player)
    Game::Market::ListCard.new.call(player:, card_season_id:, starting_price:, buy_now_price:, duration_hours:, settings_token: token)
  end

  def holding = Game::Holding.find_by!(player_id: @player.id, card_season_id: @common.id)

  def wallet = Game::Market::Wallet.find_by!(player_id: @player.id)

  def nothing_moves(&)
    assert_no_difference([ -> { Game::Market::Listing.count }, -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.sum(:reserved) } ], &)
  end

  def refused(code, **arguments)
    nothing_moves { assert_equal code, list(**arguments).failure }
  end

  test "a free copy becomes one open listing, reserved, stamped, with one event" do
    result = nil
    assert_difference [ -> { Game::Market::Listing.count }, -> { Game::Market::LedgerEntry.count } ], 1 do
      travel_to(Time.utc(2026, 11, 10, 12)) { result = list(starting_price: @minimum, buy_now_price: @minimum * 2, duration_hours: 12) }
    end

    listing = result.value!
    assert_equal [ @player.id, @common.id, @settings.id, @minimum, @minimum * 2, 12, @minimum, nil, "open" ],
      listing.values_at(:seller_id, :card_season_id, :settings_id, :starting_price, :buy_now_price, :duration_hours, :current_price, :leader_id, :status)
    assert_equal Time.utc(2026, 11, 11, 0), listing.ends_at
    assert_equal 24, listing.token.size
    assert_equal 1, holding.reserved
    assert_equal 1_000 - @stamp, wallet.available
    stamp = Game::Market::LedgerEntry.find_by!(listing_id: listing.id)
    assert_equal [ "stamp", -@stamp, @player.id, @settings.id ], stamp.values_at(:kind, :available_delta, :player_id, :settings_id)
    published = Rails.configuration.event_store.read.stream(Game::Operation.stream_name(@player.id)).of_type([ Game::Market::CardListed ]).to_a
    assert_equal [ { listing_id: listing.id, seller_id: @player.id, card_season_id: @common.id } ], published.map(&:data)
  end

  test "an only copy can be listed, and the reserved copy is then refused to entrust and to trade" do
    assert list.success?
    assert_equal :not_enough_copies, Game::Market::EntrustCards.new.call(player: @player, lines: { @common.id => 1 }, settings_token: @settings.token).failure
    assert_equal :copy_not_free, list.failure
  end

  test "the seller's balance job is enqueued after commit, and none for a refusal" do
    assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: @player.id, balance: true } ] ]) { list.value! }
    assert_no_enqueued_jobs(only: PlayerStreamJob) { list(starting_price: 1) }
  end

  test "a closed or never opened market refuses" do
    close_market!
    refused :market_closed
    Game::Market::Settings.delete_all
    refused :market_closed
  end

  test "a stale form is refused" do
    refused :amounts_changed, token: "stale"
  end

  test "a card-season without a rarity cannot be listed" do
    Catalog::CardSeason.where(id: @common.id).update_all(rarity: nil)
    refused :no_rarity
  end

  test "no holding, or a copy already reserved, is not free" do
    refused :copy_not_free, card_season_id: catalog_card_seasons(:rare_card_one).id
    holding.update_columns(reserved: 1)
    refused :copy_not_free
  end

  test "every price rule refuses" do
    refused :start_below_minimum, starting_price: @minimum - 1
    refused :buy_now_below_minimum, starting_price: @minimum, buy_now_price: @minimum - 1
    refused :buy_now_not_above_start, starting_price: @minimum, buy_now_price: @minimum
    refused :invalid_price, starting_price: 0
    refused :invalid_price, starting_price: "abc"
    refused :invalid_price, starting_price: "12.5"
    refused :invalid_price, starting_price: "0x40"
    refused :invalid_price, starting_price: "1_000"
    refused :invalid_price, starting_price: @minimum, buy_now_price: -4
  end

  test "an amount above the bigint maximum is a refusal, never a range error" do
    refused :invalid_price, starting_price: 99_999_999_999_999_999_999
    refused :invalid_price, starting_price: @minimum, buy_now_price: 99_999_999_999_999_999_999
  end

  test "the bigint maximum passes the normalisation and meets the other rules" do
    maximum = Game::Market::ListCard::MAX_AMOUNT
    refused :buy_now_not_above_start, starting_price: maximum, buy_now_price: maximum
    Game::Market::Wallet.where(player_id: @player.id).update_all(available: 0)
    refused :stamp_not_covered, starting_price: maximum
  end

  test "a duration outside the version's three is refused" do
    refused :invalid_duration, duration_hours: 5
    refused :invalid_duration, duration_hours: "soon"
  end

  test "a stamp the wallet does not cover is refused, and a missing wallet reads as zero" do
    Game::Market::Wallet.where(player_id: @player.id).update_all(available: @stamp - 1)
    refused :stamp_not_covered
    stranger = Accounts::Player.create!(steam_id: "76561198000002222", persona_name: "Bob")
    hold(stranger, @common.id, 1)
    nothing_moves { assert_equal :stamp_not_covered, list(player: stranger).failure }
  end

  test "a deadlock answers market_busy and rolls everything back" do
    stub_singleton(Game::Market::Ledger, :post, ->(_entries) { raise ActiveRecord::Deadlocked }) do
      nothing_moves { assert_equal :market_busy, list.failure }
    end
    assert_equal 0, holding.reserved
  end

  test "a banned player cannot list" do
    nothing_moves { assert_equal :player_required, list(player: accounts_players(:banned)).failure }
  end
end
