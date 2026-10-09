module Game
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
