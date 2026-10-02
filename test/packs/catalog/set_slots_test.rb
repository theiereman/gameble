require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::SetSlots (CAP-6, story 4.2): one set of a season by kind and key,
# with its card-seasons in slot order.
class Catalog::SetSlotsTest < ActiveSupport::TestCase
  include CatalogSeeds

  setup do
    @season = publish_sets_draft
  end

  def members(key)
    set = Catalog::Set.find_by!(season_id: @season.id, key:)
    Catalog::SetMembership.where(set_id: set.id).order(:position, :id).pluck(:card_season_id)
  end

  test "a set comes with its kind, key and params and its card-seasons by position, in one query" do
    slots = nil
    assert_queries_count(1) { slots = Catalog::SetSlots.call(season_id: @season.id, kind: "tome", key: "action-1") }

    assert_equal Catalog::SetSlots::SetRef.new(kind: "tome", key: "action-1", params: { "genre" => "action", "volume" => 1, "volumes" => 3 }), slots.set
    assert_equal members("action-1"), slots.card_season_ids
    assert_equal 25, slots.card_season_ids.size
  end

  test "each kind is found by its key, symbols accepted" do
    assert_equal({ "publisher" => "P" }, Catalog::SetSlots.call(season_id: @season.id, kind: :publisher, key: "p").set.params)
    assert_equal members("2015"), Catalog::SetSlots.call(season_id: @season.id, kind: "best_of_year", key: "2015").card_season_ids
  end

  test "the slots follow the membership positions, not the card-season ids" do
    set = seed_published_sets([ [ "publisher", "valve", { "publisher" => "Valve" } ] ]).then { Catalog::Set.find_by!(season_id: it.id) }
    other = seed_card_seasons([ 3.0, 2.0, 1.0 ])
    ids = Catalog::CardSeason.where(season_id: other.id).order(:id).ids
    Catalog::CardSeason.where(id: ids).update_all(season_id: set.season_id)
    Catalog::SetMembership.insert_all!([ [ ids[0], 3 ], [ ids[1], 1 ], [ ids[2], 2 ] ].map { |card_season_id, position| { set_id: set.id, card_season_id:, position: } })

    assert_equal [ ids[1], ids[2], ids[0] ], Catalog::SetSlots.call(season_id: set.season_id, kind: "publisher", key: "valve").card_season_ids
  end

  test "a set without members has no slots" do
    season = seed_published_sets([ [ "tome", "xyz-1", { "genre" => "xyz", "volume" => 1, "volumes" => 1 } ] ])

    assert_equal [], Catalog::SetSlots.call(season_id: season.id, kind: "tome", key: "xyz-1").card_season_ids
  end

  test "an unknown key, a key of another kind or another season is nothing" do
    assert_nil Catalog::SetSlots.call(season_id: @season.id, kind: "tome", key: "nope")
    assert_nil Catalog::SetSlots.call(season_id: @season.id, kind: "publisher", key: "action-1")
    assert_nil Catalog::SetSlots.call(season_id: catalog_seasons(:one).id, kind: "tome", key: "action-1")
  end
end
