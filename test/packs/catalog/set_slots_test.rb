require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::SetSlots: one set of a season by kind and key,
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
    assert_queries_count(1) { slots = Catalog::SetSlots.call(season_id: @season.id, kind: "theme", key: "rpg") }

    assert_equal Catalog::SetSlots::SetRef.new(kind: "theme", key: "rpg", params: { "theme" => "rpg" }), slots.set
    assert_equal members("rpg"), slots.card_season_ids
    assert_equal 44, slots.card_season_ids.size
  end

  test "each kind is found by its key, symbols accepted" do
    assert_equal({ "theme" => "roguelike" }, Catalog::SetSlots.call(season_id: @season.id, kind: :theme, key: "roguelike").set.params)
    assert_equal members("ufos"), Catalog::SetSlots.call(season_id: @season.id, kind: "ufo", key: "ufos").card_season_ids
  end

  test "the slots follow the membership positions, not the card-season ids" do
    set = seed_published_sets([ [ "studio", "valve", { "studio" => "Valve" } ] ]).then { Catalog::Set.find_by!(season_id: it.id) }
    other = seed_card_seasons([ 3.0, 2.0, 1.0 ])
    ids = Catalog::CardSeason.where(season_id: other.id).order(:id).ids
    Catalog::CardSeason.where(id: ids).update_all(season_id: set.season_id)
    Catalog::SetMembership.insert_all!([ [ ids[0], 3 ], [ ids[1], 1 ], [ ids[2], 2 ] ].map { |card_season_id, position| { set_id: set.id, card_season_id:, position: } })

    assert_equal [ ids[1], ids[2], ids[0] ], Catalog::SetSlots.call(season_id: set.season_id, kind: "studio", key: "valve").card_season_ids
  end

  test "a set without members has no slots" do
    season = seed_published_sets([ [ "franchise", "xyz", { "franchise" => "Xyz" } ] ])

    assert_equal [], Catalog::SetSlots.call(season_id: season.id, kind: "franchise", key: "xyz").card_season_ids
  end

  test "an unknown key, a key of another kind or another season is nothing" do
    assert_nil Catalog::SetSlots.call(season_id: @season.id, kind: "theme", key: "nope")
    assert_nil Catalog::SetSlots.call(season_id: @season.id, kind: "studio", key: "rpg")
    assert_nil Catalog::SetSlots.call(season_id: catalog_seasons(:one).id, kind: "theme", key: "rpg")
  end
end
