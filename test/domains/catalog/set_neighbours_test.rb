require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::SetNeighbours (the card detail's ◀ ▶): a card-season's
# position in one set of its season, the set's size and the cards on either
# side, in slot order, in one query.
class Catalog::SetNeighboursTest < ActiveSupport::TestCase
  include CatalogSeeds

  # A published season with one studio set "valve" holding three
  # card-seasons at positions 3, 1, 2 (by id order): returns [ season, ids ].
  def three_in_a_set
    season = seed_published_sets([ [ "studio", "valve", { "studio" => "Valve" } ] ])
    other = seed_card_seasons([ 3.0, 2.0, 1.0 ])
    ids = Catalog::CardSeason.where(season_id: other.id).order(:id).ids
    Catalog::CardSeason.where(id: ids).update_all(season_id: season.id, rarity: 1)
    set = Catalog::Set.find_by!(season_id: season.id)
    Catalog::SetMembership.insert_all!([ [ ids[0], 3 ], [ ids[1], 1 ], [ ids[2], 2 ] ].map { |card_season_id, position| { set_id: set.id, card_season_id:, position: } })
    [ season, ids ]
  end

  def slug(id) = Catalog::CardSeason.find(id).card.slug

  def neighbours(id, kind: "studio", key: "valve", locale: :en)
    Catalog::SetNeighbours.call(card_season_id: id, kind:, key:, locale:)
  end

  test "the middle card: its set, its position by membership position, the total and both neighbours, in one query" do
    _, ids = three_in_a_set
    result = nil

    assert_queries_count(1) { result = neighbours(ids[2]) }

    assert_equal Catalog::SetRef.new(kind: "studio", key: "valve", params: { "studio" => "Valve" }), result.set
    assert_equal [ 2, 3, slug(ids[1]), slug(ids[0]) ], [ result.position, result.total, result.previous, result.next ]
  end

  test "the first card has no previous, the last no next" do
    _, ids = three_in_a_set

    first = neighbours(ids[1])
    assert_equal [ 1, 3, nil, slug(ids[2]) ], [ first.position, first.total, first.previous, first.next ]
    last = neighbours(ids[0])
    assert_equal [ 3, 3, slug(ids[2]), nil ], [ last.position, last.total, last.previous, last.next ]
  end

  test "equal positions fall back to the membership's order, as the album's slots" do
    season = publish_sets_draft
    set = Catalog::Set.find_by!(season_id: season.id, key: "rpg")
    members = Catalog::SetMembership.where(set_id: set.id).order(:position, :id).pluck(:card_season_id)
    Catalog::SetMembership.where(set_id: set.id).update_all(position: 1)
    ordered = Catalog::SetMembership.where(set_id: set.id).order(:id).pluck(:card_season_id)

    assert_equal Catalog::SetAlbum.call(season:, kind: "theme", key: "rpg").members.map(&:first), ordered
    result = neighbours(ordered[4], kind: "theme", key: "rpg")
    assert_equal [ 5, members.size, slug(ordered[3]), slug(ordered[5]) ], [ result.position, result.total, result.previous, result.next ]
  end

  test "a member without a text in the locale is skipped, as the grid skips it" do
    _, ids = three_in_a_set
    Catalog::CardText.where(card_id: Catalog::CardSeason.find(ids[2]).card_id, locale: "fr").delete_all

    french = neighbours(ids[0], locale: :fr)
    assert_equal [ 2, 2, slug(ids[1]), nil ], [ french.position, french.total, french.previous, french.next ]
    english = neighbours(ids[0], locale: :en)
    assert_equal [ 3, 3 ], [ english.position, english.total ]
    assert_nil neighbours(ids[2], locale: :fr)
  end

  test "a set that does not hold the card, an unknown set or a set of another season is nothing" do
    season, ids = three_in_a_set
    Catalog::Set.insert_all!([ { season_id: season.id, kind: "theme", key: "action", params: { "theme" => "action" } } ])

    assert_nil neighbours(ids[0], kind: "theme", key: "action")
    assert_nil neighbours(ids[0], key: "nope")
    assert_nil neighbours(ids[0], kind: "franchise")
    # Season 1 has its own "valve" set, holding portal only: its card-seasons
    # are looked up there, never in the newer season's "valve".
    portal = neighbours(catalog_card_seasons(:portal_one).id)
    assert_equal [ 1, 1, nil, nil ], [ portal.position, portal.total, portal.previous, portal.next ]
    assert_nil neighbours(catalog_card_seasons(:common_card_one).id)
  end
end
