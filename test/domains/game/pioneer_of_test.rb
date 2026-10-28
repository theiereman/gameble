require "test_helper"

# Game::PioneerOf: who first discovered one edition of a card (a
# card-season), for the card detail's pioneer row.
class Game::PioneerOfTest < ActiveSupport::TestCase
  setup do
    @portal_one = catalog_card_seasons(:portal_one)
  end

  test "the first discoverer and the date, in one query" do
    pioneer = nil
    assert_queries_count(1) { pioneer = Game::PioneerOf.call(@portal_one.id) }
    assert_equal accounts_players(:banned), pioneer.player
    assert_equal game_first_discoveries(:portal_one).discovered_at, pioneer.discovered_at
  end

  test "each edition of a card has its own pioneer, whichever season is published" do
    season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    newer = Catalog::CardSeason.insert_all!([ { card_id: @portal_one.card_id, season_id: season.id, prestige_score: 0.5, rating: 90, rarity: 5, number: 1 } ],
      returning: :id).rows.flatten.sole
    assert_nil Game::PioneerOf.call(newer)

    Game::FirstDiscovery.create!(card_season_id: newer, player_id: accounts_players(:player).id, discovered_at: Time.current)
    assert_equal accounts_players(:player), Game::PioneerOf.call(newer).player
    assert_equal accounts_players(:banned), Game::PioneerOf.call(@portal_one.id).player
  end

  test "an edition with no discovery has no pioneer" do
    Game::FirstDiscovery.delete_all
    assert_nil Game::PioneerOf.call(@portal_one.id)
  end
end
