module Game
  module Handlers
    # When a season is published, every player's bank is filled or topped up
    # to ten (Game::HealBanksJob), enqueued once the publication commits.
    module SeasonPublished
      def self.call(_event)
        ActiveRecord.after_all_transactions_commit { HealBanksJob.perform_later }
      end
    end
  end
end
