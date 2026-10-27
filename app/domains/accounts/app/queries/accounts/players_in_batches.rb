module Accounts
  module PlayersInBatches
    BATCH_SIZE = 500

    def self.call(batch_size: BATCH_SIZE, include_banned: false, &block)
      players = Player.where(deleted_at: nil)
      players = players.where(banned_at: nil) unless include_banned
      players.find_in_batches(batch_size:, &block)
    end
  end
end
