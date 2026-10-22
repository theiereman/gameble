require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::DraftTagUsage, Catalog::ThemeList and Catalog::ThemeByToken: what
# the themes page reads.
class Catalog::DraftTagUsageTest < ActiveSupport::TestCase
  include CatalogSeeds

  def tag_cards(season, tags)
    cards = Catalog::Card.joins(:card_seasons).where(catalog_card_seasons: { season_id: season.id }).order(:id)
    cards.each_with_index { |card, index| card.update_columns(tags: tags.fetch(index)) }
  end

  test "each tag counts the draft's cards that carry it among their five most-voted, the most carried first" do
    draft = seed_card_seasons(distinct_scores(3))
    tag_cards(draft, [ %w[indie rpg a b c sixth], %w[rpg indie], %w[puzzle] ])

    assert_equal({ "indie" => 2, "rpg" => 2, "a" => 1, "b" => 1, "c" => 1, "puzzle" => 1 }, Catalog::DraftTagUsage.call)
    assert_equal %w[indie rpg a b c puzzle], Catalog::DraftTagUsage.call.keys
  end

  test "the published season's cards do not count, and a world without draft has no usage" do
    assert_empty Catalog::DraftTagUsage.call
  end

  test "the themes are listed by English name with the number of tags attached" do
    entries = Catalog::ThemeList.call

    assert_equal entries.map { it.theme.name_en }, entries.map { it.theme.name_en }.sort_by(&:downcase)
    roguelike = entries.find { it.theme.key == "roguelike" }
    assert_equal 4, roguelike.tag_count
    assert_equal 43, entries.size
  end

  test "a theme is found by its token, and an absent or malformed token finds none" do
    theme = catalog_themes(:horror)

    assert_equal theme, Catalog::ThemeByToken.call(theme.token)
    assert_nil Catalog::ThemeByToken.call("A" * 24)
    assert_no_queries { assert_nil Catalog::ThemeByToken.call(nil) }
    assert_no_queries { assert_nil Catalog::ThemeByToken.call("") }
    assert_no_queries { assert_nil Catalog::ThemeByToken.call(12) }
  end

  test "without a draft the rescore is not needed" do
    assert_not Catalog::DraftRescoreNeeded.call
  end
end
