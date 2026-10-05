module Accounts
  # Every player in good standing (not banned), yielded in batches by
  # ascending id, for jobs that walk all players (AD-3, AD-14).
  # `include_banned: true` yields banned players too, for work every player's
  # rows need whatever their standing (Game::BackfillPlayerStatesJob).
  #
  #   Accounts::PlayersInBatches.call { |players| … }
  #   Accounts::PlayersInBatches.call(include_banned: true) { |players| … }
  module PlayersInBatches
    BATCH_SIZE = 500

    def self.call(batch_size: BATCH_SIZE, include_banned: false, &block)
      players = include_banned ? Player.all : Player.where(banned_at: nil)
      players.find_in_batches(batch_size:, &block)
    end
  end
end
