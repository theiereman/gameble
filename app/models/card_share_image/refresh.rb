module CardShareImage
  # Renders the card's stored images again once its change commits: the
  # job skips each one that still shows the card as it is.
  module Refresh
    EVENTS = [ Catalog::CardIdentityUpserted ].freeze

    def self.call(event)
      Catalog::ShareImagesOfCard.call(event.data[:card_id]).each do |image|
        CardShareImageJob.perform_later(image.card_season_id, image.locale)
      end
    end
  end
end
