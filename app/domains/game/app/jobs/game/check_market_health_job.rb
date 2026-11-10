module Game
  class CheckMarketHealthJob < ActiveJob::Base
    queue_as :default

    STALE_AFTER_SECONDS = 5.minutes.to_i

    class StaleClose < StandardError; end

    def perform
      age_seconds = Market::OldestDueListing.call
      return if age_seconds.nil? || age_seconds <= STALE_AFTER_SECONDS

      Rails.error.report(StaleClose.new("an auction has been due for #{age_seconds} seconds"), handled: true, context: { age_seconds: })
    end
  end
end
