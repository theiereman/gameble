module Accounts
  # Every player in good standing (not banned), yielded in batches by
  # ascending id, for jobs that walk all players (AD-3).
  #
  #   Accounts::PlayersInBatches.call { |players| … }
  module PlayersInBatches
    BATCH_SIZE = 500

    def self.call(batch_size: BATCH_SIZE, &block)
      Player.where(banned_at: nil).find_in_batches(batch_size:, &block)
    end
  end
end
