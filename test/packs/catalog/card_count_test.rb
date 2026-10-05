require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::CardCount: the cards of a season, the total of the hub's
# collection meta.
class Catalog::CardCountTest < ActiveSupport::TestCase
  include CatalogSeeds

  test "the card-seasons of the season with a rarity, in one query" do
    published = publish_sets_draft
    draft = seed_card_seasons([ 3.0, 2.0, 1.0 ])

    assert_queries_count(1) { assert_equal 150, Catalog::CardCount.call(published) }
    assert_equal 5, Catalog::CardCount.call(catalog_seasons(:one))
    assert_equal 0, Catalog::CardCount.call(draft), "a draft's cards have no rarity yet"
  end

  test "0, without a query, for no season" do
    assert_queries_count(0) { assert_equal 0, Catalog::CardCount.call(nil) }
  end
end
