module Game
  class ComputeDuelStatsJob < ActiveJob::Base
    queue_as :default

    def perform(reason = "weekly")
      ComputeDuelStats.new.call(reason:).value!
    end
  end
end
