require "test_helper"
require_relative "../../support/catalog_seeds"

# Steam::DraftTags: the tags of the draft's cards, named as Steam names them,
# with the games that carry each.
class Steam::DraftTagsTest < ActiveSupport::TestCase
  include CatalogSeeds

  setup do
    draft = seed_card_seasons(distinct_scores(3))
    cards = Catalog::Card.joins(:card_seasons).where(catalog_card_seasons: { season_id: draft.id }).order(:id)
    cards.zip([ %w[roguelite pixel_graphics], %w[roguelite], %w[unlisted_tag] ]).each { |card, tags| card.update_columns(tags:) }
    Steam::Tag.insert_all([ { tagid: 1, name: "Roguelite" }, { tagid: 2, name: "Pixel Graphics" } ])
  end

  test "each tag is named after Steam's English name, with its game count, the most carried first" do
    entries = Steam::DraftTags.call

    assert_equal [ [ "roguelite", "Roguelite", 2 ], [ "pixel_graphics", "Pixel Graphics", 1 ], [ "unlisted_tag", "Unlisted tag", 1 ] ],
      entries.map { [ it.key, it.name, it.game_count ] }
  end

  test "without a draft there is no tag" do
    Catalog::CardSeason.where(season_id: Catalog::Season.draft.select(:id)).delete_all
    Catalog::Season.draft.delete_all

    assert_empty Steam::DraftTags.call
  end
end
