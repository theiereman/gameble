require "test_helper"
require_relative "../../support/catalog_seeds"

# The staged batch of a season's card-seasons: staged beside the draft,
# promoted into it in one step or discarded, and reviewed before.
class Catalog::StagedBatchTest < ActiveSupport::TestCase
  include CatalogSeeds

  TOKEN = "batch-one".freeze

  def attributes(**overrides)
    {
      source_key: "src:620", publisher: "Valve", release_date: Date.new(2011, 4, 18), genres: %w[puzzle], tags: %w[puzzle],
      developers: [ "Valve" ], franchises: [ "Portal" ], image_url: "https://images.example.test/620.jpg",
      store_url: "https://store.example.test/620",
      texts: { "en" => { title: "Portal 2", short_description: "The sequel." }, "fr" => { title: "Portal 2" } }
    }.merge(overrides)
  end

  def identity(**overrides)
    Catalog::UpsertCardIdentity.new.call(**attributes(**overrides))
  end

  def stage(card, token: TOKEN, score: 0.5, **overrides)
    Catalog::StageCardSeason.new.call(batch_token: token, card_id: card.id, prestige_score: score, prestige_score_version: 2, rating: 90.0,
      review_count: 1_000, **overrides)
  end

  def promote(token: TOKEN, season_number: Catalog::DraftSeasonNumber.call)
    Catalog::PromoteStagedBatch.new.call(batch_token: token, season_number:)
  end

  def events(token = TOKEN)
    Rails.configuration.event_store.read.stream(Catalog::StagedCardSeason.stream_name(token)).to_a
  end

  # UpsertCardIdentity

  test "a card's identity is written without any season and updated in place the second time" do
    card = identity.value!

    assert_equal [ "src:620", "portal-2" ], [ card.source_key, card.slug ]
    assert_equal({ "en" => "Portal 2", "fr" => "Portal 2" }, card.texts.to_h { |text| [ text.locale, text.title ] })
    assert_equal [ 0, 0 ], [ Catalog::Season.where(number: 10_000..).count, card.card_seasons.count ]
    assert_nil Catalog::DraftSeason.call

    again = identity(publisher: "EA", texts: { "en" => { title: "Portal Two" }, "fr" => { title: "Portal 2" } }).value!

    assert_equal card, again
    assert_equal [ "EA", "portal-2" ], [ again.reload.publisher, again.slug ]
    assert_equal "Portal Two", again.text("en").title
    assert_equal [ Catalog::CardIdentityUpserted ] * 2, Rails.configuration.event_store.read.stream("Catalog::Card$#{card.id}").map(&:class)
  end

  test "an identity with a missing text or an unknown genre is refused and writes nothing" do
    assert_equal :missing_text, identity(texts: { "en" => { title: "Portal 2" } }).failure
    assert_equal :invalid_card, identity(genres: %w[not_a_theme]).failure
    assert_equal :invalid_card, identity(image_url: "").failure
    assert_nil Catalog::Card.find_by(source_key: "src:620")
  end

  # StageCardSeason

  test "staging a card's scores writes a row of the batch, replaces it the second time and leaves the draft alone" do
    draft = seed_card_seasons([ 0.1 ])
    card = identity.value!

    staged = stage(card).value!

    assert_equal [ TOKEN, card.id, 0.5, 2, BigDecimal("90"), 1_000 ], staged.attributes.values_at("batch_token", "card_id", "prestige_score", "prestige_score_version", "rating", "review_count")
    assert_equal 1, draft.card_seasons.count
    assert_empty card.card_seasons

    stage(card, score: 0.8, review_count: nil)

    assert_equal [ [ 0.8, nil ] ], Catalog::StagedCardSeason.where(batch_token: TOKEN).pluck(:prestige_score, :review_count)
    assert_equal [ Catalog::CardSeasonStaged ] * 2, events.map(&:class)
    assert_equal({ batch_token: TOKEN, card_id: card.id }, events.first.data)
  end

  test "staged scores that are not numbers in range are refused" do
    card = identity.value!

    [ { score: "0.5" }, { score: Float::NAN }, { rating: 101.0 }, { prestige_score_version: 0 }, { review_count: 0 }, { review_count: "5" } ].each do |overrides|
      overrides = { prestige_score: 0.5, prestige_score_version: 2, rating: 90.0, review_count: 1_000 }.merge(overrides.transform_keys { |key| key == :score ? :prestige_score : key })
      result = Catalog::StageCardSeason.new.call(batch_token: TOKEN, card_id: card.id, **overrides)

      assert_equal :invalid_card, result.failure, overrides.inspect
    end
    assert_equal :invalid_card, Catalog::StageCardSeason.new.call(batch_token: "", card_id: card.id, prestige_score: 0.5, prestige_score_version: 2, rating: 90.0).failure
    assert_empty Catalog::StagedCardSeason.all
    assert_empty events
  end

  # PromoteStagedBatch

  test "promoting replaces the draft's card-seasons with the batch in one step, deletes the batch and publishes one event" do
    draft = seed_card_seasons([ 0.1, 0.2 ])
    kept = draft.card_seasons.first.card
    lost = draft.card_seasons.where.not(card: kept).sole.card
    fresh = identity.value!
    stage(kept, score: 0.9)
    stage(fresh, score: 0.7)

    result = promote(season_number: draft.number)

    assert_equal draft, result.value!
    assert_equal({ kept.id => 0.9, fresh.id => 0.7 }, draft.card_seasons.pluck(:card_id, :prestige_score).to_h)
    assert_empty Catalog::CardSeason.where(card_id: lost.id)
    assert_predicate Catalog::Card.find(lost.id), :present?
    assert_empty Catalog::StagedCardSeason.where(batch_token: TOKEN)
    assert_equal [ Catalog::CardSeasonStaged, Catalog::CardSeasonStaged, Catalog::StagedBatchPromoted ], events.map(&:class)
    assert_equal({ batch_token: TOKEN, season_id: draft.id, promoted: 2, removed: 2 }, events.last.data)
    assert_equal [ 2, BigDecimal("90"), 1_000 ], draft.card_seasons.where(card: fresh).pick(:prestige_score_version, :rating, :review_count)
  end

  test "a promoted draft still publishes" do
    cards = Array.new(21) { |index| identity(source_key: "src:#{index}", texts: { "en" => { title: "Game #{index}" }, "fr" => { title: "Jeu #{index}" } }).value! }
    cards.each_with_index { |card, index| stage(card, score: (index + 1).to_f, review_count: 1_000 + index) }

    season = promote.value!

    assert Catalog::PublishSeason.new.call(number: season.number).success?
  end

  test "promoting into no draft creates it with the number the run saw" do
    expected = Catalog::DraftSeasonNumber.call
    stage(identity.value!)

    season = promote(season_number: expected).value!

    assert_equal [ expected, "draft" ], [ season.number, season.status ]
    assert_equal 1, season.card_seasons.count
  end

  test "promoting after the season was published is refused as stale and changes nothing" do
    draft = seed_card_seasons([ 0.1 ])
    card = identity.value!
    stage(card)
    draft.update!(status: :published, published_at: Time.current)

    assert_equal :stale_batch, promote(season_number: draft.number).failure
    assert_equal 1, Catalog::StagedCardSeason.where(batch_token: TOKEN).count
    assert_equal 1, draft.card_seasons.count

    newer = seed_card_seasons([ 0.2 ])
    assert_equal :stale_batch, promote(season_number: draft.number).failure
    assert_equal 1, newer.card_seasons.count
  end

  test "an empty batch is refused and leaves the draft alone" do
    draft = seed_card_seasons([ 0.1 ])

    assert_equal :empty_batch, promote(season_number: draft.number).failure
    assert_equal 1, draft.card_seasons.count
    assert_empty events
  end

  test "another batch is left alone by a promotion" do
    draft = seed_card_seasons([ 0.1 ])
    other = identity(source_key: "src:other", texts: { "en" => { title: "Other" }, "fr" => { title: "Autre" } }).value!
    stage(identity.value!)
    stage(other, token: "batch-two")

    promote(season_number: draft.number)

    assert_equal 1, Catalog::StagedCardSeason.where(batch_token: "batch-two").count
  end

  # DiscardStagedBatch

  test "discarding deletes the batch only, leaves the draft and publishes an event even with nothing to delete" do
    draft = seed_card_seasons([ 0.1 ])
    stage(identity.value!)
    stage(identity(source_key: "src:2", texts: { "en" => { title: "Two" }, "fr" => { title: "Deux" } }).value!, token: "batch-two")

    assert_equal 1, Catalog::DiscardStagedBatch.new.call(batch_token: TOKEN).value!
    assert_equal 0, Catalog::DiscardStagedBatch.new.call(batch_token: TOKEN).value!

    assert_equal 1, Catalog::StagedCardSeason.count
    assert_equal 1, draft.card_seasons.count
    assert_equal [ Catalog::CardSeasonStaged, Catalog::StagedBatchDiscarded, Catalog::StagedBatchDiscarded ], events.map(&:class)
  end

  # PublishSeason

  test "publishing is refused while a batch waits" do
    draft = seed_card_seasons(distinct_scores(21))
    stage(identity.value!)

    assert_equal :staged_batch_waiting, Catalog::PublishSeason.new.call(number: draft.number).failure
    assert_predicate draft.reload, :draft?

    Catalog::DiscardStagedBatch.new.call(batch_token: TOKEN)
    assert Catalog::PublishSeason.new.call(number: draft.number).success?
  end

  # StagedBatchReview

  test "the review counts the gap with the draft and previews the batch" do
    draft = seed_card_seasons([ 1.0, 2.0, 3.0 ])
    in_draft = draft.card_seasons.order(:id).map(&:card)
    stage(in_draft[0], score: 1.0)
    stage(in_draft[1], score: 5.0)
    stage(identity.value!, score: 4.0)

    review = Catalog::StagedBatchReview.call(TOKEN)

    assert_equal [ 3, 3, 1, 1, 1 ], [ review.staged_count, review.draft_count, review.added, review.removed, review.rescored ]
    assert_equal 3, review.panel.card_count
    assert_equal 3, review.draft_panel.card_count
    assert_equal 5.0, review.panel.max
  end

  test "the review of a batch with no draft has no draft panel, and an empty batch an empty panel" do
    stage(identity.value!)

    review = Catalog::StagedBatchReview.call(TOKEN)

    assert_equal [ 1, 0, 1, 0, 0 ], [ review.staged_count, review.draft_count, review.added, review.removed, review.rescored ]
    assert_nil review.draft_panel
    assert_predicate Catalog::StagedBatchReview.call("nothing").panel, :empty_season?
  end

  # DraftSeasonNumber

  test "the draft season number is the draft's, or the next season's when there is none" do
    expected = Catalog::DraftSeasonNumber.call
    assert_equal Catalog::Season.next_number, expected

    draft = seed_card_seasons([])

    assert_equal draft.number, Catalog::DraftSeasonNumber.call
  end
end
