require "test_helper"
require_relative "../../../support/market"

class Game::Market::LedgerTest < ActiveSupport::TestCase
  include MarketSettings

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @settings = open_market!
  end

  def entry(player, kind, available: 0, committed: 0, order: nil)
    Game::Market::Ledger::Entry.new(player_id: player.id, kind:, available_delta: available, committed_delta: committed, order_id: order&.id,
      settings_id: @settings.id)
  end

  def order!(player) = Game::Market::Order.create!(player:, card_id: catalog_cards(:common_card).id, settings: @settings, price: 300, expires_at: 7.days.from_now)

  def wallet(player) = Game::Market::Wallet.find_by(player_id: player.id)

  test "a first entry creates the wallet and records the entry" do
    Game::Market::Ledger.post([ entry(@alice, :mint, available: 7_000) ])

    assert_equal [ 7_000, 0 ], wallet(@alice).values_at(:available, :committed)
    recorded = Game::Market::LedgerEntry.find_by!(player_id: @alice.id)
    assert_equal [ "mint", 7_000, 0, @settings.id ], recorded.values_at(:kind, :available_delta, :committed_delta, :settings_id)
  end

  test "several entries of a player net into one update of their wallet, and each entry is kept" do
    Game::Market::Ledger.post([ entry(@alice, :mint, available: 5_000) ])
    Game::Market::Ledger.post([ entry(@alice, :hold, available: -3_000, committed: 3_000), entry(@alice, :release, available: 1_000, committed: -1_000),
                                entry(@bob, :mint, available: 100) ])

    assert_equal [ 3_000, 2_000 ], wallet(@alice).values_at(:available, :committed)
    assert_equal [ 100, 0 ], wallet(@bob).values_at(:available, :committed)
    assert_equal 4, Game::Market::LedgerEntry.count
  end

  test "an entry that would push a balance below zero is refused and nothing is written" do
    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.transaction(requires_new: true) do
        Game::Market::Ledger.post([ entry(@bob, :mint, available: 100), entry(@alice, :stamp, available: -1) ])
      end
    end

    assert_equal 0, Game::Market::LedgerEntry.count
    assert_nil wallet(@bob)
  end

  test "a purchase from the Archive or of a slot moves the wallet, and a hold can name its order" do
    order = order!(@alice)
    Game::Market::Ledger.post([ entry(@alice, :mint, available: 1_000) ])
    Game::Market::Ledger.post([ entry(@alice, :archive_purchase, available: -200), entry(@alice, :slot_purchase, available: -100),
                                entry(@alice, :hold, available: -300, committed: 300, order:) ])

    assert_equal [ 400, 300 ], wallet(@alice).values_at(:available, :committed)
    assert_equal order.id, Game::Market::LedgerEntry.find_by!(kind: "hold").order_id
    assert_equal 4, Game::Market::LedgerEntry.count
  end

  test "a second hold of one order for one player is refused, another player's passes" do
    order = order!(@alice)
    Game::Market::Ledger.post([ entry(@alice, :mint, available: 1_000), entry(@bob, :mint, available: 1_000) ])
    Game::Market::Ledger.post([ entry(@alice, :hold, available: -300, committed: 300, order:) ])

    assert_raises(ActiveRecord::RecordNotUnique) do
      ActiveRecord::Base.transaction(requires_new: true) { Game::Market::Ledger.post([ entry(@alice, :hold, available: -300, committed: 300, order:) ]) }
    end
    assert_nothing_raised { Game::Market::Ledger.post([ entry(@bob, :hold, available: -300, committed: 300, order:) ]) }
  end

  test "an unknown kind is refused" do
    assert_raises(ArgumentError) { entry(@alice, :gift, available: 1) }
  end

  test "an entry and a settings version cannot be changed or removed" do
    Game::Market::Ledger.post([ entry(@alice, :mint, available: 10) ])
    recorded = Game::Market::LedgerEntry.last

    assert_raises(ActiveRecord::ReadOnlyRecord) { recorded.update!(available_delta: 99) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { recorded.destroy }
    assert_raises(ActiveRecord::ReadOnlyRecord) { @settings.update!(daily_cap: 1) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { @settings.destroy }
  end

  test "posting nothing writes nothing" do
    assert_no_difference -> { Game::Market::Wallet.count } do
      Game::Market::Ledger.post([])
    end
  end
end
