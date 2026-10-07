require "test_helper"
require_relative "../../support/game_packs"

# What other players' operations meet once a player deleted their account
# (CAP-14, story 7.8): until story 5.11 drops a deleted player's trades and
# friendships, a trade with them cannot be accepted or countered (no
# friend), declines and expires without releasing anything of theirs, and
# never creates a row for them; the goal reward job and the presence write
# skip them.
class Game::DeletedPlayerPartnerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GamePacks

  setup do
    Game::DrawPool.reset!
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @one = catalog_card_seasons(:portal_one).id
    @three = catalog_card_seasons(:rare_card_one).id
    low, high = [ @alice.id, @bob.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    Game::Holding.create!(player_id: @alice.id, card_season_id: @one, quantity: 3)
    Game::Holding.create!(player_id: @bob.id, card_season_id: @three, quantity: 2)
    @trade = Game::ProposeTrade.new.call(player: @alice, recipient: @bob, offer: { @one => 2 }, request: { @three => 1 }).value!
  end

  def delete(player) = Accounts::DeletePlayer.new.call(player:).value!
  def rows_of(player) = Game::Holding.where(player_id: player.id).pluck(:card_season_id, :quantity, :reserved)

  test "the recipient cannot accept or counter a trade whose proposer was deleted; nothing moves, no row is created for them" do
    delete(@alice)
    bob_rows = rows_of(@bob)

    assert_equal Dry::Monads::Failure(:not_friends), Game::AcceptTrade.new.call(player: @bob, trade_id: @trade.id)
    assert_equal Dry::Monads::Failure(:not_friends),
      Game::CounterTrade.new.call(player: @bob, trade_id: @trade.id, offer: { @three => 1 }, request: { @one => 1 })
    assert_empty rows_of(@alice)
    assert_equal bob_rows, rows_of(@bob)
    assert_predicate @trade.reload, :open?
  end

  test "the recipient declines a trade whose proposer was deleted: it closes, nothing of theirs to release" do
    delete(@alice)

    assert Game::DeclineTrade.new.call(player: @bob, trade_id: @trade.id).success?
    assert_equal "declined", @trade.reload.status
    assert_empty rows_of(@alice)
  end

  test "the expiry job closes a deleted proposer's trade without error" do
    delete(@alice)

    travel 8.days do
      assert_nothing_raised { Game::ExpireTradesJob.perform_now }
    end
    assert_equal "expired", @trade.reload.status
    assert_empty rows_of(@alice)
  end

  test "a deleted recipient's partner cannot have the trade accepted for them, and the proposer may still cancel" do
    delete(@bob)

    assert_equal Dry::Monads::Failure(:player_required), Game::AcceptTrade.new.call(player: @bob, trade_id: @trade.id)
    assert Game::CancelTrade.new.call(player: @alice, trade_id: @trade.id).success?
    assert_equal [ [ @one, 3, 0 ] ], rows_of(@alice)
    assert_empty rows_of(@bob)
  end

  test "the goal reward job skips a deleted contributor" do
    week = Date.current.beginning_of_week
    [ @alice, @bob ].each { |player| Game::WeeklyContribution.create!(player_id: player.id, week_start: week, openings: 1) }
    Game::WeeklyGoal.create!(week_start: week, total: 2, target: 2)
    delete(@alice)

    Game::GrantGoalRewardsJob.perform_now(week_start: week)

    assert_empty Game::GoalReward.where(player_id: @alice.id)
    assert_equal 0, Game::Pack.where(player_id: @alice.id).count
    assert Game::GoalReward.exists?(player_id: @bob.id)
  end
end
