require "test_helper"
require_relative "../../support/singleton_stub"
require_relative "../../support/game_packs"
require_relative "../../support/game_sets"
require_relative "../../support/custom_sets"
require_relative "../../support/holdings"
require_relative "../../support/market"
require_relative "../../support/market_auctions"
require_relative "../../support/market_bidding"

# Buying the next goal, custom set or deck slot: the price of the settings version read is destroyed, the slot is kept for
# good, and a goal slot makes the aimed set that goal in the same purchase; a refusal moves nothing.
class Game::BuySlotTest < ActiveSupport::TestCase
  include SingletonStub
  include GamePacks
  include GameSets
  include CustomSets
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @settings = open_market!
    fund!(@player, 1_000)
  end

  def theme(key) = insert_set(unheld_cards(3), { complete: 3 }, key:, params: { "theme" => key })

  def five_goals
    %w[a1 a2 a3 a4 a5 a6].each { theme(it) }
    %w[a1 a2 a3 a4 a5].each { Game::AddGoal.new.call(player: @player, kind: "theme", key: it).value! }
  end

  def buy(kind: :goal, slot: 6, settings_token: Game::Market::CurrentSettings.call&.token, player: @player, aim: { kind: "theme", key: "a6" })
    Game::BuySlot.new.call(player:, kind:, slot:, settings_token:, aim:)
  end

  def bought(kind) = Game::CapacitySlot.where(player_id: @player.id, kind:).pick(:bought)

  def slot_entries = Game::Market::LedgerEntry.where(player_id: @player.id, kind: "slot_purchase").pluck(:available_delta, :settings_id)

  def nothing_moves(&)
    assert_no_difference([ -> { Game::CapacitySlot.count }, -> { Game::CapacitySlot.sum(:bought) }, -> { Game::Market::LedgerEntry.count },
      -> { Game::Market::Wallet.sum(:available) }, -> { Game::Goal.count }, -> { Rails.configuration.event_store.read.count } ], &)
  end

  def refused(code, **)
    result = nil
    nothing_moves { result = buy(**) }
    assert_equal code, result.failure
  end

  test "a goal slot keeps the sixth slot, makes the aimed set goal 6 and destroys the price" do
    five_goals
    destroyed = Game::Market::ReconcileWallets.call.destroyed
    added = game_events(@player, Game::GoalAdded).size

    goal = buy.value!

    assert_equal [ 6, "theme", "a6" ], [ goal.position, goal.set_kind, goal.set_key ]
    assert_equal 1, bought("goal")
    assert_equal [ [ -500, @settings.id ] ], slot_entries
    assert_equal [ 500, 0 ], figures(@player)
    assert_equal [ { player_id: @player.id, kind: "goal", goal_id: goal.id } ], game_events(@player, Game::SlotBought).map(&:data)
    assert_equal added, game_events(@player, Game::GoalAdded).size
    assert_equal destroyed + 500, Game::Market::ReconcileWallets.call.destroyed
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "a custom set or deck slot is kept with no set or deck created, a second one adding to the first" do
    fund!(@player, 1_500)

    assert_no_difference([ -> { Game::CustomSet.count }, -> { Game::Deck.count } ]) do
      assert_equal 1, buy(kind: :custom_set, slot: 6, aim: nil).value!.bought
      assert_equal 2, buy(kind: "custom_set", slot: 7).value!.bought
      assert_equal 1, buy(kind: :deck, slot: 4).value!.bought
    end

    assert_equal [ 2, 1 ], [ bought("custom_set"), bought("deck") ]
    assert_equal [ [ -500, @settings.id ], [ -1_000, @settings.id ], [ -1_000, @settings.id ] ], slot_entries.sort_by(&:first).reverse
    assert_equal [ [ "custom_set", nil ], [ "custom_set", nil ], [ "deck", nil ] ],
      game_events(@player, Game::SlotBought).map { it.data.values_at(:kind, :goal_id) }
  end

  test "a slot already bought, in another tab or by a second press, is refused and charged once" do
    assert buy(kind: :deck, slot: 4).success?

    refused(:slot_already_bought, kind: :deck, slot: 4)
    refused(:slot_already_bought, kind: :custom_set, slot: 7)
    assert_equal [ [ -1_000, @settings.id ] ], slot_entries
  end

  test "a slot past the ceiling, or with every slot bought, is refused" do
    Game::CapacitySlot.create!(player_id: @player.id, kind: "deck", bought: 2)

    refused(:slot_ceiling, kind: :deck, slot: 6)
    refused(:slot_ceiling, kind: :deck, slot: 5)
    refused(:slot_ceiling, kind: :goal, slot: 11)
  end

  test "a settings version other than the one in force, or none, is refused" do
    refused(:amounts_changed, kind: :deck, slot: 4, settings_token: "stale")
    open_market!(slot_price_deck_4: 900)
    refused(:amounts_changed, kind: :deck, slot: 4, settings_token: @settings.token)
    forget_market!
    refused(:amounts_changed, kind: :deck, slot: 4, settings_token: "")
  end

  test "a price above the PiCoins available is refused" do
    open_market!(slot_price_custom_set_6: 1_001)

    refused(:more_than_available, kind: :custom_set, slot: 6)
  end

  test "a goal the aimed set cannot be undoes the purchase" do
    five_goals
    custom_set = create_custom_set(accounts_players(:moderator))
    library = create_library_set(@player, card_ids: [])
    hold(@player, catalog_card_seasons(:portal_one).id)

    refused(:goal_set_complete, aim: { kind: "studio", key: "valve" })
    refused(:goal_set_not_found, aim: { kind: "theme", key: "pirates" })
    refused(:goal_set_not_found, aim: nil)
    refused(:custom_set_not_found, aim: { custom_set: custom_set.token })
    refused(:goal_already_set, aim: { kind: "theme", key: "a1" })
    refused(:library_set_empty, aim: { custom_set: library.token })
  end

  test "a closed market still sells slots" do
    close_market!

    assert buy(kind: :deck, slot: 4).success?
  end

  test "a banned or deleted player is refused, and a deadlock is the market being busy" do
    @player.update_columns(banned_at: Time.current)
    refused(:player_required, kind: :deck, slot: 4)
    @player.update_columns(banned_at: nil)

    stub_singleton(Game::Market::Ledger, :post, ->(*) { raise ActiveRecord::Deadlocked }) do
      refused(:market_busy, kind: :deck, slot: 4)
    end
  end

  test "a bought slot is kept when its goal leaves" do
    five_goals
    buy.value!

    Game::RemoveGoal.new.call(player: @player, kind: "theme", key: "a6").value!

    assert_equal 1, bought("goal")
    assert_equal 6, Game::Capacity.limit(@player, :goal)
  end

  test "an unknown kind is a programming error" do
    assert_raises(ArgumentError) { buy(kind: :booster, slot: 1) }
  end
end
