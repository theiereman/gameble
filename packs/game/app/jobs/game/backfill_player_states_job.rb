module Game
  # Gives every player who predates the game_player_states table their row
  # (AD-28: created, then backfilled), banned players included: one
  # Game::CreatePlayerState per player, each in its own transaction (AD-14).
  # Per batch, one query reads which players already have a row; they cost
  # nothing more, so a rerun is a no-op. A player whose creation fails is
  # reported and skipped, so the others still get their row.
  #
  # Run once after the deploy that creates the table:
  # `bin/rails game:backfill_player_states`.
  class BackfillPlayerStatesJob < ActiveJob::Base
    queue_as :default

    # How many players, banned included (deleted ones left out), still have
    # no row: what a run left behind (game:backfill_player_states reports it).
    def self.players_without_a_row
      Accounts::Player.where(deleted_at: nil).where.not(id: PlayerState.select(:player_id)).count
    end

    def perform
      Accounts::PlayersInBatches.call(include_banned: true) do |players|
        with_state = PlayerState.where(player_id: players.map(&:id)).pluck(:player_id).to_set
        players.each do |player|
          next if with_state.include?(player.id)

          CreatePlayerState.new.call(player:).value!
        rescue StandardError => error
          Rails.error.report(error, context: { player_id: player.id })
        end
      end
    end
  end
end
