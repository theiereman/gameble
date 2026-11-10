module Game
  class ArchiveStocksJob < ActiveJob::Base
    queue_as :default

    def perform(now: Time.current)
      Market::SumArchiveStocks.new.call(now:).value!
    end
  end
end
