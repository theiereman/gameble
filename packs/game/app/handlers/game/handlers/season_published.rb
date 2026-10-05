module Game
  module Handlers
    # When a season is published, every player's bank is filled or topped up
    # to ten (Game::HealBanksJob). The job leaves once the publication
    # commits (enqueue_after_transaction_commit, AD-13).
    module SeasonPublished
      def self.call(_event)
        HealBanksJob.perform_later
      end
    end
  end
end
