require "test_helper"
require_relative "../../support/catalog_seeds"

class Catalog::SeasonScoresTest < ActiveSupport::TestCase
  include CatalogSeeds

  def tiers_of(scores)
    scores.panel.tiers.map { |tier| [ tier.tier, tier.card_count, tier.threshold ] }
  end

  def card_season_ids(season)
    Catalog::CardSeason.where(season_id: season.id).order(:id).ids
  end

  test "a published season shows its stored tiers, extremes, themes, UFOs, sets and score versions" do
    season = publish_sets_draft

    scores = Catalog::SeasonScores.call(season.number)

    assert_equal [ season.number, "published", season.published_at ], [ scores.number, scores.status, scores.published_at ]
    assert_predicate scores, :published?
    assert_equal [ nil ], scores.score_versions
    panel = scores.panel
    assert_nil panel.verdict
    assert_equal 150, panel.card_count
    assert_equal({ 10 => 15.0, 50 => 75.0, 90 => 135.0, 99 => 149.0 }, panel.percentiles)
    assert_equal [ 1.0, 150.0 ], [ panel.min, panel.max ]
    assert_nil panel.score_version_verdict
    assert_nil panel.tier_verdict
    assert_equal [ [ 5, 2, 149.0 ], [ 4, 6, 143.0 ], [ 3, 15, 128.0 ], [ 2, 37, 91.0 ], [ 1, 90, nil ] ], tiers_of(scores)
    assert_equal (0..9).map { |i| "Seed #{i}" }, panel.top.map(&:title)
    assert_equal "Seed 149", panel.bottom.first.title
    assert_equal [ [ "roguelike", 119 ], [ "rpg", 44 ], [ "horror", 16 ], [ "pirates", 8 ] ], panel.themes.map { |theme| [ theme.theme, theme.card_count ] }
    assert_equal 15, panel.ufo_count
    assert_nil panel.theme_verdict
    assert_equal({ "theme" => 4, "ufo" => 1, "tome" => 0, "publisher" => 0, "best_of_year" => 0 }, panel.set_counts)
  end

  test "a published season's tiers and sets are the stored ones, even where a new cut would differ" do
    season = publish_sets_draft
    lowest = card_season_ids(season).last
    Catalog::CardSeason.where(id: lowest).update_all(rarity: 5)
    set_id = Catalog::Set.insert_all!([ { season_id: season.id, kind: "theme", key: "zombies", params: { "theme" => "zombies" } } ], returning: :id)
      .rows.flatten.sole
    Catalog::SetMembership.insert_all!([ { set_id:, card_season_id: lowest, position: 1 } ])

    scores = Catalog::SeasonScores.call(season.number)

    assert_equal [ [ 5, 3, 1.0 ], [ 4, 6, 143.0 ], [ 3, 15, 128.0 ], [ 2, 37, 91.0 ], [ 1, 89, nil ] ], tiers_of(scores)
    assert_equal [ [ "roguelike", 119 ], [ "rpg", 44 ], [ "horror", 16 ], [ "pirates", 8 ], [ "zombies", 1 ] ],
      scores.panel.themes.map { |theme| [ theme.theme, theme.card_count ] }
    assert_equal 5, scores.panel.set_counts.fetch("theme")
  end

  test "a published season too small for a new cut still shows the five rarities it stored" do
    scores = Catalog::SeasonScores.call(1)

    assert_nil Catalog::RarityThresholds.tiers(Catalog::CardSeason.where(season_id: catalog_seasons(:one).id).pluck(:prestige_score))
    assert_equal [ [ 5, 1, 0.99 ], [ 4, 1, 0.9 ], [ 3, 1, 0.7 ], [ 2, 1, 0.5 ], [ 1, 1, nil ] ], tiers_of(scores)
    assert_equal({ "theme" => 0, "ufo" => 0, "tome" => 0, "publisher" => 1, "best_of_year" => 0 }, scores.panel.set_counts)
    assert_equal [ [], nil ], [ scores.panel.themes, scores.panel.ufo_count ]
  end

  test "a season scored before versions has none recorded" do
    assert_equal [ nil ], Catalog::SeasonScores.call(1).score_versions
  end

  test "a published season of mixed versions lists each once, the unrecorded one first" do
    season = publish_sets_draft
    ids = card_season_ids(season)
    Catalog::CardSeason.where(id: ids.first(20)).update_all(prestige_score_version: 3)
    Catalog::CardSeason.where(id: ids.last(20)).update_all(prestige_score_version: 2)

    scores = Catalog::SeasonScores.call(season.number)

    assert_equal [ nil, 2, 3 ], scores.score_versions
    assert_nil scores.panel.score_version_verdict
  end

  test "the draft shows the panel the list previews, cut now" do
    draft = seed_sets_draft

    scores = Catalog::SeasonScores.call(draft.number)

    assert_predicate scores, :draft?
    assert_nil scores.published_at
    assert_equal Catalog::DraftPreview.call, scores.panel
    assert_equal [ 5, 4, 3, 2, 1 ], scores.panel.tiers.map(&:tier)
  end

  test "a draft of mixed versions shows the mixed_score_versions verdict and both versions" do
    draft = seed_card_seasons(distinct_scores(150), score_versions: Array.new(100, 2) + Array.new(50))

    scores = Catalog::SeasonScores.call(draft.number)

    assert_equal :mixed_score_versions, scores.panel.score_version_verdict
    assert_equal [ nil, 2 ], scores.score_versions
  end

  test "an empty draft gives the empty_season verdict and no version" do
    draft = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)

    scores = Catalog::SeasonScores.call(draft.number)

    assert_predicate scores.panel, :empty_season?
    assert_equal [], scores.score_versions
  end

  test "an unknown number gives nil" do
    assert_nil Catalog::SeasonScores.call(99)
  end
end
