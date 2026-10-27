require "test_helper"

# The cards a player chose for their showcase, in their order.
class Game::ChosenShowcaseTest < ActiveSupport::TestCase
  test "answers the card-seasons in position order, only the player's" do
    player = accounts_players(:player)
    portal, common = catalog_card_seasons(:portal_one).id, catalog_card_seasons(:common_card_one).id
    Game::ShowcaseEntry.create!(player_id: player.id, card_season_id: portal, position: 1)
    Game::ShowcaseEntry.create!(player_id: player.id, card_season_id: common, position: 0)
    Game::ShowcaseEntry.create!(player_id: accounts_players(:moderator).id, card_season_id: portal, position: 0)

    assert_equal [ common, portal ], Game::ChosenShowcase.call(player)
  end

  test "a visitor has none and costs no query" do
    assert_no_queries { assert_equal [], Game::ChosenShowcase.call(nil) }
  end
end
