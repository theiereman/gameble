module Game
  class CreatePlayerState < Operation
    def call(player:)
      player = step require_account(player)

      transaction do
        step lock_bank(player)
        published = Catalog::PublishedSeason.call&.number
        PlayerState.insert({ player_id: player.id, allocation_received_season: published, allocation_seen_season: published }, unique_by: :player_id)
        PlayerState.find_by!(player_id: player.id)
      end
    end
  end
end
