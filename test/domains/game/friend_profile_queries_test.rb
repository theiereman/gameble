require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/holdings"

class Game::FriendProfileQueriesTest < ActiveSupport::TestCase
  include Holdings
  include CatalogSeeds

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def befriend(one, other)
    Game::Friendship.create!(low_player_id: [ one.id, other.id ].min, high_player_id: [ one.id, other.id ].max)
  end

  test "two players are friends from either side once their friendship exists" do
    assert_not Game::FriendshipBetween.call(@player, @other)

    befriend(@player, @other)

    assert Game::FriendshipBetween.call(@player, @other)
    assert Game::FriendshipBetween.call(@other, @player)
    assert_not Game::FriendshipBetween.call(@player, accounts_players(:administrator))
  end

  test "a visitor or the player themselves is no friend, without a query" do
    assert_no_queries do
      assert_not Game::FriendshipBetween.call(nil, @player)
      assert_not Game::FriendshipBetween.call(@player, nil)
      assert_not Game::FriendshipBetween.call(@player, @player)
    end
  end
end
