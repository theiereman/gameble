module Game
  # Creates a player's game state row (Game::PlayerState, AD-10): inserted
  # with ON CONFLICT DO NOTHING, so a player who has one keeps it and a rerun
  # changes nothing. Housekeeping: it publishes no event (AD-10).
  #
  # Any persisted player gets one, a banned player included (their row must
  # exist like anyone's), hence its own check rather than `require_player`.
  #
  # Called on sign-up after the bank fill (Game::Handlers::PlayerRegistered),
  # and for the players who predate the table by
  # Game::BackfillPlayerStatesJob.
  #
  #   Game::CreatePlayerState.new.call(player:)
  #   # => Success(state) | Failure(:player_required)
  class CreatePlayerState < Operation
    def call(player:)
      player = step require_account(player)

      transaction do
        PlayerState.insert({ player_id: player.id }, unique_by: :player_id)
        PlayerState.find_by!(player_id: player.id)
      end
    end
  end
end
