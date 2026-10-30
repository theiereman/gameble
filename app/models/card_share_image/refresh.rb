module CardShareImage
  module Refresh
    EVENTS = [ Catalog::CardIdentityUpserted ].freeze

    def self.call(event)
      Catalog::ShareImagesOfCard.call(event.data[:card_id]).each do |image|
        CardShareImageJob.perform_later(image.card_season_id, image.locale)
      end
    end
  end
end
