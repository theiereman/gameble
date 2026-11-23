module Game
  class CheckMarketHealthJob < ActiveJob::Base
    queue_as :default

    STALE_AFTER_SECONDS = 5.minutes.to_i

    class StaleClose < StandardError; end
    class StaleExpiry < StandardError; end

    def perform
      report_stale(StaleClose, "an auction", Market::OldestDueListing.call)
      report_stale(StaleExpiry, "a buy order", Market::OldestDueOrder.call)
    end

    private

    def report_stale(error, subject, age_seconds)
      return if age_seconds.nil? || age_seconds <= STALE_AFTER_SECONDS

      Rails.error.report(error.new("#{subject} has been due for #{age_seconds} seconds"), handled: true, context: { age_seconds: })
    end
  end
end
