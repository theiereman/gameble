require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/share_image_art"

# CardShareImageJob: renders and stores a published card-season's image in
# one language; a rerun on the stored fingerprint fetches and writes
# nothing; an unusable art stores nothing and is reported; a render the card
# outgrew while it was drawn stores nothing, quietly.
class CardShareImageJobTest < ActiveJob::TestCase
  include CatalogSeeds
  include ShareImageArt

  setup do
    stub_share_image_art
    use_steam_art(card_season_id)
  end

  teardown { unstub_share_image_art }

  def card_season_id = catalog_card_seasons(:rare_card_one).id

  def stored(locale = "en") = Catalog::ShareImageFor.call(card_season_id:, locale:)

  test "renders the card's 1200 × 630 PNG and stores it under its current fingerprint" do
    stub_art

    CardShareImageJob.perform_now(card_season_id, "fr")

    assert_equal current_fingerprint(card_season_id, "fr"), stored("fr").fingerprint
    assert_nil stored("en")
    assert_equal [ "pngload_buffer", 1200, 630 ], png_size(Catalog::ShareImageByToken.call(stored("fr").token))
  end

  test "a card changed while its image was drawn stores nothing and reports nothing, and its next render is not held off" do
    cache_was = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    view = Catalog::CardViews.call([ card_season_id ], locale: "en").fetch(card_season_id)
    art_stubs.get(STEAM_ART) do
      Catalog::CardText.where(card: catalog_cards(:rare_card), locale: "en").update_all(title: "Bluer Depths")
      [ 200, { "Content-Type" => "image/jpeg" }, cover_jpeg ]
    end

    assert_no_difference [ "ActiveStorage::Blob.count", -> { Rails.configuration.event_store.read.of_type(Catalog::ShareImageStored).count } ] do
      assert_no_error_reported { CardShareImageJob.perform_now(card_season_id, "en") }
    end

    assert_nil stored
    assert_enqueued_jobs(1, only: CardShareImageJob) { CardShareImage.current_token(card_season_id:, view:, locale: :en) }
  ensure
    Rails.cache = cache_was
  end

  test "an image whose file is lost renders again under a new token" do
    stub_art
    CardShareImageJob.perform_now(card_season_id, "en")
    share_image = Catalog::ShareImage.find_by!(card_season_id:, locale: "en")
    share_image.image.blob.service.delete(share_image.image.blob.key)

    CardShareImageJob.perform_now(card_season_id, "en")

    assert_not_equal share_image.token, stored.token
    assert_equal [ "pngload_buffer", 1200, 630 ], png_size(Catalog::ShareImageByToken.call(stored.token))
  end

  test "a rerun on the stored fingerprint fetches nothing and writes nothing" do
    stub_art
    CardShareImageJob.perform_now(card_season_id, "en")
    token = stored.token
    stub_share_image_art

    assert_no_difference [ "ActiveStorage::Blob.count", -> { Rails.configuration.event_store.read.of_type(Catalog::ShareImageStored).count } ] do
      CardShareImageJob.perform_now(card_season_id, "en")
    end
    assert_equal token, stored.token
  end

  test "a changed card renders again under a new token" do
    stub_art
    CardShareImageJob.perform_now(card_season_id, "en")
    token = stored.token
    Catalog::CardText.where(card: catalog_cards(:rare_card), locale: "en").update_all(title: "Bluer Depths")

    CardShareImageJob.perform_now(card_season_id, "en")

    assert_not_equal token, stored.token
    assert_equal current_fingerprint(card_season_id, "en"), stored.fingerprint
  end

  test "an unusable art stores nothing and is reported" do
    [ -> { use_steam_art(card_season_id, "https://images.example.test/403.jpg") },
      -> { stub_art(status: 503) },
      -> { stub_art(body: "<html>") },
      -> { stub_art(body: cover_jpeg(width: 200, height: 300)) },
      -> { stub_art(body: grey_placeholder_jpeg) } ].each do |arrange|
      stub_share_image_art
      use_steam_art(card_season_id)
      arrange.call

      assert_error_reported(CardShareImage::Art::Unusable) { CardShareImageJob.perform_now(card_season_id, "en") }
      assert_nil stored
    end
  end

  test "after a card's change, only its stale image is rendered again" do
    stub_art
    CardShareImageJob.perform_now(card_season_id, "en")
    CardShareImageJob.perform_now(card_season_id, "fr")
    english, french = stored("en").token, stored("fr").token
    Catalog::CardText.where(card: catalog_cards(:rare_card), locale: "fr").update_all(title: "Profondeurs plus bleues")

    perform_enqueued_jobs(only: CardShareImageJob) do
      CardShareImage::Refresh.call(Catalog::CardIdentityUpserted.new(data: { card_id: catalog_cards(:rare_card).id }))
    end

    assert_equal english, stored("en").token
    assert_not_equal french, stored("fr").token
  end

  test "a failed render keeps the page from enqueueing it again past the hourly throttle" do
    cache_was = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    stub_art(body: grey_placeholder_jpeg)
    view = Catalog::CardViews.call([ card_season_id ], locale: "en").fetch(card_season_id)

    assert_error_reported(CardShareImage::Art::Unusable) { CardShareImageJob.perform_now(card_season_id, "en") }

    travel CardShareImage::RENDER_THROTTLE + 1.second do
      assert_no_enqueued_jobs(only: CardShareImageJob) { CardShareImage.current_token(card_season_id:, view:, locale: :en) }
    end
  ensure
    Rails.cache = cache_was
  end

  test "a rendered image the catalog refuses to store is reported" do
    draft = seed_card_seasons([ 1.0 ]).card_seasons.sole
    draft.update_columns(rarity: 3, number: 1)
    use_steam_art(draft.id)
    stub_art

    assert_error_reported(CardShareImageJob::NotStored) { CardShareImageJob.perform_now(draft.id, "en") }
    assert_equal 0, Catalog::ShareImage.count
  end

  test "a card-season outside a published season, an unknown one or an unknown locale renders nothing" do
    draft = seed_card_seasons([ 1.0 ]).card_seasons.sole

    assert_no_error_reported do
      CardShareImageJob.perform_now(draft.id, "en")
      CardShareImageJob.perform_now(0, "en")
      CardShareImageJob.perform_now(card_season_id, "de")
    end
    assert_equal 0, Catalog::ShareImage.count
  end
end
