require "test_helper"

# The cards step of an import run (epic 2, R4, R5): the prestige score, the
# mapping of a ready game onto Catalog::UpsertDraftCard, and the pages that
# write the cards into the draft season.
class Steam::CardsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include Dry::Monads[:result]

  def events_of(run)
    Rails.configuration.event_store.read.stream(Steam::ImportRun.stream_name(run.id)).to_a
  end

  def run_on(step, last_appid: 0, counts: {})
    Steam::ImportRun.create!(status: :running, step: step, cursor: { "step" => step, "last_appid" => last_appid },
      counts: { "apps_listed" => 0 }.merge(counts), started_at: 1.minute.ago)
  end

  # Apps carried by `run` through every step, each with every card field.
  def ready(run, *appids, **overrides)
    Steam::App.insert_all(appids.map do |appid|
      { appid: appid, name: "Game #{appid}", import_run_id: run.id, reviewed_run_id: run.id, details_run_id: run.id,
        review_count: 1_000 + appid, review_percent_positive: 90,
        name_en: "Game #{appid}", name_fr: "Jeu #{appid}", short_description_en: "The game #{appid}.", short_description_fr: "Le jeu #{appid}.",
        publishers: [ "Publisher #{appid}", "Other" ], release_on: Date.new(2011, 4, 19), tag_ids: [ 492, 1664, 19, 122 ],
        store_url_path: "app/#{appid}/Game_#{appid}/", image_url: "https://example.test/#{appid}.jpg" }.merge(overrides)
    end)
  end

  # A new run on the cards step, the previous one completed, carrying the
  # apps already listed through every step.
  def rerun(appids)
    Steam::ImportRun.active.update_all(status: "completed", finished_at: Time.current)
    run = run_on("cards")
    Steam::App.where(appid: appids).update_all(import_run_id: run.id, reviewed_run_id: run.id, details_run_id: run.id)
    run
  end

  def name_tags
    Steam::Tag.insert_all([ { tagid: 19, name: "Action" }, { tagid: 492, name: "Indie" } ])
  end

  def cards_page(run, **options)
    Steam::ImportCardsPage.new(**options).call(import_run_id: run.id, cursor: run.reload.cursor)
  end

  def card_of(appid)
    Catalog::Card.find_by!(source_key: "steam:#{appid}")
  end

  def draft
    Catalog::DraftSeason.call
  end

  # The cards this step wrote, not the fixtures'.
  def steam_cards
    Catalog::Card.where("source_key LIKE 'steam:%'")
  end

  # PrestigeScore

  def score(percent, count)
    Steam::PrestigeScore.call(percent_positive: percent, review_count: count)
  end

  test "the prestige score lets popularity lead and acclaim separate" do
    assert_in_delta 6.739, score(95, 1_000), 0.0005
    assert_in_delta 6.927, score(99, 1_000), 0.0005
    assert_in_delta 2.699, score(0, 500), 0.0005
    assert_in_delta 9.654, score(87, 1_500_000), 0.0005
    assert_in_delta 7.602, score(98, 5_000), 0.0005
    assert_operator score(98, 5_000), :<, score(87, 1_500_000), "a blockbuster ranks above a small acclaimed game"
    assert_operator score(95, 10_000), :<, score(92, 200_000), "twenty times the reviews outweigh three points of score"
    assert_operator score(95, 1_000), :<, score(99, 1_000), "among games known alike, the better liked ranks higher"
    assert_operator score(100, 500), :<, score(95, 10_000), "a perfect score does not lift a little-known game above a well-known, well-liked one"
  end

  test "the prestige score is strictly increasing in each input over a grid of the domain" do
    percents = (0..100).to_a
    counts = [ 1, 2, 3, 5, 10, 50, 100, 499, 500, 501, 1_000, 5_000, 10_000, 100_000, 1_000_000, 10_000_000, 100_000_000 ]

    counts.each do |count|
      percents.each_cons(2) { |low, high| assert_operator score(low, count), :<, score(high, count), "#{low} → #{high} % at #{count}" }
    end
    percents.each do |percent|
      counts.each_cons(2) { |low, high| assert_operator score(percent, low), :<, score(percent, high), "#{low} → #{high} reviews at #{percent} %" }
    end
  end

  test "the prestige score refuses anything outside its domain" do
    [ [ nil, 10 ], [ 50, nil ], [ -1, 10 ], [ 101, 10 ], [ 50.0, 10 ], [ "50", 10 ], [ 50, 0 ], [ 50, -3 ], [ 50, 10.0 ] ].each do |percent, count|
      assert_raises(ArgumentError, "#{percent.inspect}, #{count.inspect}") { score(percent, count) }
    end
  end

  # CardMapping

  test "a ready game maps onto the card keywords with plain Ruby values" do
    run = run_on("cards")
    ready(run, 620, review_percent_positive: 95, review_count: 1_000, store_url_path: "/app/620/Portal_2/",
      tag_ids: [ 1, 492, 1664, 2, 3, 19, 4, 122 ])
    tag_names = { 492 => "Indie", 2 => "!!!", 3 => "Co-op", 19 => "Action", 4 => "Co op" }

    attributes = Steam::CardMapping.call(Steam::App.find_by!(appid: 620), tag_names: tag_names).value!

    assert_equal({
      source_key: "steam:620",
      texts: { "en" => { title: "Game 620", short_description: "The game 620." }, "fr" => { title: "Jeu 620", short_description: "Le jeu 620." } },
      release_date: Date.new(2011, 4, 19),
      image_url: "https://example.test/620.jpg",
      store_url: "https://store.steampowered.com/app/620/Portal_2/",
      publisher: "Publisher 620",
      genres: %w[puzzle rpg],
      tags: %w[indie co_op action],
      prestige_score: Steam::PrestigeScore.call(percent_positive: 95, review_count: 1_000),
      rating: 95
    }, attributes)

    plain = [ String, Date, Integer, Float, Array, Hash, NilClass ]
    walk = ->(value) do
      assert(plain.any? { |klass| value.instance_of?(klass) }, "#{value.inspect} is a #{value.class}")
      value.each { |item| walk.(item) } if value.is_a?(Array)
      value.each_value { |item| walk.(item) } if value.is_a?(Hash)
    end
    attributes.each_value { |value| walk.(value) }
    assert_instance_of Float, attributes[:prestige_score]
    assert_instance_of Integer, attributes[:rating]
  end

  test "a blank store path falls back to the app's page; no publisher maps to nil" do
    run = run_on("cards")
    ready(run, 7, store_url_path: nil, publishers: [])

    attributes = Steam::CardMapping.call(Steam::App.find_by!(appid: 7), tag_names: {}).value!

    assert_equal "https://store.steampowered.com/app/7/", attributes[:store_url]
    assert_nil attributes[:publisher]
    assert_equal [], attributes[:tags]
  end

  test "a game without a review score or count is refused" do
    run = run_on("cards")
    ready(run, 1, review_percent_positive: nil)
    ready(run, 2, review_count: nil)

    Steam::App.where(appid: [ 1, 2 ]).find_each do |app|
      assert_equal :no_reviews, Steam::CardMapping.call(app, tag_names: {}).failure
    end
  end

  test "a game whose stored review values are out of range is refused with invalid_reviews, never raising" do
    run = run_on("cards")
    ready(run, 1, review_percent_positive: 150)
    ready(run, 2, review_percent_positive: -1)
    ready(run, 3, review_count: 0)
    ready(run, 4, review_count: -5)

    Steam::App.where(appid: [ 1, 2, 3, 4 ]).find_each do |app|
      assert_equal :invalid_reviews, Steam::CardMapping.call(app, tag_names: {}).failure, app.appid
    end
  end

  # ImportCardsPage

  test "a cards page writes each ready game into the draft season with every field, its prestige score and its rating" do
    run = run_on("cards", counts: { "cards_written" => 4, "cards_refused" => 1 })
    ready(run, 10, 20, 30)
    name_tags

    result = cards_page(run)

    assert result.success?
    assert_equal 3, draft.card_seasons.count
    card = card_of(20)
    assert_equal [ Date.new(2011, 4, 19), "https://example.test/20.jpg", "https://store.steampowered.com/app/20/Game_20/" ],
      [ card.release_date, card.image_url, card.store_url ]
    assert_equal [ "Publisher 20", %w[puzzle rpg], %w[indie action] ], [ card.publisher, card.genres, card.tags ]
    assert_equal({ "en" => [ "Game 20", "The game 20." ], "fr" => [ "Jeu 20", "Le jeu 20." ] },
      card.texts.to_h { |text| [ text.locale, [ text.title, text.short_description ] ] })
    card_season = card.card_seasons.sole
    assert_equal draft, card_season.season
    assert_in_delta Steam::PrestigeScore.call(percent_positive: 90, review_count: 1_020), card_season.prestige_score
    assert_equal BigDecimal("90"), card_season.rating

    run.reload
    assert_predicate run, :running?
    assert_equal({ "step" => "cards", "last_appid" => 30 }, run.cursor)
    assert_equal [ 7, 1 ], [ run.cards_written, run.cards_refused ]
    assert_equal [ Steam::CardsPageImported ], events_of(run).map(&:class)
    assert_equal({ import_run_id: run.id, last_appid: 30 }, events_of(run).first.data)
    assert_equal 3, Rails.configuration.event_store.read.stream(Catalog::Season.stream_name(draft.id)).of_type(Catalog::DraftCardUpserted).count
  end

  test "a cards page takes the next ready games after the cursor, never one the run did not carry through" do
    run = run_on("cards", last_appid: 2)
    ready(run, *(1..8).to_a)
    Steam::App.where(appid: 4).update_all(details_exclusion: "no_vertical_image")

    cards_page(run, page_size: 3)

    assert_equal %w[steam:3 steam:5 steam:6], steam_cards.order(:source_key).pluck(:source_key)
    assert_equal 6, run.reload.last_appid
  end

  test "a second run with changed scores updates the same cards and their draft card-seasons in place" do
    first = run_on("cards")
    ready(first, 10, 20, 30)
    cards_page(first)
    ids = draft.card_seasons.order(:id).pluck(:id)
    counts = [ Catalog::Card.count, Catalog::CardText.count, Catalog::CardSeason.count ]

    Steam::App.update_all(review_percent_positive: 70, review_count: 50_000)
    Steam::App.where(appid: 20).update_all(name_en: "Renamed")
    second = rerun([ 10, 20, 30 ])
    cards_page(second)

    assert_equal counts, [ Catalog::Card.count, Catalog::CardText.count, Catalog::CardSeason.count ]
    assert_equal ids, draft.card_seasons.order(:id).pluck(:id)
    assert_equal [ BigDecimal("70") ] * 3, draft.card_seasons.pluck(:rating)
    assert_in_delta Steam::PrestigeScore.call(percent_positive: 70, review_count: 50_000), card_of(10).card_seasons.sole.prestige_score
    assert_equal "Renamed", card_of(20).texts.find_by!(locale: "en").title
    assert_equal "game-20", card_of(20).slug
  end

  test "once a season is published with these cards, a new run updates the cards and gives the new draft its card-seasons" do
    first = run_on("cards")
    ready(first, 10, 20)
    cards_page(first)
    published = draft
    Catalog::CardSeason.where(season: published).update_all(rarity: 1)
    published.update_columns(status: "published", published_at: Time.current)
    frozen = Catalog::CardSeason.where(season: published).order(:id).pluck(:id, :prestige_score, :rating, :updated_at)

    Steam::App.update_all(review_percent_positive: 50, name_fr: "Nouveau")
    second = rerun([ 10, 20 ])
    cards_page(second)

    assert_not_equal published, draft
    assert_equal frozen, Catalog::CardSeason.where(season: published).order(:id).pluck(:id, :prestige_score, :rating, :updated_at)
    assert_equal 2, draft.card_seasons.count
    assert_equal [ BigDecimal("50") ] * 2, draft.card_seasons.pluck(:rating)
    assert_equal 2, steam_cards.count
    assert_equal [ "Nouveau" ] * 2, Catalog::CardText.where(locale: "fr", card: steam_cards).pluck(:title)
  end

  test "a card the upsert refuses after writing is rolled back with its event; the others are written and the refusal recorded" do
    run = run_on("cards")
    ready(run, 10, 20, 30)
    real = Catalog::UpsertDraftCard.new
    refused = Failure(:invalid_card)
    upsert = Object.new
    upsert.define_singleton_method(:call) do |**attributes|
      result = real.call(**attributes)
      attributes[:source_key] == "steam:20" ? refused : result
    end

    assert cards_page(run, upsert: upsert).success?

    assert_equal %w[steam:10 steam:30], steam_cards.order(:source_key).pluck(:source_key)
    assert_equal 2, Catalog::CardSeason.where(season: draft).count
    assert_equal 2, Rails.configuration.event_store.read.of_type(Catalog::DraftCardUpserted).count
    run.reload
    assert_equal [ 2, 1 ], [ run.cards_written, run.cards_refused ]
    assert_equal [ "appid 20: invalid_card" ], run.latest_errors.map(&:message)
    assert_equal 30, run.last_appid
    assert_predicate run, :running?
  end

  test "a game without a review score is refused without calling Catalog, and the page goes on" do
    run = run_on("cards")
    ready(run, 10, 20)
    Steam::App.where(appid: 10).update_all(review_percent_positive: nil)
    called = []
    real = Catalog::UpsertDraftCard.new
    upsert = Object.new
    upsert.define_singleton_method(:call) do |**attributes|
      called << attributes[:source_key]
      real.call(**attributes)
    end

    cards_page(run, upsert: upsert)

    assert_equal [ "steam:20" ], called
    run.reload
    assert_equal [ 1, 1 ], [ run.cards_written, run.cards_refused ]
    assert_equal [ "appid 10: no_reviews" ], run.latest_errors.map(&:message)
    assert_equal 20, run.last_appid
  end

  test "a game Catalog refuses for a missing text is refused, its page goes on" do
    run = run_on("cards")
    ready(run, 10, 20)
    Steam::App.where(appid: 20).update_all(name_fr: nil)

    cards_page(run)

    assert_equal [ "steam:10" ], steam_cards.pluck(:source_key)
    assert_equal [ "appid 20: missing_text" ], run.reload.latest_errors.map(&:message)
  end

  test "an exception in a card rolls the whole page back" do
    run = run_on("cards")
    ready(run, 10, 20)
    real = Catalog::UpsertDraftCard.new
    upsert = Object.new
    upsert.define_singleton_method(:call) do |**attributes|
      raise "boom" if attributes[:source_key] == "steam:20"

      real.call(**attributes)
    end

    assert_raises(RuntimeError) { cards_page(run, upsert: upsert) }

    assert_empty steam_cards
    assert_nil draft
    run.reload
    assert_equal [ 0, 0, 0 ], [ run.last_appid, run.cards_written, run.cards_refused ]
    assert_empty events_of(run)
  end

  test "25 refusals keep the last 20 errors and count 25" do
    run = run_on("cards")
    ready(run, *(1..25).to_a, review_count: nil)

    cards_page(run)

    run.reload
    assert_equal 25, run.cards_refused
    assert_equal Steam::ImportRun::ERROR_LIMIT, run.error_messages.size
    assert_equal (6..25).map { |appid| "appid #{appid}: no_reviews" }, run.error_messages.map { |error| error["message"] }
  end

  test "a cards page marks the apps whose card it wrote with the run, not the refused ones" do
    run = run_on("cards")
    ready(run, 10, 20, 30)
    Steam::App.where(appid: 20).update_all(review_percent_positive: 150)

    cards_page(run)

    assert_equal [ 10, 30 ], Steam::App.carded_by(run).order(:appid).pluck(:appid)
    assert_equal [ "appid 20: invalid_reviews" ], run.reload.latest_errors.map(&:message)
    assert_equal [ 2, 1 ], [ run.cards_written, run.cards_refused ]
  end

  def card_scores
    Catalog::CardSeason.where(season: draft).joins(:card).order("catalog_cards.source_key").pluck("catalog_cards.source_key", :prestige_score).to_h
  end

  test "the database refuses a card mark for a run that does not exist" do
    run = run_on("cards")
    ready(run, 10)

    assert_raises(ActiveRecord::InvalidForeignKey) { Steam::App.where(appid: 10).update_all(carded_run_id: -1) }
  end

  test "the end of a pass keeps in the draft only the cards it wrote: an earlier run's other cards leave it, their card rows stay" do
    first = run_on("cards")
    ready(first, 10, 20)
    cards_page(first)
    cards_page(first)
    assert_predicate first.reload, :completed?
    assert_equal 0, first.cards_removed

    Steam::App.update_all(review_percent_positive: 70)
    ready(first, 30)
    second = rerun([ 20, 30 ])
    cards_page(second)
    assert_equal %w[steam:10 steam:20 steam:30], card_scores.keys, "nothing is pruned in the middle of a pass"

    assert cards_page(second).success?

    second.reload
    assert_predicate second, :completed?
    assert_equal [ 2, 0, 1 ], [ second.cards_written, second.cards_refused, second.cards_removed ]
    assert_equal %w[steam:20 steam:30], card_scores.keys
    assert_in_delta Steam::PrestigeScore.call(percent_positive: 70, review_count: 1_020), card_scores["steam:20"]
    assert_predicate card_of(10), :present?
    pruned = Rails.configuration.event_store.read.stream(Catalog::Season.stream_name(draft.id)).of_type(Catalog::DraftPruned).to_a
    assert_equal [ { season_id: draft.id, removed: 0 }, { season_id: draft.id, removed: 1 } ], pruned.map(&:data)
    assert_equal [ Steam::CardsPageImported, Steam::ImportStepFinished, Steam::ImportRunFinished ], events_of(second).map(&:class)
  end

  test "a pass over several pages, failed then resumed, keeps every card it wrote and removes only an earlier run's other card" do
    other = run_on("cards")
    ready(other, 40)
    cards_page(other)
    other.update!(status: :completed, finished_at: Time.current)
    run = run_on("cards")
    ready(run, 10, 20, 30)

    cards_page(run, page_size: 2)
    assert Steam::FailImport.new.call(import_run_id: run.id, error: "Steam::WebApi::Error: boom").success?
    assert Steam::ResumeImport.new.call(import_run_id: run.id).success?
    3.times { cards_page(run, page_size: 2) unless run.reload.completed? }

    run.reload
    assert_predicate run, :completed?
    assert_equal %w[steam:10 steam:20 steam:30], card_scores.keys
    assert_equal [ 3, 1 ], [ run.cards_written, run.cards_removed ]
    assert_predicate card_of(40), :present?
  end

  test "the end of a pass never touches a published season" do
    first = run_on("cards")
    ready(first, 10, 20)
    cards_page(first)
    published = draft
    Catalog::CardSeason.where(season: published).update_all(rarity: 1)
    published.update_columns(status: "published", published_at: Time.current)
    first.update!(status: :completed, finished_at: Time.current)
    frozen = Catalog::CardSeason.where(season: published).order(:id).pluck(:id, :prestige_score, :rarity)

    second = rerun([ 20 ])
    cards_page(second)
    cards_page(second)

    assert_equal frozen, Catalog::CardSeason.where(season: published).order(:id).pluck(:id, :prestige_score, :rarity)
    assert_equal %w[steam:20], card_scores.keys
    assert_equal 0, second.reload.cards_removed
  end

  test "a pass that wrote no card empties the draft" do
    first = run_on("cards")
    ready(first, 10, 20)
    cards_page(first)
    cards_page(first)
    Steam::App.update_all(review_count: nil)
    second = rerun([ 10, 20 ])

    cards_page(second)
    cards_page(second)

    second.reload
    assert_predicate second, :completed?
    assert_equal [ 0, 2, 2 ], [ second.cards_written, second.cards_refused, second.cards_removed ]
    assert_empty card_scores
    assert_equal :empty_season, Catalog::PublishSeason.new.call(number: draft.number).failure
  end

  test "an exception in the prune rolls the end of the pass back" do
    run = run_on("cards", last_appid: 10)
    prune = Object.new
    prune.define_singleton_method(:call) { |**| raise "boom" }

    assert_raises(RuntimeError) { cards_page(run, prune: prune) }

    run.reload
    assert_predicate run, :running?
    assert_equal [ "cards", 10 ], [ run.step, run.last_appid ]
    assert_empty events_of(run)
  end

  test "with no ready game after the cursor, the cards step completes the run" do
    run = run_on("cards", last_appid: 10)
    ready(run, 10)

    assert cards_page(run).success?

    run.reload
    assert_predicate run, :completed?
    assert_equal "cards", run.step
    assert_equal [ Steam::ImportStepFinished, Steam::ImportRunFinished ], events_of(run).map(&:class)
  end

  test "a stale details job once the run is on the cards does nothing" do
    run = run_on("cards")
    ready(run, 10)

    result = Steam::ImportCardsPage.new.call(import_run_id: run.id, cursor: { "step" => "details", "last_appid" => 0 })

    assert_equal :cursor_moved, result.failure
    assert_empty steam_cards
  end

  test "a cards page whose cursor moved before it locked the run writes nothing" do
    run = run_on("cards")
    ready(run, 10)
    page = Steam::ImportCardsPage.new
    page.define_singleton_method(:lock_run) do |import_run_id|
      Steam::ImportRun.where(id: import_run_id).update_all(cursor: { "step" => "cards", "last_appid" => 10 })
      super(import_run_id)
    end

    assert_equal :cursor_moved, page.call(import_run_id: run.id, cursor: run.cursor).failure
    assert_empty steam_cards
    assert_empty events_of(run)
  end

  test "a cards page for a run on another step, unknown, or not running fails" do
    assert_equal :not_running, Steam::ImportCardsPage.new.call(import_run_id: run_on("details").id).failure
    assert_equal :not_found, Steam::ImportCardsPage.new.call(import_run_id: -1).failure
    assert_equal :not_running, Steam::ImportCardsPage.new.call(import_run_id: Steam::ImportRun.create!(status: :failed, step: "cards").id).failure
  end

  # The job

  test "an exception in a card is retried by the job, then fails the run at its cursor" do
    run = run_on("cards")
    ready(run, 10)
    # Not `call`: dry-operation wraps every method named `call` it sees defined.
    Catalog::UpsertDraftCard.class_eval do
      alias_method :draft_season_without_boom, :draft_season
      define_method(:draft_season) { raise "boom" }
    end
    begin
      perform_enqueued_jobs { Steam::ImportStepJob.perform_later(run.id, run.cursor) }
    ensure
      Catalog::UpsertDraftCard.class_eval do
        alias_method :draft_season, :draft_season_without_boom
        remove_method :draft_season_without_boom
      end
    end

    run.reload
    assert_predicate run, :failed?
    assert_equal({ "step" => "cards", "last_appid" => 0 }, run.cursor)
    assert_includes run.latest_errors.first.message, "RuntimeError: boom"
    assert_empty steam_cards
  end

  test "the details step hands over to the cards, whose last page completes the run" do
    run = run_on("details", last_appid: 10)
    ready(run, 10)

    perform_enqueued_jobs { Steam::ImportStepJob.perform_later(run.id, run.cursor) }

    run.reload
    assert_predicate run, :completed?
    assert_equal "cards", run.step
    assert_equal 1, run.cards_written
    assert_predicate card_of(10), :present?
  end

  # ImportRun#append_errors

  test "errors are appended stamped and cut, the latest ERROR_LIMIT kept" do
    run = run_on("cards")
    run.update!(error_messages: Array.new(19) { |index| { "at" => "2026-01-01T00:00:00Z", "message" => "old #{index}" } })

    run.append_errors([ "x" * 600, "new" ], at: Time.utc(2026, 10, 2, 12))

    assert_equal 20, run.error_messages.size
    assert_equal "old 1", run.error_messages.first["message"]
    assert_equal 500, run.error_messages[-2]["message"].length
    assert_equal({ "at" => "2026-10-02T12:00:00Z", "message" => "new" }, run.error_messages.last)
  end
end
