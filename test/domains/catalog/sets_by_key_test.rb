require "test_helper"
require_relative "../../support/game_sets"

# Several sets of a season read at once by kind and key: each set with its
# games in set order and the cards each tier asks.
class Catalog::SetsByKeyTest < ActiveSupport::TestCase
  include GameSets

  setup do
    @season = catalog_seasons(:one)
  end

  test "reads each set asked by kind and key, its games in set order and its tiers, in one query per table" do
    members = [ catalog_card_seasons(:rare_card_one).id, catalog_card_seasons(:common_card_one).id ]
    roguelike = insert_set(members, { bronze: 1, complete: 2 }, key: "roguelike")

    entries = nil
    assert_queries_count(3) { entries = Catalog::SetsByKey.call(season: @season, keys: [ %w[theme roguelike], [ :studio, :valve ], %w[theme pirates] ]) }

    assert_equal [ %w[studio valve], %w[theme roguelike] ], entries.keys.sort
    assert_equal roguelike, entries[%w[theme roguelike]].set.id
    assert_equal %i[rare_card common_card].map { catalog_cards(it).id }, entries[%w[theme roguelike]].card_ids
    assert_equal({ "bronze" => 1, "complete" => 2 }, entries[%w[theme roguelike]].tiers)
    assert_equal [ [ catalog_cards(:portal).id ], { "complete" => 1 } ], entries[%w[studio valve]].then { [ it.card_ids, it.tiers ] }
  end

  test "reads the sets alone, and nothing without a season or a key" do
    assert_equal [ %w[studio valve] ], Catalog::SetsByKey.sets(season: @season, keys: [ %w[studio valve], %w[studio valve] ]).keys
    assert_equal({}, Catalog::SetsByKey.call(season: nil, keys: [ %w[studio valve] ]))
    assert_equal({}, Catalog::SetsByKey.call(season: @season, keys: []))
  end
end
