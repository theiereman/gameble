module Game
  class RefreshAltSignalsJob < ActiveJob::Base
    queue_as :default

    def perform(now: Time.current)
      Market::RefreshAltSignals.new.call(now:).value!
    end
  end
end
