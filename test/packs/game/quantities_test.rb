require "test_helper"

# Game::Quantities (CAP-6, story 4.2): a player's copies of each card-season
# asked about.
class Game::QuantitiesTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
    @portal, @steel, @gold = %i[portal_one steel_card_one gold_card_one].map { catalog_card_seasons(it).id }
  end

  def hold(player, card_season_id, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:)
  end

  test "the copies of the cards asked about that the player holds, in one query" do
    hold(@player, @portal, 2)
    hold(@player, @steel, 1)
    hold(@player, @gold, 0)
    hold(accounts_players(:moderator), @gold, 3)

    quantities = nil
    assert_queries_count(1) { quantities = Game::Quantities.call(@player, [ @portal, @steel, @gold, @portal ]) }
    assert_equal({ @portal => 2, @steel => 1 }, quantities)
    assert_equal({ @portal => 2 }, Game::Quantities.call(@player, [ @portal ]))
  end

  test "another player can be asked about" do
    hold(accounts_players(:moderator), @gold, 3)

    assert_equal({ @gold => 3 }, Game::Quantities.call(accounts_players(:moderator), [ @gold, @portal ]))
  end

  test "no query for a visitor or no card" do
    hold(@player, @portal, 1)

    assert_queries_count(0) { assert_equal({}, Game::Quantities.call(nil, [ @portal ])) }
    assert_queries_count(0) { assert_equal({}, Game::Quantities.call(@player, [])) }
  end
end
