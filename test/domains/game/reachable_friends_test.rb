require "test_helper"
require_relative "../../support/live_duels"

class Game::ReachableFriendsTest < ActiveSupport::TestCase
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @max = accounts_players(:administrator)
    @hugo.update_columns(persona_name: "Hugo")
    @max.update_columns(persona_name: "Max")
    befriend(@lea, @hugo)
    befriend(@lea, @max)
  end

  def rows = Game::ReachableFriends.call(@lea).map { [ it.player.persona_name, it.in_duel ] }

  test "friends with a future lease and an open profile, ordered by name" do
    assert_equal [ [ "Hugo", false ], [ "Max", false ] ], rows
  end

  test "a lapsed or null lease leaves the friend out" do
    @hugo.update_columns(reachable_until: 1.second.ago)
    @max.update_columns(reachable_until: nil)

    assert_empty rows
  end

  test "a private friend and a removed friend are left out" do
    @hugo.update_columns(visibility: "private")
    @max.update_columns(banned_at: Time.current)

    assert_empty rows
  end

  test "a non-friend with a lease is left out" do
    accounts_players(:banned).update_columns(reachable_until: 1.day.from_now)

    assert_equal [ [ "Hugo", false ], [ "Max", false ] ], rows
  end

  test "a friend seated or invited elsewhere is kept, in a duel" do
    Game::DuelSeat.create!(duel: Game::Duel.create!, role: "opponent", player_id: @hugo.id, status: "invited")
    Game::DuelSeat.create!(duel: Game::Duel.create!, role: "challenger", player_id: @max.id, status: "left")

    assert_equal [ [ "Hugo", true ], [ "Max", false ] ], rows
  end

  test "a private own profile and no player give no rows" do
    @lea.update_columns(visibility: "private")

    assert_empty rows
    assert_empty Game::ReachableFriends.call(nil)
  end
end
