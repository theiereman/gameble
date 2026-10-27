require "test_helper"

# Catalog::UpsertCardIdentity: the slugs it gives, the attributes it refuses,
# and the races it absorbs on its unique indexes.
class Catalog::UpsertCardIdentityTest < ActiveSupport::TestCase
  def attributes(**overrides)
    {
      source_key: "src:620", publisher: "Valve", release_date: Date.new(2011, 4, 18),
      genres: %w[puzzle comedy], tags: %w[puzzle co-op], developers: [ "Valve", "Hidden Path" ], franchises: [ "Portal" ],
      image_url: "https://images.example.test/620.jpg", store_url: "https://store.example.test/620",
      texts: {
        "en" => { title: "Portal 2", short_description: "The sequel." },
        "fr" => { title: "Portal 2", short_description: "La suite." }
      }
    }.merge(overrides)
  end

  def upsert(**overrides)
    Catalog::UpsertCardIdentity.new.call(**attributes(**overrides))
  end

  def row_counts
    [ Catalog::Card, Catalog::CardText ].map(&:count)
  end

  def identity_events
    Rails.configuration.event_store.read.of_type(Catalog::CardIdentityUpserted).to_a
  end

  # A competing card that already holds the slug a "Portal 2" card would take:
  # the other writer of the slug race.
  def racer_card
    racer = Catalog::Card.new(source_key: "src:racer", release_date: Date.new(2011, 4, 18),
      image_url: "https://images.example.test/620.jpg", store_url: "https://store.example.test/620",
      genres: %w[puzzle], tags: %w[puzzle])
    racer.texts.build(locale: "en", title: "Portal 2")
    racer.texts.build(locale: "fr", title: "Portal 2")
    racer.save!
    racer
  end

  # Makes the first (or every) card built inside the block carry the slug the
  # racer holds, as the racing writer's card would: its slug was computed before
  # the racer's row existed. The operation's own `create_card` then meets the
  # real unique index. Yields the array of the cards built.
  def with_colliding_slug(racer, collide_every_time: false)
    built = []
    original = Catalog::Card.method(:new)
    Catalog::Card.define_singleton_method(:new) do |*args, &block|
      original.call(*args, &block).tap do |card|
        built << card
        card.slug = racer.slug if collide_every_time || built.size == 1
      end
    end
    yield built
  ensure
    Catalog::Card.singleton_class.send(:remove_method, :new)
  end

  test "a new card writes its attributes and texts, and is found by its slug" do
    card = upsert.value!

    assert_equal "src:620", card.source_key
    assert_equal "portal-2", card.slug
    assert_equal Date.new(2011, 4, 18), card.release_date
    assert_equal "Valve", card.publisher
    assert_equal %w[puzzle comedy], card.genres
    assert_equal %w[puzzle co-op], card.tags
    assert_equal [ [ "Valve", "Hidden Path" ], [ "Portal" ] ], [ card.developers, card.franchises ]
    assert_equal({ "en" => [ "Portal 2", "The sequel." ], "fr" => [ "Portal 2", "La suite." ] },
      card.texts.to_h { |text| [ text.locale, [ text.title, text.short_description ] ] })
    assert_equal card, Catalog::Card.friendly.find("portal-2")
  end

  test "the same source key again updates the card and its texts in place" do
    first = upsert.value!
    counts = row_counts

    card = upsert(
      texts: { "en" => { title: "Portal 2: Remastered" }, "fr" => { title: "Portal 2 : Remasterisé", short_description: "Encore." } },
      genres: %w[comedy], publisher: "Valve Corporation", developers: [ "Valve" ], franchises: []
    ).value!

    assert_equal first, card
    assert_equal counts, row_counts
    assert_equal "portal-2", card.slug
    assert_equal "Portal 2: Remastered", card.text("en").title
    assert_nil card.text("en").short_description
    assert_equal "Portal 2 : Remasterisé", card.text("fr").title
    assert_equal %w[comedy], card.genres
    assert_equal "Valve Corporation", card.publisher
    assert_equal [ [ "Valve" ], [] ], [ card.developers, card.franchises ]
    assert_equal 2, identity_events.size
  end

  test "a card of the published season is updated in place" do
    portal = catalog_cards(:portal)
    published = catalog_card_seasons(:portal_one)
    before = published.attributes

    card = upsert(source_key: "src:400", release_date: Date.new(2007, 10, 10),
      texts: { "en" => { title: "Portal (2007)" }, "fr" => { title: "Portal (2007)" } },
      developers: [ "Valve" ], franchises: [ "Portal" ]).value!

    assert_equal portal, card
    assert_equal [ [ "Valve" ], [ "Portal" ] ], [ card.developers, card.franchises ]
    assert_equal "Portal (2007)", card.text("en").title
    assert_equal "portal", card.slug
    assert_equal 2, card.texts.count
    assert_equal before, published.reload.attributes
  end

  test "a taken title falls back to the title and the release year" do
    result = upsert(source_key: "src:1", texts: { "en" => { title: "Portal" }, "fr" => { title: "Portal" } })

    assert_equal "portal-2011", result.value!.slug
  end

  test "a title taken with its year too falls back to a random suffix" do
    upsert(source_key: "src:1", texts: { "en" => { title: "Portal" }, "fr" => { title: "Portal" } })

    slug = upsert(source_key: "src:2", texts: { "en" => { title: "Portal" }, "fr" => { title: "Portal" } }).value!.slug

    assert_match(/\Aportal-2011-[a-z0-9]{6}\z/, slug)
  end

  test "a non-Latin title takes the release year and a random suffix" do
    slug = upsert(texts: { "en" => { title: "ポータル" }, "fr" => { title: "ポータル" } }).value!.slug

    assert_match(/\A2011-[a-z0-9]{6}\z/, slug)
  end

  test "the slug follows the English title, not the French one" do
    slug = upsert(texts: { "en" => { title: "The Witness" }, "fr" => { title: "Le Témoin" } }).value!.slug

    assert_equal "the-witness", slug
  end

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
      assert_empty identity_events
    end
  end

  {
    "a blank source key" => { source_key: " " },
    "a nil source key" => { source_key: nil },
    "a blank image URL" => { image_url: "" },
    "a blank store URL" => { store_url: nil },
    "no release date" => { release_date: nil },
    "a release date as a string" => { release_date: "2011-04-18" },
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
    "a numeric title" => { texts: { "en" => { title: 2 }, "fr" => { title: "Portal 2" } } },
    "an array title" => { texts: { "en" => { title: "Portal 2" }, "fr" => { title: [] } } }
  }.each do |label, overrides|
    test "#{label} fails with invalid_card and writes nothing" do
      counts = row_counts

      result = upsert(**overrides)

      assert_equal :invalid_card, result.failure
      assert_equal counts, row_counts
      assert_empty identity_events
    end
  end

  test "without developers or franchises, a card has empty lists" do
    card = Catalog::UpsertCardIdentity.new.call(**attributes.except(:developers, :franchises)).value!

    assert_equal [ [], [] ], [ card.developers, card.franchises ]
  end

  test "a blank publisher is stored as NULL" do
    card = upsert(publisher: "  ").value!.reload

    assert_nil card.publisher
  end

  test "the same source key written at once meets the source key index and updates the other's card" do
    upsert
    operation = Catalog::UpsertCardIdentity.new
    calls = 0
    operation.define_singleton_method(:find_card) { |source_key| (calls += 1) == 1 ? nil : super(source_key) }
    counts = row_counts

    result = operation.call(**attributes(texts: { "en" => { title: "Portal 2 GOTY" }, "fr" => { title: "Portal 2" } }))

    assert result.success?
    assert_equal counts, row_counts
    assert_equal "Portal 2 GOTY", result.value!.text("en").title
    assert_equal "portal-2", result.value!.slug
  end

  test "a text created meanwhile meets the card and locale index and is updated" do
    first = upsert.value!
    operation = Catalog::UpsertCardIdentity.new
    calls = 0
    operation.define_singleton_method(:find_text) { |card, locale| (calls += 1) == 1 ? nil : super(card, locale) }

    result = operation.call(**attributes(texts: { "en" => { title: "Portal Two" }, "fr" => { title: "Portal 2" } }))

    assert result.success?
    assert_equal 2, first.texts.count
    assert_equal "Portal Two", first.reload.text("en").title
  end

  test "a new card racing another on its slug retries and succeeds with the title and year" do
    racer = racer_card
    before = row_counts

    result = with_colliding_slug(racer) do |built|
      outcome = Catalog::UpsertCardIdentity.new.call(**attributes)
      assert_equal 2, built.size
      outcome
    end

    assert result.success?
    assert_equal "portal-2-2011", result.value!.slug
    assert_equal "portal-2", racer.reload.slug
    assert_equal [ before[0] + 1, before[1] + 2 ], row_counts
  end

  test "a slug colliding on every attempt gives up after its attempts" do
    racer = racer_card
    before = row_counts

    with_colliding_slug(racer, collide_every_time: true) do |built|
      error = assert_raises(ActiveRecord::RecordNotUnique) { Catalog::UpsertCardIdentity.new.call(**attributes) }

      assert_equal Catalog::UpsertCardIdentity::ATTEMPTS, built.size
      assert_match(/no card after #{Catalog::UpsertCardIdentity::ATTEMPTS} attempts/, error.message)
    end

    assert_equal "portal-2", racer.reload.slug
    assert_equal before, row_counts
    assert_empty identity_events
  end

  test "every failure code has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        %i[missing_text invalid_card].each do |code|
          assert_predicate Catalog::UpsertCardIdentity.failure_message(code), :present?, "#{code} #{locale}"
          assert_not_includes Catalog::UpsertCardIdentity.failure_message(code), "Translation missing"
        end
      end
    end
  end
end
