require "test_helper"

# Game::PioneerOf: who first discovered a card's edition of the published
# season, for the card detail's pioneer row.
class Game::PioneerOfTest < ActiveSupport::TestCase
  setup do
    @portal = catalog_cards(:portal)
  end

  test "the first discoverer and the date, in one query" do
    pioneer = nil
    assert_queries_count(1) { pioneer = Game::PioneerOf.call(@portal.id) }
    assert_equal accounts_players(:banned), pioneer.player
    assert_in_delta 2.weeks.ago, pioneer.discovered_at, 1.minute
  end

  test "the published season's edition counts, not an older one" do
    season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    newer = Catalog::CardSeason.insert_all!([ { card_id: @portal.id, season_id: season.id, prestige_score: 0.5, rating: 90, rarity: 5 } ],
      returning: :id).rows.flatten.sole
    assert_nil Game::PioneerOf.call(@portal.id)

    Game::FirstDiscovery.create!(card_season_id: newer, player_id: accounts_players(:player).id, discovered_at: Time.current)
    assert_equal accounts_players(:player), Game::PioneerOf.call(@portal.id).player
  end

  test "a card with no discovery has no pioneer" do
    Game::FirstDiscovery.delete_all
    assert_nil Game::PioneerOf.call(@portal.id)
  end
end
