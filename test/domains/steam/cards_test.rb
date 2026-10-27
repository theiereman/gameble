require "test_helper"

# The cards step of an import run: the prestige score, the
# mapping of a ready game onto the card keywords, and the pages that stage
# the cards beside the draft season.
class Steam::CardsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include Dry::Monads[:result]

  def events_of(run)
    Rails.configuration.event_store.read.stream(Steam::ImportRun.stream_name(run.id)).to_a
  end

  def run_on(step, last_appid: 0, counts: {})
    Steam::ImportRun.create!(status: :running, step: step, cursor: { "step" => step, "last_appid" => last_appid },
      counts: { "apps_listed" => 0, "season_number" => Catalog::DraftSeasonNumber.call }.merge(counts), started_at: 1.minute.ago)
  end

  # Apps carried by `run` through every step, each with every card field.
  def ready(run, *appids, **overrides)
    Steam::App.insert_all(appids.map do |appid|
      { appid: appid, name: "Game #{appid}", import_run_id: run.id, reviewed_run_id: run.id, details_run_id: run.id,
        review_count: 1_000 + appid, review_percent_positive: 90,
        name_en: "Game #{appid}", name_fr: "Jeu #{appid}", short_description_en: "The game #{appid}.", short_description_fr: "Le jeu #{appid}.",
        publishers: [ "Publisher #{appid}", "Other" ], release_on: Date.new(2011, 4, 19), tag_ids: [ 492, 1664, 19, 122 ],
        store_url_path: "app/#{appid}/Game_#{appid}/", image_url: "https://example.test/#{appid}.jpg",
        details: { "basic_info" => { "developers" => [ { "name" => "Studio #{appid}" } ], "franchises" => [ { "name" => "Series #{appid}" } ] } } }
        .merge(overrides)
    end)
  end

  # A new run on the cards step, the previous one promoted, carrying the
  # apps already listed through every step.
  def rerun(appids)
    Steam::ImportRun.active.update_all(status: "promoted", finished_at: Time.current)
    run = run_on("cards")
    Steam::App.where(appid: appids).update_all(import_run_id: run.id, reviewed_run_id: run.id, details_run_id: run.id)
    run
  end

  def name_tags
    Steam::Tag.insert_all([ { tagid: 19, name: "Action" }, { tagid: 492, name: "Indie" }, { tagid: 1664, name: "Puzzle" }, { tagid: 122, name: "RPG" } ])
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

  # The run's staged batch replaces the draft's cards.
  def promote_batch(run)
    Catalog::PromoteStagedBatch.new.call(batch_token: run.token, season_number: run.season_number).value!
  end

  def staged(run)
    Catalog::StagedCardSeason.where(batch_token: run.token)
  end

  def staged_scores(run)
    staged(run).joins(:card).order("catalog_cards.source_key").pluck("catalog_cards.source_key", :prestige_score).to_h
  end

  # The cards this step wrote, not the fixtures'.
  def steam_cards
    Catalog::Card.where("source_key LIKE 'steam:%'")
  end

  # PrestigeScore

  def score(percent, count)
    Steam::PrestigeScore.call(percent_positive: percent, review_count: count)
  end

  test "the prestige score ranks by review count, the positive share only ordering equal counts" do
    assert_equal [ 3, 5_000.098 ], [ Steam::PrestigeScore::VERSION, score(98, 5_000).round(3) ]
    assert_in_delta 1.0, score(0, 1), 1e-9
    assert_in_delta 1_500_000.04, score(40, 1_500_000), 1e-9
    assert_operator score(99, 5_000), :<, score(40, 1_500_000), "a much-reviewed, badly rated game ranks above a less-reviewed, well-liked one"
    assert_operator score(60, 20_000), :<, score(95, 20_000), "among games with the same count, the better liked ranks higher"
    [ 1, 2, 500, 20_000, 100_000_000 ].each do |count|
      assert_operator score(100, count), :<, score(0, count + 1), "#{count + 1} reviews at 0 % rank above #{count} at 100 %"
    end
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

  test "a published season gives the higher rarity to the more reviewed game, and to the better liked of two equal counts" do
    name_tags
    run = run_on("cards")
    ready(run, 1, review_count: 1_500_000, review_percent_positive: 40)
    ready(run, 2, review_count: 1_000_000)
    ready(run, 3, review_count: 500_000)
    ready(run, 4, review_count: 30_000, review_percent_positive: 95)
    ready(run, 5, review_count: 30_000, review_percent_positive: 60)
    (6..20).each { |appid| ready(run, appid, review_count: 30_000 - 1_000 * appid) }
    ready(run, 21, review_count: 5_000, review_percent_positive: 99)
    cards_page(run)
    season = promote_batch(run)

    result = Catalog::PublishSeason.new.call(number: season.number)
    assert result.success?, result.inspect

    rarities = Catalog::CardSeason.where(season:).joins(:card).pluck("catalog_cards.source_key", :rarity).to_h
    expected = { 1 => "legendary", 2 => "epic", 3 => "rare", 4 => "rare", 5 => "uncommon", 21 => "common" }
    expected.each { |appid, rarity| assert_equal rarity, rarities.fetch("steam:#{appid}"), "steam:#{appid}" }
    assert_equal [ "uncommon" ] * 4, (6..9).map { |appid| rarities.fetch("steam:#{appid}") }
    assert_equal [ "common" ] * 11, (10..20).map { |appid| rarities.fetch("steam:#{appid}") }
  end

  # CardMapping

  test "a ready game maps onto the card keywords with plain Ruby values" do
    run = run_on("cards")
    ready(run, 620, review_percent_positive: 95, review_count: 1_000, store_url_path: "/app/620/Portal_2/",
      tag_ids: [ 1, 492, 1664, 2, 3, 19, 4, 122 ])
    tag_names = { 492 => "Indie", 1664 => "Puzzle", 2 => "!!!", 3 => "Co-op", 19 => "Action", 4 => "Co op", 122 => "RPG" }

    attributes = Steam::CardMapping.call(Steam::App.find_by!(appid: 620), tag_names: tag_names).value!

    assert_equal({
      source_key: "steam:620",
      texts: { "en" => { title: "Game 620", short_description: "The game 620." }, "fr" => { title: "Jeu 620", short_description: "Le jeu 620." } },
      release_date: Date.new(2011, 4, 19),
      image_url: "https://example.test/620.jpg",
      store_url: "https://store.steampowered.com/app/620/Portal_2/",
      publisher: "Publisher 620",
      developers: [ "Studio 620" ],
      franchises: [ "Series 620" ],
      genres: %w[puzzle rpg],
      tags: %w[indie puzzle co_op action rpg],
      prestige_score: Steam::PrestigeScore.call(percent_positive: 95, review_count: 1_000),
      prestige_score_version: Steam::PrestigeScore::VERSION,
      rating: 95,
      review_count: 1_000
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

  test "developers and franchises map from the stored item, unescaped and once each, or to empty lists without one" do
    run = run_on("cards")
    ready(run, 7, details: { "basic_info" => { "developers" => [ { "name" => "Westwood &amp; EA" }, { "name" => " " }, { "name" => "Westwood & EA" } ] } })
    ready(run, 8, details: { "name" => "No basic info" })

    seven = Steam::CardMapping.call(Steam::App.find_by!(appid: 7), tag_names: {}).value!
    eight = Steam::CardMapping.call(Steam::App.find_by!(appid: 8), tag_names: {}).value!

    assert_equal [ [ "Westwood & EA" ], [] ], seven.values_at(:developers, :franchises)
    assert_equal [ [], [] ], eight.values_at(:developers, :franchises)
  end

  test "a detailed app maps onto a row of the card sources fill, its themes included, an invalid review count to nil" do
    run = run_on("cards")
    ready(run, 7, 8)
    Steam::App.where(appid: 8).update_all(review_count: 0)
    tag_names = { 492 => "Indie", 1664 => "Puzzle", 122 => "RPG" }

    assert_equal({ source_key: "steam:7", developers: [ "Studio 7" ], franchises: [ "Series 7" ], genres: %w[puzzle rpg], review_count: 1_007 },
      Steam::CardMapping.sources(Steam::App.find_by!(appid: 7), tag_names:))
    assert_nil Steam::CardMapping.sources(Steam::App.find_by!(appid: 8), tag_names:)[:review_count]
  end

  # The themes of a game, as named by Steam's tags, keyed by made-up tagids.
  THEME_TAGS = { 1 => "Indie", 2 => "Roguelite", 3 => "Deckbuilding", 4 => "Pixel Graphics", 5 => "Horror", 6 => "RPG",
    7 => "Action", 8 => "Adventure", 9 => "Casual", 10 => "Singleplayer" }.freeze

  def genres_of(tag_ids)
    run = run_on("cards")
    ready(run, 99, tag_ids:)
    Steam::CardMapping.call(Steam::App.find_by!(appid: 99), tag_names: THEME_TAGS).value![:genres]
  end

  test "a game's genres are the themes among its five most-voted tags, most-voted first; the sixth does not count" do
    assert_equal %w[roguelike deckbuilder horror], genres_of([ 1, 2, 3, 4, 5, 6 ])
  end

  test "a tag missing from the tag names takes no place among the five" do
    assert_equal %w[roguelike deckbuilder horror], genres_of([ 1, 404, 2, 3, 4, 5 ])
  end

  test "an unknown tagid and a key seen twice take no place among the five, as in the stored tags" do
    run = run_on("cards")
    ready(run, 99, tag_ids: [ 404, 2, 12, 4, 11, 1, 5 ])
    app = Steam::App.find_by!(appid: 99)
    tag_names = THEME_TAGS.merge(11 => "Puzzle", 12 => "Roguelite")

    mapping = Steam::CardMapping.call(app, tag_names:).value!

    assert_equal %w[roguelite pixel_graphics puzzle indie horror], mapping[:tags].first(5)
    assert_equal %w[roguelike puzzle horror], mapping[:genres]
  end

  test "a game whose five most-voted tags are broad has no genre" do
    assert_equal [], genres_of([ 7, 1, 9, 10, 4, 6 ])
  end

  test "an adventure game is in the adventure theme, even behind a broad tag" do
    assert_equal %w[adventure horror], genres_of([ 7, 8, 1, 5, 9 ])
  end

  test "a published season gives a game tagged like Dreamfall the adventure theme as main theme, out of the UFOs" do
    Steam::Tag.insert_all([ { tagid: 21, name: "Adventure" }, { tagid: 7208, name: "Female Protagonist" }, { tagid: 1742, name: "Story Rich" },
      { tagid: 1684, name: "Fantasy" }, { tagid: 3942, name: "Sci-fi" }, { tagid: 122, name: "RPG" } ])
    assert Catalog::DismissTags.new.call(tag_keys: %w[female_protagonist story_rich fantasy sci_fi]).success?
    run = run_on("cards")
    ready(run, 6300, tag_ids: [ 21, 7208, 1742, 1684, 3942 ])
    (1..20).each { |appid| ready(run, appid, review_count: 30_000 - 1_000 * appid, tag_ids: [ 122 ]) }
    cards_page(run)
    season = promote_batch(run)

    assert Catalog::PublishSeason.new.call(number: season.number).success?

    dreamfall = Catalog::CardSeason.find_by!(season:, card: card_of(6300))
    assert_equal "adventure", dreamfall.main_theme
    memberships = Catalog::SetMembership.where(card_season: dreamfall).joins(:set).pluck("catalog_sets.kind", "catalog_sets.key")
    assert_includes memberships, [ "theme", "adventure" ]
    assert_empty Catalog::Set.where(season:, kind: "ufo")
  end

  test "two tags of one theme give it once, at the first one's place" do
    assert_equal %w[rpg roguelike], Catalog::Themes.of(%w[jrpg roguelite action_rpg roguelike])
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

  test "a cards page stages each ready game's scores beside the draft and writes its identity, leaving the draft alone" do
    run = run_on("cards", counts: { "cards_written" => 4, "cards_refused" => 1 })
    ready(run, 10, 20, 30)
    name_tags

    result = cards_page(run)

    assert result.success?
    assert_nil draft
    assert_equal 3, staged(run).count
    card = card_of(20)
    assert_equal [ Date.new(2011, 4, 19), "https://example.test/20.jpg", "https://store.steampowered.com/app/20/Game_20/" ],
      [ card.release_date, card.image_url, card.store_url ]
    assert_equal [ "Publisher 20", %w[puzzle rpg], %w[indie puzzle action rpg] ], [ card.publisher, card.genres, card.tags ]
    assert_equal [ [ "Studio 20" ], [ "Series 20" ] ], [ card.developers, card.franchises ]
    assert_equal({ "en" => [ "Game 20", "The game 20." ], "fr" => [ "Jeu 20", "Le jeu 20." ] },
      card.texts.to_h { |text| [ text.locale, [ text.title, text.short_description ] ] })
    assert_empty card.card_seasons
    row = staged(run).find_by!(card:)
    assert_in_delta Steam::PrestigeScore.call(percent_positive: 90, review_count: 1_020), row.prestige_score
    assert_equal Steam::PrestigeScore::VERSION, row.prestige_score_version
    assert_equal BigDecimal("90"), row.rating
    assert_equal 1_020, row.review_count

    run.reload
    assert_predicate run, :running?
    assert_equal({ "step" => "cards", "last_appid" => 30 }, run.cursor)
    assert_equal [ 7, 1 ], [ run.cards_written, run.cards_refused ]
    assert_equal [ Steam::CardsPageImported ], events_of(run).map(&:class)
    assert_equal({ import_run_id: run.id, last_appid: 30 }, events_of(run).first.data)
    assert_equal 3, Rails.configuration.event_store.read.stream(Catalog::StagedCardSeason.stream_name(run.token)).of_type(Catalog::CardSeasonStaged).count
  end

  test "a cards page takes the next ready games after the cursor, never one the run did not carry through" do
    run = run_on("cards", last_appid: 2)
    ready(run, *(1..8).to_a)
    Steam::App.where(appid: 4).update_all(details_exclusion: "no_vertical_image")

    cards_page(run, page_size: 3)

    assert_equal %w[steam:3 steam:5 steam:6], steam_cards.order(:source_key).pluck(:source_key)
    assert_equal 6, run.reload.last_appid
  end

  test "a second run with changed scores stages new scores for the same cards; the draft changes only when it is promoted" do
    first = run_on("cards")
    ready(first, 10, 20, 30)
    cards_page(first)
    promote_batch(first)
    ids = draft.card_seasons.order(:card_id).pluck(:card_id)
    counts = [ Catalog::Card.count, Catalog::CardText.count ]
    before = draft.card_seasons.order(:card_id).pluck(:card_id, :prestige_score, :rating)

    Steam::App.update_all(review_percent_positive: 70, review_count: 50_000)
    Steam::App.where(appid: 20).update_all(name_en: "Renamed")
    second = rerun([ 10, 20, 30 ])
    cards_page(second)

    assert_equal counts, [ Catalog::Card.count, Catalog::CardText.count ]
    assert_equal before, draft.card_seasons.order(:card_id).pluck(:card_id, :prestige_score, :rating)
    assert_equal "Renamed", card_of(20).texts.find_by!(locale: "en").title
    assert_equal "game-20", card_of(20).slug

    promote_batch(second)

    assert_equal ids, draft.card_seasons.order(:card_id).pluck(:card_id)
    assert_equal [ BigDecimal("70") ] * 3, draft.card_seasons.pluck(:rating)
    assert_in_delta Steam::PrestigeScore.call(percent_positive: 70, review_count: 50_000), card_of(10).card_seasons.sole.prestige_score
  end

  test "once a season is published with these cards, a new run updates the cards and gives the new draft its card-seasons when promoted" do
    first = run_on("cards")
    ready(first, 10, 20)
    cards_page(first)
    published = promote_batch(first)
    Catalog::CardSeason.where(season: published).update_all(rarity: 1)
    published.update_columns(status: "published", published_at: Time.current)
    frozen = Catalog::CardSeason.where(season: published).order(:id).pluck(:id, :prestige_score, :rating, :review_count, :updated_at)

    Steam::App.update_all(review_percent_positive: 50, review_count: 7_000, name_fr: "Nouveau",
      details: { "basic_info" => { "developers" => [ { "name" => "New Studio" } ], "franchises" => [] } })
    second = rerun([ 10, 20 ])
    cards_page(second)

    assert_nil draft
    promote_batch(second)

    assert_not_equal published, draft
    assert_equal frozen, Catalog::CardSeason.where(season: published).order(:id).pluck(:id, :prestige_score, :rating, :review_count, :updated_at)
    assert_equal [ 1_010, 1_020 ], frozen.map { |row| row[3] }
    assert_equal 2, draft.card_seasons.count
    assert_equal [ BigDecimal("50") ] * 2, draft.card_seasons.pluck(:rating)
    assert_equal [ 7_000 ] * 2, draft.card_seasons.pluck(:review_count)
    assert_equal [ [ [ "New Studio" ], [] ] ] * 2, steam_cards.pluck(:developers, :franchises)
    assert_equal 2, steam_cards.count
    assert_equal [ "Nouveau" ] * 2, Catalog::CardText.where(locale: "fr", card: steam_cards).pluck(:title)
  end

  test "a card the staging refuses after its identity is written is rolled back with its event; the others are staged and the refusal recorded" do
    run = run_on("cards")
    ready(run, 10, 20, 30)
    real = Catalog::StageCardSeason.new
    refused = Failure(:invalid_card)
    stage = Object.new
    stage.define_singleton_method(:call) do |**attributes|
      result = real.call(**attributes)
      Catalog::Card.find(attributes[:card_id]).source_key == "steam:20" ? refused : result
    end

    assert cards_page(run, stage: stage).success?

    assert_equal %w[steam:10 steam:30], steam_cards.order(:source_key).pluck(:source_key)
    assert_equal %w[steam:10 steam:30], staged_scores(run).keys
    assert_equal 2, Rails.configuration.event_store.read.of_type(Catalog::CardIdentityUpserted).count
    assert_equal 2, Rails.configuration.event_store.read.of_type(Catalog::CardSeasonStaged).count
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
    real = Catalog::UpsertCardIdentity.new
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
    real = Catalog::UpsertCardIdentity.new
    upsert = Object.new
    upsert.define_singleton_method(:call) do |**attributes|
      raise "boom" if attributes[:source_key] == "steam:20"

      real.call(**attributes)
    end

    assert_raises(RuntimeError) { cards_page(run, upsert: upsert) }

    assert_empty steam_cards
    assert_empty staged(run)
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

  test "a refused game is not staged, and the others are" do
    run = run_on("cards")
    ready(run, 10, 20, 30)
    Steam::App.where(appid: 20).update_all(review_percent_positive: 150)

    cards_page(run)

    assert_equal %w[steam:10 steam:30], staged_scores(run).keys
    assert_equal [ "appid 20: invalid_reviews" ], run.reload.latest_errors.map(&:message)
    assert_equal [ 2, 1 ], [ run.cards_written, run.cards_refused ]
  end

  test "the end of a pass leaves the draft as it was and readies the run: its batch waits for promotion" do
    first = run_on("cards")
    ready(first, 10, 20)
    cards_page(first)
    promote_batch(first)
    first.update!(status: :promoted)
    before = draft.card_seasons.order(:card_id).pluck(:card_id, :prestige_score)

    Steam::App.update_all(review_percent_positive: 70)
    ready(first, 30)
    second = rerun([ 20, 30 ])
    cards_page(second)
    assert_equal before, draft.card_seasons.order(:card_id).pluck(:card_id, :prestige_score)

    assert cards_page(second).success?

    second.reload
    assert_predicate second, :ready?
    assert_equal [ 2, 0 ], [ second.cards_written, second.cards_refused ]
    assert_equal before, draft.card_seasons.order(:card_id).pluck(:card_id, :prestige_score)
    assert_equal %w[steam:20 steam:30], staged_scores(second).keys
    assert_in_delta Steam::PrestigeScore.call(percent_positive: 70, review_count: 1_020), staged_scores(second)["steam:20"]
    assert_equal [ Steam::CardsPageImported, Steam::ImportStepFinished, Steam::ImportRunFinished ], events_of(second).map(&:class)
  end

  test "a pass over several pages, failed then resumed, keeps every card it staged" do
    run = run_on("cards")
    ready(run, 10, 20, 30)

    cards_page(run, page_size: 2)
    assert Steam::FailImport.new.call(import_run_id: run.id, error: "Steam::WebApi::Error: boom").success?
    assert_equal %w[steam:10 steam:20], staged_scores(run).keys
    assert Steam::ResumeImport.new.call(import_run_id: run.id).success?
    3.times { cards_page(run, page_size: 2) unless run.reload.ready? }

    run.reload
    assert_predicate run, :ready?
    assert_equal %w[steam:10 steam:20 steam:30], staged_scores(run).keys
    assert_equal 3, run.cards_written
    assert_nil draft
  end

  test "a failed pass leaves the draft exactly as it was" do
    first = run_on("cards")
    ready(first, 10, 20)
    cards_page(first)
    promote_batch(first)
    first.update!(status: :promoted)
    before = draft.card_seasons.order(:card_id).pluck(:card_id, :prestige_score, :rating)

    Steam::App.update_all(review_percent_positive: 70)
    second = rerun([ 10, 20 ])
    cards_page(second)
    assert Steam::FailImport.new.call(import_run_id: second.id, error: "Steam::WebApi::Error: boom").success?

    assert_equal before, draft.card_seasons.order(:card_id).pluck(:card_id, :prestige_score, :rating)
  end

  test "the end of a pass never touches a published season" do
    first = run_on("cards")
    ready(first, 10, 20)
    cards_page(first)
    published = promote_batch(first)
    Catalog::CardSeason.where(season: published).update_all(rarity: 1)
    published.update_columns(status: "published", published_at: Time.current)
    first.update!(status: :promoted, finished_at: Time.current)
    frozen = Catalog::CardSeason.where(season: published).order(:id).pluck(:id, :prestige_score, :rarity)

    second = rerun([ 20 ])
    cards_page(second)
    cards_page(second)

    assert_equal frozen, Catalog::CardSeason.where(season: published).order(:id).pluck(:id, :prestige_score, :rarity)
    assert_equal %w[steam:20], staged_scores(second).keys
    assert_nil draft
  end

  test "a pass that staged no card cannot be promoted, and the draft is left alone" do
    first = run_on("cards")
    ready(first, 10, 20)
    cards_page(first)
    promote_batch(first)
    first.update!(status: :promoted)
    Steam::App.update_all(review_count: nil)
    second = rerun([ 10, 20 ])

    cards_page(second)
    cards_page(second)

    second.reload
    assert_predicate second, :ready?
    assert_equal [ 0, 2 ], [ second.cards_written, second.cards_refused ]
    assert_empty staged(second)
    assert_equal :empty_batch, Steam::PromoteImport.new.call(import_run_id: second.id).failure
    assert_equal 2, draft.card_seasons.count
  end

  test "with no ready game after the cursor, the cards step readies the run" do
    run = run_on("cards", last_appid: 10)
    ready(run, 10)

    assert cards_page(run).success?

    run.reload
    assert_predicate run, :ready?
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
    Catalog::UpsertCardIdentity.class_eval do
      alias_method :upsert_card_without_boom, :upsert_card
      define_method(:upsert_card) { |*| raise "boom" }
    end
    begin
      perform_enqueued_jobs { Steam::ImportStepJob.perform_later(run.id, run.cursor) }
    ensure
      Catalog::UpsertCardIdentity.class_eval do
        alias_method :upsert_card, :upsert_card_without_boom
        remove_method :upsert_card_without_boom
      end
    end

    run.reload
    assert_predicate run, :failed?
    assert_equal({ "step" => "cards", "last_appid" => 0 }, run.cursor)
    assert_includes run.latest_errors.first.message, "RuntimeError: boom"
    assert_empty steam_cards
  end

  test "the details step hands over to the cards, whose last page readies the run" do
    run = run_on("details", last_appid: 10)
    ready(run, 10)

    perform_enqueued_jobs { Steam::ImportStepJob.perform_later(run.id, run.cursor) }

    run.reload
    assert_predicate run, :ready?
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
