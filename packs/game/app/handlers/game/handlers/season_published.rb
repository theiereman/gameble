module Game
  module Handlers
    # When a season is published, the players who never had a pack get their
    # bank (Game::FillEmptyBanksJob), enqueued once the publication commits.
    module SeasonPublished
      def self.call(_event)
        ActiveRecord.after_all_transactions_commit { FillEmptyBanksJob.perform_later }
      end
    end
  end
end
