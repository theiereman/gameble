require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/share_image_art"

# Catalog::StoreShareImage and the share image queries: one image per
# published card-season and language, replaced under a new token when its
# fingerprint changes or its file is lost, untouched when it does not; the
# PNG uploaded before the transaction, a render the card has outgrown
# refused, and no file left behind by what is not stored.
class Catalog::StoreShareImageTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include CatalogSeeds
  include ShareImageArt

  FINGERPRINT = "a" * 64
  OTHER_FINGERPRINT = "b" * 64

  def card_season_id = catalog_card_seasons(:rare_card_one).id

  def store(fingerprint: FINGERPRINT, locale: "en", png: tiny_png, card_season_id: self.card_season_id, width: 4, height: 4,
    current_fingerprint: -> { fingerprint })
    Catalog::StoreShareImage.new.call(card_season_id:, locale:, fingerprint:, png:, width:, height:, current_fingerprint:)
  end

  def stored_events
    Rails.configuration.event_store.read.of_type(Catalog::ShareImageStored).to_a
  end

  def service = ActiveStorage::Blob.service

  def open_transactions = ActiveRecord::Base.connection.open_transactions

  # The files the block uploads, each with the transactions open at its upload.
  def recording_uploads
    uploads = []
    upload = service.method(:upload)
    service.define_singleton_method(:upload) do |key, io, **options|
      uploads << { key:, open_transactions: ActiveRecord::Base.connection.open_transactions }
      upload.call(key, io, **options)
    end
    yield uploads
    uploads
  ensure
    service.singleton_class.send(:remove_method, :upload)
  end

  def assert_no_file_left(uploads)
    assert_not_empty uploads
    uploads.each { assert_not service.exist?(it[:key]), "#{it[:key]} left in storage" }
  end

  def lose_file(share_image)
    service.delete(share_image.image.blob.key)
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

    uploads = nil
    assert_no_difference [ "ActiveStorage::Blob.count", "Catalog::ShareImage.count", -> { stored_events.size } ] do
      uploads = recording_uploads { assert_equal first, store(png: tiny_png(width: 6)).value! }
    end
    assert_equal first.token, first.reload.token
    assert service.exist?(first.image.blob.key)
    assert_no_file_left(uploads)
  end

  test "the PNG is uploaded before the transaction opens, and its file is there when the card-season is locked" do
    outside = open_transactions
    file_when_locked = nil
    uploads = recording_uploads do |so_far|
      store(current_fingerprint: -> { file_when_locked = service.exist?(so_far.sole[:key]) && open_transactions > outside; FINGERPRINT })
        .value!
    end

    assert_equal [ outside ], uploads.map { it[:open_transactions] }
    assert service.exist?(uploads.sole[:key])
    assert file_when_locked
  end

  test "a render the card has outgrown is refused: no row changed, no event, no file left" do
    first = store.value!

    uploads = nil
    assert_no_difference [ "ActiveStorage::Blob.count", "Catalog::ShareImage.count", -> { stored_events.size } ] do
      uploads = recording_uploads do
        assert_equal :stale_render, store(fingerprint: OTHER_FINGERPRINT, current_fingerprint: -> { FINGERPRINT }).failure
        assert_equal :stale_render, store(locale: "fr", current_fingerprint: -> { nil }).failure
      end
    end

    assert_equal [ first.token, FINGERPRINT ], first.reload.slice(:token, :fingerprint).values
    assert_no_file_left(uploads)
  end

  test "a stored image whose file is lost is not found, and its fingerprint stores again under a new token" do
    first = store.value!
    lose_file(first)

    assert_nil Catalog::ShareImageFor.call(card_season_id:, locale: "en")
    first.image.blob.update_columns(service_name: "gone")
    assert_nil Catalog::ShareImageFor.call(card_season_id:, locale: "en")

    replaced = store.value!
    assert_equal first.id, replaced.id
    assert_not_equal first.token, replaced.reload.token
    assert service.exist?(replaced.image.blob.key)
    assert_equal 2, stored_events.size
    assert_equal Catalog::ShareImageFor::Stored.new(token: replaced.token, fingerprint: FINGERPRINT),
      Catalog::ShareImageFor.call(card_season_id:, locale: "en")
  end

  test "an error inside the transaction rolls it back and leaves no file" do
    uploads = recording_uploads do
      assert_raises(RuntimeError) { store(current_fingerprint: -> { raise "the card could not be read" }) }
    end

    assert_equal 0, Catalog::ShareImage.count
    assert_empty stored_events
    assert_no_file_left(uploads)
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

    uploads = nil
    assert_no_difference [ "ActiveStorage::Blob.count", "Catalog::ShareImage.count", -> { stored_events.size } ] do
      uploads = recording_uploads do
        assert_equal :card_season_not_published, store(card_season_id: draft.id).failure
        assert_equal :card_season_not_published, store(card_season_id: 0).failure
      end
    end
    assert_no_file_left(uploads)
  end

  test "a malformed locale, fingerprint, PNG, size or card fingerprint is refused before any upload" do
    uploads = recording_uploads do
      [ { locale: "de" }, { locale: nil }, { fingerprint: "abc" }, { fingerprint: nil }, { png: "GIF89a" }, { png: nil },
        { width: 0 }, { height: "630" }, { current_fingerprint: FINGERPRINT }, { current_fingerprint: nil } ].each do |overrides|
        assert_equal :invalid_share_image, store(**overrides).failure, overrides.inspect
      end
    end
    assert_equal 0, Catalog::ShareImage.count
    assert_empty uploads
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
