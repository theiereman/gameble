require "test_helper"
require_relative "../../../support/custom_sets"
require_relative "../../../support/game_packs"
require_relative "../../../support/game_sets"
require_relative "../../../support/game_trades"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_listings"

# After every change to a player's goals, custom sets, holdings or orders, their wanted rows are those a fresh rebuild writes.
class Game::Market::WantedRefreshTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include CustomSets
  include GamePacks
  include GameSets
  include GameTrades
  include Holdings
  include MarketAuctions
  include MarketListings
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
    @common = catalog_card_seasons(:common_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @settings = open_market!
    fund!(@player, 10_000)
    fund!(@other, 10_000)
    insert_set([ @common.id, @rare.id ], { complete: 2 }, key: "roguelike", params: { "theme" => "roguelike" })
  end

  def aim(player = @player, key: "roguelike") = Game::AddGoal.new.call(player:, kind: "theme", key:).value!

  def place_order(player, card, price) = Game::Market::PlaceOrder.new.call(player:, card_id: card.card_id, price:, settings_token: @settings.token).value!

  def rows(player = @player) = Game::Market::Wanted.where(player_id: player.id).order(:card_id, :reason).pluck(:card_id, :reason, :rarities)

  def goal_row(card) = [ card.card_id, "goal", nil ]

  def goal_rows(*cards) = cards.map { goal_row(it) }.sort

  def assert_fresh(*players)
    players.each do |player|
      refreshed = rows(player)
      Game::Market::RebuildWanted.new.call(player:).value!
      assert_equal rows(player), refreshed, "player #{player.id}'s rows were not refreshed"
    end
  end

  def publish_locked(event, player)
    ApplicationRecord.transaction do
      Game::BankLock.acquire(player.id)
      Rails.configuration.event_store.publish(event, stream_name: Game::Operation.stream_name(player.id))
    end
  end

  test "a refresh outside the player's bank lock raises and writes nothing" do
    Game::Market::Wanted.insert_all([ { player_id: @player.id, card_id: @common.card_id, reason: "goal", rarities: nil } ])

    assert_raises(ArgumentError) { Game::Market::RefreshWanted.call(@player) }

    assert_equal [ goal_row(@common) ], rows
  end

  test "an added goal wants its missing games, a removed one wants nothing" do
    hold(@player, @common.id)
    aim

    assert_equal [ goal_row(@rare) ], rows
    assert_fresh(@player)

    Game::RemoveGoal.new.call(player: @player, kind: "theme", key: "roguelike").value!

    assert_empty rows
  end

  test "a placed order wants its game at the rarities it reaches, a cancelled one no more" do
    order = place_order(@player, @common, @settings.minimum_price_common)

    assert_equal [ [ @common.card_id, "order", [ 1 ] ] ], rows
    assert_fresh(@player)

    Game::Market::CancelOrder.new.call(player: @player, order_id: order.id).value!

    assert_empty rows
  end

  test "a goal and an order on one game are two rows" do
    aim
    place_order(@player, @rare, @settings.minimum_price_rare)

    assert_equal [ goal_row(@common), goal_row(@rare), [ @rare.card_id, "order", [ 1, 2, 3 ] ] ].sort_by { it.take(2) }, rows
    assert_fresh(@player)
  end

  test "a sale to an order refreshes both players, the buyer's completed goal dropped first" do
    insert_set([ @rare.id ], { complete: 1 }, key: "solo", params: { "theme" => "solo" })
    hold(@player, @rare.id)
    aim(@player)
    aim(@other, key: "solo")
    order = place_order(@other, @rare, 900)

    Game::Market::SellToOrder.new.call(player: @player, card_season_id: @rare.id, order_token: order.token, settings_token: @settings.token).value!

    assert_empty Game::Goal.where(player_id: @other.id)
    assert_empty rows(@other)
    assert_equal goal_rows(@common, @rare), rows(@player)
    assert_fresh(@player, @other)
  end

  test "applied wanted choices refresh the seller and each buyer" do
    hold(@player, @rare.id)
    aim(@player)
    aim(@other)
    order = place_order(@other, @rare, 900)
    line = { card_season_id: @rare.id, copies: 1, choice: "order", order_tokens: [ order.token ] }

    Game::Market::ApplyWantedChoices.new.call(player: @player, lines: [ line ], settings_token: @settings.token).value!

    assert_equal goal_rows(@common, @rare), rows(@player)
    assert_equal [ goal_row(@common) ], rows(@other)
    assert_fresh(@player, @other)
  end

  test "an entrusted last copy is wanted again" do
    hold(@player, @common.id)
    aim

    Game::Market::EntrustCards.new.call(player: @player, lines: { @common.id => 1 }, settings_token: @settings.token).value!

    assert_equal goal_rows(@common, @rare), rows
    assert_fresh(@player)
  end

  test "an opening that brings a wanted game takes its row out" do
    aim
    create_pack(@player, cards: Array.new(Game::Pack::SIZE, @common.id))

    Game::OpenPack.new.call(player: @player).value!

    assert_equal [ goal_row(@rare) ], rows
    assert_fresh(@player)
  end

  test "an opening that completes the goal drops it and its rows" do
    insert_set([ @common.id ], { complete: 1 }, key: "solo", params: { "theme" => "solo" })
    aim(key: "solo")
    create_pack(@player, cards: Array.new(Game::Pack::SIZE, @common.id))

    Game::OpenPack.new.call(player: @player).value!

    assert_empty Game::Goal.where(player_id: @player.id)
    assert_empty rows
    assert_fresh(@player)
  end

  test "an accepted trade refreshes both players" do
    aim(@player)
    aim(@other)

    conclude_trade(@other, @player, offer: { @rare.id => 1 }, request: { catalog_card_seasons(:portal_one).id => 1 })

    assert_equal [ goal_row(@common) ], rows(@player)
    assert_equal goal_rows(@common, @rare), rows(@other)
    assert_fresh(@player, @other)
  end

  test "a closed auction refreshes the seller and the winner" do
    hold(@player, @common.id, 1, reserved: 1)
    aim(@player)
    aim(@other)
    listing = listing!(seller: @player, card_season: @common, starting_price: 100, ends_at: 1.minute.ago)
    lead!(listing, @other, 200, price: 100)

    Game::Market::CloseAuction.new.call(player: @player, listing_id: listing.id).value!

    assert_equal goal_rows(@common, @rare), rows(@player)
    assert_equal [ goal_row(@rare) ], rows(@other)
    assert_fresh(@player, @other)
  end

  test "an edited custom set wants its new games, a deleted one nothing" do
    custom_set = create_custom_set(@player, card_ids: fixture_card_ids.values_at(0, 1, 2))
    Game::AddGoal.new.call(player: @player, custom_set: custom_set.token).value!

    Game::EditCustomSet.new.call(player: @player, token: custom_set.token, name: custom_set.name, card_ids: fixture_card_ids.values_at(0, 3, 4)).value!

    assert_equal fixture_card_ids.values_at(0, 3, 4).sort, rows.map(&:first)
    assert_fresh(@player)

    Game::DeleteCustomSet.new.call(player: @player, token: custom_set.token).value!

    assert_empty rows
  end

  test "a published season that drops a goal rebuilds the rows once its jobs run" do
    insert_set([ @common.id, @rare.id ], { complete: 2 }, key: "cosy", params: { "theme" => "cosy" })
    aim(key: "cosy")
    custom_set = create_custom_set(@player, card_ids: fixture_card_ids.values_at(2, 3, 4))
    Game::AddGoal.new.call(player: @player, custom_set: custom_set.token).value!

    publish_sets_draft
    perform_enqueued_jobs(only: Game::Market::RebuildAllWantedJob)

    assert_empty Game::Goal.where(player_id: @player.id, set_key: "cosy")
    assert_not_includes rows.map(&:first), @common.card_id
    assert_fresh(@player)
  end

  test "an Archive purchase refreshes its buyer" do
    aim
    hold(@player, @common.id)

    publish_locked(Game::Market::ArchivePurchased.with(player_id: @player.id, card_season_id: @common.id, price: 13), @player)

    assert_equal [ goal_row(@rare) ], rows
    assert_fresh(@player)
  end

  test "a slot bought with a goal refreshes its player, one bought without a goal does not" do
    aim
    Game::Goal.where(player_id: @player.id).delete_all

    publish_locked(Game::SlotBought.with(player_id: @player.id, kind: "deck"), @player)
    assert_equal goal_rows(@common, @rare), rows

    publish_locked(Game::SlotBought.with(player_id: @player.id, kind: "goal", goal_id: 1), @player)
    assert_empty rows
  end

  [ [ Game::Market::OrderExpired, "expired" ], [ Game::Market::OrderWithdrawn, "withdrawn" ] ].each do |event, status|
    test "an order #{status} wants its game no more" do
      order = place_order(@player, @common, @settings.minimum_price_common)
      order.update!(status:)

      publish_locked(event.about(order), @player)

      assert_empty rows
      assert_fresh(@player)
    end
  end

  test "a removed player's refresh deletes their rows and writes none" do
    banned = accounts_players(:banned)
    Game::Goal.create!(player_id: banned.id, position: 1, set_kind: "theme", set_key: "roguelike")
    Game::Market::Wanted.insert_all([ { player_id: banned.id, card_id: @common.card_id, reason: "goal", rarities: nil } ])

    Game::Market::RebuildWanted.new.call(player: banned).value!

    assert_empty rows(banned)
  end

  test "a ban leaves the rows, an unban rebuilds them once its job runs" do
    aim
    Accounts::BanPlayer.new.call(staff: accounts_players(:administrator), player: @player, reason: "Cheating").value!
    assert_equal goal_rows(@common, @rare), rows

    Game::Market::Wanted.where(player_id: @player.id).delete_all
    assert_enqueued_with(job: Game::Market::RebuildWantedJob, args: [ @player.id ]) do
      Accounts::UnbanPlayer.new.call(staff: accounts_players(:administrator), player: @player.reload).value!
    end
    perform_enqueued_jobs(only: Game::Market::RebuildWantedJob)

    assert_equal goal_rows(@common, @rare), rows
  end

  test "the rebuild job skips a missing or a deleted player" do
    deleted = Accounts::Player.create!(deleted_at: 1.day.ago)

    assert_nothing_raised { [ 0, deleted.id ].each { Game::Market::RebuildWantedJob.perform_now(it) } }
    assert_empty rows(deleted)
  end

  test "the account's release clears its rows" do
    aim

    Game::ReleasePlayer.new.call(player: @player).value!

    assert_empty rows
  end
end
