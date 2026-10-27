require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::SeasonSets: a season's sets of every kind in tab order, and
# the kinds it holds.
class Catalog::SeasonSetsTest < ActiveSupport::TestCase
  include CatalogSeeds

  test "the kinds the published season holds sets of, none without a season" do
    season = seed_published_sets([ [ "theme", "rpg", { "theme" => "rpg" } ], [ "theme", "horror", { "theme" => "horror" } ], [ "ufo", "ufos", {} ] ])

    assert_equal %w[theme ufo], Catalog::SeasonSets.kinds(season:).sort
    assert_equal %w[studio], Catalog::SeasonSets.kinds(season: catalog_seasons(:one))
    assert_queries_count(0) { assert_equal [], Catalog::SeasonSets.kinds(season: nil) }
  end

  test "every kind: themes, franchises, studios, hall of fame, then the UFOs, each in its own order, lazily" do
    season = seed_published_sets([
      [ "ufo", "ufos", {} ],
      [ "hall_of_fame", "pepites", { "hall_of_fame" => "pepites" } ],
      [ "studio", "capcom", { "studio" => "Capcom" } ],
      [ "hall_of_fame", "intouchables", { "hall_of_fame" => "intouchables" } ],
      [ "franchise", "halo", { "franchise" => "Halo" } ],
      [ "theme", "rpg", { "theme" => "rpg" } ],
      [ "studio", "activision", { "studio" => "Activision" } ],
      [ "franchise", "doom", { "franchise" => "Doom" } ],
      [ "theme", "horror", { "theme" => "horror" } ]
    ])

    relation = nil
    assert_queries_count(0) { relation = Catalog::SeasonSets.every_kind(season:) }
    assert_equal %w[horror rpg doom halo activision capcom intouchables pepites ufos], relation.map(&:key)
    assert_empty relation.group_values
  end

  test "every kind answers nothing without a season" do
    assert_queries_count(0) { assert_nil Catalog::SeasonSets.every_kind(season: nil) }
  end
end
