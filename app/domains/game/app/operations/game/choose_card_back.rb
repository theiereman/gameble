module Game
  class ChooseCardBack < Operation
    def call(player:, back:)
      player = step require_player(player)
      back = step known(back)

      transaction do
        step lock_bank(player)
        step unlocked(player, back)
        store(player, back)
        step publish(CardBackChosen.new(data: { player_id: player.id, back: back.key }), stream_name: stream_name(player.id))
        back
      end
    end

    private

    def known(key)
      back = CardBacks.find(key)
      back ? Success(back) : Failure(:unknown_back)
    end

    def unlocked(player, back)
      return Success() if back.key == CardBacks::STANDARD

      CardBackUnlock.exists?(player_id: player.id, back: back.key) ? Success() : Failure(:back_locked)
    end

    def store(player, back)
      PlayerState.insert({ player_id: player.id }, unique_by: :player_id)
      PlayerState.where(player_id: player.id).update_all(active_card_back: back.key, updated_at: Time.current)
    end
  end
end
