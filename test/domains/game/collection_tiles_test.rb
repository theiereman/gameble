require "test_helper"

# Game::CollectionTiles: one tile per game, over the season's games and
# every game held in any edition, at the edition the game shows.
class Game::CollectionTilesTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
    @one = catalog_seasons(:one)
    @two = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
  end

  def edition(name, season:, rarity:)
    one = catalog_card_seasons(name)
    Catalog::CardSeason.insert_all!([ { card_id: one.card_id, season_id: season.id, prestige_score: one.prestige_score, rating: one.rating,
      rarity:, number: one.number } ], returning: :id).rows.flatten.sole
  end

  def hold(card_season_id, quantity = 1, player: @player) = Game::Holding.create!(player_id: player.id, card_season_id:, quantity:)

  def tiles(player = @player, season = @two) = Game::CollectionTiles.call(player, season).pluck(:id).sort

  test "a game held in the season and another one shows one tile, at its best rarity, else the season's edition, else the latest" do
    portal_two = edition(:portal_one, season: @two, rarity: "rare")
    rare_two = edition(:rare_card_one, season: @two, rarity: "rare")
    common_two = edition(:common_card_one, season: @two, rarity: "common")
    hold(catalog_card_seasons(:portal_one).id)
    hold(portal_two)
    hold(catalog_card_seasons(:rare_card_one).id)
    hold(rare_two)

    assert_equal [ catalog_card_seasons(:portal_one).id, rare_two, common_two ].sort, tiles
  end

  test "a game held only in an edition gone from the season keeps its tile; an edition with no copy left counts for nothing" do
    common_two = edition(:common_card_one, season: @two, rarity: "common")
    hold(catalog_card_seasons(:legendary_card_one).id)
    hold(catalog_card_seasons(:uncommon_card_one).id, 0)
    hold(catalog_card_seasons(:rare_card_one).id, player: accounts_players(:moderator))

    assert_equal [ catalog_card_seasons(:legendary_card_one).id, common_two ].sort, tiles
  end

  test "a visitor, or a player who holds nothing, sees the season's rated card-seasons; a lazy relation" do
    common_two = edition(:common_card_one, season: @two, rarity: "common")
    edition(:portal_one, season: @two, rarity: nil)

    assert_queries_count(0) { Game::CollectionTiles.call(nil, @two) }
    assert_equal [ common_two ], tiles(nil)
    assert_equal [ common_two ], tiles
  end

  test "the season asked decides between two editions at the same rarity" do
    rare_two = edition(:rare_card_one, season: @two, rarity: "rare")
    hold(catalog_card_seasons(:rare_card_one).id)
    hold(rare_two)

    assert_includes tiles, rare_two
    assert_includes tiles(@player, @one), catalog_card_seasons(:rare_card_one).id
    assert_not_includes tiles(@player, @one), rare_two
  end
end
