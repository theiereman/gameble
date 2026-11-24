module Game
  class OpenArchiveAuctionsJob < ActiveJob::Base
    queue_as :default

    def perform(now: Time.current)
      Market::ArchiveAuctionPicks.call(now:).each do |card_season_id|
        result = Market::OpenArchiveAuction.new.call(card_season_id:, now:)
        result.value! unless result.failure == :market_closed
      end
    end
  end
end
