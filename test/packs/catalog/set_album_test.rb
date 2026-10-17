require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_sets"

class Catalog::SetAlbumTest < ActiveSupport::TestCase
  include CatalogSeeds
  include GameSets

  test "a set comes with its members in slot order, each with its game, and its tiers, in three queries" do
    season, cards = published_cards(20)
    insert_theme(cards.reverse, key: "roguelike", season:)
    games = Catalog::CardSeason.where(id: cards).pluck(:id, :card_id).to_h

    album = nil
    assert_queries_count(3) { album = Catalog::SetAlbum.call(season:, kind: "theme", key: "roguelike") }

    assert_equal [ "theme", "roguelike" ], [ album.set.kind, album.set.key ]
    assert_equal cards.reverse.map { [ it, games.fetch(it) ] }, album.members
    assert_equal({ "bronze" => 2, "silver" => 5, "gold" => 10, "complete" => 20 }, album.tiers)
  end

  test "the members follow their positions, then their memberships" do
    season, cards = published_cards(3)
    set_id = insert_set([], {}, kind: "studio", key: "valve", params: { "studio" => "Valve" }, season:)
    Catalog::SetMembership.insert_all!([ [ cards[0], 2 ], [ cards[1], 1 ], [ cards[2], 2 ] ].map { |card_season_id, position| { set_id:, card_season_id:, position: } })

    album = Catalog::SetAlbum.call(season:, kind: :studio, key: "valve")

    assert_equal [ cards[1], cards[0], cards[2] ], album.members.map(&:first)
    assert_equal({}, album.tiers)
  end

  test "an unknown key, a key of another kind or of another season is nothing, after one query" do
    season, cards = published_cards(3)
    insert_set(cards, { complete: 3 }, kind: "franchise", key: "halo", params: { "franchise" => "Halo" }, season:)

    assert_queries_count(1) { assert_nil Catalog::SetAlbum.call(season:, kind: "franchise", key: "nope") }
    assert_nil Catalog::SetAlbum.call(season:, kind: "studio", key: "halo")
    assert_nil Catalog::SetAlbum.call(season: catalog_seasons(:one), kind: "franchise", key: "halo")
  end
end
