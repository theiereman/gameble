require "test_helper"

# Catalog::UpsertDraftCard (AD-3, AD-5): every row of its matrix, the event it
# publishes, and the races it absorbs on its unique indexes.
class Catalog::UpsertDraftCardTest < ActiveSupport::TestCase
  def attributes(**overrides)
    {
      source_key: "src:620", publisher: "Valve", release_date: Date.new(2011, 4, 18),
      genres: %w[puzzle comedy], tags: %w[puzzle co-op], developers: [ "Valve", "Hidden Path" ], franchises: [ "Portal" ],
      image_url: "https://images.example.test/620.jpg", store_url: "https://store.example.test/620",
      texts: {
        "en" => { title: "Portal 2", short_description: "The sequel." },
        "fr" => { title: "Portal 2", short_description: "La suite." }
      },
      prestige_score: 0.97, prestige_score_version: 2, rating: 98.0, review_count: 1_000
    }.merge(overrides)
  end

  def upsert(**overrides)
    Catalog::UpsertDraftCard.new.call(**attributes(**overrides))
  end

  def events_of(season)
    Rails.configuration.event_store.read.stream(Catalog::Season.stream_name(season.id)).to_a
  end

  def row_counts
    [ Catalog::Season, Catalog::Card, Catalog::CardText, Catalog::CardSeason ].map(&:count)
  end

  # New card

  test "a first card with no draft opens the next season and writes the card, its texts and its card-season" do
    assert_nil Catalog::DraftSeason.call

    result = upsert

    assert result.success?
    card_season = result.value!.reload
    season = card_season.season
    assert_predicate season, :draft?
    assert_equal 2, season.number
    assert_nil season.published_at
    assert_equal season, Catalog::DraftSeason.call

    card = card_season.card
    assert_equal "src:620", card.source_key
    assert_equal "portal-2", card.slug
    assert_equal Date.new(2011, 4, 18), card.release_date
    assert_equal "Valve", card.publisher
    assert_equal %w[puzzle comedy], card.genres
    assert_equal %w[puzzle co-op], card.tags
    assert_equal [ [ "Valve", "Hidden Path" ], [ "Portal" ] ], [ card.developers, card.franchises ]
    assert_equal "https://images.example.test/620.jpg", card.image_url
    assert_equal "https://store.example.test/620", card.store_url
    assert_equal({ "en" => [ "Portal 2", "The sequel." ], "fr" => [ "Portal 2", "La suite." ] },
      card.texts.to_h { |text| [ text.locale, [ text.title, text.short_description ] ] })

    assert_in_delta 0.97, card_season.prestige_score
    assert_equal 2, card_season.prestige_score_version
    assert_equal BigDecimal("98.0"), card_season.rating
    assert_equal 1_000, card_season.review_count
    assert_nil card_season.rarity

    events = events_of(season)
    assert_equal [ Catalog::DraftCardUpserted ], events.map(&:class)
    assert_equal({ card_id: card.id, season_id: season.id, card_season_id: card_season.id }, events.first.data)
  end

  test "a card is found by its slug" do
    card = upsert.value!.card

    assert_equal card, Catalog::Card.friendly.find("portal-2")
    assert_equal "portal-2", card.to_param
  end

  test "an existing draft is reused" do
    first = upsert.value!
    second = upsert(source_key: "src:70", texts: { "en" => { title: "Half-Life" }, "fr" => { title: "Half-Life" } }).value!

    assert_equal first.season, second.season
    assert_equal 1, Catalog::Season.draft.count
  end

  # Same source key again

  test "the same source key again updates the card, its texts and its card-season in place" do
    first = upsert.value!
    counts = row_counts

    result = upsert(
      texts: { "en" => { title: "Portal 2: Remastered" }, "fr" => { title: "Portal 2 : Remasterisé", short_description: "Encore." } },
      prestige_score: 0.5, prestige_score_version: 3, rating: 75.25, genres: %w[comedy], publisher: "Valve Corporation",
      developers: [ "Valve" ], franchises: [], review_count: 2_500
    )

    assert result.success?
    assert_equal counts, row_counts
    card_season = result.value!.reload
    assert_equal first.id, card_season.id
    card = card_season.card
    assert_equal "portal-2", card.slug
    assert_equal "Portal 2: Remastered", card.text("en").title
    assert_nil card.text("en").short_description
    assert_equal "Portal 2 : Remasterisé", card.text("fr").title
    assert_equal %w[comedy], card.genres
    assert_equal "Valve Corporation", card.publisher
    assert_equal [ [ "Valve" ], [] ], [ card.developers, card.franchises ]
    assert_equal 2_500, card_season.review_count
    assert_in_delta 0.5, card_season.prestige_score
    assert_equal 3, card_season.prestige_score_version
    assert_equal BigDecimal("75.25"), card_season.rating
    assert_equal 2, events_of(card_season.season).size
  end

  test "an upsert that changes nothing still publishes its event" do
    first = upsert.value!
    counts = row_counts

    assert upsert.success?

    assert_equal counts, row_counts
    assert_equal 2, events_of(first.season).size
  end

  # Card known in a published season

  test "a card of the published season is updated and gets its own card-season in the draft" do
    portal = catalog_cards(:portal)
    published = catalog_card_seasons(:portal_one)
    before = published.attributes

    result = upsert(source_key: "src:400", release_date: Date.new(2007, 10, 10),
      texts: { "en" => { title: "Portal (2007)" }, "fr" => { title: "Portal (2007)" } }, prestige_score: 0.1, rating: 10,
      developers: [ "Valve" ], franchises: [ "Portal" ], review_count: 4_000)

    assert result.success?
    card_season = result.value!
    assert_equal portal, card_season.card
    assert_equal 4_000, card_season.review_count
    assert_equal [ [ "Valve" ], [ "Portal" ] ], [ portal.reload.developers, portal.franchises ]
    assert_nil published.reload.review_count
    assert_not_equal published, card_season
    assert_predicate card_season.season, :draft?
    assert_equal "Portal (2007)", portal.reload.text("en").title
    assert_equal "portal", portal.slug
    assert_equal 2, portal.texts.count
    assert_equal before, published.reload.attributes
    assert_equal [ catalog_set_memberships(:portal_valve_one) ], published.set_memberships.to_a
  end

  # Slugs

  test "a taken title falls back to the title and the release year" do
    result = upsert(source_key: "src:1", texts: { "en" => { title: "Portal" }, "fr" => { title: "Portal" } })

    assert_equal "portal-2011", result.value!.card.slug
  end

  test "a title taken with its year too falls back to a random suffix" do
    upsert(source_key: "src:1", texts: { "en" => { title: "Portal" }, "fr" => { title: "Portal" } })

    slug = upsert(source_key: "src:2", texts: { "en" => { title: "Portal" }, "fr" => { title: "Portal" } }).value!.card.slug

    assert_match(/\Aportal-2011-[a-z0-9]{6}\z/, slug)
  end

  test "a non-Latin title takes the release year and a random suffix" do
    slug = upsert(texts: { "en" => { title: "ポータル" }, "fr" => { title: "ポータル" } }).value!.card.slug

    assert_match(/\A2011-[a-z0-9]{6}\z/, slug)
  end

  test "the slug follows the English title, not the French one" do
    slug = upsert(texts: { "en" => { title: "The Witness" }, "fr" => { title: "Le Témoin" } }).value!.card.slug

    assert_equal "the-witness", slug
  end

  # Missing locale

  [
    [ "no fr text", ->(texts) { texts.except("fr") } ],
    [ "no en text", ->(texts) { texts.except("en") } ],
    [ "a nil fr text", ->(texts) { texts.merge("fr" => nil) } ],
    [ "a blank en title", ->(texts) { texts.merge("en" => { title: "  " }) } ],
    [ "no fr title", ->(texts) { texts.merge("fr" => { short_description: "…" }) } ]
  ].each do |label, change|
    test "#{label} fails with missing_text and writes nothing" do
      counts = row_counts

      result = upsert(texts: change.call(attributes[:texts]))

      assert_equal :missing_text, result.failure
      assert_equal counts, row_counts
      assert_empty Rails.configuration.event_store.read.of_type(Catalog::DraftCardUpserted).to_a
    end
  end

  # Bad attributes

  {
    "a blank source key" => { source_key: " " },
    "a nil source key" => { source_key: nil },
    "a blank image URL" => { image_url: "" },
    "a blank store URL" => { store_url: nil },
    "no release date" => { release_date: nil },
    "a release date as a string" => { release_date: "2011-04-18" },
    "a nil score" => { prestige_score: nil },
    "a score as a string" => { prestige_score: "0.97" },
    "an infinite score" => { prestige_score: Float::INFINITY },
    "a score version of 0" => { prestige_score_version: 0 },
    "a negative score version" => { prestige_score_version: -1 },
    "a fractional score version" => { prestige_score_version: 1.5 },
    "a score version as a string" => { prestige_score_version: "2" },
    "a nil score version" => { prestige_score_version: nil },
    "a score version beyond its column" => { prestige_score_version: 32_768 },
    "a nil rating" => { rating: nil },
    "a rating as a string" => { rating: "98" },
    "a rating below 0" => { rating: -0.5 },
    "a rating above 100" => { rating: 100.5 },
    "a NaN rating" => { rating: Float::NAN },
    "a third locale" => { texts: { "en" => { title: "Portal 2" }, "fr" => { title: "Portal 2" }, "de" => { title: "Portal 2" } } },
    "texts that are not a hash" => { texts: [ "Portal 2" ] },
    "genres that are not strings" => { genres: [ :rpg ] },
    "a genre outside the theme list" => { genres: [ "action" ] },
    "a theme's name in place of its key" => { genres: [ "Souls-like" ] },
    "nil tags" => { tags: nil },
    "nil developers" => { developers: nil },
    "a developer that is not a string" => { developers: [ :valve ] },
    "a blank franchise" => { franchises: [ "Portal", " " ] },
    "franchises that are not a list" => { franchises: "Portal" },
    "a review count of 0" => { review_count: 0 },
    "a negative review count" => { review_count: -1 },
    "a fractional review count" => { review_count: 10.0 },
    "a review count as a string" => { review_count: "1000" },
    "a review count beyond its column" => { review_count: 2**31 },
    "a numeric title" => { texts: { "en" => { title: 2 }, "fr" => { title: "Portal 2" } } },
    "an array title" => { texts: { "en" => { title: "Portal 2" }, "fr" => { title: [] } } }
  }.each do |label, overrides|
    test "#{label} fails with invalid_card and writes nothing" do
      counts = row_counts

      result = upsert(**overrides)

      assert_equal :invalid_card, result.failure
      assert_equal counts, row_counts
      assert_empty Rails.configuration.event_store.read.of_type(Catalog::DraftCardUpserted).to_a
    end
  end

  test "the score version is a required keyword" do
    assert_raises(ArgumentError) { Catalog::UpsertDraftCard.new.call(**attributes.except(:prestige_score_version)) }
  end

  test "without developers, franchises or review count, a card has empty lists and its card-season no count" do
    card_season = Catalog::UpsertDraftCard.new.call(**attributes.except(:developers, :franchises, :review_count)).value!.reload

    assert_equal [ [], [] ], [ card_season.card.developers, card_season.card.franchises ]
    assert_nil card_season.review_count
  end

  test "a blank publisher is stored as NULL" do
    card = upsert(publisher: "  ").value!.card.reload

    assert_nil card.publisher
  end

  test "a rating of 0 and of 100 are accepted, and integers are numbers" do
    assert upsert(rating: 0).success?
    assert upsert(rating: 100, prestige_score: 3).success?
  end

  # Races

  test "a first upsert racing another meets the one-draft index and reads the other's draft" do
    other = Catalog::Season.create!(status: :draft, number: 2)
    operation = Catalog::UpsertDraftCard.new
    calls = 0
    operation.define_singleton_method(:find_draft_season) { (calls += 1) == 1 ? nil : super() }

    result = operation.call(**attributes)

    assert result.success?
    assert_equal other, result.value!.season
    assert_equal 1, Catalog::Season.draft.count
  end

  test "the same source key written at once meets the source key index and updates the other's card" do
    upsert
    operation = Catalog::UpsertDraftCard.new
    calls = 0
    operation.define_singleton_method(:find_card) { |source_key| (calls += 1) == 1 ? nil : super(source_key) }
    counts = row_counts

    result = operation.call(**attributes(texts: { "en" => { title: "Portal 2 GOTY" }, "fr" => { title: "Portal 2" } }))

    assert result.success?
    assert_equal counts, row_counts
    assert_equal "Portal 2 GOTY", result.value!.card.text("en").title
    assert_equal "portal-2", result.value!.card.slug
  end

  test "a card-season created meanwhile meets the card and season index and is updated" do
    first = upsert.value!
    operation = Catalog::UpsertDraftCard.new
    calls = 0
    operation.define_singleton_method(:find_card_season) { |card, season| (calls += 1) == 1 ? nil : super(card, season) }

    result = operation.call(**attributes(rating: 50))

    assert_equal first, result.value!
    assert_equal BigDecimal("50"), first.reload.rating
    assert_equal 1, Catalog::CardSeason.where(season: first.season).count
  end

  test "a text created meanwhile meets the card and locale index and is updated" do
    first = upsert.value!
    operation = Catalog::UpsertDraftCard.new
    calls = 0
    operation.define_singleton_method(:find_text) { |card, locale| (calls += 1) == 1 ? nil : super(card, locale) }

    result = operation.call(**attributes(texts: { "en" => { title: "Portal Two" }, "fr" => { title: "Portal 2" } }))

    assert result.success?
    assert_equal 2, first.card.texts.count
    assert_equal "Portal Two", first.card.reload.text("en").title
  end

  test "every failure code has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        %i[missing_text invalid_card].each do |code|
          assert_predicate Catalog::UpsertDraftCard.failure_message(code), :present?, "#{code} #{locale}"
          assert_not_includes Catalog::UpsertDraftCard.failure_message(code), "Translation missing"
        end
      end
    end
  end
end
