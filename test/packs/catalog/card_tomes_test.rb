require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::CardTomes (epic 10 R2): the tome of each card-season, which the
# whole-season collection's links name, in one query.
class Catalog::CardTomesTest < ActiveSupport::TestCase
  include CatalogSeeds

  def members(season, key)
    set = Catalog::Set.find_by!(season_id: season.id, key:)
    Catalog::SetMembership.where(set_id: set.id).pluck(:card_season_id)
  end

  test "each card-season's tome, in one query; one in no tome, or unknown, is left out" do
    season = publish_sets_draft
    action = members(season, "action-2").first
    rpg = members(season, "rpg-1").first
    tomes = Catalog::Set.where(season_id: season.id, kind: "tome").ids
    loose = Catalog::CardSeason.where(season_id: season.id).where.not(rarity: nil).ids.find do |id|
      Catalog::SetMembership.where(card_season_id: id, set_id: tomes).none?
    end
    assert loose, "the seed has a card in no tome"
    result = nil

    assert_queries_count(1) { result = Catalog::CardTomes.call([ action, rpg, loose, action, -1 ]) }

    assert_equal [ action, rpg ].sort, result.keys.sort
    params = Catalog::Set.find_by!(season_id: season.id, key: "action-2").params
    assert_equal Catalog::SetSlots::SetRef.new(kind: "tome", key: "action-2", params:), result.fetch(action)
    assert_equal [ "tome", "rpg-1" ], result.fetch(rpg).then { [ it.kind, it.key ] }
  end

  test "only tomes: a card's publisher or best-of-year set is not one" do
    season = publish_sets_draft
    publisher_only = members(season, "p") - Catalog::SetMembership.joins(:set).where(catalog_sets: { season_id: season.id, kind: "tome" }).pluck(:card_season_id)
    assert publisher_only.any?, "the seed has a publisher's card in no tome"

    assert_equal({}, Catalog::CardTomes.call(publisher_only))
  end

  test "no card-season, no query" do
    assert_no_queries { assert_equal({}, Catalog::CardTomes.call([])) }
  end
end
