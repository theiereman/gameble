require "test_helper"

class SetAlbumFiltersTest < ActiveSupport::TestCase
  Card = Data.define(:title, :rarity)
  Edition = Data.define(:copies)

  def filters(**params) = SetAlbumFilters.from(ActionController::Parameters.new(params))

  test "no filter asked shows every card, the default state chosen by nobody" do
    none = filters

    assert_equal [ "all" ], none.states
    assert_not none.states_asked
    assert_empty none.chosen_rarities
    assert_equal "", none.query
    assert_not none.by_card?
    assert none.shows_holding?(nil)
    assert none.shows_holding?(Edition.new(copies: 1))
    assert none.shows_card?(Card.new(title: "Portal", rarity: "rare"))
  end

  test "the states are the album's three, read as the catalog reads them; others are ignored" do
    assert_equal [ "missing" ], filters(state: [ "missing", "all" ]).states
    assert_equal [ "owned", "missing" ], filters(state: [ "missing", "owned" ]).states
    assert_equal [ "all" ], filters(state: [ "new", "duplicates" ]).states
    assert_equal [ "missing" ], filters(state: "missing").states
    assert_not filters(state: [ { "a" => "b" } ]).states_asked

    owned = filters(state: [ "owned" ])
    assert owned.shows_holding?(Edition.new(copies: 2))
    assert_not owned.shows_holding?(nil)
    missing = filters(state: [ "missing" ])
    assert missing.shows_holding?(nil)
    assert_not missing.shows_holding?(Edition.new(copies: 1))
  end

  test "the rarities asked that exist, and a text found in the title, case and accents ignored, both narrowing" do
    chosen = filters(rarity: [ "rare", "mythic", "legendary" ], q: "  ÉLAN  ")

    assert_equal [ "rare", "legendary" ], chosen.chosen_rarities
    assert_equal "ÉLAN", chosen.query
    assert chosen.by_card?
    assert chosen.shows_card?(Card.new(title: "Élan Vital", rarity: "rare"))
    assert chosen.shows_card?(Card.new(title: "The elan", rarity: "legendary"))
    assert_not chosen.shows_card?(Card.new(title: "Élan Vital", rarity: "common"))
    assert_not chosen.shows_card?(Card.new(title: "Portal", rarity: "rare"))
    assert_equal 100, filters(q: "x" * 300).query.size
  end

  test "it answers the FILTRES zone with no set or genre group" do
    none = filters

    assert_empty none.chosen_sets
    assert_empty none.chosen_genres
    assert_empty none.genres
  end
end
