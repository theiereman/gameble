require "test_helper"
require_relative "../../support/catalog_seeds"

# Game::DrawPool (AD-7): the published season by tier, held per process and
# reloaded when the published season changes.
class Game::DrawPoolTest < ActiveSupport::TestCase
  include CatalogSeeds

  setup { Game::DrawPool.reset! }

  def tier_ids(*names)
    names.map { |name| catalog_card_seasons(name).id }
  end

  test "the pool holds the published season's card-seasons by tier, frozen" do
    pool = Game::DrawPool.current

    season = catalog_seasons(:one)
    assert_equal season.id, pool.season_id
    assert_equal [ season.id, season.published_at ], pool.key
    assert_equal({ 1 => tier_ids(:steel_card_one), 2 => tier_ids(:emerald_card_one), 3 => tier_ids(:sapphire_card_one),
      4 => tier_ids(:portal_one), 5 => tier_ids(:gold_card_one) }, pool.tiers)
    assert_predicate pool.tiers, :frozen?
    assert pool.tiers.values.all?(&:frozen?)
  end

  test "the same snapshot serves while the published season is unchanged" do
    first = Game::DrawPool.current

    assert_no_queries_match(/catalog_card_seasons/) { assert_same first, Game::DrawPool.current }
  end

  test "a newly published season reloads the pool" do
    first = Game::DrawPool.current
    season = seed_card_seasons(distinct_scores(150))
    Catalog::PublishSeason.new.call(number: season.number).value!

    pool = Game::DrawPool.current

    assert_not_same first, pool
    assert_equal season.id, pool.season_id
    assert_equal 150, pool.tiers.values.sum(&:size)
  end

  test "the same season id published at another time reloads the pool (a database reset reusing an id)" do
    first = Game::DrawPool.current
    season = catalog_seasons(:one)
    seed_card_seasons([ 0.1 ], season:)
    added = Catalog::CardSeason.where(season_id: season.id, rarity: nil).sole
    Catalog::CardSeason.where(id: added.id).update_all(rarity: 1)
    season.update_columns(published_at: season.published_at + 1.day)

    pool = Game::DrawPool.current

    assert_not_same first, pool
    assert_equal season.id, pool.season_id
    assert_equal [ catalog_card_seasons(:steel_card_one).id, added.id ].sort, pool.tiers.fetch(1).sort
  end

  test "no published season gives no pool" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    assert_nil Game::DrawPool.current
  end

  test "a published season with an empty tier raises" do
    Catalog::CardSeason.where(id: catalog_card_seasons(:gold_card_one).id).update_all(rarity: 4)
    catalog_seasons(:one).update_columns(published_at: 1.minute.ago)

    error = assert_raises(Game::DrawPool::EmptyTier) { Game::DrawPool.current }
    assert_match(/tier\(s\) 5/, error.message)
  end
end
