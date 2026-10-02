require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::SeasonShelf and Catalog::SetTotals (CAP-6): the published
# season's sets of one kind in shelf order, and their sizes.
class Catalog::SeasonShelfTest < ActiveSupport::TestCase
  include CatalogSeeds

  def keys(kind)
    Catalog::SeasonShelf.relation(kind:).map(&:key)
  end

  test "each kind comes from the published season only, in its own order" do
    seed_published_sets([
      [ "tome", "adventure-1", { "genre" => "adventure", "volume" => 1, "volumes" => 1 } ],
      [ "tome", "action-10", { "genre" => "action", "volume" => 10, "volumes" => 10 } ],
      [ "tome", "action-2", { "genre" => "action", "volume" => 2, "volumes" => 10 } ],
      [ "publisher", "valve", { "publisher" => "Valve" } ],
      [ "publisher", "activision", { "publisher" => "Activision" } ],
      [ "best_of_year", "2011", { "year" => 2011 } ],
      [ "best_of_year", "2015", { "year" => 2015 } ]
    ])

    assert_equal %w[action-2 action-10 adventure-1], keys("tome")
    assert_equal %w[activision valve], keys(:publisher)
    assert_equal %w[2015 2011], keys("best_of_year")
  end

  test "the relation is ungrouped and costs one query, for the published season" do
    seed_published_sets([ [ "publisher", "valve", { "publisher" => "Valve" } ] ])

    relation = nil
    assert_queries_count(1) { relation = Catalog::SeasonShelf.relation(kind: "publisher") }
    assert_empty relation.group_values
    assert_equal 1, relation.count
  end

  test "a season with no set of that kind gives an empty relation" do
    seed_published_sets([ [ "tome", "action-1", { "genre" => "action", "volume" => 1, "volumes" => 1 } ] ])

    assert_empty keys("publisher")
  end

  test "nothing is answered when no season is published" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    assert_nil Catalog::SeasonShelf.relation(kind: "tome")
  end

  test "an unknown kind is refused" do
    assert_raises(KeyError) { Catalog::SeasonShelf.relation(kind: "nope") }
  end

  test "the totals count each set's members, in one query, and nothing for no set" do
    season = publish_sets_draft
    sets = Catalog::Set.where(season_id: season.id).index_by(&:key)

    totals = nil
    assert_queries_count(1) { totals = Catalog::SetTotals.call(sets.values_at("p", "action-1", "rpg-1", "2012").map(&:id)) }
    assert_equal [ 5, 25, 44, 9 ], sets.values_at("p", "action-1", "rpg-1", "2012").map { |set| totals.fetch(set.id) }
    assert_equal 4, totals.size

    assert_queries_count(0) { assert_equal({}, Catalog::SetTotals.call([])) }
  end
end
