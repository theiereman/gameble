module Catalog
  # Stores the link-preview PNG of a published card-season in one language.
  # A new fingerprint gets a new image under a new token, so an image cached
  # for a year under the old token is never served for the new one; the
  # fingerprint already stored writes nothing.
  class StoreShareImage < ApplicationOperation
    PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze
    CONTENT_TYPE = "image/png".freeze

    def call(card_season_id:, locale:, fingerprint:, png:, width:, height:)
      locale = locale.to_s
      step validate(locale:, fingerprint:, png:, width:, height:)

      transaction do
        step lock_published_card_season(card_season_id)
        share_image = ShareImage.find_by(card_season_id:, locale:)
        if share_image&.fingerprint == fingerprint
          share_image
        else
          share_image = step replace(share_image || ShareImage.new(card_season_id:, locale:), fingerprint:, png:, width:, height:)
          step publish(ShareImageStored.new(data: { share_image_id: share_image.id, card_season_id:, locale: }),
            stream_name: ShareImage.stream_name(share_image.id))
          share_image
        end
      end
    end

    private

    def validate(locale:, fingerprint:, png:, width:, height:)
      valid = ShareImage::LOCALES.include?(locale) && fingerprint.is_a?(String) && ShareImage::FINGERPRINT.match?(fingerprint) &&
        png.is_a?(String) && png.b.start_with?(PNG_SIGNATURE) && [ width, height ].all? { it.is_a?(Integer) && it.positive? }
      valid ? Success() : Failure(:invalid_share_image)
    end

    # Writers of one card-season's images queue on its row; the season row stays free.
    def lock_published_card_season(card_season_id)
      locked = CardSeason.joins(:season).where(id: card_season_id, catalog_seasons: { status: "published" }).where.not(rarity: nil)
        .lock("FOR NO KEY UPDATE OF catalog_card_seasons").pick(:id)
      locked ? Success(locked) : Failure(:card_season_not_published)
    end

    def replace(share_image, fingerprint:, png:, width:, height:)
      share_image.token = ShareImage.generate_unique_secure_token(length: 24)
      share_image.fingerprint = fingerprint
      share_image.image = upload(png, share_image.token, width:, height:)
      share_image.save!
      Success(share_image)
    end

    def upload(png, token, width:, height:)
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), filename: "#{token}.png", content_type: CONTENT_TYPE,
        identify: false, metadata: { analyzed: true, identified: true, width:, height: })
    end
  end
end
