require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::DraftPreview (story 2.8): what publishing the draft now would
# produce, read without writing, in two queries.
class Catalog::DraftPreviewTest < ActiveSupport::TestCase
  include CatalogSeeds

  def preview
    Catalog::DraftPreview.call
  end

  def card_ids(season)
    Catalog::CardSeason.where(season_id: season.id).order(:id).pluck(:card_id)
  end

  test "the 150-card draft previews its scores, tiers, extremes, genres and sets" do
    draft = seed_sets_draft
    ids = card_ids(draft)

    result = preview

    assert_nil result.verdict
    assert_equal 150, result.card_count
    assert_equal({ 10 => 15.0, 50 => 75.0, 90 => 135.0, 99 => 149.0 }, result.percentiles)
    assert_equal [ 1.0, 150.0 ], [ result.min, result.max ]
    assert_nil result.score_version_verdict
    assert_nil result.tier_verdict
    assert_equal [ [ 5, 2, 149.0 ], [ 4, 6, 143.0 ], [ 3, 15, 128.0 ], [ 2, 37, 91.0 ], [ 1, 90, nil ] ],
      result.tiers.map { |tier| [ tier.tier, tier.card_count, tier.threshold ] }
    assert_equal ids.first(10), result.top.map(&:card_id)
    assert_equal (0..9).map { |i| "Seed #{i}" }, result.top.map(&:title)
    assert_equal [ 150.0, BigDecimal(50) ], [ result.top.first.prestige_score, result.top.first.rating ]
    assert_equal ids.last(10).reverse, result.bottom.map(&:card_id)
    assert_equal "Seed 149", result.bottom.first.title
    assert_equal [ [ "action", 75, 3 ], [ "rpg", 44, 1 ], [ nil, 31, 0 ] ],
      result.genres.map { |genre| [ genre.genre, genre.card_count, genre.tome_count ] }
    assert_equal({ "publisher" => 1, "tome" => 4, "best_of_year" => 3 }, result.set_counts)
  end

  test "a draft too small for five tiers shows the empty_tier verdict in place of the tiers, and the rest" do
    seed_card_seasons(distinct_scores(20))

    result = preview

    assert_equal :empty_tier, result.tier_verdict
    assert_nil result.tiers
    assert_equal 20, result.card_count
    assert_equal({ 10 => 2.0, 50 => 10.0, 90 => 18.0, 99 => 20.0 }, result.percentiles)
    assert_equal 10, result.top.size
    assert_equal({ "publisher" => 0, "tome" => 0, "best_of_year" => 1 }, result.set_counts)
  end

  test "a draft mixing two score versions shows the mixed_score_versions verdict, its tiers still cut" do
    seed_card_seasons(distinct_scores(150), score_versions: Array.new(100, 2) + Array.new(50))

    result = preview

    assert_equal :mixed_score_versions, result.score_version_verdict
    assert_nil result.tier_verdict
    assert_equal [ 2, 6, 15, 37, 90 ], result.tiers.map(&:card_count)
  end

  test "a draft scored by one version has no score version verdict" do
    seed_card_seasons(distinct_scores(150), score_versions: Array.new(150, 2))

    assert_nil preview.score_version_verdict
  end

  test "a draft without card-season gives the empty_season verdict and no number" do
    Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)

    result = preview

    assert_predicate result, :empty_season?
    assert_equal({}, result.to_h.except(:verdict).compact)
  end

  test "with only published seasons there is no preview" do
    assert_empty Catalog::Season.draft
    assert_nil preview
  end

  test "of two cards sharing the score of ranks 10 and 11, the lower card id is in the top ten" do
    scores = distinct_scores(30)
    scores[10] = scores[9]
    draft = seed_card_seasons(scores)
    ids = card_ids(draft)

    top = preview.top.map(&:card_id)

    assert_includes top, ids[9]
    assert_not_includes top, ids[10]
    assert_operator ids[9], :<, ids[10]
  end

  test "the bottom ten break ties by card id too" do
    scores = Array.new(12, 1.0)
    draft = seed_card_seasons(scores)

    assert_equal card_ids(draft).sort.first(10), preview.bottom.map(&:card_id)
  end

  test "the preview takes two queries at any size" do
    seed_card_seasons(Array.new(15_000) { |index| (index * 7919 % 15_000).to_f },
      genres: Array.new(15_000) { |index| [ %w[action rpg indie][index % 3] ] })

    result = nil
    assert_queries_count(2) { result = preview }

    assert_equal 15_000, result.card_count
    assert_equal 10, result.top.count { |entry| entry.title.present? }
  end

  test "publishing the 150-card draft gives the tier sizes and set counts the preview showed" do
    draft = seed_sets_draft
    expected = preview

    assert Catalog::PublishSeason.new.call(number: draft.number).success?

    summary = Catalog::SeasonSummaries.call.find { |season| season.number == draft.number }
    assert_equal expected.tiers.to_h { |tier| [ tier.tier, tier.card_count ] }, summary.tier_counts
    assert_equal expected.set_counts, summary.set_counts
  end
end
