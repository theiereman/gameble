require "test_helper"
require_relative "../../support/catalog_seeds"

# Game::DrawOdds and Game::Draw (R2, AD-7, AD-22): a tier by the odds, then a
# card uniformly within the tier; and the statistical test of the odds.
class Game::DrawTest < ActiveSupport::TestCase
  include CatalogSeeds

  # A random source that answers the given numbers in turn.
  class Scripted
    def initialize(*numbers) = @numbers = numbers
    def random_number(_limit) = @numbers.shift
  end

  setup { Game::DrawPool.reset! }

  test "each odds table covers the five tiers and sums to ten thousand" do
    assert_equal Catalog::Rarity::TIERS.keys, Game::DrawOdds::REGULAR.keys.sort
    assert_equal Game::DrawOdds::TOTAL, Game::DrawOdds::REGULAR.values.sum
    assert_equal({ 1 => 7_600, 2 => 1_900, 3 => 430, 4 => 65, 5 => 5 }, Game::DrawOdds::REGULAR)
  end

  test "the daily bonus odds: emerald to gold, no steel, summing to ten thousand" do
    assert_equal({ 2 => 7_000, 3 => 2_400, 4 => 500, 5 => 100 }, Game::DrawOdds::BONUS)
    assert_equal [ 2, 3, 4, 5 ], Game::DrawOdds::BONUS.keys.sort
    assert_not_includes Game::DrawOdds::BONUS.keys, Catalog::Rarity::TIERS.key(:steel)
    assert_equal Game::DrawOdds::TOTAL, Game::DrawOdds::BONUS.values.sum
    assert_equal 3, Game::Pack::BONUS_SIZE
  end

  test "a roll picks the tier whose cumulative odds it falls under" do
    { 0 => 1, 7_599 => 1, 7_600 => 2, 9_499 => 2, 9_500 => 3, 9_929 => 3, 9_930 => 4, 9_994 => 4, 9_995 => 5, 9_999 => 5 }.each do |roll, tier|
      assert_equal tier, Game::Draw.tier(odds: Game::DrawOdds::REGULAR, random: Scripted.new(roll)), "roll #{roll}"
    end
  end

  test "a card is picked by its index within the tier" do
    pool = Game::DrawPool.current
    assert_equal catalog_card_seasons(:gold_card_one).id, Game::Draw.card(tier: 5, random: Scripted.new(0), pool:)
    assert_equal [ catalog_card_seasons(:steel_card_one).id, catalog_card_seasons(:gold_card_one).id ],
      Game::Draw.pack(odds: Game::DrawOdds::REGULAR, size: 2, random: Scripted.new(10, 0, 9_999, 0), pool:)
  end

  test "SecureRandom is the default source" do
    ids = Game::Draw.pack(odds: Game::DrawOdds::REGULAR, size: 5)

    assert_equal 5, ids.size
    assert_empty ids - Catalog::CardSeason.where(season_id: catalog_seasons(:one).id).ids
  end

  test "200,000 draws follow the odds per tier, and every card of a small tier is drawn evenly" do
    season = seed_card_seasons(distinct_scores(150))
    assert Catalog::PublishSeason.new.call(number: season.number).success?
    pool = Game::DrawPool.current
    assert_equal season.id, pool.season_id
    rarity_of = Catalog::CardSeason.where(season_id: season.id).pluck(:id, :rarity)
      .to_h { |id, rarity| [ id, Catalog::CardSeason.rarities.fetch(rarity) ] }
    n = 200_000

    ids = Game::Draw.pack(odds: Game::DrawOdds::REGULAR, size: n, random: Random.new(20_261_002), pool:)

    by_tier = ids.map { |id| rarity_of.fetch(id) }.tally
    Game::DrawOdds::REGULAR.each do |tier, parts|
      p = parts.fdiv(Game::DrawOdds::TOTAL)
      sigma = Math.sqrt(n * p * (1 - p))
      assert_in_delta n * p, by_tier.fetch(tier, 0), 4 * sigma, "tier #{tier}"
    end

    amethysts = pool.tiers.fetch(4)
    assert_equal 6, amethysts.size
    counts = ids.select { |id| rarity_of.fetch(id) == 4 }.tally
    m = counts.values.sum
    amethysts.each do |id|
      p = 1.0 / amethysts.size
      assert_in_delta m * p, counts.fetch(id, 0), 4 * Math.sqrt(m * p * (1 - p)), "card-season #{id}"
    end
  end

  test "100,000 bonus draws follow the bonus odds per tier, and never draw steel" do
    season = seed_card_seasons(distinct_scores(150))
    assert Catalog::PublishSeason.new.call(number: season.number).success?
    pool = Game::DrawPool.current
    rarity_of = Catalog::CardSeason.where(season_id: season.id).pluck(:id, :rarity)
      .to_h { |id, rarity| [ id, Catalog::CardSeason.rarities.fetch(rarity) ] }
    n = 100_000

    ids = Game::Draw.pack(odds: Game::DrawOdds::BONUS, size: n, random: Random.new(20_261_003), pool:)

    by_tier = ids.map { |id| rarity_of.fetch(id) }.tally
    assert_equal 0, by_tier.fetch(1, 0)
    Game::DrawOdds::BONUS.each do |tier, parts|
      p = parts.fdiv(Game::DrawOdds::TOTAL)
      sigma = Math.sqrt(n * p * (1 - p))
      assert_in_delta n * p, by_tier.fetch(tier, 0), 4 * sigma, "tier #{tier}"
    end
  end
end
