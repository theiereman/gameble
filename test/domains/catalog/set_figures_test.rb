require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_sets"

# Catalog::SetFigures: the size and tiers of sets, in one query.
class Catalog::SetFiguresTest < ActiveSupport::TestCase
  include CatalogSeeds
  include GameSets

  test "each set's size and the cards its tiers ask; an unknown id left out; one query, none for no set" do
    season, cards = published_cards(20)
    theme = insert_theme(cards, key: "roguelike", season:)
    franchise = insert_set(cards.first(3), { complete: 3 }, kind: "franchise", key: "halo", params: { "franchise" => "Halo" }, season:)
    bare = insert_set([], {}, kind: "studio", key: "valve", params: { "studio" => "Valve" }, season:)

    figures = nil
    assert_queries_count(1) { figures = Catalog::SetFigures.call([ theme, franchise, bare, theme, -1 ]) }
    assert_equal [ theme, franchise, bare ].sort, figures.keys.sort
    assert_equal Catalog::SetFigures::Figures.new(total: 20, tiers: { "bronze" => 2, "silver" => 5, "gold" => 10, "complete" => 20 }), figures.fetch(theme)
    assert_equal Catalog::SetFigures::Figures.new(total: 3, tiers: { "complete" => 3 }), figures.fetch(franchise)
    assert_equal Catalog::SetFigures::Figures.new(total: 0, tiers: {}), figures.fetch(bare)
    assert_queries_count(0) { assert_equal({}, Catalog::SetFigures.call([])) }
  end
end
