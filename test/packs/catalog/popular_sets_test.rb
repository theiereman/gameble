require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_sets"

# Catalog::PopularSets: a season's sets by the average review count of their
# members, unreviewed members at 0.
class Catalog::PopularSetsTest < ActiveSupport::TestCase
  include CatalogSeeds
  include GameSets

  setup do
    @season, @cards = published_cards(8, review_counts: [ 100, 300, nil, 50, 1000, 10, nil, nil ])
  end

  def set(key, members) = insert_theme(members, key:, season: @season)

  test "by average review count, unreviewed as 0, then by id; the sets excluded left out" do
    low = set("low", @cards.values_at(5, 6))
    high = set("high", @cards.values_at(4, 2))
    middle = set("middle", @cards.values_at(0, 1))
    tie = set("tie", @cards.values_at(3, 7))
    empty = insert_set([], {}, key: "empty", season: @season)
    twin = set("twin", @cards.values_at(3, 6))

    assert_equal [ high, middle, tie, twin, low, empty ], Catalog::PopularSets.call(season: @season, limit: 10)
    assert_equal [ high, tie ], Catalog::PopularSets.call(season: @season, limit: 2, exclude: [ middle ])
  end

  test "another season's sets never come; one query, none for a limit of 0" do
    set("theme", @cards.first(2))
    valve = catalog_sets(:valve_one).id

    assert_queries_count(1) { assert_not_includes Catalog::PopularSets.call(season: @season, limit: 4), valve }
    assert_queries_count(0) { assert_equal [], Catalog::PopularSets.call(season: @season, limit: 0) }
    assert_queries_count(0) { assert_equal [], Catalog::PopularSets.call(season: @season, limit: -1) }
  end
end
