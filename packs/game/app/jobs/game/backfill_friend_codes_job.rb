module Game
  # Gives every player who predates the game_friend_codes table their code
  # (AD-8), banned players included: one Game::CreateFriendCode per player.
  # A player whose creation fails is reported and skipped, so the others
  # still get theirs; a rerun is a no-op for those who have one.
  #
  # Run once after the deploy that creates the table:
  # `bin/rails game:backfill_friend_codes`.
  class BackfillFriendCodesJob < ActiveJob::Base
    queue_as :default

    # How many players, banned included, still have no code.
    def self.players_without_a_code
      Accounts::Player.where.not(id: FriendCode.select(:player_id)).count
    end

    def perform
      Accounts::PlayersInBatches.call(include_banned: true) do |players|
        with_code = FriendCode.where(player_id: players.map(&:id)).pluck(:player_id).to_set
        players.each do |player|
          next if with_code.include?(player.id)

          CreateFriendCode.new.call(player:).value!
        rescue StandardError => error
          Rails.error.report(error, context: { player_id: player.id })
        end
      end
    end
  end
end
