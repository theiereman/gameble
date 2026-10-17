require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"

# SetSearch: the season's sets whose name or kind holds the query, accents
# and case ignored, names starting with it first.
class SetSearchTest < ActiveSupport::TestCase
  include CatalogSeeds
  include GameSets

  setup do
    @season, = published_cards(1)
  end

  def set(kind, key, params) = insert_set([], {}, kind:, key:, params:, season: @season)
  def names(query, locale: :en)
    I18n.with_locale(locale) { SetSearch.call(season: @season, query:, locale:).sets.map { SetLabel.for(it) } }
  end

  test "by name in the locale, accents and case ignored, names starting with the query first, then by name" do
    set("theme", "roguelike", { "theme" => "roguelike" })
    set("theme", "rpg", { "theme" => "rpg" })
    set("theme", "horror", { "theme" => "horror" })
    set("studio", "pere", { "studio" => "Père Games" })
    set("hall_of_fame", "mal-aimes", { "hall_of_fame" => "mal-aimes" })

    assert_equal [ "Roguelike", "RPG", "Horror" ], names("  R ").first(3)
    assert_equal [ "Père Games" ], names("PERE")
    assert_equal [ "Père Games" ], names("père")
    assert_equal [ "Les Mal-aimés" ], names("aimes", locale: :fr)
    assert_equal [ "The Unloved" ], names("unloved", locale: :en)
    assert_empty names("unloved", locale: :fr)
  end

  test "a name in a non-Latin script is found by it, and a question mark finds nothing" do
    set("studio", "x-capcom", { "studio" => "カプコン" })
    set("franchise", "x-sword", { "franchise" => "검과 마법" })
    set("theme", "rpg", { "theme" => "rpg" })

    assert_equal [ "カプコン" ], names("カプ")
    assert_equal [ "검과 마법" ], names("마법")
    assert_empty names("?")
  end

  test "by the kind's name in the locale" do
    set("theme", "rpg", { "theme" => "rpg" })
    set("ufo", "ufos", {})
    set("hall_of_fame", "pepites", { "hall_of_fame" => "pepites" })

    assert_equal [ "RPG" ], names("thème", locale: :fr)
    assert_equal [ "Les OVNI" ], names("ovni", locale: :fr)
    assert_equal [ "Hidden Gems" ], names("hall of", locale: :en)
    assert_equal [ "Les Pépites" ], names("palmares", locale: :fr)
  end

  test "fifty sets at most, with the count of every match" do
    60.times { |index| set("studio", "studio-#{index}", { "studio" => format("Studio %02d", index) }) }

    result = SetSearch.call(season: @season, query: "studio", locale: :en)
    assert_equal 60, result.count
    assert_equal (0...50).map { format("Studio %02d", it) }, result.sets.map { SetLabel.for(it) }
  end

  test "a blank query, or no season, finds nothing without a query; a long one is cut to a hundred characters" do
    set("studio", "long", { "studio" => "#{"a" * 100}b" })

    assert_queries_count(0) { assert_equal SetSearch::NONE, SetSearch.call(season: @season, query: "  ", locale: :en) }
    assert_queries_count(0) { assert_equal SetSearch::NONE, SetSearch.call(season: nil, query: "a", locale: :en) }
    assert_queries_count(1) { assert_equal 1, SetSearch.call(season: @season, query: "a" * 100 + "zzz", locale: :en).count }
    assert_equal "a" * 100, SetSearch.clean(" #{"a" * 120} ")
  end
end
