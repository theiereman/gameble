require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::CardSeasonTiers: the rarity tier of each card-season asked about.
class Catalog::CardSeasonTiersTest < ActiveSupport::TestCase
  include CatalogSeeds

  test "each card-season's tier in one query; a draft's or an unknown id left out" do
    common, rare, legendary = %i[common_card_one rare_card_one legendary_card_one].map { catalog_card_seasons(it).id }
    draft = Catalog::CardSeason.where(season_id: seed_card_seasons([ 1.0 ]).id).sole.id

    assert_queries_count(1) do
      assert_equal({ common => 1, rare => 3, legendary => 5 }, Catalog::CardSeasonTiers.call([ legendary, common, rare, rare, draft, 0 ]))
    end
  end

  test "nothing asked costs no query" do
    assert_queries_count(0) { assert_equal({}, Catalog::CardSeasonTiers.call([])) }
  end
end
