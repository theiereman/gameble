require "test_helper"
require_relative "../support/share_image_art"

# CardShareImage: the fingerprint of what an image shows, the page's
# lookup that enqueues a missing or stale render at most once an hour,
# the art taken only from Steam's hosts and refused as the card face
# refuses it, the composed PNG, kept light, and the refresh on a card's
# change, each on the share_images queue.
class CardShareImageTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ShareImageArt

  setup { stub_share_image_art }
  teardown { unstub_share_image_art }

  def card_season_id = catalog_card_seasons(:rare_card_one).id

  def view(locale = "en") = Catalog::CardViews.call([ card_season_id ], locale:).fetch(card_season_id)

  def with_memory_cache
    cache_was = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = cache_was
  end

  test "the fingerprint follows every field of the view, the locale and the render version" do
    base = view
    fingerprint = CardShareImage.fingerprint(base, "en")

    assert_match(/\A\h{64}\z/, fingerprint)
    assert_equal fingerprint, CardShareImage.fingerprint(view, :en)
    assert_not_equal fingerprint, CardShareImage.fingerprint(base, "fr")
    { id: "other", title: "Other", publisher: "Other", year: 1999, season_number: 2, rarity: "epic",
      image_url: "https://shared.akamai.steamstatic.com/other.jpg", number: 99, genre: "horror" }.each do |field, value|
      assert_not_equal fingerprint, CardShareImage.fingerprint(base.with(field => value), "en"), field
    end
    stub_const(CardShareImage, :RENDER_VERSION, CardShareImage::RENDER_VERSION + 1) do
      assert_not_equal fingerprint, CardShareImage.fingerprint(base, "en")
    end
  end

  test "the fingerprint follows the words the image draws: a renamed theme changes it, in its language" do
    horror = view.with(genre: "horror")
    english = CardShareImage.fingerprint(horror, "en")
    french = CardShareImage.fingerprint(horror, "fr")

    assert_equal french, I18n.with_locale(:en) { CardShareImage.fingerprint(horror, "fr") }
    Catalog::RenameTheme.new.call(theme: catalog_themes(:horror), name_en: "Scary", name_fr: "Effrayant")

    assert_not_equal english, CardShareImage.fingerprint(horror, "en")
    assert_not_equal french, CardShareImage.fingerprint(horror, "fr")
  end

  test "a failed render holds off the page's next enqueue of that fingerprint for a day" do
    with_memory_cache do
      fingerprint = CardShareImage.fingerprint(view, "en")
      CardShareImage.hold_off(card_season_id, "en", fingerprint)

      travel CardShareImage::RENDER_THROTTLE + 1.second do
        assert_no_enqueued_jobs(only: CardShareImageJob) { CardShareImage.current_token(card_season_id:, view:, locale: :en) }
      end
      assert_enqueued_jobs(1, only: CardShareImageJob) { CardShareImage.current_token(card_season_id:, view: view("fr"), locale: :fr) }
      travel CardShareImage::FAILURE_HOLD_OFF + 1.second do
        assert_enqueued_jobs(1, only: CardShareImageJob) { CardShareImage.current_token(card_season_id:, view:, locale: :en) }
      end
    end
  end

  test "the page's lookup: the token of a current image, enqueueing nothing" do
    token = store_share_image(card_season_id, "en").token

    assert_no_enqueued_jobs do
      assert_equal token, CardShareImage.current_token(card_season_id:, view:, locale: :en)
    end
  end

  test "the page's lookup: no image, a stale one or one whose file is lost gives nil and enqueues its render" do
    assert_enqueued_with(job: CardShareImageJob, args: [ card_season_id, "en" ], queue: "share_images") do
      assert_nil CardShareImage.current_token(card_season_id:, view:, locale: :en)
    end

    store_share_image(card_season_id, "fr", fingerprint: "c" * 64)
    assert_enqueued_with(job: CardShareImageJob, args: [ card_season_id, "fr" ], queue: "share_images") do
      assert_nil CardShareImage.current_token(card_season_id:, view: view("fr"), locale: :fr)
    end

    lost = store_share_image(card_season_id, "en")
    ActiveStorage::Blob.service.delete(lost.image.blob.key)
    with_memory_cache do
      assert_enqueued_with(job: CardShareImageJob, args: [ card_season_id, "en" ], queue: "share_images") do
        assert_nil CardShareImage.current_token(card_season_id:, view:, locale: :en)
      end
    end
  end

  test "the card's current fingerprint by card-season, nil for a card-season with no card view" do
    assert_equal CardShareImage.fingerprint(view("fr"), "fr"), CardShareImage.fingerprint_of(card_season_id, "fr")
    assert_nil CardShareImage.fingerprint_of(0, "en")
  end

  test "the page's lookup enqueues one render an hour per card-season, language and fingerprint" do
    with_memory_cache do
      assert_enqueued_jobs(1, only: CardShareImageJob) do
        3.times { CardShareImage.current_token(card_season_id:, view:, locale: :en) }
      end
      assert_enqueued_jobs(1, only: CardShareImageJob) { CardShareImage.current_token(card_season_id:, view: view("fr"), locale: :fr) }
      assert_enqueued_jobs(1, only: CardShareImageJob) do
        CardShareImage.current_token(card_season_id:, view: view.with(title: "Renamed"), locale: :en)
      end

      travel CardShareImage::RENDER_THROTTLE + 1.second do
        assert_enqueued_jobs(1, only: CardShareImageJob) { CardShareImage.current_token(card_season_id:, view:, locale: :en) }
      end
    end
  end

  test "Steam's image hosts only, over https" do
    [ STEAM_ART, "https://cdn.akamai.steamstatic.com/steam/apps/1/header.jpg" ].each do |url|
      assert CardShareImage::Art.steam_image?(url), url
    end
    [ "http://shared.akamai.steamstatic.com/a.jpg", "https://steamstatic.com.evil.test/a.jpg", "https://evilsteamstatic.com/a.jpg",
      "https://images.example.test/403.jpg", "javascript:alert(1)", "not a url", nil, "" ].each do |url|
      assert_not CardShareImage::Art.steam_image?(url), url.inspect
    end
  end

  test "the art: the cover at the xl face's 109 × 112 pixels, three bands, 32 colours at most" do
    stub_art

    art = CardShareImage::Art.new(STEAM_ART).pixels

    assert_equal [ 109, 112, 3, :uchar ], [ art.width, art.height, art.bands, art.format ]
    colours = art.write_to_memory.unpack("C*").each_slice(3).uniq
    assert_operator colours.size, :<=, 32
  end

  test "the art is refused off Steam's hosts without a request, and on a failed fetch, an undecodable body, a small or grey cover" do
    assert_raises(CardShareImage::Art::Unusable) { CardShareImage::Art.new("https://images.example.test/403.jpg").pixels }

    { 404 => cover_jpeg, 200 => "not an image" }.each do |status, body|
      stub_share_image_art
      stub_art(status:, body:)
      assert_raises(CardShareImage::Art::Unusable) { CardShareImage::Art.new(STEAM_ART).pixels }
    end
    [ cover_jpeg(width: 299, height: 450), cover_jpeg(width: 300, height: 449), grey_placeholder_jpeg ].each do |body|
      stub_share_image_art
      stub_art(body:)
      error = assert_raises(CardShareImage::Art::Unusable) { CardShareImage::Art.new(STEAM_ART).pixels }
      assert_includes error.message, STEAM_ART
    end
  end

  test "the art is refused over 8 MB, over 4096 pixels a side, or in a format other than JPEG, PNG or WebP" do
    gif = Vips::Image.new_from_buffer(cover_jpeg, "").gifsave_buffer
    { "x" * (CardShareImage::Art::MAX_BYTES + 1) => "bytes", cover_jpeg(width: 300, height: 4097) => "pixels a side",
      gif => "is not a JPEG" }.each do |body, reason|
      stub_share_image_art
      stub_art(body:)
      error = assert_raises(CardShareImage::Art::Unusable) { CardShareImage::Art.new(STEAM_ART).pixels }
      assert_includes error.message, reason
    end
  end

  test "the art is refused when the fetch fails at the connection" do
    art_stubs.get(STEAM_ART) { raise Faraday::ConnectionFailed, "refused" }

    assert_raises(CardShareImage::Art::Unusable) { CardShareImage::Art.new(STEAM_ART).pixels }
  end

  test "the composition: a 1200 × 630 PNG, whatever the title holds, in either language" do
    stub_art
    art = CardShareImage::Art.new(STEAM_ART).pixels

    pngs = %w[en fr].map do |locale|
      I18n.with_locale(locale) do
        title = "Tom & Jerry <b>Łódź</b>\u0007 #{"Long words " * 12}"
        CardShareImage::Composition.new(view(locale).with(title:, rarity: "epic", publisher: nil, genre: nil, number: nil), art).png
      end
    end

    pngs.each { assert_equal [ "pngload_buffer", 1200, 630 ], png_size(it) }
    assert_equal 2, pngs.uniq.size, "the rarity in each language"
  end

  test "the composition of a card with busy art stays under the size limit" do
    stub_art(body: noisy_cover_jpeg)
    art = CardShareImage::Art.new(STEAM_ART).pixels

    png = CardShareImage::Composition.new(view.with(title: "Long words " * 12), art).png

    assert_operator png.bytesize, :<, CardShareImage::MAX_BYTES
    assert_equal 2, png_colour_type(png), "truecolour under the limit"
  end

  test "a composition over the size limit is saved again with a palette" do
    stub_art(body: noisy_cover_jpeg)
    art = CardShareImage::Art.new(STEAM_ART).pixels
    plain = CardShareImage::Composition.new(view, art).png

    paletted = stub_const(CardShareImage, :MAX_BYTES, plain.bytesize - 1) { CardShareImage::Composition.new(view, art).png }

    assert_equal 3, png_colour_type(paletted)
    assert_operator paletted.bytesize, :<, plain.bytesize
    assert_equal [ "pngload_buffer", 1200, 630 ], png_size(paletted)
  end

  test "the composition draws the title on the card and in the column" do
    stub_art
    art = CardShareImage::Art.new(STEAM_ART).pixels
    composition = CardShareImage::Composition
    drawn = ->(title) { Vips::Image.new_from_buffer(composition.new(view.with(title:), art).png, "") }
    region = ->(image, box) { image.crop(box.x, box.y, box.width, box.height).write_to_memory }

    portal, half_life = drawn.("Portal"), drawn.("Half-Life")

    [ composition::BAND, composition::COLUMN ].each do |box|
      assert_not_equal region.(portal, box), region.(half_life, box), box.inspect
    end
  end

  test "the composition draws the art at three screen pixels a pixel, inside the rarity's frame" do
    stub_art
    art = CardShareImage::Art.new(STEAM_ART).pixels
    composition = CardShareImage::Composition

    image = Vips::Image.new_from_buffer(composition.new(view.with(rarity: "epic"), art).png, "")

    [ [ 40, 50 ], [ 41, 50 ], [ 100, 3 ], [ 5, 100 ] ].each do |x, y|
      [ 0, 1, 2 ].each do |offset|
        at = image.getpoint(composition::ART.x + (x * 3) + offset, composition::ART.y + (y * 3) + offset)
        assert_equal art.getpoint(x, y), at, [ x, y, offset ].inspect
      end
    end
    frame = image.getpoint(composition::CARD.x + composition::BEVEL + 1, composition::CARD.y + (composition::CARD.height / 2))
    assert_equal composition::RARITY_COLOURS.fetch("epic"), frame.map(&:to_i)
  end

  test "the rarity icons are drawn from the pixel SVGs' runs" do
    Catalog::Rarity::TIERS.each_value do |rarity|
      icon = CardShareImage::RarityIcon.of(rarity)
      assert_equal 21, icon.size(3), rarity
      assert icon.runs.all? { it.x.between?(0, 6) && it.y.between?(0, 6) && it.colour.size == 3 }, rarity
    end
    assert_empty CardShareImage::RarityIcon.new("<svg></svg>").runs
  end

  test "a card's change enqueues the render of each of its stored images, after commit; a card without images enqueues nothing" do
    store_share_image(card_season_id, "en")
    store_share_image(card_season_id, "fr", fingerprint: "c" * 64)
    identity = ->(source_key, title) do
      Catalog::UpsertCardIdentity.new.call(source_key:, release_date: Date.new(2014, 6, 1), image_url: STEAM_ART,
        store_url: "https://store.example.test/x", texts: { en: { title: }, fr: { title: } }, genres: [])
    end

    assert_enqueued_jobs(2, only: CardShareImageJob, queue: "share_images") { assert identity.("src:403", "Blue Depths").success? }
    assert_equal [ [ card_season_id, "en" ], [ card_season_id, "fr" ] ],
      enqueued_jobs.select { it[:job] == CardShareImageJob }.map { it[:args] }.sort

    assert_no_enqueued_jobs(only: CardShareImageJob) { assert identity.("src:400", "Portal").success? }
  end

  private
    def stub_const(owner, name, value)
      was = owner.const_get(name)
      owner.send(:remove_const, name)
      owner.const_set(name, value)
      yield
    ensure
      owner.send(:remove_const, name)
      owner.const_set(name, was)
    end
end
