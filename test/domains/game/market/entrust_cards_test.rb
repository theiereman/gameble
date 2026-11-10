require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/singleton_stub"

class Game::Market::EntrustCardsTest < ActiveSupport::TestCase
  include Holdings
  include MarketSettings
  include SingletonStub

  setup do
    @player = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
    @legendary = catalog_card_seasons(:legendary_card_one)
    @settings = open_market!
  end

  def minted_before(player, amount)
    Game::Market::Mint.credit(player_id: player.id, amount:, settings_id: @settings.id)
  end

  def entrust(lines, token: @settings.token, player: @player)
    Game::Market::EntrustCards.new.call(player:, lines:, settings_token: token)
  end

  def quantity(card_season) = Game::Holding.find_by(player_id: @player.id, card_season_id: card_season.id)&.quantity.to_i

  def wallet = Game::Market::Wallet.find_by(player_id: @player.id)

  def nothing_moves(&)
    assert_no_difference([ -> { Game::Holding.sum(:quantity) }, -> { Game::Market::LedgerEntry.count }, -> { Game::Market::ArchiveDeposit.count } ], &)
  end

  test "a batch lowers the holdings, mints one entry, records the deposits and publishes the event" do
    hold(@player, @common.id, 2)
    hold(@player, @rare.id, 1)

    result = nil
    assert_difference -> { Game::Market::LedgerEntry.count } => 1 do
      result = entrust({ @common.id => 2, @rare.id => 1 })
    end

    assert_equal 7_000, result.value!.minted
    assert_equal 3, result.value!.copies
    assert_equal [ [], 1_200_000 ], [ result.value!.stayed, result.value!.cap_left ]
    assert_equal [ 0, 0 ], [ quantity(@common), quantity(@rare) ]
    assert_equal [ 7_000, 0 ], wallet.values_at(:available, :committed)
    mint = Game::Market::LedgerEntry.find_by!(player_id: @player.id)
    assert_equal [ "mint", 7_000, @settings.id ], mint.values_at(:kind, :available_delta, :settings_id)
    assert_equal({ @common.id => 2, @rare.id => 1 }, Game::Market::ArchiveDeposit.where(player_id: @player.id).pluck(:card_season_id, :quantity).to_h)
    assert_equal 1, Rails.configuration.event_store.read.stream(Game::Operation.stream_name(@player.id)).of_type([ Game::Market::CardsEntrusted ]).count
  end

  test "a second batch adds to the deposits and the wallet" do
    hold(@player, @common.id, 3)
    entrust({ @common.id => 1 })
    entrust({ @common.id => 2 })

    assert_equal 3, Game::Market::ArchiveDeposit.find_by!(player_id: @player.id, card_season_id: @common.id).quantity
    assert_equal 3_000, wallet.available
  end

  test "an entrusted card leaves the showcase once no copy is left" do
    hold(@player, @common.id, 1)
    Game::ShowcaseEntry.create!(player_id: @player.id, card_season_id: @common.id, position: 0)

    entrust({ @common.id => 1 }).value!

    assert_not Game::ShowcaseEntry.exists?(player_id: @player.id, card_season_id: @common.id)
  end

  test "the amounts are those of the version in force" do
    hold(@player, @common.id, 1)
    current = open_market!(entrustment_common: 1_500)

    assert_equal 1_500, entrust({ @common.id => 1 }, token: current.token).value!.minted
  end

  test "a closed market moves nothing" do
    hold(@player, @common.id, 1)
    closed = close_market!

    nothing_moves { assert_equal :market_closed, entrust({ @common.id => 1 }, token: closed.token).failure }
    assert_equal 1, quantity(@common)
  end

  test "a market that has no settings yet is closed" do
    hold(@player, @common.id, 1)
    Game::Market::Settings.delete_all

    nothing_moves { assert_equal :market_closed, entrust({ @common.id => 1 }, token: "none").failure }
  end

  test "a form drawn before a change is refused" do
    hold(@player, @common.id, 1)
    drawn = @settings.token
    open_market!(entrustment_common: 2_000)

    nothing_moves { assert_equal :amounts_changed, entrust({ @common.id => 1 }, token: drawn).failure }
  end

  test "reserved copies cannot be entrusted" do
    hold(@player, @common.id, 2, reserved: 1)

    nothing_moves { assert_equal :not_enough_copies, entrust({ @common.id => 2 }).failure }
    assert_equal 1_000, entrust({ @common.id => 1 }).value!.minted
  end

  test "a card the player does not hold cannot be entrusted" do
    nothing_moves { assert_equal :not_enough_copies, entrust({ @common.id => 1 }).failure }
  end

  test "a card-season with no rarity cannot be entrusted" do
    hold(@player, @common.id, 1)
    Catalog::CardSeason.where(id: @common.id).update_all(rarity: nil)

    nothing_moves { assert_equal :no_rarity, entrust({ @common.id => 1 }).failure }
  end

  test "a batch with no copy is refused" do
    nothing_moves do
      assert_equal :empty_batch, entrust({}).failure
      assert_equal :empty_batch, entrust({ @common.id => 0 }).failure
    end
  end

  test "one line that fails keeps the whole batch back" do
    hold(@player, @common.id, 1)

    nothing_moves { assert_equal :not_enough_copies, entrust({ @common.id => 1, @rare.id => 1 }).failure }
    assert_equal 1, quantity(@common)
  end

  test "a deadlock answers market_busy and rolls everything back" do
    hold(@player, @common.id, 1)

    stub_singleton(Game::Market::Mint, :credit, ->(**) { raise ActiveRecord::Deadlocked }) do
      nothing_moves { assert_equal :market_busy, entrust({ @common.id => 1 }).failure }
    end
    assert_equal 1, quantity(@common)
  end

  test "a deleted player cannot entrust" do
    hold(@player, @common.id, 1)
    @player.update_columns(deleted_at: Time.current, steam_id: nil)

    nothing_moves { assert_equal :player_required, entrust({ @common.id => 1 }).failure }
  end

  test "a legendary over the cap stays while cheaper copies pass, and the cap left is the figure before the batch" do
    hold(@player, @legendary.id, 1)
    hold(@player, @uncommon.id, 2)
    hold(@player, @common.id, 1)
    minted_before(@player, 1_150_000)

    value = entrust({ @legendary.id => 1, @uncommon.id => 2, @common.id => 1 }).value!

    assert_equal [ 5_000, 3, 50_000 ], [ value.minted, value.copies, value.cap_left ]
    assert_equal [ Game::Market::EntrustCards::Stayed.new(card_season_id: @legendary.id, copies: 1, value: 100_000) ], value.stayed
    assert_equal [ 1, 0, 0 ], [ quantity(@legendary), quantity(@uncommon), quantity(@common) ]
    assert_nil Game::Market::ArchiveDeposit.find_by(player_id: @player.id, card_season_id: @legendary.id)
    assert_equal 1_155_000, wallet.available
  end

  test "a copy that does not fit is skipped and a cheaper one after it still passes" do
    hold(@player, @rare.id, 1)
    hold(@player, @uncommon.id, 1)
    minted_before(@player, 1_197_000)

    value = entrust({ @rare.id => 1, @uncommon.id => 1 }).value!

    assert_equal 2_000, value.minted
    assert_equal [ @rare.id ], value.stayed.map(&:card_season_id)
    assert_equal 1, quantity(@rare)
  end

  test "a line is split by copies" do
    hold(@player, @common.id, 3)
    minted_before(@player, 1_197_500)

    value = entrust({ @common.id => 3 }).value!

    assert_equal [ 2, 1, 2_000 ], [ value.copies, value.stayed.sole.copies, value.minted ]
    assert_equal 1, quantity(@common)
  end

  test "the lines are applied in the order received" do
    hold(@player, @rare.id, 1)
    hold(@player, @uncommon.id, 1)
    minted_before(@player, 1_195_000)

    value = entrust({ @uncommon.id => 1, @rare.id => 1 }).value!

    assert_equal 7_000, value.minted
  end

  test "a batch where nothing fits moves nothing" do
    hold(@player, @common.id, 1)
    minted_before(@player, 1_199_500)

    assert_no_difference -> { Rails.configuration.event_store.read.of_type([ Game::Market::CardsEntrusted ]).count } do
      nothing_moves { assert_equal :nothing_fits, entrust({ @common.id => 1 }).failure }
    end
    assert_equal 1, quantity(@common)
  end

  test "a cap fully minted today refuses the batch" do
    hold(@player, @common.id, 1)
    minted_before(@player, 1_200_000)

    nothing_moves { assert_equal :nothing_fits, entrust({ @common.id => 1 }).failure }
  end

  test "the cap renews at 00:00 UTC" do
    hold(@player, @common.id, 1)
    travel_to Time.utc(2026, 11, 10, 23, 59) do
      minted_before(@player, 1_200_000)
      nothing_moves { assert_equal :nothing_fits, entrust({ @common.id => 1 }).failure }
    end

    travel_to Time.utc(2026, 11, 11, 0, 1) do
      assert_equal 1_200_000, entrust({ @common.id => 1 }).value!.cap_left
    end
  end

  test "only mint entries of this player count" do
    hold(@player, @common.id, 1)
    other = accounts_players(:moderator)
    minted_before(other, 1_200_000)
    Game::Market::Ledger.post([ Game::Market::Ledger::Entry.new(player_id: @player.id, kind: :sale, available_delta: 1_200_000, settings_id: @settings.id) ])

    assert_equal 1_200_000, entrust({ @common.id => 1 }).value!.cap_left
  end

  test "a cap lowered under what was minted today leaves nothing and never goes negative" do
    hold(@player, @common.id, 1)
    minted_before(@player, 1_000_000)
    lowered = open_market!(daily_cap: 500_000)

    nothing_moves { assert_equal :nothing_fits, entrust({ @common.id => 1 }, token: lowered.token).failure }
  end

  test "the event lists only the entrusted copies" do
    hold(@player, @legendary.id, 1)
    hold(@player, @common.id, 1)
    minted_before(@player, 1_150_000)

    entrust({ @legendary.id => 1, @common.id => 1 }).value!

    event = Rails.configuration.event_store.read.of_type([ Game::Market::CardsEntrusted ]).last
    assert_equal [ { card_season_id: @common.id, copies: 1 } ], event.data[:cards].map(&:symbolize_keys)
  end
end
