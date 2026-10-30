require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/share_image_art"

# Catalog::StoreShareImage and the share image queries: one image per
# published card-season and language, replaced under a new token when its
# fingerprint changes, untouched when it does not.
class Catalog::StoreShareImageTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include CatalogSeeds
  include ShareImageArt

  FINGERPRINT = "a" * 64
  OTHER_FINGERPRINT = "b" * 64

  def card_season_id = catalog_card_seasons(:rare_card_one).id

  def store(fingerprint: FINGERPRINT, locale: "en", png: tiny_png, card_season_id: self.card_season_id, width: 4, height: 4)
    Catalog::StoreShareImage.new.call(card_season_id:, locale:, fingerprint:, png:, width:, height:)
  end

  def stored_events
    Rails.configuration.event_store.read.of_type(Catalog::ShareImageStored).to_a
  end

  test "a first image: its row with a token, its PNG with its size and no analysis to run, and one event" do
    png = tiny_png

    share_image = nil
    assert_no_enqueued_jobs(only: ActiveStorage::AnalyzeJob) { share_image = store(png:).value! }

    assert_match(/\A[1-9A-HJ-NP-Za-km-z]{24}\z/, share_image.token)
    assert_equal [ card_season_id, "en", FINGERPRINT ], share_image.reload.slice(:card_season_id, :locale, :fingerprint).values
    blob = share_image.image.blob
    assert_equal [ "image/png", "#{share_image.token}.png", png ], [ blob.content_type, blob.filename.to_s, blob.download ]
    assert_equal({ "analyzed" => true, "identified" => true, "width" => 4, "height" => 4 }, blob.metadata)
    assert_equal [ { share_image_id: share_image.id, card_season_id:, locale: "en" } ], stored_events.map(&:data)
    assert_equal stored_events.map(&:event_id),
      Rails.configuration.event_store.read.stream("Catalog::ShareImage$#{share_image.id}").map(&:event_id)
  end

  test "the fingerprint already stored writes nothing" do
    first = store.value!

    assert_no_difference [ "ActiveStorage::Blob.count", "Catalog::ShareImage.count", -> { stored_events.size } ] do
      assert_equal first, store(png: tiny_png(width: 6)).value!
    end
    assert_equal first.token, first.reload.token
  end

  test "a new fingerprint replaces the image under a new token, and the old blob is purged after commit" do
    first = store.value!
    old_token = first.token
    old_blob = first.image.blob

    replaced = nil
    assert_enqueued_with(job: ActiveStorage::PurgeJob, args: [ old_blob ]) do
      replaced = store(fingerprint: OTHER_FINGERPRINT, png: tiny_png(width: 6), width: 6).value!
    end

    assert_equal first.id, replaced.id
    assert_not_equal old_token, replaced.reload.token
    assert_equal OTHER_FINGERPRINT, replaced.fingerprint
    assert_equal 6, replaced.image.blob.metadata["width"]
    assert_equal 2, stored_events.size
    assert_nil Catalog::ShareImageByToken.call(old_token)
  end

  test "each language has its own image" do
    english = store.value!
    french = store(locale: "fr").value!

    assert_not_equal english.token, french.token
    assert_equal %w[en fr], Catalog::ShareImage.where(card_season_id:).order(:locale).pluck(:locale)
  end

  test "a card-season outside a published season is refused, nothing written" do
    draft = seed_card_seasons([ 1.0 ]).card_seasons.sole

    assert_no_difference [ "ActiveStorage::Blob.count", "Catalog::ShareImage.count", -> { stored_events.size } ] do
      assert_equal :card_season_not_published, store(card_season_id: draft.id).failure
      assert_equal :card_season_not_published, store(card_season_id: 0).failure
    end
  end

  test "a malformed locale, fingerprint, PNG or size is refused" do
    [ { locale: "de" }, { locale: nil }, { fingerprint: "abc" }, { fingerprint: nil }, { png: "GIF89a" }, { png: nil },
      { width: 0 }, { height: "630" } ].each do |overrides|
      assert_equal :invalid_share_image, store(**overrides).failure, overrides.inspect
    end
    assert_equal 0, Catalog::ShareImage.count
  end

  test "a locale given as a symbol is the same language" do
    assert_equal "fr", store(locale: :fr).value!.locale
  end

  test "the queries: the stored token and fingerprint, the PNG by token, the images of a card" do
    png = tiny_png
    share_image = store(png:).value!
    store(locale: "fr", fingerprint: OTHER_FINGERPRINT)

    assert_equal Catalog::ShareImageFor::Stored.new(token: share_image.token, fingerprint: FINGERPRINT),
      Catalog::ShareImageFor.call(card_season_id:, locale: :en)
    assert_nil Catalog::ShareImageFor.call(card_season_id: catalog_card_seasons(:portal_one).id, locale: "en")

    assert_equal png, Catalog::ShareImageByToken.call(share_image.token)
    [ "A" * 24, "", nil, 42 ].each { assert_nil Catalog::ShareImageByToken.call(it) }

    assert_equal [ [ card_season_id, "en", FINGERPRINT ], [ card_season_id, "fr", OTHER_FINGERPRINT ] ],
      Catalog::ShareImagesOfCard.call(catalog_cards(:rare_card).id).map(&:to_h).map(&:values).sort
    assert_empty Catalog::ShareImagesOfCard.call(catalog_cards(:portal).id)
  end

  test "a stored image whose file is gone is not found" do
    share_image = store.value!
    share_image.image.blob.service.delete(share_image.image.blob.key)

    assert_nil Catalog::ShareImageByToken.call(share_image.token)
  end
end
