module Game
  class ComputeDuelStatsJob < ActiveJob::Base
    queue_as :default

    def perform(reason)
      ComputeDuelStats.new.call(reason:).value!
    end
  end
end
