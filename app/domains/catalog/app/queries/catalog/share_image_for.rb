module Catalog
  module ShareImageFor
    Stored = Data.define(:token, :fingerprint)

    def self.call(card_season_id:, locale:)
      token, fingerprint, key, service_name = ShareImage.joins(image_attachment: :blob).where(card_season_id:, locale: locale.to_s)
        .pick(:token, :fingerprint, "active_storage_blobs.key", "active_storage_blobs.service_name")
      Stored.new(token:, fingerprint:) if token && ShareImage.file_stored?(key:, service_name:)
    end
  end
end
