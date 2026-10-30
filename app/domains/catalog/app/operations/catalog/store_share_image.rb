module Catalog
  class StoreShareImage < ApplicationOperation
    PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze
    CONTENT_TYPE = "image/png".freeze

    def call(card_season_id:, locale:, fingerprint:, png:, width:, height:, current_fingerprint:)
      locale = locale.to_s
      step validate(locale:, fingerprint:, png:, width:, height:, current_fingerprint:)
      token = ShareImage.generate_unique_secure_token(length: 24)
      blob = build_blob(png, token, width:, height:)
      blob.upload_without_unfurling(StringIO.new(png))

      stored = transaction do
        step lock_published_card_season(card_season_id)
        step refuse_stale(fingerprint, current_fingerprint)
        share_image = ShareImage.find_by(card_season_id:, locale:)
        if share_image&.fingerprint == fingerprint && share_image.file_stored?
          share_image
        else
          share_image = step replace(share_image || ShareImage.new(card_season_id:, locale:), token:, blob:, fingerprint:)
          step publish(ShareImageStored.new(data: { share_image_id: share_image.id, card_season_id:, locale: }),
            stream_name: ShareImage.stream_name(share_image.id))
          share_image
        end
      end
    ensure
      discard_unless_attached(blob, stored)
    end

    private

    def validate(locale:, fingerprint:, png:, width:, height:, current_fingerprint:)
      valid = ShareImage::LOCALES.include?(locale) && fingerprint.is_a?(String) && ShareImage::FINGERPRINT.match?(fingerprint) &&
        png.is_a?(String) && png.b.start_with?(PNG_SIGNATURE) && [ width, height ].all? { it.is_a?(Integer) && it.positive? } &&
        current_fingerprint.respond_to?(:call)
      valid ? Success() : Failure(:invalid_share_image)
    end

    def lock_published_card_season(card_season_id)
      locked = CardSeason.joins(:season).where(id: card_season_id, catalog_seasons: { status: "published" }).where.not(rarity: nil)
        .lock("FOR NO KEY UPDATE OF catalog_card_seasons").pick(:id)
      locked ? Success(locked) : Failure(:card_season_not_published)
    end

    def refuse_stale(fingerprint, current_fingerprint)
      current_fingerprint.call == fingerprint ? Success() : Failure(:stale_render)
    end

    def replace(share_image, token:, blob:, fingerprint:)
      share_image.token = token
      share_image.fingerprint = fingerprint
      share_image.image = blob
      share_image.save!
      Success(share_image)
    end

    def build_blob(png, token, width:, height:)
      ActiveStorage::Blob.build_after_unfurling(io: StringIO.new(png), filename: "#{token}.png", content_type: CONTENT_TYPE,
        identify: false, metadata: { analyzed: true, identified: true, width:, height: })
    end

    def discard_unless_attached(blob, share_image)
      blob.delete if blob && share_image&.image&.blob != blob
    end
  end
end
