require "test_helper"
require_relative "../../support/custom_sets"
require_relative "../../support/game_sets"
require_relative "../../support/holdings"

# What an empty reserve proposes: the set in progress closest to its next
# tier, a friend sparing a card a goal needs, and the rewards to claim.
class Game::NextStepsTest < ActiveSupport::TestCase
  include CustomSets
  include GameSets
  include Holdings

  setup do
    @player = accounts_players(:player)
    @season = catalog_seasons(:one)
  end

  def steps = Game::NextSteps.call(@player, season: @season)

  def theme(key, bronze:)
    members = unheld_cards(6)
    [ insert_set(members, { bronze:, complete: members.size }, key:), members ]
  end

  test "nothing to propose: no set, no friend, no reward" do
    result = steps

    assert_nil result.closest_set
    assert_nil result.friend
    assert_equal 0, result.rewards
  end

  test "the set in progress closest to its next tier, even behind the one the latest opening touched" do
    touched, touched_cards = theme("roguelike", bronze: 5)
    closest, closest_cards = theme("horror", bronze: 3)
    hold_all(@player, closest_cards.first(2), gained_at: 2.days.ago)
    hold_all(@player, touched_cards.first(2), gained_at: 1.hour.ago)
    assert_equal touched, Game::SetBoard.call(@player, season: @season).in_progress.first.set_id

    result = steps.closest_set

    assert_equal closest, result.set.id
    assert_equal 1, result.standing.missing
  end

  test "two sets as close: the first on the board" do
    first, first_cards = theme("roguelike", bronze: 3)
    second, second_cards = theme("horror", bronze: 3)
    hold_all(@player, first_cards.first(2) + second_cards.first(2), gained_at: 1.hour.ago)
    board = Game::SetBoard.call(@player, season: @season).in_progress.map(&:set_id)

    assert_equal board.first, steps.closest_set.set.id
    assert_equal [ first, second ].sort, board.sort
  end

  test "the friend of the first trade suggestion, and the rewards waiting to be claimed" do
    friend = accounts_players(:moderator)
    low, high = [ @player.id, friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    wanted = catalog_card_seasons(:portal_one)
    card_ids = Catalog::CardSeason.where(id: [ wanted.id, *unheld_cards(2) ]).pluck(:card_id)
    Game::AddGoal.new.call(player: @player, custom_set: create_custom_set(@player, name: "Favourites", card_ids:).token).value!
    hold(friend, wanted.id, 2)
    Game::AchievementUnlock.record(@player.id, "boosters_100", Time.current, claimed: false)

    result = steps

    assert_equal friend, result.friend
    assert_equal 1, result.rewards
  end
end
