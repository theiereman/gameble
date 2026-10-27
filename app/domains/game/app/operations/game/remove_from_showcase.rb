module Game
  class RemoveFromShowcase < Operation
    def call(player:, card_season_id:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        entry = step showcased(player, card_season_id)
        ShowcaseEntry.remove(entry)
        step publish(ShowcaseCardRemoved.new(data: { player_id: player.id, card_season_id: }), stream_name: stream_name(player.id))
      end
    end

    private

    def showcased(player, card_season_id)
      entry = ShowcaseEntry.find_by(player_id: player.id, card_season_id:)
      entry ? Success(entry) : Failure(:card_not_showcased)
    end
  end
end
