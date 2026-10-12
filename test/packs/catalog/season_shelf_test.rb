require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::SeasonShelf and Catalog::SetTotals: the published season's sets
# of one kind in shelf order, the kinds it holds, and their sizes.
class Catalog::SeasonShelfTest < ActiveSupport::TestCase
  include CatalogSeeds

  def keys(kind)
    Catalog::SeasonShelf.relation(kind:).map(&:key)
  end

  test "each kind comes from the published season only, in its own order" do
    seed_published_sets([
      [ "theme", "rpg", { "theme" => "rpg" } ],
      [ "theme", "horror", { "theme" => "horror" } ],
      [ "ufo", "ufos", {} ],
      [ "tome", "adventure-1", { "genre" => "adventure", "volume" => 1, "volumes" => 1 } ],
      [ "tome", "action-10", { "genre" => "action", "volume" => 10, "volumes" => 10 } ],
      [ "tome", "action-2", { "genre" => "action", "volume" => 2, "volumes" => 10 } ],
      [ "publisher", "valve", { "publisher" => "Valve" } ],
      [ "publisher", "activision", { "publisher" => "Activision" } ],
      [ "best_of_year", "2011", { "year" => 2011 } ],
      [ "best_of_year", "2015", { "year" => 2015 } ]
    ])

    assert_equal %w[horror rpg], keys("theme")
    assert_equal %w[ufos], keys(:ufo)
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

  test "a season given is not looked up again, and none given as nil answers nothing" do
    season = seed_published_sets([ [ "publisher", "valve", { "publisher" => "Valve" } ] ])

    relation = nil
    assert_queries_count(0) { relation = Catalog::SeasonShelf.relation(kind: "publisher", season:) }
    assert_equal %w[valve], relation.map(&:key)
    assert_queries_count(0) { assert_nil Catalog::SeasonShelf.relation(kind: "publisher", season: nil) }
  end

  test "a season with no set of that kind gives an empty relation" do
    seed_published_sets([ [ "tome", "action-1", { "genre" => "action", "volume" => 1, "volumes" => 1 } ] ])

    assert_empty keys("publisher")
  end

  test "nothing is answered when no season is published" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    assert_nil Catalog::SeasonShelf.relation(kind: "tome")
  end

  test "a kind without a shelf order of its own is by key; an unknown kind holds nothing" do
    seed_published_sets([ [ "studio", "valve", { "studio" => "Valve" } ], [ "studio", "capcom", { "studio" => "Capcom" } ] ])

    assert_equal %w[capcom valve], keys("studio")
    assert_empty keys("nope")
  end

  test "the kinds the published season holds sets of, none without a season" do
    season = seed_published_sets([ [ "theme", "rpg", { "theme" => "rpg" } ], [ "theme", "horror", { "theme" => "horror" } ], [ "ufo", "ufos", {} ] ])

    assert_equal %w[theme ufo], Catalog::SeasonShelf.kinds(season:).sort
    assert_equal %w[publisher], Catalog::SeasonShelf.kinds(season: catalog_seasons(:one))
    assert_queries_count(0) { assert_equal [], Catalog::SeasonShelf.kinds(season: nil) }
  end

  test "the totals count each set's members, in one query, and nothing for no set" do
    season = publish_sets_draft
    sets = Catalog::Set.where(season_id: season.id).index_by(&:key)

    totals = nil
    assert_queries_count(1) { totals = Catalog::SetTotals.call(sets.values_at("roguelike", "rpg", "ufos").map(&:id)) }
    assert_equal [ 119, 44, 15 ], sets.values_at("roguelike", "rpg", "ufos").map { |set| totals.fetch(set.id) }
    assert_equal 3, totals.size

    assert_queries_count(0) { assert_equal({}, Catalog::SetTotals.call([])) }
  end

  test "every kind: themes, the UFOs, then tomes, publishers and best of year, each in its own order, lazily" do
    season = seed_published_sets([
      [ "ufo", "ufos", {} ],
      [ "theme", "rpg", { "theme" => "rpg" } ],
      [ "best_of_year", "2011", { "year" => 2011 } ],
      [ "publisher", "valve", { "publisher" => "Valve" } ],
      [ "tome", "adventure-1", { "genre" => "adventure", "volume" => 1, "volumes" => 1 } ],
      [ "best_of_year", "2015", { "year" => 2015 } ],
      [ "tome", "action-10", { "genre" => "action", "volume" => 10, "volumes" => 10 } ],
      [ "publisher", "activision", { "publisher" => "Activision" } ],
      [ "tome", "action-2", { "genre" => "action", "volume" => 2, "volumes" => 10 } ],
      [ "theme", "horror", { "theme" => "horror" } ]
    ])

    relation = nil
    assert_queries_count(0) { relation = Catalog::SeasonShelf.every_kind(season:) }
    assert_equal %w[horror rpg ufos action-2 action-10 adventure-1 activision valve 2015 2011], relation.map(&:key)
    assert_empty relation.group_values
  end

  test "every kind answers nothing without a season" do
    assert_queries_count(0) { assert_nil Catalog::SeasonShelf.every_kind(season: nil) }
  end
end
