module Catalog
  module ShareImageFor
    Stored = Data.define(:token, :fingerprint)

    def self.call(card_season_id:, locale:)
      row = ShareImage.where(card_season_id:, locale: locale.to_s).pick(:token, :fingerprint)
      row && Stored.new(*row)
    end
  end
end
