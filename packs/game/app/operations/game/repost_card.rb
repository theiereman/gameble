module Game
  class RepostCard < Operation
    def call(player:, card_season_id:)
      player = step require_player(player)

      transaction do
        step held(player, card_season_id)
        step publish(CardReposted.new(data: { player_id: player.id, card_season_id: }), stream_name: stream_name(player.id))
      end
    end

    private

    def held(player, card_season_id)
      Quantities.call(player, [ card_season_id ]).key?(card_season_id) ? Success() : Failure(:card_not_owned)
    end
  end
end
